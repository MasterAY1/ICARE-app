"""
Unit tests for RBACScopeService (Phase 8.6.1)
"""
import unittest
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
        self.assertNotIn("User Management", co_items)

        bm_items = RBACScopeService.get_permitted_menu_items("Branch Manager")
        self.assertIn("Loan Origination", bm_items)
        self.assertIn("Master Cashbook", bm_items)
        self.assertNotIn("User Management", bm_items)

        admin_items = RBACScopeService.get_permitted_menu_items("Admin")
        self.assertIn("User Management", admin_items)


if __name__ == "__main__":
    unittest.main()
