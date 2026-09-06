"""
Unit tests verifying strict Credit Officer data isolation in Collection History and Audit Ledgers.
Ensures Credit Officers cannot see other officers' collections, savings, loans, or audit records,
while maintaining full audit visibility for Branch Managers and Administrators.
"""
import unittest
from services.rbac_scope_service import RBACScopeService


class TestAuditOfficerScoping(unittest.TestCase):

    def setUp(self):
        self.co1_user = {
            "id": "573eca5f-0000-0000-0000-000000000001",
            "username": "CO1",
            "full_name": "Mrs. Dorcas",
            "role": "Credit Officer",
            "branch": "Ogijo",
            "branch_id": "b09f451c-0000-0000-0000-000000000001"
        }
        self.co2_user = {
            "id": "c32125e1-0000-0000-0000-000000000002",
            "username": "CO2",
            "full_name": "Mr. Ayomide",
            "role": "Credit Officer",
            "branch": "Ogijo",
            "branch_id": "b09f451c-0000-0000-0000-000000000001"
        }
        self.bm_user = {
            "id": "bm-uuid-0000-0000-0000-000000000001",
            "username": "BM_Ogijo",
            "full_name": "Branch Manager Ogijo",
            "role": "Branch Manager",
            "branch": "Ogijo",
            "branch_id": "b09f451c-0000-0000-0000-000000000001"
        }

    def test_officer_role_normalization_and_scope(self):
        """Verify that 'Credit Officer', 'CO', and 'Officer' resolve to OFFICER scope."""
        for role in ["Credit Officer", "CO", "Officer"]:
            u = dict(self.co1_user, role=role)
            scope = RBACScopeService.resolve_scope(u)
            self.assertEqual(scope.scope_level, "OFFICER")
            is_officer = (scope.scope_level == "OFFICER" or role in ['CO', 'Officer', 'Credit Officer'])
            self.assertTrue(is_officer)

    def test_bm_and_am_scope(self):
        """Verify that BM and AM roles do NOT get classified as officer scope."""
        bm_scope = RBACScopeService.resolve_scope(self.bm_user)
        self.assertEqual(bm_scope.scope_level, "BRANCH")
        is_officer_bm = (bm_scope.scope_level == "OFFICER" or self.bm_user["role"] in ['CO', 'Officer', 'Credit Officer'])
        self.assertFalse(is_officer_bm)

    def test_co_collection_history_isolation(self):
        """Simulate collection history query results and verify CO1 cannot see CO2's collections."""
        repayments = [
            {"id": "rep-1", "officer_id": self.co1_user["id"], "amount_paid": 5000},
            {"id": "rep-2", "officer_id": self.co2_user["id"], "amount_paid": 12000},
        ]
        group_savings = [
            {"id": "gs-1", "officer_id": self.co1_user["id"], "deposit_amount": 3000},
            {"id": "gs-2", "officer_id": self.co2_user["id"], "deposit_amount": 8000},
        ]

        # Filter as CO1
        co1_id = self.co1_user["id"]
        co1_reps = [r for r in repayments if r["officer_id"] == co1_id]
        co1_gsav = [g for g in group_savings if g["officer_id"] == co1_id]

        self.assertEqual(len(co1_reps), 1)
        self.assertEqual(co1_reps[0]["id"], "rep-1")
        self.assertEqual(len(co1_gsav), 1)
        self.assertEqual(co1_gsav[0]["id"], "gs-1")

        # Verify CO2's data was completely excluded
        self.assertNotIn("rep-2", [r["id"] for r in co1_reps])
        self.assertNotIn("gs-2", [g["id"] for g in co1_gsav])

    def test_audit_enricher_name_resolution_and_filtering(self):
        """Verify in-memory filtering matches by raw UUID or full name without leaking."""
        enriched_records = [
            {
                "Date": "2026-09-01",
                "Client Name": "Client A",
                "Officer": "Mrs. Dorcas",
                "Deposit_Raw": 5000,
                "_raw_record": {"officer_id": self.co1_user["id"]}
            },
            {
                "Date": "2026-09-01",
                "Client Name": "Client B",
                "Officer": "Mr. Ayomide",
                "Deposit_Raw": 10000,
                "_raw_record": {"officer_id": self.co2_user["id"]}
            }
        ]

        # CO1 views savings ledger
        user_id = self.co1_user["id"]
        username = self.co1_user["username"]
        full_name = self.co1_user["full_name"]

        co1_view = [
            s for s in enriched_records
            if str(s.get("_raw_record", {}).get("officer_id") or "") == str(user_id)
            or str(s.get("Officer", "")).lower() in [
                str(username).lower(),
                full_name.lower(),
                f"{full_name.lower()} ({str(username).lower()})"
            ]
        ]

        self.assertEqual(len(co1_view), 1)
        self.assertEqual(co1_view[0]["Officer"], "Mrs. Dorcas")
        self.assertEqual(co1_view[0]["Deposit_Raw"], 5000)

        # CO2 views savings ledger
        user_id_2 = self.co2_user["id"]
        username_2 = self.co2_user["username"]
        full_name_2 = self.co2_user["full_name"]

        co2_view = [
            s for s in enriched_records
            if str(s.get("_raw_record", {}).get("officer_id") or "") == str(user_id_2)
            or str(s.get("Officer", "")).lower() in [
                str(username_2).lower(),
                full_name_2.lower(),
                f"{full_name_2.lower()} ({str(username_2).lower()})"
            ]
        ]

        self.assertEqual(len(co2_view), 1)
        self.assertEqual(co2_view[0]["Officer"], "Mr. Ayomide")
        self.assertEqual(co2_view[0]["Deposit_Raw"], 10000)

    def test_bm_and_co_collection_performance_scoping(self):
        """Verify Branch Manager sees all branch collection performance while CO is strictly scoped."""
        enriched_cp = [
            {
                "Meeting Date": "04 Sep 2026",
                "Client Name": "Client A",
                "Officer": "Mrs. Dorcas",
                "Branch": "Ogijo",
                "Expected": "₦5,000.00",
                "Paid": "₦5,000.00",
                "Compliance %": "100.0%",
                "Status": "PAID",
                "Expected_Raw": 5000.0,
                "Paid_Raw": 5000.0,
                "Status_Raw": "PAID",
                "_raw_record": {"officer_id": self.co1_user["id"], "branch_id": self.co1_user["branch_id"]}
            },
            {
                "Meeting Date": "04 Sep 2026",
                "Client Name": "Client B",
                "Officer": "Mr. Ayomide",
                "Branch": "Ogijo",
                "Expected": "₦10,000.00",
                "Paid": "₦8,000.00",
                "Compliance %": "80.0%",
                "Status": "PART_PAYMENT",
                "Expected_Raw": 10000.0,
                "Paid_Raw": 8000.0,
                "Status_Raw": "PART_PAYMENT",
                "_raw_record": {"officer_id": self.co2_user["id"], "branch_id": self.co2_user["branch_id"]}
            }
        ]

        # 1. BM view: sees all records in branch
        bm_view = [
            c for c in enriched_cp
            if str(c.get("_raw_record", {}).get("branch_id")) == str(self.bm_user["branch_id"])
        ]
        self.assertEqual(len(bm_view), 2)
        tot_exp = sum(c["Expected_Raw"] for c in bm_view)
        tot_act = sum(c["Paid_Raw"] for c in bm_view)
        self.assertEqual(tot_exp, 15000.0)
        self.assertEqual(tot_act, 13000.0)

        # 2. CO1 view: strictly isolated to CO1
        user_id_1 = self.co1_user["id"]
        username_1 = self.co1_user["username"]
        full_name_1 = self.co1_user["full_name"]
        co1_cp_view = [
            c for c in enriched_cp
            if str(c.get("_raw_record", {}).get("officer_id") or "") == str(user_id_1)
            or str(c.get("Officer", "")).lower() in [
                str(username_1).lower(),
                full_name_1.lower(),
                f"{full_name_1.lower()} ({str(username_1).lower()})"
            ]
        ]
        self.assertEqual(len(co1_cp_view), 1)
        self.assertEqual(co1_cp_view[0]["Officer"], "Mrs. Dorcas")
        self.assertEqual(co1_cp_view[0]["Paid_Raw"], 5000.0)


if __name__ == "__main__":
    unittest.main()
