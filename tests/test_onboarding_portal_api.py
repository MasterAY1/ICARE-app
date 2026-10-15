"""
Unit & Integration tests for Branch Onboarding REST API and Domain Engine.
Verifies token generation, public guest session retrieval, Excel uploading,
draft saving with 14-day auto-extension, validation rules, atomic commitment,
and Option B dynamic multi-officer auto-sequence collision guard.
"""
import io
import unittest
from fastapi.testclient import TestClient
from api.main import app
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.onboarding_service import OnboardingService

client = TestClient(app)

class TestOnboardingPortalApi(unittest.TestCase):

    def setUp(self):
        self.uow = SupabaseUnitOfWork()
        self._cleanup()

    def tearDown(self):
        self._cleanup()

    def _cleanup(self):
        try:
            self.uow.client.table("branch_onboarding_sessions").delete().eq("branch_code", "TST").execute()
            b_res = self.uow.client.table("branches").select("branch_id").eq("code", "TST").execute()
            if b_res.data:
                bid = b_res.data[0]["branch_id"]
                self.uow.client.table("individual_savings").delete().eq("branch_id", bid).execute()
                self.uow.client.table("group_savings").delete().eq("branch_id", bid).execute()
                self.uow.client.table("client_memberships").delete().eq("branch_id", bid).execute()
                self.uow.client.table("loans").delete().eq("branch_id", bid).execute()
                self.uow.client.table("clients").delete().eq("branch_id", bid).execute()
                self.uow.client.table("groups").delete().eq("branch_id", bid).execute()
                self.uow.client.table("branches").delete().eq("branch_id", bid).execute()
        except Exception:
            pass

    def test_onboarding_lifecycle_via_api(self):
        # 1. Create a session directly via service
        session = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Test Automation Branch",
            branch_code="TST",
            contact_person="Tester",
            contact_phone="08099998888"
        )
        token = session["token"]
        self.assertTrue(token.startswith("onb_tst_"))

        # 2. Public GET /session/{token}
        res_get = client.get(f"/api/v1/onboarding/session/{token}")
        self.assertEqual(res_get.status_code, 200)
        data = res_get.json()
        self.assertEqual(data["session"]["branch_name"], "Test Automation Branch")
        self.assertGreaterEqual(len(data["loan_products"]), 10)
        self.assertIn("Daily", data["meeting_days"])

        # 3. Save Draft via PUT /session/{token}/save-draft
        payload = {
            "groups": [
                {
                    "group_reference": "GRP-01",
                    "group_name": "Progress Solidarity",
                    "meeting_day": "Tuesday",
                    "leader_name": "Mrs. Adeola",
                    "group_savings": 25000.0
                }
            ],
            "members": [
                {
                    "member_reference": "TST-01-001",
                    "group_reference": "GRP-01",
                    "member_number": 1,
                    "full_name": "Ayodele Bello",
                    "phone_number": "08012345678",
                    "home_address": "12 Market Street",
                    "savings_balance": 5000.0,
                    "loan_type": "Daily 60 Days",
                    "principal_loan": 100000.0,
                    "active_credit": 99000.0,
                    "current_credit_balance": 49500.0
                }
            ]
        }
        res_save = client.put(f"/api/v1/onboarding/session/{token}/save-draft", json={"payload": payload})
        self.assertEqual(res_save.status_code, 200)
        save_data = res_save.json()
        self.assertEqual(save_data["aggregates"]["total_groups"], 1)
        self.assertEqual(save_data["aggregates"]["total_members"], 1)
        self.assertEqual(save_data["aggregates"]["total_savings"], 5000.0)
        self.assertEqual(save_data["aggregates"]["total_active_credit"], 99000.0)
        self.assertEqual(save_data["aggregates"]["total_current_balance"], 49500.0)
        self.assertTrue(save_data["validation_summary"]["is_valid"])

        # 4. Submit via POST /session/{token}/submit
        res_submit = client.post(f"/api/v1/onboarding/session/{token}/submit")
        self.assertEqual(res_submit.status_code, 200)

        # 5. Verify status is submitted
        res_check = client.get(f"/api/v1/onboarding/session/{token}")
        self.assertEqual(res_check.json()["session"]["status"], "submitted")

    def test_upload_excel_template(self):
        session = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Test Excel Branch",
            branch_code="TST",
            contact_person="Tester",
            contact_phone="08099998888"
        )
        token = session["token"]

        with open("storage/workbooks/icare-group-member-onboarding-template-Ogijo-Oct2026.xlsx", "rb") as f:
            file_bytes = f.read()

        response = client.post(
            f"/api/v1/onboarding/session/{token}/upload-excel",
            files={"file": ("onboarding.xlsx", file_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")}
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "success")
        self.assertEqual(data["aggregates"]["total_groups"], 51)
        self.assertEqual(data["aggregates"]["total_members"], 424)
        self.assertTrue(data["validation_summary"]["is_valid"])

    def test_option_b_multi_officer_auto_offset_collision_guard(self):
        """
        Verifies Option B: When two officers onboard clients for the same branch and
        both create group 'GRP-01', the second session automatically offsets its group
        number to 2 and its client codes to TST-02-xxx, with ZERO data overwrite.
        """
        self._cleanup()

        # Session A: Officer 1 creates Group 1 and Member 1
        session_a = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Test Automation Branch",
            branch_code="TST",
            contact_person="Officer 1",
            contact_phone="08011111111"
        )
        token_a = session_a["token"]

        payload_a = {
            "groups": [
                {
                    "group_reference": "GRP-01",
                    "group_name": "Officer 1 Group",
                    "meeting_day": "Monday",
                    "leader_name": "Leader A",
                    "group_savings": 1000.0
                }
            ],
            "members": [
                {
                    "member_reference": "TST-01-001",
                    "group_reference": "GRP-01",
                    "member_number": 1,
                    "full_name": "Officer 1 Client A",
                    "phone_number": "08011112222",
                    "home_address": "Street 1",
                    "savings_balance": 2000.0,
                    "loan_type": "Daily 60 Days",
                    "principal_loan": 50000.0,
                    "active_credit": 45000.0,
                    "current_credit_balance": 30000.0
                }
            ]
        }
        client.put(f"/api/v1/onboarding/session/{token_a}/save-draft", json={"payload": payload_a})
        client.post(f"/api/v1/onboarding/session/{token_a}/submit")
        OnboardingService.commit_session(uow=self.uow, session_id=session_a["id"])

        # Verify Session A resulted in group_number 1 and client code TST-01-001
        res_g1 = self.uow.client.table("groups").select("group_id, group_number, name").eq("name", "Officer 1 Group").execute()
        self.assertEqual(len(res_g1.data), 1)
        self.assertEqual(res_g1.data[0]["group_number"], "1")

        res_c1 = self.uow.client.table("clients").select("client_id, client_code, name").eq("client_code", "TST-01-001").execute()
        self.assertEqual(len(res_c1.data), 1)
        self.assertEqual(res_c1.data[0]["name"], "Officer 1 Client A")

        # Session B: Officer 2 also onboards for branch TST
        session_b = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Test Automation Branch",
            branch_code="TST",
            contact_person="Officer 2",
            contact_phone="08022222222"
        )
        token_b = session_b["token"]

        # Check smart UI suggestion Layer 1: next_branch_group_number must be 2
        res_get_b = client.get(f"/api/v1/onboarding/session/{token_b}")
        self.assertEqual(res_get_b.status_code, 200)
        self.assertEqual(res_get_b.json()["session"]["next_branch_group_number"], 2)

        # Even if Officer 2 ALSO used "GRP-01" and member_number 1:
        payload_b = {
            "groups": [
                {
                    "group_reference": "GRP-01",
                    "group_name": "Officer 2 Group",
                    "meeting_day": "Tuesday",
                    "leader_name": "Leader B",
                    "group_savings": 5000.0
                }
            ],
            "members": [
                {
                    "member_reference": "TST-01-001",
                    "group_reference": "GRP-01",
                    "member_number": 1,
                    "full_name": "Officer 2 Client B",
                    "phone_number": "08033334444",
                    "home_address": "Street 2",
                    "savings_balance": 3000.0,
                    "loan_type": "Daily 60 Days",
                    "principal_loan": 60000.0,
                    "active_credit": 54000.0,
                    "current_credit_balance": 36000.0
                }
            ]
        }
        client.put(f"/api/v1/onboarding/session/{token_b}/save-draft", json={"payload": payload_b})
        client.post(f"/api/v1/onboarding/session/{token_b}/submit")
        OnboardingService.commit_session(uow=self.uow, session_id=session_b["id"])

        # Verify Option B:
        # 1. Officer 1's group is UNTOUCHED
        res_g1_after = self.uow.client.table("groups").select("group_id, group_number, name").eq("name", "Officer 1 Group").execute()
        self.assertEqual(len(res_g1_after.data), 1)
        self.assertEqual(res_g1_after.data[0]["group_number"], "1")

        # 2. Officer 1's member is UNTOUCHED
        res_c1_after = self.uow.client.table("clients").select("client_id, client_code, name").eq("client_code", "TST-01-001").execute()
        self.assertEqual(len(res_c1_after.data), 1)
        self.assertEqual(res_c1_after.data[0]["name"], "Officer 1 Client A")

        # 3. Officer 2's group was auto-offset to group_number "2"
        res_g2 = self.uow.client.table("groups").select("group_id, group_number, name").eq("name", "Officer 2 Group").execute()
        self.assertEqual(len(res_g2.data), 1)
        self.assertEqual(res_g2.data[0]["group_number"], "2")

        # 4. Officer 2's member was auto-assigned client_code "TST-02-001"
        res_c2 = self.uow.client.table("clients").select("client_id, client_code, name").eq("client_code", "TST-02-001").execute()
        self.assertEqual(len(res_c2.data), 1)
        self.assertEqual(res_c2.data[0]["name"], "Officer 2 Client B")

        # Cleanup after test
        self._cleanup()

if __name__ == "__main__":
    unittest.main()
