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
                self.uow.client.table("internal_savings").delete().eq("branch_id", bid).execute()
                self.uow.client.table("laps_savings").delete().eq("branch_id", bid).execute()
                self.uow.client.table("individual_savings").delete().eq("branch_id", bid).execute()
                self.uow.client.table("group_savings").delete().eq("branch_id", bid).execute()
                self.uow.client.table("client_memberships").delete().eq("branch_id", bid).execute()
                self.uow.client.table("loans").delete().eq("branch_id", bid).execute()
                self.uow.client.table("clients").delete().eq("branch_id", bid).execute()
                self.uow.client.table("groups").delete().eq("branch_id", bid).execute()
                u_res = self.uow.client.table("app_users").select("id").eq("branch_id", bid).execute()
                for u in (u_res.data or []):
                    self.uow.client.table("user_roles").delete().eq("user_id", u["id"]).execute()
                self.uow.client.table("app_users").delete().eq("branch_id", bid).execute()
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

    def test_officer_provisioning_and_pooled_savings_migration(self):
        """
        Verifies:
        1. Credit officers are provisioned into app_users and assigned role 'Credit Officer' in user_roles.
        2. Designated Misc Savings officer is persisted to branches.extra_fields (BR-SAV-006).
        3. Groups, clients, memberships, individual savings, and loans are assigned officer_id.
        4. Misc Savings is ingested into internal_savings with designated officer_id.
        5. LAPS Savings reserve is ingested into laps_savings.
        """
        self._cleanup()

        session = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Test Automation Branch",
            branch_code="TST",
            contact_person="Admin Coordinator",
            contact_phone="08022223333"
        )
        token = session["token"]

        payload = {
            "officers": [
                {
                    "name": "Olajumoke Bakare",
                    "phone": "08011223344",
                    "role": "Credit Officer",
                    "is_misc_savings_manager": True
                },
                {
                    "name": "Babatunde Lawal",
                    "phone": "08099887766",
                    "role": "Credit Officer",
                    "is_misc_savings_manager": False
                }
            ],
            "groups": [
                {
                    "group_reference": "GRP-01",
                    "group_name": "Progress Solidarity",
                    "meeting_day": "Tuesday",
                    "leader_name": "Mrs. Adeola",
                    "officer_name": "Olajumoke Bakare",
                    "officer_phone": "08011223344",
                    "group_savings": 20000.0
                },
                {
                    "group_reference": "GRP-02",
                    "group_name": "Success Group",
                    "meeting_day": "Thursday",
                    "leader_name": "Mr. Joseph",
                    "officer_name": "Babatunde Lawal",
                    "officer_phone": "08099887766",
                    "group_savings": 15000.0
                }
            ],
            "members": [
                {
                    "member_reference": "TST-01-001",
                    "group_reference": "GRP-01",
                    "member_number": 1,
                    "full_name": "Client A",
                    "phone_number": "08012345678",
                    "savings_balance": 5000.0,
                    "loan_type": "Daily 60 Days",
                    "principal_loan": 100000.0,
                    "active_credit": 99000.0,
                    "current_credit_balance": 49500.0
                },
                {
                    "member_reference": "TST-02-001",
                    "group_reference": "GRP-02",
                    "member_number": 1,
                    "full_name": "Client B",
                    "phone_number": "08087654321",
                    "savings_balance": 8000.0,
                    "loan_type": "Daily 60 Days",
                    "principal_loan": 50000.0,
                    "active_credit": 49500.0,
                    "current_credit_balance": 25000.0
                }
            ],
            "misc_savings": 35000.0,
            "laps_savings": 18500.0
        }

        save_res = client.put(f"/api/v1/onboarding/session/{token}/save-draft", json={"payload": payload})
        self.assertEqual(save_res.status_code, 200)

        submit_res = client.post(f"/api/v1/onboarding/session/{token}/submit")
        self.assertEqual(submit_res.status_code, 200)

        commit_res = OnboardingService.commit_session(uow=self.uow, session_id=session["id"])
        self.assertEqual(commit_res["status"], "success")
        self.assertEqual(commit_res["officers_provisioned"], 2)
        self.assertEqual(commit_res["misc_savings_posted"], 35000.0)
        self.assertEqual(commit_res["laps_savings_posted"], 18500.0)

        # 1. Verify app_users & user_roles
        b_res = self.uow.client.table("branches").select("branch_id, officer_assignments").eq("code", "TST").execute()
        self.assertTrue(bool(b_res.data))
        b_id = b_res.data[0]["branch_id"]
        b_assignments = b_res.data[0].get("officer_assignments") or []

        u_res = self.uow.client.table("app_users").select("id, username, full_name, extra_fields").eq("branch_id", b_id).execute()
        self.assertEqual(len(u_res.data), 2)
        user_by_name = {u["full_name"]: u for u in u_res.data}
        self.assertIn("Olajumoke Bakare", user_by_name)
        self.assertIn("Babatunde Lawal", user_by_name)

        olajumoke_id = user_by_name["Olajumoke Bakare"]["id"]
        babatunde_id = user_by_name["Babatunde Lawal"]["id"]

        # Check user roles
        ur1 = self.uow.client.table("user_roles").select("*").eq("user_id", olajumoke_id).execute()
        self.assertEqual(len(ur1.data), 1)
        self.assertEqual(ur1.data[0]["role_id"], "bd8790ee-c0eb-485a-8b6a-93f54519965d")

        # 2. Check designated Misc Savings Officer in app_users and branches.officer_assignments (BR-SAV-006)
        self.assertTrue(user_by_name["Olajumoke Bakare"].get("extra_fields", {}).get("is_misc_savings_manager"))
        self.assertFalse(user_by_name["Babatunde Lawal"].get("extra_fields", {}).get("is_misc_savings_manager", False))

        mgr_assign = [oa for oa in b_assignments if isinstance(oa, dict) and oa.get("is_misc_savings_manager")]
        self.assertEqual(len(mgr_assign), 1)
        self.assertEqual(mgr_assign[0]["officer_id"], olajumoke_id)

        # 3. Check groups officer_id
        g1 = self.uow.client.table("groups").select("officer_id").eq("branch_id", b_id).eq("name", "Progress Solidarity").execute()
        self.assertEqual(g1.data[0]["officer_id"], olajumoke_id)
        g2 = self.uow.client.table("groups").select("officer_id").eq("branch_id", b_id).eq("name", "Success Group").execute()
        self.assertEqual(g2.data[0]["officer_id"], babatunde_id)

        # 4. Check clients & client_memberships officer_id
        c1 = self.uow.client.table("clients").select("officer_id, client_id").eq("name", "Client A").execute()
        self.assertEqual(c1.data[0]["officer_id"], olajumoke_id)
        m1 = self.uow.client.table("client_memberships").select("officer_id").eq("client_id", c1.data[0]["client_id"]).execute()
        self.assertEqual(m1.data[0]["officer_id"], olajumoke_id)

        c2 = self.uow.client.table("clients").select("officer_id, client_id").eq("name", "Client B").execute()
        self.assertEqual(c2.data[0]["officer_id"], babatunde_id)
        m2 = self.uow.client.table("client_memberships").select("officer_id").eq("client_id", c2.data[0]["client_id"]).execute()
        self.assertEqual(m2.data[0]["officer_id"], babatunde_id)

        # 5. Check loans officer_id
        l1 = self.uow.client.table("loans").select("officer_id").eq("client_id", c1.data[0]["client_id"]).execute()
        self.assertEqual(l1.data[0]["officer_id"], olajumoke_id)
        l2 = self.uow.client.table("loans").select("officer_id").eq("client_id", c2.data[0]["client_id"]).execute()
        self.assertEqual(l2.data[0]["officer_id"], babatunde_id)

        # 6. Check internal_savings (Misc Savings)
        misc_res = self.uow.client.table("internal_savings").select("*").eq("branch_id", b_id).execute()
        self.assertEqual(len(misc_res.data), 1)
        self.assertEqual(float(misc_res.data[0]["deposit_amount"]), 35000.0)
        self.assertEqual(misc_res.data[0]["officer_id"], olajumoke_id)

        # 7. Check laps_savings
        laps_res = self.uow.client.table("laps_savings").select("*").eq("branch_id", b_id).execute()
        self.assertEqual(len(laps_res.data), 1)
        self.assertEqual(float(laps_res.data[0]["deposit_amount"]), 18500.0)

        self._cleanup()

if __name__ == "__main__":
    unittest.main()

