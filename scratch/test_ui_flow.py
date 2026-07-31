"""
UI Automated Audit Test Script for ICARE Core Banking Platform
Simulates role contexts and tests service layer outputs for all pages.
"""
import sys
import unittest
import pandas as pd
from datetime import date

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.rbac_scope_service import RBACScopeService
from services.dashboard_service import DashboardService
from services.portfolio_service import PortfolioService
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder


class TestUIRoleFlows(unittest.TestCase):

    def test_co_role_dashboard(self):
        with SupabaseUnitOfWork() as uow:
            scope = RBACScopeService.resolve_scope({
                "id": "test_co_id", "username": "co1", "role": "CO", "branch": "Ogijo Branch"
            })
            self.assertEqual(scope.scope_level, "OFFICER")
            
            data = DashboardService.get_co_dashboard_data(
                uow, scope.branch_name, scope.username, officer_id=scope.user_id, branch_id=scope.branch_id
            )
            self.assertIn("welcome", data)
            self.assertIn("repayment_summary", data)
            self.assertIn("meeting_portfolio", data)
            self.assertIn("savings", data)
            self.assertIn("repayment_status", data)
            self.assertIn("cash_position", data)
            self.assertIn("attention_list", data)

    def test_bm_role_dashboard(self):
        with SupabaseUnitOfWork() as uow:
            scope = RBACScopeService.resolve_scope({
                "id": "test_bm_id", "username": "bm1", "role": "Branch Manager", "branch": "Ogijo Branch"
            })
            self.assertEqual(scope.scope_level, "BRANCH")
            
            data = DashboardService.get_bm_dashboard_data(
                uow, scope.branch_name, branch_id=scope.branch_id
            )
            self.assertIn("branch_summary", data)
            self.assertIn("officer_collection_status", data)
            self.assertIn("approval_queue", data)
            self.assertIn("branch_cash_position", data)

    def test_am_role_dashboard(self):
        with SupabaseUnitOfWork() as uow:
            scope = RBACScopeService.resolve_scope({
                "id": "test_am_id", "username": "am1", "role": "Area Manager", "assigned_branches": ["Ogijo Branch", "Ikeja Main"]
            })
            self.assertEqual(scope.scope_level, "REGION")
            
            data = DashboardService.get_am_dashboard_data(
                uow, scope.assigned_branch_names
            )
            self.assertIn("regional_summary", data)
            self.assertIn("branch_performance", data)

    def test_admin_role_dashboard(self):
        with SupabaseUnitOfWork() as uow:
            scope = RBACScopeService.resolve_scope({
                "id": "test_admin_id", "username": "admin", "role": "Admin"
            })
            self.assertEqual(scope.scope_level, "INSTITUTION")
            
            data = DashboardService.get_admin_dashboard_data(uow)
            self.assertIn("today_operations", data)
            self.assertIn("system_health", data)

    def test_director_role_dashboard(self):
        with SupabaseUnitOfWork() as uow:
            scope = RBACScopeService.resolve_scope({
                "id": "test_dir_id", "username": "director", "role": "Director"
            })
            self.assertTrue(scope.is_read_only())
            
            data = DashboardService.get_director_dashboard_data(uow)
            self.assertIn("executive_overview", data)
            self.assertIn("top_five_branches", data)

    def test_portfolio_service_for_scopes(self):
        with SupabaseUnitOfWork() as uow:
            co_scope = RBACScopeService.resolve_scope({
                "id": "co1_id", "username": "co1", "role": "CO", "branch": "Ogijo Branch"
            })
            p_data = PortfolioService.get_portfolio_data_for_scope(uow, co_scope)
            self.assertIn("summary", p_data)
            self.assertIn("client_table", p_data)


if __name__ == "__main__":
    unittest.main()
