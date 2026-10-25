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
from auth.session import generate_session_token

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
        self.assertEqual(save_data["aggregates"]["total_member_savings"], 5000.0)
        self.assertEqual(save_data["aggregates"]["total_group_savings"], 25000.0)
        self.assertEqual(save_data["aggregates"]["total_savings"], 30000.0)
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
        self.assertEqual(len(u_res.data), 3)
        user_by_name = {u["full_name"]: u for u in u_res.data}
        self.assertIn("Admin Coordinator", user_by_name)
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

    def test_co_specific_scoped_workspace_and_draft_merging(self):
        """
        Verifies:
        1. When an onboarding session link with ?officer=Officer%20A is opened,
           get_session_by_token attaches scoped_officer: "Officer A".
        2. When Officer A saves a draft containing their group and member,
           and then Officer B saves a draft with scoped_officer="Officer B",
           Officer A's groups and members are fully preserved and NOT clobbered.
        3. Total savings accurately sums member savings, group savings, and misc savings.
        """
        self._cleanup()

        # 1. Create a session
        session = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Scoped Branch Test",
            branch_code="TST",
            contact_person="Area Manager",
            contact_phone="08012345678"
        )
        token = session["token"]

        # 2. Officer A retrieves session with ?officer=Officer A
        res_get = client.get(f"/api/v1/onboarding/session/{token}?officer=Officer%20A")
        self.assertEqual(res_get.status_code, 200)
        self.assertEqual(res_get.json().get("scoped_officer"), "Officer A")

        # 3. Officer A saves their draft (1 group, 1 member)
        payload_a = {
            "officers": [
                {"name": "Officer A", "phone": "08011111111", "role": "Credit Officer", "is_misc_savings_manager": False}
            ],
            "groups": [
                {
                    "group_reference": "GRP-01",
                    "group_name": "Group A",
                    "officer_name": "Officer A",
                    "meeting_day": "Daily",
                    "group_savings": 10000.0
                }
            ],
            "members": [
                {
                    "member_reference": "TST-01-001",
                    "group_reference": "GRP-01",
                    "member_number": 1,
                    "full_name": "Member A",
                    "phone_number": "08011112222",
                    "savings_balance": 5000.0,
                    "loan_type": None,
                    "principal_loan": 0.0,
                    "active_credit": 0.0,
                    "current_credit_balance": 0.0
                }
            ],
            "misc_savings": 0.0,
            "laps_savings": 0.0
        }
        res_save_a = client.put(
            f"/api/v1/onboarding/session/{token}/save-draft",
            json={"payload": payload_a, "scoped_officer": "Officer A"}
        )
        self.assertEqual(res_save_a.status_code, 200)
        data_a = res_save_a.json()
        self.assertEqual(data_a["aggregates"]["total_groups"], 1)
        self.assertEqual(data_a["aggregates"]["total_members"], 1)
        self.assertEqual(data_a["aggregates"]["total_member_savings"], 5000.0)
        self.assertEqual(data_a["aggregates"]["total_group_savings"], 10000.0)
        self.assertEqual(data_a["aggregates"]["total_savings"], 15000.0)

        # 4. Officer B saves their draft with scoped_officer="Officer B" (1 group, 1 member, misc_savings=20000.0)
        payload_b = {
            "officers": [
                {"name": "Officer B", "phone": "08022222222", "role": "Credit Officer", "is_misc_savings_manager": True}
            ],
            "groups": [
                {
                    "group_reference": "GRP-02",
                    "group_name": "Group B",
                    "officer_name": "Officer B",
                    "meeting_day": "Wednesday",
                    "group_savings": 15000.0
                }
            ],
            "members": [
                {
                    "member_reference": "TST-02-001",
                    "group_reference": "GRP-02",
                    "member_number": 1,
                    "full_name": "Member B",
                    "phone_number": "08022223333",
                    "savings_balance": 7000.0,
                    "loan_type": None,
                    "principal_loan": 0.0,
                    "active_credit": 0.0,
                    "current_credit_balance": 0.0
                }
            ],
            "misc_savings": 20000.0,
            "laps_savings": 5000.0
        }
        res_save_b = client.put(
            f"/api/v1/onboarding/session/{token}/save-draft",
            json={"payload": payload_b, "scoped_officer": "Officer B"}
        )
        self.assertEqual(res_save_b.status_code, 200)
        data_b = res_save_b.json()

        # 5. Verify intelligent merge: BOTH Officer A's and Officer B's data exist!
        self.assertEqual(data_b["aggregates"]["total_groups"], 2)
        self.assertEqual(data_b["aggregates"]["total_members"], 2)
        self.assertEqual(data_b["aggregates"]["total_officers"], 2)

        # Verify savings calculation: member (5000 + 7000) + group (10000 + 15000) + misc (20000) = 57000.0
        self.assertEqual(data_b["aggregates"]["total_member_savings"], 12000.0)
        self.assertEqual(data_b["aggregates"]["total_group_savings"], 25000.0)
        self.assertEqual(data_b["aggregates"]["misc_savings"], 20000.0)
        self.assertEqual(data_b["aggregates"]["total_savings"], 57000.0)

        # 6. Retrieve session as Area Manager (no officer param)
        res_am = client.get(f"/api/v1/onboarding/session/{token}")
        self.assertEqual(res_am.status_code, 200)
        am_data = res_am.json()["session"]["payload"]
        self.assertEqual(len(am_data["groups"]), 2)
        self.assertEqual(len(am_data["members"]), 2)
        self.assertEqual(len(am_data["officers"]), 2)

        self._cleanup()

    def test_three_tier_provisioning_and_isolation(self):
        # 1. Create a session
        session = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Test Isolation Branch",
            branch_code="TST",
            contact_person="BM Johnson",
            contact_phone="08011112222"
        )
        branch_token = session["token"]

        # 2. BM provisions Officer 1
        res_off1 = client.post(
            f"/api/v1/onboarding/session/{branch_token}/officers",
            json={"name": "Babatunde Adeleke", "phone": "08033334444", "is_misc_savings_manager": False}
        )
        self.assertEqual(res_off1.status_code, 200)
        off1_data = res_off1.json()
        token1 = off1_data["token"]
        self.assertTrue(token1.startswith("onb_co_"))

        # 3. BM provisions Officer 2
        res_off2 = client.post(
            f"/api/v1/onboarding/session/{branch_token}/officers",
            json={"name": "Olajumoke Fashola", "phone": "08055556666", "is_misc_savings_manager": True}
        )
        self.assertEqual(res_off2.status_code, 200)
        off2_data = res_off2.json()
        token2 = off2_data["token"]
        self.assertTrue(token2.startswith("onb_co_"))

        # 4. Officer 1 loads workspace
        res_ws1 = client.get(f"/api/v1/onboarding/officer/{token1}")
        self.assertEqual(res_ws1.status_code, 200)
        ws1 = res_ws1.json()
        self.assertEqual(ws1["officer"]["name"], "Babatunde Adeleke")
        self.assertEqual(len(ws1["groups"]), 0)
        self.assertEqual(len(ws1["members"]), 0)

        # 5. Officer 1 saves 2 groups and 2 members
        payload_off1 = {
            "groups": [
                {"group_reference": "GRP-01", "group_name": "Progress 1", "meeting_day": "Daily", "group_savings": 5000.0},
                {"group_reference": "GRP-02", "group_name": "Progress 2", "meeting_day": "Tuesday", "group_savings": 6000.0}
            ],
            "members": [
                {"member_reference": "TST-01-001", "group_reference": "GRP-01", "full_name": "Ayodele Bello", "savings_balance": 1000.0},
                {"member_reference": "TST-02-001", "group_reference": "GRP-02", "full_name": "Folashade Ade", "savings_balance": 2000.0}
            ]
        }
        res_save1 = client.put(f"/api/v1/onboarding/officer/{token1}/save-draft", json={"payload": payload_off1})
        self.assertEqual(res_save1.status_code, 200)
        ws1_updated = res_save1.json()
        self.assertEqual(len(ws1_updated["groups"]), 2)
        self.assertEqual(len(ws1_updated["members"]), 2)
        self.assertEqual(ws1_updated["aggregates"]["total_portfolio_savings"], 14000.0) # 5000+6000+1000+2000

        # 6. Officer 2 loads workspace -> MUST HAVE 100% DATA ISOLATION (ZERO visibility of Officer 1's data)
        res_ws2 = client.get(f"/api/v1/onboarding/officer/{token2}")
        self.assertEqual(res_ws2.status_code, 200)
        ws2 = res_ws2.json()
        self.assertEqual(ws2["officer"]["name"], "Olajumoke Fashola")
        self.assertEqual(len(ws2["groups"]), 0)
        self.assertEqual(len(ws2["members"]), 0)
        self.assertEqual(ws2["aggregates"]["total_portfolio_savings"], 0.0)

        # 7. Officer 1 submits roster
        res_sub1 = client.post(f"/api/v1/onboarding/officer/{token1}/submit")
        self.assertEqual(res_sub1.status_code, 200)

        # Officer 1 editing after submission is locked (400 Bad Request)
        res_edit_locked = client.put(f"/api/v1/onboarding/officer/{token1}/save-draft", json={"payload": payload_off1})
        self.assertEqual(res_edit_locked.status_code, 400)

        # BM unlocks Officer 1's roster
        res_unlock = client.post(f"/api/v1/onboarding/session/{branch_token}/officers/{off1_data['id']}/unlock")
        self.assertEqual(res_unlock.status_code, 200)

        # Officer 1 can now edit again
        res_edit_unlocked = client.put(f"/api/v1/onboarding/officer/{token1}/save-draft", json={"payload": payload_off1})
        self.assertEqual(res_edit_unlocked.status_code, 200)

        self._cleanup()

    def test_contiguous_officer_block_sequencing(self):
        # Test Case matching user specification:
        # CO1 has GRP-01 to GRP-06 (6 groups)
        # CO2 has GRP-01 to GRP-09 (9 groups)
        # Global database group numbers must be:
        # CO1 groups: 1 to 6 (GRP-01 to GRP-06)
        # CO2 groups: 7 to 15 (GRP-01 to GRP-09)
        session = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Contiguous Test Branch",
            branch_code="TST",
            contact_person="BM Adebayo",
            contact_phone="08011112222"
        )
        branch_token = session["token"]

        # Provision Officer 1 (CO1)
        res_off1 = client.post(
            f"/api/v1/onboarding/session/{branch_token}/officers",
            json={"name": "Babatunde Adeleke", "phone": "08033334444"}
        )
        off1 = res_off1.json()
        token1 = off1["token"]

        # Provision Officer 2 (CO2)
        res_off2 = client.post(
            f"/api/v1/onboarding/session/{branch_token}/officers",
            json={"name": "Olajumoke Fashola", "phone": "08055556666"}
        )
        off2 = res_off2.json()
        token2 = off2["token"]

        # CO1 creates 6 groups (GRP-01 to GRP-06)
        co1_groups = [{"group_reference": f"GRP-{str(i).zfill(2)}", "group_name": f"CO1 Group {i}", "meeting_day": "Daily"} for i in range(1, 7)]
        co1_members = [{"member_reference": f"TST-01-{str(i).zfill(3)}", "group_reference": f"GRP-{str(i).zfill(2)}", "full_name": f"CO1 Client {i}", "savings_balance": 100.0} for i in range(1, 7)]
        res_s1 = client.put(f"/api/v1/onboarding/officer/{token1}/save-draft", json={"payload": {"groups": co1_groups, "members": co1_members}})
        self.assertEqual(res_s1.status_code, 200)

        # CO2 creates 9 groups (GRP-01 to GRP-09)
        co2_groups = [{"group_reference": f"GRP-{str(i).zfill(2)}", "group_name": f"CO2 Group {i}", "meeting_day": "Tuesday"} for i in range(1, 10)]
        co2_members = [{"member_reference": f"TST-01-{str(i).zfill(3)}", "group_reference": f"GRP-{str(i).zfill(2)}", "full_name": f"CO2 Client {i}", "savings_balance": 200.0} for i in range(1, 10)]
        res_s2 = client.put(f"/api/v1/onboarding/officer/{token2}/save-draft", json={"payload": {"groups": co2_groups, "members": co2_members}})
        self.assertEqual(res_s2.status_code, 200)

        # Both submit to BM
        client.post(f"/api/v1/onboarding/officer/{token1}/submit")
        client.post(f"/api/v1/onboarding/officer/{token2}/submit")

        # BM confirms total 15 groups and submits to AM
        res_bm = client.post(f"/api/v1/onboarding/session/{branch_token}/bm-submit")
        self.assertEqual(res_bm.status_code, 200)
        self.assertEqual(res_bm.json()["aggregates"]["total_groups"], 15)
        self.assertEqual(res_bm.json()["aggregates"]["total_members"], 15)

        # AM Approves & Commits to Core Database via link
        admin_user = self.uow.users.find_by_username("Admin") or self.uow.users.find_by_username("admin")
        admin_token = generate_session_token(admin_user.id, admin_user.username)
        res_approve = client.post(
            f"/api/v1/onboarding/session/{branch_token}/am-approve",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        self.assertEqual(res_approve.status_code, 200)
        commit_data = res_approve.json()
        self.assertEqual(commit_data["groups_migrated"], 15)
        self.assertEqual(commit_data["clients_created"], 15)

        # Verify live database table 'groups' for contiguous distribution:
        # CO1 groups: 1 to 6
        # CO2 groups: 7 to 15
        b_res = self.uow.client.table("branches").select("branch_id").eq("code", "TST").execute()
        branch_id = b_res.data[0]["branch_id"]
        g_res = self.uow.client.table("groups").select("name, group_number, officer_id").eq("branch_id", branch_id).execute()
        self.assertEqual(len(g_res.data), 15)

        # Sort by integer group_number
        sorted_groups = sorted(g_res.data, key=lambda g: int(g["group_number"]))
        group_numbers = [int(g["group_number"]) for g in sorted_groups]
        self.assertEqual(group_numbers, list(range(1, 16))) # [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

        # First 6 groups are CO1 groups
        for g in sorted_groups[:6]:
            self.assertIn("CO1 Group", g["name"])

        # Groups 7 to 15 are CO2 groups
        for g in sorted_groups[6:]:
            self.assertIn("CO2 Group", g["name"])

        # Verify client codes:
        c_res = self.uow.client.table("clients").select("client_code, name").eq("branch_id", branch_id).execute()
        self.assertEqual(len(c_res.data), 15)
        client_codes = {c["name"]: c["client_code"] for c in c_res.data}
        self.assertEqual(client_codes["CO1 Client 1"], "TST-01-001")
        self.assertEqual(client_codes["CO1 Client 6"], "TST-06-001")
        self.assertEqual(client_codes["CO2 Client 1"], "TST-07-001") # Sequenced into Group 7!
        self.assertEqual(client_codes["CO2 Client 9"], "TST-15-001") # Sequenced into Group 15!

        self._cleanup()

    def test_delete_session_lifecycle(self):
        """
        Verifies that draft and submitted sessions can be deleted from the AM dashboard,
        while approved sessions are permanently protected against deletion.
        """
        from api.dependencies import get_current_user
        from models.user import CurrentUser

        # 1. Create a draft session
        draft_session = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Test Draft Branch",
            branch_code="TST",
            contact_person="Draft Manager",
            contact_phone="08012345678"
        )
        draft_id = draft_session["id"]

        # Verify draft exists in database
        check_res = self.uow.client.table("branch_onboarding_sessions").select("id").eq("id", draft_id).execute()
        self.assertEqual(len(check_res.data), 1)

        # 2. Delete draft session via OnboardingService.delete_session
        res_del = OnboardingService.delete_session(uow=self.uow, session_id=draft_id)
        self.assertEqual(res_del["status"], "success")
        self.assertEqual(res_del["session_id"], draft_id)

        # Verify draft is completely removed
        check_after = self.uow.client.table("branch_onboarding_sessions").select("id").eq("id", draft_id).execute()
        self.assertEqual(len(check_after.data), 0)

        # 3. Create a session, set to 'submitted', and verify it can be deleted
        sub_session = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Test Submitted Branch",
            branch_code="TST",
            contact_person="Submitted Manager",
            contact_phone="08012345679"
        )
        sub_id = sub_session["id"]
        self.uow.client.table("branch_onboarding_sessions").update({"status": "submitted"}).eq("id", sub_id).execute()

        res_del_sub = OnboardingService.delete_session(uow=self.uow, session_id=sub_id)
        self.assertEqual(res_del_sub["status"], "success")

        # Verify submitted session is removed
        check_sub = self.uow.client.table("branch_onboarding_sessions").select("id").eq("id", sub_id).execute()
        self.assertEqual(len(check_sub.data), 0)

        # 4. Create an 'approved' session and assert deletion is strictly blocked
        appr_session = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Test Approved Branch",
            branch_code="TST",
            contact_person="Approved Manager",
            contact_phone="08012345680"
        )
        appr_id = appr_session["id"]
        self.uow.client.table("branch_onboarding_sessions").update({"status": "approved"}).eq("id", appr_id).execute()

        with self.assertRaises(ValueError) as ctx:
            OnboardingService.delete_session(uow=self.uow, session_id=appr_id)
        self.assertIn("Approved onboarding sessions cannot be deleted", str(ctx.exception))

        # Clean up the approved test session manually
        self.uow.client.table("branch_onboarding_sessions").delete().eq("id", appr_id).execute()

        # 5. Non-existent session raises ValueError
        with self.assertRaises(ValueError) as ctx:
            OnboardingService.delete_session(uow=self.uow, session_id="00000000-0000-0000-0000-000000000000")
        self.assertIn("not found", str(ctx.exception).lower())

        # 6. Test REST API endpoint DELETE /api/v1/onboarding/admin/sessions/{session_id}
        api_session = OnboardingService.create_session(
            uow=self.uow,
            branch_name="Test API Delete Branch",
            branch_code="TST",
            contact_person="API Manager",
            contact_phone="08012345681"
        )
        api_id = api_session["id"]

        # Mock current user as Area Manager
        mock_am = CurrentUser(
            id="am-test-user-id",
            username="areamanager",
            role="Area Manager",
            branch="Head Office",
            permissions={"manage_branches"}
        )
        app.dependency_overrides[get_current_user] = lambda: mock_am

        try:
            # Delete via API
            resp = client.delete(f"/api/v1/onboarding/admin/sessions/{api_id}")
            self.assertEqual(resp.status_code, 200)
            data = resp.json()
            self.assertEqual(data["status"], "success")

            # Try deleting again -> should return 404
            resp_404 = client.delete(f"/api/v1/onboarding/admin/sessions/{api_id}")
            self.assertEqual(resp_404.status_code, 404)
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        self._cleanup()


if __name__ == "__main__":
    unittest.main()

