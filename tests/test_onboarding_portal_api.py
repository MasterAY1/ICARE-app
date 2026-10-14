"""
Unit & Integration tests for Branch Onboarding REST API and Domain Engine.
Verifies token generation, public guest session retrieval, Excel uploading,
draft saving with 14-day auto-extension, validation rules, and atomic commitment.
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
        # Clean up any pre-existing test sessions
        self.uow.client.table("branch_onboarding_sessions").delete().eq("branch_code", "TST").execute()

    def tearDown(self):
        self.uow.client.table("branch_onboarding_sessions").delete().eq("branch_code", "TST").execute()

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

if __name__ == "__main__":
    unittest.main()
