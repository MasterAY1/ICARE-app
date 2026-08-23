import unittest
from datetime import date, datetime
from unittest.mock import MagicMock, patch
import pandas as pd
from services.rbac_scope_service import RBACScopeService

class TestMasterCashbookMonthlyLedger(unittest.TestCase):
    def test_r1_tab1_balancing_identity(self):
        auto_opening = 50000.0
        auto_savings = 25000.0
        auto_rep_60d = 10000.0
        auto_rep_120d = 5000.0
        auto_rep_12w = 30000.0
        auto_rep_24w = 15000.0
        auto_rep_mth = 20000.0
        auto_laps_res = 5000.0
        funds_ho = 100000.0
        funds_branch = 0.0
        funds_area = 0.0
        auto_asset_cr_sales = 0.0
        auto_cash_carry = 0.0
        auto_fund_finance = 80000.0
        auto_fund_asset = 0.0
        auto_daily_11 = 1100.0
        auto_daily_20 = 0.0
        auto_weekly_11 = 3300.0
        auto_weekly_20 = 0.0
        auto_monthly_markup = 2000.0
        auto_contingency = 800.0
        auto_credit_form_dmg = 0.0
        auto_bonus = 0.0
        auto_app_fee = 1000.0
        auto_passbook = 500.0
        auto_bank_wd = 0.0

        auto_prod_wd = 5000.0
        xfer_branch = 0.0
        xfer_ho = 0.0
        xfer_area = 0.0
        salaries = 20000.0
        auto_expenses = 4000.0
        auto_laps_ret = 0.0
        auto_bank_dep = 60000.0

        total_inflows = (
            auto_opening + auto_savings + auto_rep_60d + auto_rep_120d + auto_rep_12w + auto_rep_24w + auto_rep_mth +
            auto_laps_res + funds_ho + funds_branch + funds_area +
            auto_asset_cr_sales + auto_cash_carry + auto_fund_finance +
            auto_daily_11 + auto_daily_20 + auto_weekly_11 + auto_weekly_20 + auto_monthly_markup +
            auto_contingency + auto_credit_form_dmg + auto_bonus + auto_app_fee + auto_passbook + auto_bank_wd
        )

        total_outflows = (
            auto_prod_wd +
            auto_fund_asset + auto_fund_finance +
            xfer_branch + xfer_ho + xfer_area +
            salaries + auto_expenses + auto_laps_ret + auto_bank_dep
        )

        closing_balance = total_inflows - total_outflows

        inflows_without = total_inflows - auto_fund_finance
        outflows_without = total_outflows - auto_fund_finance
        closing_without = inflows_without - outflows_without

        self.assertEqual(closing_balance, closing_without)

    def test_r2_rbac_branch_selector_resolution(self):
        admin_user = {'id': 'u-admin', 'username': 'admin', 'role': 'Admin', 'branch': 'Head Office', 'branch_id': 'b-ho', 'assigned_branches': []}
        am_user = {'id': 'u-am', 'username': 'areamanager', 'role': 'Area Manager', 'branch': 'Ogijo', 'branch_id': 'b-ogijo', 'assigned_branches': ['Ogijo', 'Ikorodu']}
        bm_user = {'id': 'u-bm', 'username': 'kola_bm', 'role': 'Branch Manager', 'branch': 'Kola', 'branch_id': 'b-kola', 'assigned_branches': []}

        scope_admin = RBACScopeService.resolve_scope(admin_user)
        scope_am = RBACScopeService.resolve_scope(am_user)
        scope_bm = RBACScopeService.resolve_scope(bm_user)

        self.assertEqual(scope_admin.scope_level, 'INSTITUTION')
        self.assertEqual(scope_am.scope_level, 'REGION')
        self.assertEqual(scope_bm.scope_level, 'BRANCH')

        self.assertIn('Ogijo', scope_am.assigned_branch_names)
        self.assertIn('Ikorodu', scope_am.assigned_branch_names)
        self.assertEqual(scope_bm.branch_name, 'Kola')

    def test_r3_dynamic_loan_product_breakdown(self):
        loans_data = [
            {'Date': '2026-08-10', 'Branch': 'Ogijo', 'Status': 'Active', 'Loan Amount': 30000, 'Active Credit': 30000, 'Loan Product': 'Daily 60 Days', 'Product Category': 'Finance'},
            {'Date': '2026-08-10', 'Branch': 'Ogijo', 'Status': 'Active', 'Loan Amount': 50000, 'Active Credit': 50000, 'Loan Product': 'Daily 120 Days', 'Product Category': 'Finance'},
            {'Date': '2026-08-10', 'Branch': 'Ogijo', 'Status': 'Active', 'Loan Amount': 40000, 'Active Credit': 40000, 'Loan Product': 'Weekly 12 Weeks', 'Product Category': 'Finance'},
            {'Date': '2026-08-10', 'Branch': 'Ogijo', 'Status': 'Active', 'Loan Amount': 60000, 'Active Credit': 60000, 'Loan Product': 'Weekly 24 Weeks', 'Product Category': 'Finance'},
            {'Date': '2026-08-10', 'Branch': 'Ogijo', 'Status': 'Active', 'Loan Amount': 100000, 'Active Credit': 100000, 'Loan Product': 'Monthly 3 Months', 'Product Category': 'Finance'},
            {'Date': '2026-08-10', 'Branch': 'Kola', 'Status': 'Active', 'Loan Amount': 25000, 'Active Credit': 25000, 'Loan Product': 'Weekly 12 Weeks', 'Product Category': 'Finance'},
            {'Date': '2026-08-10', 'Branch': 'Ogijo', 'Status': 'Active', 'Loan Amount': 99000, 'Active Credit': 99000, 'Loan Product': 'Weekly 12 Weeks', 'Product Category': 'Finance', 'extra_fields': {'is_legacy': True}},
        ]
        all_loans = pd.DataFrame(loans_data)

        selected_mc_branch = 'Ogijo'
        loan_disb_map = {}
        loans_df = all_loans.copy()
        if 'extra_fields' in loans_df.columns:
            loans_df = loans_df[~loans_df['extra_fields'].apply(lambda x: isinstance(x, dict) and x.get('is_legacy') is True)]
        if 'Branch' in loans_df.columns and selected_mc_branch:
            loans_df = loans_df[loans_df['Branch'] == selected_mc_branch]
        if 'Status' in loans_df.columns:
            loans_df = loans_df[loans_df['Status'].isin(['Active', 'Approved', 'Completed'])]

        loans_df['_dt_str'] = pd.to_datetime(loans_df['Date'], errors='coerce').dt.strftime('%Y-%m-%d')
        for _, l_row in loans_df.iterrows():
            d_key = l_row.get('_dt_str')
            if d_key not in loan_disb_map:
                loan_disb_map[d_key] = {
                    'disb_60d': 0.0, 'disb_120d': 0.0, 'disb_12w': 0.0, 'disb_24w': 0.0, 'disb_mth': 0.0,
                    'fund_asset': 0.0, 'fund_finance': 0.0
                }
            princ = float(l_row.get('Loan Amount', 0))
            act_cr = float(l_row.get('Active Credit', princ))
            p_cat = str(l_row.get('Product Category', 'Finance'))
            p_name = str(l_row.get('Loan Product', '')).lower()

            if 'Asset' in p_cat:
                loan_disb_map[d_key]['fund_asset'] += princ
            else:
                loan_disb_map[d_key]['fund_finance'] += princ

            if '120' in p_name: loan_disb_map[d_key]['disb_120d'] += act_cr
            elif '60' in p_name: loan_disb_map[d_key]['disb_60d'] += act_cr
            elif '24w' in p_name or '24' in p_name: loan_disb_map[d_key]['disb_24w'] += act_cr
            elif '12w' in p_name or '12' in p_name: loan_disb_map[d_key]['disb_12w'] += act_cr
            elif '3m' in p_name or '6m' in p_name or 'month' in p_name: loan_disb_map[d_key]['disb_mth'] += act_cr
            else: loan_disb_map[d_key]['disb_12w'] += act_cr

        d_res = loan_disb_map['2026-08-10']
        self.assertEqual(d_res['disb_60d'], 30000.0)
        self.assertEqual(d_res['disb_120d'], 50000.0)
        self.assertEqual(d_res['disb_12w'], 40000.0)
        self.assertEqual(d_res['disb_24w'], 60000.0)
        self.assertEqual(d_res['disb_mth'], 100000.0)
        self.assertEqual(d_res['fund_finance'], 280000.0)

    def test_r4_monthly_kpi_summary_and_identity(self):
        records = [
            {'date': '2026-08-03', 'opening_balance': 150000.0, 'total_inflows': 230000.0, 'total_outflows': 60000.0, 'closing_balance': 170000.0},
            {'date': '2026-08-04', 'opening_balance': 170000.0, 'total_inflows': 290000.0, 'total_outflows': 110000.0, 'closing_balance': 180000.0},
            {'date': '2026-08-05', 'opening_balance': 180000.0, 'total_inflows': 260000.0, 'total_outflows': 90000.0, 'closing_balance': 170000.0},
            {'date': '2026-08-06', 'opening_balance': 170000.0, 'total_inflows': 310000.0, 'total_outflows': 130000.0, 'closing_balance': 180000.0},
            {'date': '2026-08-07', 'opening_balance': 180000.0, 'total_inflows': 275000.0, 'total_outflows': 85000.0, 'closing_balance': 190000.0},
        ]
        display_df = pd.DataFrame(records)

        month_opening = float(display_df.iloc[0]['opening_balance'])
        month_inflows = float((display_df['total_inflows'] - display_df['opening_balance']).sum())
        month_outflows = float(display_df['total_outflows'].sum())
        month_closing = float(display_df.iloc[-1]['closing_balance'])

        self.assertEqual(month_opening, 150000.0)
        self.assertEqual(month_inflows, 515000.0)
        self.assertEqual(month_outflows, 475000.0)
        self.assertEqual(month_closing, 190000.0)

        self.assertEqual(month_opening + month_inflows - month_outflows, month_closing)

    def test_r2_am_uuid_branch_resolution(self):
        # Simulate Area Manager with assigned_branch_ids as UUIDs
        id_to_name = {
            "b-uuid-1": "Ogijo",
            "b-uuid-2": "Ikorodu",
            "b-uuid-3": "Kola",
        }
        all_operational = ["Ibadan", "Ikorodu", "Kola", "Ogijo"]

        am_user = {
            'id': 'u-am', 'username': 'areamanager', 'role': 'Area Manager',
            'branch': 'Ogijo', 'branch_id': 'b-uuid-1',
            'assigned_branches': ["b-uuid-1", "b-uuid-2", "b-uuid-3"],
            'assigned_branch_ids': ["b-uuid-1", "b-uuid-2", "b-uuid-3"]
        }
        scope = RBACScopeService.resolve_scope(am_user)

        raw_assigned = list(scope.assigned_branch_names or []) + list(scope.assigned_branch_ids or [])
        resolved_assigned = []
        for b in raw_assigned:
            b_str = str(b)
            if b_str in id_to_name:
                resolved_assigned.append(id_to_name[b_str])
            elif b_str in all_operational:
                resolved_assigned.append(b_str)
        branch_options = sorted(list(set(b for b in resolved_assigned if b and b != "Head Office")))

        self.assertEqual(branch_options, ["Ikorodu", "Kola", "Ogijo"])
        self.assertNotIn("Head Office", branch_options)

    def test_tab1_loan_routing_and_fallbacks(self):
        today_loans_data = [
            {'Loan Product': 'Daily 60 Days', 'Loan Amount': 20000, 'Active Credit': 20000, 'Product Category': 'Finance'},
            {'Loan Product': '120 Days Special', 'Loan Amount': 40000, 'Active Credit': 40000, 'Product Category': 'Finance'},
            {'Loan Product': 'Weekly 12 Weeks Regular', 'Loan Amount': 30000, 'Active Credit': 30000, 'Product Category': 'Finance'},
            {'Loan Product': 'Weekly 24 Weeks Extended', 'Loan Amount': 50000, 'Active Credit': 50000, 'Product Category': 'Finance'},
            {'Loan Product': 'Monthly 3M Asset Program', 'Loan Amount': 70000, 'Active Credit': 70000, 'Product Category': 'Asset'},
            {'Loan Product': 'Unknown Product Custom', 'Loan Amount': 15000, 'Active Credit': 0, 'Product Category': 'Finance'},
        ]
        today_loans = pd.DataFrame(today_loans_data)

        auto_fund_asset = 0.0
        auto_fund_finance = 0.0
        auto_disb_60d = 0.0
        auto_disb_120d = 0.0
        auto_disb_12w = 0.0
        auto_disb_24w = 0.0
        auto_disb_mth = 0.0

        for _, loan in today_loans.iterrows():
            principal = pd.to_numeric(loan.get('Loan Amount', 0), errors='coerce')
            active_cr = pd.to_numeric(loan.get('Active Credit', 0), errors='coerce')
            if pd.isna(principal): principal = 0
            if pd.isna(active_cr) or active_cr == 0: active_cr = principal
            cat = str(loan.get('Product Category', 'Finance'))
            prod = str(loan.get('Loan Product', '')).lower()
            if 'Asset' in cat:
                auto_fund_asset += principal
            else:
                auto_fund_finance += principal

            if '120' in prod: auto_disb_120d += active_cr
            elif '60' in prod: auto_disb_60d += active_cr
            elif '24w' in prod or '24' in prod: auto_disb_24w += active_cr
            elif '12w' in prod or '12' in prod: auto_disb_12w += active_cr
            elif '3m' in prod or '6m' in prod or 'month' in prod: auto_disb_mth += active_cr
            else: auto_disb_12w += active_cr

        self.assertEqual(auto_disb_60d, 20000.0)
        self.assertEqual(auto_disb_120d, 40000.0)
        self.assertEqual(auto_disb_12w, 45000.0)  # 30000 (12w) + 15000 (fallback)
        self.assertEqual(auto_disb_24w, 50000.0)
        self.assertEqual(auto_disb_mth, 70000.0)
        self.assertEqual(auto_fund_asset, 70000.0)
        self.assertEqual(auto_fund_finance, 155000.0)

    def test_excel_export_output_stream(self):
        import io
        display_cols = [
            'date', 'opening_balance', 'savings_deposit',
            'rep_daily', 'rep_120_days', 'rep_12_weeks', 'rep_24_weeks', 'rep_monthly',
            'laps_reserve',
            'funds_received_ho', 'funds_received_other_branch', 'funds_received_other_area',
            'asset_credit_sales', 'cash_and_carry', 'loan_received_finance',
            'daily_11_pct', 'daily_20_pct', 'weekly_11_pct', 'weekly_20_pct', 'risk_premium_returns',
            'contingency', 'credit_form_damage', 'bonus', 'app_fee', 'passbook', 'bank_withdrawal',
            'total_inflows',
            'disb_60d', 'disb_120d', 'disb_12w', 'disb_24w', 'disb_mth',
            'fund_transferred_other_branch', 'fund_transferred_ho', 'fund_to_other_area',
            'fund_to_asset_program', 'fund_to_product_finance',
            'product_withdrawal', 'staff_salaries', 'office_expenses',
            'laps_returns', 'bank_deposit',
            'total_outflows', 'closing_balance'
        ]
        df = pd.DataFrame([{c: 0.0 for c in display_cols}])
        df['date'] = '2026-08-01'

        col_rename = {
            "date": "Date", "opening_balance": "Opening Balance", "savings_deposit": "Savings Deposit (Amount)",
            "rep_daily": "Credit Repayment (60 days)", "rep_120_days": "Credit Repayment (120 days)",
            "rep_12_weeks": "Credit Repayment (12 weeks)", "rep_24_weeks": "Credit Repayment (24 weeks)",
            "rep_monthly": "Credit Repayment (Monthly)", "laps_reserve": "Laps Reserve",
            "funds_received_ho": "Funds Received from Head Office",
            "funds_received_other_branch": "Funds Received from Branch Office",
            "funds_received_other_area": "Funds Received from Other Areas",
            "asset_credit_sales": "Asset Credit Sales", "cash_and_carry": "Cash & Carry",
            "loan_received_finance": "Funds from Finance",
            "daily_11_pct": "Daily 11%", "daily_20_pct": "Daily 20%", "weekly_11_pct": "Weekly 11%",
            "weekly_20_pct": "Weekly 20%", "risk_premium_returns": "Monthly 11%/20%",
            "contingency": "Contingency (1%)", "credit_form_damage": "Credit form damage",
            "bonus": "Bonus", "app_fee": "Credit form/App fee", "passbook": "Pass book",
            "bank_withdrawal": "Bank withdrawal", "total_inflows": "Total Inflows",
            "disb_60d": "60 days", "disb_120d": "120 days", "disb_12w": "12 weeks", "disb_24w": "24 weeks",
            "disb_mth": "Monthly", "fund_transferred_other_branch": "Branch Office",
            "fund_transferred_ho": "Head office", "fund_to_other_area": "Other Areas",
            "fund_to_asset_program": "Fund To Assets", "fund_to_product_finance": "Fund to Finance",
            "product_withdrawal": "Product/Savings withdrawals", "staff_salaries": "Staff Salaries",
            "office_expenses": "Office Expenses", "laps_returns": "Laps Return",
            "bank_deposit": "Bank Deposit", "total_outflows": "Total Outflows",
            "closing_balance": "Closing Balance"
        }
        df_renamed = df.rename(columns=col_rename)

        output = io.BytesIO()
        with pd.ExcelWriter(output, engine='openpyxl') as writer:
            df_renamed.to_excel(writer, sheet_name='Ledger Data', index=False)

        excel_bytes = output.getvalue()
        self.assertGreater(len(excel_bytes), 0)

        # Read back to verify
        read_df = pd.read_excel(io.BytesIO(excel_bytes), sheet_name='Ledger Data')
        self.assertEqual(len(read_df.columns), 44)
        self.assertIn("Funds from Finance", read_df.columns)
        self.assertIn("Fund to Finance", read_df.columns)

    def test_funds_received_other_area_domain_and_db_mapping(self):
        """Verify funds_received_other_area is faithfully mapped across Domain and Database"""
        from domain.entities.cashbook_entry import CashbookEntry
        from mappers.base_mappers import CashbookMapper

        dto = {
            "date": "2026-08-15",
            "branch": "Ogijo",
            "opening_balance": 50000.0,
            "funds_received_other_area": 35000.0,
            "fund_to_other_area": 12000.0,
            "loan_received_finance": 20000.0,
            "fund_to_product_finance": 20000.0,
            "total_inflows": 105000.0,
            "total_outflows": 32000.0,
            "closing_balance": 73000.0
        }

        entity = CashbookMapper.to_domain(dto)
        self.assertEqual(entity.funds_received_other_area, 35000.0)
        self.assertEqual(entity.fund_to_other_area, 12000.0)
        self.assertEqual(entity.loan_received_finance, 20000.0)

        db_dict = CashbookMapper.to_database(entity)
        self.assertEqual(db_dict["funds_received_other_area"], 35000.0)
        self.assertEqual(db_dict["fund_to_other_area"], 12000.0)
        self.assertEqual(db_dict["loan_received_finance"], 20000.0)

    def test_repository_resolve_branch_id_handles_both_uuid_and_name(self):
        """Verify cashbook repository resolves both UUID strings and human branch names without exception"""
        from database.repositories.cashbook_repository import SupabaseCashbookRepository

        mock_client = MagicMock()
        mock_client.table().select().eq().execute().data = [{"branch_id": "resolved-b-uuid"}]

        repo = SupabaseCashbookRepository(mock_client)

        # 1. UUID string input
        test_uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        res_uuid = repo._resolve_branch_id(test_uuid)
        self.assertEqual(res_uuid, test_uuid)

        # 2. Branch name input
        res_name = repo._resolve_branch_id("Ogijo")
        self.assertEqual(res_name, "resolved-b-uuid")

    def test_multi_branch_switching_and_legacy_filtering_integration(self):
        """ISSUE-03 Simulation: AM switching branches, legacy exclusion, dynamic overlay and Excel export"""
        import io
        am_user = {
            'id': 'u-am-1', 'username': 'area_mgr', 'role': 'Area Manager',
            'branch': 'Ogijo', 'branch_id': 'uuid-ogijo',
            'assigned_branches': ['uuid-ogijo', 'uuid-ikorodu', 'uuid-kola']
        }
        id_to_name = {
            'uuid-ogijo': 'Ogijo',
            'uuid-ikorodu': 'Ikorodu',
            'uuid-kola': 'Kola'
        }
        all_op = ['Ibadan', 'Ikorodu', 'Kola', 'Ogijo']

        scope = RBACScopeService.resolve_scope(am_user)
        raw = list(scope.assigned_branch_names or []) + list(scope.assigned_branch_ids or [])
        resolved = []
        for b in raw:
            b_str = str(b)
            if b_str in id_to_name: resolved.append(id_to_name[b_str])
            elif b_str in all_op: resolved.append(b_str)
        branch_options = sorted(list(set(b for b in resolved if b and b != "Head Office")))
        self.assertEqual(branch_options, ['Ikorodu', 'Kola', 'Ogijo'])

        # Multi-branch dataset with legacy loans and live disbursements
        all_loans_data = [
            # Ogijo live loans
            {'Date': '2026-08-12', 'Branch': 'Ogijo', 'Status': 'Active', 'Loan Amount': 60000, 'Active Credit': 60000, 'Loan Product': 'Daily 120 Days', 'Product Category': 'Finance'},
            {'Date': '2026-08-12', 'Branch': 'Ogijo', 'Status': 'Active', 'Loan Amount': 45000, 'Active Credit': 45000, 'Loan Product': 'Weekly 12 Weeks', 'Product Category': 'Finance'},
            # Ogijo legacy loan (MUST BE IGNORED)
            {'Date': '2026-08-12', 'Branch': 'Ogijo', 'Status': 'Active', 'Loan Amount': 150000, 'Active Credit': 150000, 'Loan Product': 'Weekly 12 Weeks', 'Product Category': 'Finance', 'extra_fields': {'is_legacy': True}},
            # Ikorodu live loans
            {'Date': '2026-08-12', 'Branch': 'Ikorodu', 'Status': 'Active', 'Loan Amount': 80000, 'Active Credit': 80000, 'Loan Product': 'Weekly 24 Weeks', 'Product Category': 'Finance'},
            # Kola live loans
            {'Date': '2026-08-12', 'Branch': 'Kola', 'Status': 'Active', 'Loan Amount': 120000, 'Active Credit': 120000, 'Loan Product': 'Monthly 6 Months', 'Product Category': 'Finance'},
        ]
        all_loans = pd.DataFrame(all_loans_data)

        # Switch to Ogijo
        selected_branch = 'Ogijo'
        loans_df = all_loans.copy()
        if 'extra_fields' in loans_df.columns:
            loans_df = loans_df[~loans_df['extra_fields'].apply(lambda x: isinstance(x, dict) and x.get('is_legacy') is True)]
        loans_df = loans_df[loans_df['Branch'] == selected_branch]

        loan_disb_map = {}
        loans_df['_dt_str'] = pd.to_datetime(loans_df['Date'], errors='coerce').dt.strftime('%Y-%m-%d')
        for _, l_row in loans_df.iterrows():
            d_key = l_row.get('_dt_str')
            if d_key not in loan_disb_map:
                loan_disb_map[d_key] = {'disb_60d': 0.0, 'disb_120d': 0.0, 'disb_12w': 0.0, 'disb_24w': 0.0, 'disb_mth': 0.0, 'fund_asset': 0.0, 'fund_finance': 0.0}
            princ = float(l_row.get('Loan Amount', 0))
            act_cr = float(l_row.get('Active Credit', princ))
            p_name = str(l_row.get('Loan Product', '')).lower()
            loan_disb_map[d_key]['fund_finance'] += princ
            if '120' in p_name: loan_disb_map[d_key]['disb_120d'] += act_cr
            elif '12w' in p_name or '12' in p_name: loan_disb_map[d_key]['disb_12w'] += act_cr

        d_ogijo = loan_disb_map['2026-08-12']
        self.assertEqual(d_ogijo['disb_120d'], 60000.0)
        self.assertEqual(d_ogijo['disb_12w'], 45000.0)
        self.assertEqual(d_ogijo['fund_finance'], 105000.0) # 60k + 45k (legacy 150k excluded)

        # Historical ledger row with 0.0 fund_finance
        ledger_df = pd.DataFrame([{
            'date': '2026-08-12', 'opening_balance': 100000.0, 'savings_deposit': 50000.0,
            'loan_received_finance': 0.0, 'fund_to_product_finance': 0.0,
            'total_inflows': 150000.0, 'total_outflows': 20000.0, 'closing_balance': 130000.0
        }])

        for idx, row in ledger_df.iterrows():
            d_str = str(row.get("date", ""))[:10]
            if d_str in loan_disb_map:
                d_info = loan_disb_map[d_str]
                ledger_df.at[idx, "disb_120d"] = d_info["disb_120d"]
                ledger_df.at[idx, "disb_12w"] = d_info["disb_12w"]
                if d_info["fund_finance"] > 0 and float(row.get("fund_to_product_finance") or 0.0) == 0:
                    ledger_df.at[idx, "fund_to_product_finance"] = d_info["fund_finance"]
                    ledger_df.at[idx, "total_outflows"] = float(row.get("total_outflows") or 0.0) + d_info["fund_finance"]
                if d_info["fund_finance"] > 0 and float(row.get("loan_received_finance") or 0.0) == 0:
                    ledger_df.at[idx, "loan_received_finance"] = d_info["fund_finance"]
                    ledger_df.at[idx, "total_inflows"] = float(row.get("total_inflows") or 0.0) + d_info["fund_finance"]

        month_opening = float(ledger_df.iloc[0]["opening_balance"])
        month_inflows = float((ledger_df["total_inflows"] - ledger_df["opening_balance"]).sum())
        month_outflows = float(ledger_df["total_outflows"].sum())
        month_closing = float(ledger_df.iloc[-1]["closing_balance"])

        self.assertEqual(month_opening, 100000.0)
        self.assertEqual(month_inflows, 155000.0)  # 50k savings + 105k loan_received_finance
        self.assertEqual(month_outflows, 125000.0) # 20k + 105k fund_to_product_finance
        self.assertEqual(month_closing, 130000.0)
        self.assertEqual(month_opening + month_inflows - month_outflows, month_closing)

    def test_empty_month_ledger_safely_handled(self):
        """ISSUE-02 Simulation: Verify empty dataframe produces valid default 0.0 metrics without IndexError"""
        empty_df = pd.DataFrame()

        month_opening = float(empty_df.iloc[0]["opening_balance"]) if not empty_df.empty else 0.0
        month_inflows = float((empty_df["total_inflows"] - empty_df["opening_balance"]).sum()) if not empty_df.empty else 0.0
        month_outflows = float(empty_df["total_outflows"].sum()) if not empty_df.empty else 0.0
        month_closing = float(empty_df.iloc[-1]["closing_balance"]) if not empty_df.empty else 0.0

        self.assertEqual(month_opening, 0.0)
        self.assertEqual(month_inflows, 0.0)
        self.assertEqual(month_outflows, 0.0)
    def test_inter_area_reversal_mapping(self):
        """Verify TreasuryService reverses INTER_AREA_IN and INTER_AREA_OUT correctly"""
        from services.treasury_service import TreasuryService
        
        mock_uow = MagicMock()
        mock_uow.client.table().select().eq().execute().data = [{
            "id": "tx-area-01",
            "transaction_type": "INTER_AREA_IN",
            "amount": 50000.0,
            "branch_id": "b-uuid-1",
            "officer_id": "o-uuid-1"
        }]

        with patch("services.posting_engine.FinancialPostingEngine.post_event", return_value=("tx-id", {"type": "insert"})):
            rev_id = TreasuryService.reverse_treasury_transaction(
                mock_uow, "tx-area-01", "Duplicate entry", "BM_Ogijo"
            )
            self.assertTrue(bool(rev_id))
            
            # Check operations passed to rpc
            rpc_args = mock_uow.client.rpc.call_args[0][1]["p_operations"]
            tx_record = rpc_args[0]["record"]
            ev_record = rpc_args[1]["record"]
            self.assertEqual(tx_record["transaction_type"], "INTER_AREA_OUT")
            self.assertEqual(ev_record["event_type"], "CashTransferred_HO_Out")

if __name__ == '__main__':
    unittest.main()


