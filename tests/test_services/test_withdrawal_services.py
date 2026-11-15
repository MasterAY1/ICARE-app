import unittest
from datetime import date
from unittest.mock import MagicMock, patch
from services.savings_service import SavingsService


class TestWithdrawalServices(unittest.TestCase):
    def setUp(self):
        from services.posting_engine import FinancialPostingEngine
        FinancialPostingEngine._rules_cache.clear()
        self.mock_uow = MagicMock()
        self.mock_uow.event_store.is_processed.return_value = False

        def _get_rule(ev_type, version=1):
            pairs = {
                "LoanOffsetFromSavings": ("2000", "1200"),
                "LapsTransferred": ("2000", "2030"),
                "LapsPaidOut": ("2030", "1000"),
                "SavingsWithdrawn": ("2000", "1000"),
                "FeeOffsetFromSavings": ("2000", "3000"),
                "SavingsTransferred": ("2000", "2000"),
            }
            if ev_type in pairs:
                r = MagicMock()
                r.debit_account, r.credit_account = pairs[ev_type]
                return r
            return None

        self.mock_uow.posting_rules.get_rule.side_effect = _get_rule
        self.mock_uow.client.rpc.return_value.execute.return_value = MagicMock(data={"success": True})
        self.mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value = MagicMock(data=[])
        self.mock_uow.individual_savings.get_total_balance.return_value = 50000.0
        self.weekday = date(2026, 8, 12)

    def tearDown(self):
        from services.posting_engine import FinancialPostingEngine
        FinancialPostingEngine._rules_cache.clear()

    def _common_patches(self):
        return (
            patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")),
            patch("services.posting_engine.FinancialPostingEngine._resolve_branch_id", return_value="b-uuid-1"),
            patch("services.posting_engine.FinancialPostingEngine._resolve_officer_id", return_value="o-uuid-1"),
        )

    def _extract_rpc_ops(self):
        rpc_calls = self.mock_uow.client.rpc.call_args_list
        self.assertTrue(any(c.args[0] == "atomic_execute_operations" for c in rpc_calls))
        for c in reversed(rpc_calls):
            if c.args[0] == "atomic_execute_operations":
                return c.args[1]["p_operations"]
        return []

    def test_post_loan_offset_from_savings(self):
        p1, p2, p3 = self._common_patches()
        with p1, p2, p3:
            result = SavingsService.post_loan_offset_from_savings(
                uow=self.mock_uow,
                client_id="client-001",
                client_name="John Doe",
                loan_id="loan-001",
                source_savings_type="IndividualSavings",
                branch="Lagos",
                officer="officer1",
                amount=20000.0,
                reference="REF-OFFSET-001",
                remarks="Loan offset using savings",
                posting_date=self.weekday,
            )
        self.assertEqual(result["status"], "SUCCESS")
        self.assertEqual(result["amount"], 20000.0)
        self.assertFalse(result["affects_cash_vault"])

        ops = self._extract_rpc_ops()
        tables = [o.get("table") for o in ops]
        self.assertIn("individual_savings", tables)
        self.assertIn("repayments", tables)
        self.assertIn("event_store", tables)
        self.assertIn("user_audit_logs", tables)
        self.assertTrue(any(o.get("type") == "post_financial_transaction" for o in ops))

    def test_transfer_to_laps(self):
        p1, p2, p3 = self._common_patches()
        with p1, p2, p3:
            result = SavingsService.transfer_to_laps(
                uow=self.mock_uow,
                client_id="c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
                client_name="John Doe",
                source_savings_type="IndividualSavings",
                branch="Lagos",
                officer="officer1",
                amount=15000.0,
                reference="REF-TRANSFER-001",
                remarks="Transfer savings to LAPS",
                posting_date=self.weekday,
            )
        self.assertEqual(result["status"], "SUCCESS")
        self.assertEqual(result["amount"], 15000.0)
        self.assertFalse(result["affects_cash_vault"])

        ops = self._extract_rpc_ops()
        tables = [o.get("table") for o in ops]
        self.assertIn("individual_savings", tables)
        self.assertIn("laps_savings", tables)
        self.assertIn("event_store", tables)
        self.assertIn("user_audit_logs", tables)

    def test_pay_laps_cash_true(self):
        p1, p2, p3 = self._common_patches()
        with p1, p2, p3:
            result = SavingsService.pay_laps(
                uow=self.mock_uow,
                client_id="client-001",
                client_name="John Doe",
                branch="Lagos",
                officer="officer1",
                amount=10000.0,
                cash_paid=True,
                reference="REF-PAYOUT-001",
                remarks="LAPS cash payout",
                posting_date=self.weekday,
            )
        self.assertEqual(result["status"], "SUCCESS")
        self.assertEqual(result["amount"], 10000.0)
        self.assertTrue(result["cash_paid"])
        self.assertTrue(result["affects_cash_vault"])

        ops = self._extract_rpc_ops()
        tables = [o.get("table") for o in ops]
        self.assertIn("laps_savings", tables)
        self.assertIn("event_store", tables)
        self.assertIn("user_audit_logs", tables)

    def test_pay_laps_cash_false(self):
        p1, p2, p3 = self._common_patches()
        with p1, p2, p3:
            result = SavingsService.pay_laps(
                uow=self.mock_uow,
                client_id="client-001",
                client_name="John Doe",
                branch="Lagos",
                officer="officer1",
                amount=10000.0,
                cash_paid=False,
                reference="REF-PAYOUT-002",
                remarks="LAPS bank transfer payout",
                posting_date=self.weekday,
            )
        self.assertEqual(result["status"], "SUCCESS")
        self.assertEqual(result["amount"], 10000.0)
        self.assertFalse(result["cash_paid"])
        self.assertFalse(result["affects_cash_vault"])
        ops = self._extract_rpc_ops()
        fin_ops = [o for o in ops if o.get("type") == "post_financial_transaction"]
        self.assertEqual(len(fin_ops), 1)
        cr_accounts = [e["account_code"] for e in fin_ops[0]["record"]["entries_payload"] if e["side"] == "Credit"]
        self.assertIn("1050", cr_accounts)

    def test_invalid_amount_validation(self):
        with self.assertRaises(ValueError):
            SavingsService.post_loan_offset_from_savings(
                uow=self.mock_uow,
                client_id="c1", client_name="N", loan_id="l1",
                source_savings_type="IndividualSavings", branch="B", officer="O", amount=0.0
            )

        with self.assertRaises(ValueError):
            SavingsService.transfer_to_laps(
                uow=self.mock_uow,
                client_id="c1", client_name="N",
                source_savings_type="IndividualSavings", branch="B", officer="O", amount=-500.0
            )

        with self.assertRaises(ValueError):
            SavingsService.pay_laps(
                uow=self.mock_uow,
                client_id="c1", client_name="N", branch="B", officer="O", amount=0.0
            )

if __name__ == "__main__":
    unittest.main()
