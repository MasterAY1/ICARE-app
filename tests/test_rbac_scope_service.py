"""
Unit tests for RBACScopeService (Phase 8.6.1)
"""
import unittest
from unittest.mock import MagicMock
import pandas as pd
from services.rbac_scope_service import RBACScopeService, RBACScope


class TestRBACScopeService(unittest.TestCase):

    def test_normalize_roles(self):
        self.assertEqual(RBACScopeService.normalize_role("CO"), "CO")
        self.assertEqual(RBACScopeService.normalize_role("Credit Officer"), "CO")
        self.assertEqual(RBACScopeService.normalize_role("BM"), "Branch Manager")
        self.assertEqual(RBACScopeService.normalize_role("Branch Manager"), "Branch Manager")
        self.assertEqual(RBACScopeService.normalize_role("AM"), "Area Manager")
        self.assertEqual(RBACScopeService.normalize_role("Area Manager"), "Area Manager")
        self.assertEqual(RBACScopeService.normalize_role("Admin"), "Admin")
        self.assertEqual(RBACScopeService.normalize_role("Director"), "Director")

    def test_resolve_scope_co(self):
        user = {"id": "u1", "username": "officer1", "role": "CO", "branch": "Ikeja Main", "branch_id": "b1"}
        scope = RBACScopeService.resolve_scope(user)
        self.assertEqual(scope.scope_level, "OFFICER")
        self.assertEqual(scope.role, "CO")
        self.assertFalse(scope.is_read_only())

    def test_resolve_scope_bm(self):
        user = {"id": "u2", "username": "bm1", "role": "Branch Manager", "branch": "Ikeja Main", "branch_id": "b1"}
        scope = RBACScopeService.resolve_scope(user)
        self.assertEqual(scope.scope_level, "BRANCH")
        self.assertEqual(scope.role, "Branch Manager")
        self.assertFalse(scope.is_read_only())

    def test_resolve_scope_am(self):
        user = {"id": "u3", "username": "am1", "role": "Area Manager", "assigned_branches": ["Ikeja Main", "Epe Outlet"]}
        scope = RBACScopeService.resolve_scope(user)
        self.assertEqual(scope.scope_level, "REGION")
        self.assertEqual(len(scope.assigned_branch_names), 2)

    def test_resolve_scope_director(self):
        user = {"id": "u4", "username": "director1", "role": "Director"}
        scope = RBACScopeService.resolve_scope(user)
        self.assertEqual(scope.scope_level, "INSTITUTION")
        self.assertTrue(scope.is_read_only())

    def test_navigation_permissions(self):
        co_items = RBACScopeService.get_permitted_menu_items("CO")
        self.assertIn("Dashboard", co_items)
        self.assertIn("Portfolio", co_items)
        self.assertIn("Withdrawal Operations", co_items)
        self.assertNotIn("User Management", co_items)

        bm_items = RBACScopeService.get_permitted_menu_items("Branch Manager")
        self.assertIn("Dashboard", bm_items)
        self.assertIn("Master Cashbook", bm_items)
        self.assertIn("User Management", bm_items)
        self.assertNotIn("Collections", bm_items)

        admin_items = RBACScopeService.get_permitted_menu_items("Admin")
        self.assertIn("User Management", admin_items)
        self.assertIn("Withdrawal Operations", admin_items)

    def test_apply_scope_to_query_fail_closed_unassigned_am(self):
        query = MagicMock()
        query.eq.return_value = query
        query.in_.return_value = query

        # AM with empty assigned_branch_ids must fail closed to nil UUID
        am_empty_scope = RBACScope(
            user_id="u_am",
            username="am_user",
            role="Area Manager",
            scope_level="REGION",
            assigned_branch_ids=[]
        )
        result = RBACScopeService.apply_scope_to_query(query, am_empty_scope)
        query.eq.assert_called_with("branch_id", "00000000-0000-0000-0000-000000000000")
        query.in_.assert_not_called()

    def test_apply_scope_to_query_am_assigned(self):
        query = MagicMock()
        query.in_.return_value = query

        am_scope = RBACScope(
            user_id="u_am",
            username="am_user",
            role="Area Manager",
            scope_level="REGION",
            assigned_branch_ids=["b_ikeja", "b_epe"]
        )
        result = RBACScopeService.apply_scope_to_query(query, am_scope)
        query.in_.assert_called_with("branch_id", ["b_ikeja", "b_epe"])

    def test_apply_scope_to_query_co_and_bm(self):
        query = MagicMock()
        query.eq.return_value = query

        co_scope = RBACScope(
            user_id="u_co_1",
            username="co_user",
            role="CO",
            scope_level="OFFICER"
        )
        RBACScopeService.apply_scope_to_query(query, co_scope)
        query.eq.assert_called_with("officer_id", "u_co_1")

        query.reset_mock()
        bm_scope = RBACScope(
            user_id="u_bm_1",
            username="bm_user",
            role="Branch Manager",
            scope_level="BRANCH",
            branch_id="b_ikeja"
        )
        RBACScopeService.apply_scope_to_query(query, bm_scope)
        query.eq.assert_called_with("branch_id", "b_ikeja")

    def test_apply_scope_to_query_fail_closed_missing_scope(self):
        query = MagicMock()
        query.eq.return_value = query

        RBACScopeService.apply_scope_to_query(query, None)
        query.eq.assert_called_with("branch_id", "00000000-0000-0000-0000-000000000000")

    def test_filter_dataframe_fail_closed(self):
        df = pd.DataFrame([
            {"branch": "Ikeja Main", "officer": "co1", "amount": 100},
            {"branch": "Epe Outlet", "officer": "co2", "amount": 200},
            {"branch": "Victoria Island", "officer": "co3", "amount": 300},
        ])

        # None scope -> empty DataFrame
        filtered_none = RBACScopeService.filter_dataframe(df, None)
        self.assertEqual(len(filtered_none), 0)

        # AM with empty assigned branches -> empty DataFrame
        am_empty_scope = RBACScope(
            user_id="u_am",
            username="am_user",
            role="Area Manager",
            scope_level="REGION",
            assigned_branch_names=[]
        )
        filtered_am_empty = RBACScopeService.filter_dataframe(df, am_empty_scope)
        self.assertEqual(len(filtered_am_empty), 0)

        # AM with assigned branches -> only matching branches
        am_scope = RBACScope(
            user_id="u_am",
            username="am_user",
            role="Area Manager",
            scope_level="REGION",
            assigned_branch_names=["Ikeja Main", "Epe Outlet"]
        )
        filtered_am = RBACScopeService.filter_dataframe(df, am_scope)
        self.assertEqual(len(filtered_am), 2)
        self.assertNotIn("Victoria Island", filtered_am["branch"].values)

        # CO -> only matching officer
        co_scope = RBACScope(
            user_id="u1",
            username="co1",
            role="CO",
            scope_level="OFFICER"
        )
        filtered_co = RBACScopeService.filter_dataframe(df, co_scope)
        self.assertEqual(len(filtered_co), 1)
        self.assertEqual(filtered_co.iloc[0]["officer"], "co1")


if __name__ == "__main__":
    unittest.main()
