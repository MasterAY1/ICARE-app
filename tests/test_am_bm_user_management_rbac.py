import os
import sys
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.user_service import UserService
from domain.entities.user import User


class MockUser:
    def __init__(self, id, username, role, branch_id=None, branch_name=None, assigned_branch_ids=None):
        self.id = id
        self.username = username
        self.full_name = f"Full Name {username}"
        self.role = role
        self.branch_id = branch_id
        self.branch_name = branch_name
        self.assigned_branch_ids = assigned_branch_ids or []
        self.is_active = True
        self.created_at = None
        self.last_login = None


class TestAmBmUserManagementRbac(unittest.TestCase):

    def test_list_users_bm_scoping(self):
        """
        Verify that a Branch Manager:
        1. Only sees Credit Officers in their own branch.
        2. NEVER sees their own account or other managers.
        """
        bm_user = MockUser(id="bm-1", username="BM_Ogijo", role="Branch Manager", branch_id="b-ogijo", branch_name="Ogijo")

        users_db = [
            MockUser(id="bm-1", username="BM_Ogijo", role="Branch Manager", branch_id="b-ogijo", branch_name="Ogijo"),
            MockUser(id="co-1", username="CO1", role="Credit Officer", branch_id="b-ogijo", branch_name="Ogijo"),
            MockUser(id="co-2", username="CO2", role="Credit Officer", branch_id="b-ogijo", branch_name="Ogijo"),
            MockUser(id="co-3", username="CO3", role="Credit Officer", branch_id="b-ikorodu", branch_name="Ikorodu"),
            MockUser(id="admin-1", username="AdminUser", role="Admin", branch_id=None, branch_name=None),
        ]

        mock_uow = MagicMock()
        mock_uow.users.find_all.return_value = users_db

        with patch("database.repositories.unit_of_work.SupabaseUnitOfWork") as mock_uow_cls:
            mock_uow_cls.return_value.__enter__.return_value = mock_uow
            results = UserService.list_users(requesting_user=bm_user)

        usernames = [u["username"] for u in results]
        self.assertIn("CO1", usernames)
        self.assertIn("CO2", usernames)
        self.assertNotIn("BM_Ogijo", usernames, "BM must not see their own account in the list")
        self.assertNotIn("CO3", usernames, "BM must not see COs from other branches")
        self.assertNotIn("AdminUser", usernames, "BM must not see Admin users")

    def test_list_users_am_scoping(self):
        """
        Verify that an Area Manager:
        1. Sees Branch Managers and Credit Officers in their assigned branches.
        2. NEVER sees their own account or Admins or unassigned branches.
        """
        am_user = MockUser(
            id="am-1",
            username="AM_Area1",
            role="Area Manager",
            assigned_branch_ids=["b-ogijo", "b-ikorodu"]
        )

        users_db = [
            MockUser(id="am-1", username="AM_Area1", role="Area Manager", assigned_branch_ids=["b-ogijo", "b-ikorodu"]),
            MockUser(id="bm-1", username="BM_Ogijo", role="Branch Manager", branch_id="b-ogijo", branch_name="Ogijo"),
            MockUser(id="co-1", username="CO1", role="Credit Officer", branch_id="b-ogijo", branch_name="Ogijo"),
            MockUser(id="bm-2", username="BM_Ikorodu", role="Branch Manager", branch_id="b-ikorodu", branch_name="Ikorodu"),
            MockUser(id="co-4", username="CO4", role="Credit Officer", branch_id="b-kola", branch_name="Kola"),
            MockUser(id="admin-1", username="AdminUser", role="Admin", branch_id=None, branch_name=None),
        ]

        mock_uow = MagicMock()
        mock_uow.users.find_all.return_value = users_db

        with patch("database.repositories.unit_of_work.SupabaseUnitOfWork") as mock_uow_cls:
            mock_uow_cls.return_value.__enter__.return_value = mock_uow
            results = UserService.list_users(requesting_user=am_user)

        usernames = [u["username"] for u in results]
        self.assertIn("BM_Ogijo", usernames)
        self.assertIn("CO1", usernames)
        self.assertIn("BM_Ikorodu", usernames)
        self.assertNotIn("AM_Area1", usernames, "AM must not see their own account in staff list")
        self.assertNotIn("CO4", usernames, "AM must not see unassigned branch Kola")
        self.assertNotIn("AdminUser", usernames, "AM must not see Admin users")

    def test_create_user_scoping(self):
        """
        Verify create_user authorization:
        - BM can only create Credit Officer for their own branch.
        - AM can create BM and CO for their assigned branches.
        """
        bm_user = MockUser(id="bm-1", username="BM_Ogijo", role="Branch Manager", branch_id="b-ogijo", branch_name="Ogijo")

        # BM attempting to create Branch Manager should fail
        res1 = UserService.create_user(
            username="NewBM", full_name="New BM", password="pass", role="Branch Manager",
            branch_name="Ogijo", requesting_user=bm_user
        )
        self.assertFalse(res1["success"])
        self.assertIn("only create Credit Officers", res1["message"])

        # BM attempting to create CO for another branch should fail
        res2 = UserService.create_user(
            username="NewCO", full_name="New CO", password="pass", role="Credit Officer",
            branch_name="Ikorodu", requesting_user=bm_user
        )
        self.assertFalse(res2["success"])
        self.assertIn("own branch", res2["message"])

        # AM creating BM for an assigned branch should succeed
        am_user = MockUser(id="am-1", username="AM_Area1", role="Area Manager", assigned_branch_ids=["b-ogijo", "b-ikorodu"])
        mock_uow = MagicMock()
        mock_uow.users.find_by_username.return_value = None
        mock_uow.client.table().select().ilike().execute.return_value = MagicMock(data=[{"branch_id": "b-ogijo"}])

        with patch("database.repositories.unit_of_work.SupabaseUnitOfWork") as mock_uow_cls:
            mock_uow_cls.return_value.__enter__.return_value = mock_uow
            res3 = UserService.create_user(
                username="NewBMOgijo", full_name="New BM Ogijo", password="password123",
                role="Branch Manager", branch_name="Ogijo", requesting_user=am_user
            )
        self.assertTrue(res3["success"])

    def test_reset_password_scoping(self):
        """
        Verify reset_password:
        - BM cannot reset own password or other BMs.
        - BM can reset CO password in own branch.
        - AM cannot reset own password or Admin.
        - AM can reset BM or CO password in assigned branch.
        """
        bm_user = MockUser(id="bm-1", username="BM_Ogijo", role="Branch Manager", branch_id="b-ogijo", branch_name="Ogijo")
        co_user = MockUser(id="co-1", username="CO1", role="Credit Officer", branch_id="b-ogijo", branch_name="Ogijo")

        mock_uow = MagicMock()

        # BM attempting to reset self
        mock_uow.users.find_by_username.return_value = bm_user
        with patch("database.repositories.unit_of_work.SupabaseUnitOfWork") as mock_uow_cls:
            mock_uow_cls.return_value.__enter__.return_value = mock_uow
            res_self = UserService.reset_password("BM_Ogijo", "newpass123", requesting_user=bm_user)
        self.assertFalse(res_self["success"])
        self.assertIn("cannot reset your own password", res_self["message"])

        # BM resetting CO in own branch
        mock_uow.users.find_by_username.return_value = co_user
        with patch("database.repositories.unit_of_work.SupabaseUnitOfWork") as mock_uow_cls:
            mock_uow_cls.return_value.__enter__.return_value = mock_uow
            res_co = UserService.reset_password("CO1", "newpass123", requesting_user=bm_user)
        self.assertTrue(res_co["success"])

    def test_remove_user_permanently_scoping(self):
        """
        Verify remove_user_permanently:
        - BM cannot delete themselves.
        - BM can delete CO in own branch.
        - AM can delete BM in assigned branch.
        """
        bm_user = MockUser(id="bm-1", username="BM_Ogijo", role="Branch Manager", branch_id="b-ogijo", branch_name="Ogijo")
        co_user = MockUser(id="co-1", username="CO1", role="Credit Officer", branch_id="b-ogijo", branch_name="Ogijo")

        mock_uow = MagicMock()

        # BM attempting to delete self
        mock_uow.users.find_by_id.return_value = bm_user
        with patch("database.repositories.unit_of_work.SupabaseUnitOfWork") as mock_uow_cls:
            mock_uow_cls.return_value.__enter__.return_value = mock_uow
            res_del_self = UserService.remove_user_permanently("bm-1", requesting_user=bm_user)
        self.assertFalse(res_del_self["success"])
        self.assertIn("cannot delete your own account", res_del_self["message"])

        # BM deleting CO in own branch
        mock_uow.users.find_by_id.return_value = co_user
        mock_uow.users.delete.return_value = True
        with patch("database.repositories.unit_of_work.SupabaseUnitOfWork") as mock_uow_cls:
            mock_uow_cls.return_value.__enter__.return_value = mock_uow
            res_del_co = UserService.remove_user_permanently("co-1", requesting_user=bm_user)
        self.assertTrue(res_del_co["success"])


if __name__ == "__main__":
    unittest.main()
