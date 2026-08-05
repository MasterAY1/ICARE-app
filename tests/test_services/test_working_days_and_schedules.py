import unittest
from datetime import date
from services.business_date_service import BusinessDateService
from services.loan_product_engine import LoanProductEngine

class TestWorkingDaysAndSchedules(unittest.TestCase):

    def test_non_working_days_weekend_block(self):
        """Test Saturday and Sunday are flagged as non-working days."""
        sunday_date = date(2026, 8, 9)  # Sunday
        is_valid, reason = BusinessDateService.is_working_day(sunday_date)
        self.assertFalse(is_valid)
        self.assertIn("Sunday is a weekend", reason)

        saturday_date = date(2026, 8, 8)  # Saturday
        is_valid_sat, reason_sat = BusinessDateService.is_working_day(saturday_date)
        self.assertFalse(is_valid_sat)
        self.assertIn("Saturday is a weekend", reason_sat)

    def test_working_days_weekday_valid(self):
        """Test Monday is a valid working day."""
        monday_date = date(2026, 8, 10)  # Monday
        is_valid, _ = BusinessDateService.is_working_day(monday_date)
        self.assertTrue(is_valid)

    def test_daily_schedule_skips_weekends(self):
        """Test Daily program generates Monday to Friday installments skipping weekends."""
        start_d = date(2026, 8, 7)  # Friday
        schedule = LoanProductEngine.generate_repayment_schedule(start_d, 5, "Daily")
        self.assertEqual(len(schedule), 5)
        for d in schedule:
            self.assertLess(d.weekday(), 5)  # M-F only

    def test_weekly_group_meeting_day_schedule(self):
        """Test Weekly program aligns strictly with Group Meeting Day."""
        start_d = date(2026, 8, 6)  # Thursday
        schedule = LoanProductEngine.generate_repayment_schedule(start_d, 4, "Weekly", meeting_day="Thursday")
        self.assertEqual(len(schedule), 4)
        for d in schedule:
            self.assertEqual(d.weekday(), 3)  # Thursday is weekday 3

    def test_monthly_one_month_offset_schedule(self):
        """Test Monthly program starts 1 month after start_date."""
        start_d = date(2026, 8, 6)
        schedule = LoanProductEngine.generate_repayment_schedule(start_d, 3, "Monthly")
        self.assertEqual(len(schedule), 3)
        self.assertEqual(schedule[0], date(2026, 9, 7))  # Sept 6 is Sunday -> shifts to Monday Sept 7

if __name__ == "__main__":
    unittest.main()
