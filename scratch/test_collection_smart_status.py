import unittest

class TestCollectionSmartStatus(unittest.TestCase):

    def classify_collection(self, rep_val, exp_amt, is_marked_not_paid):
        if is_marked_not_paid or rep_val == 0.0:
            rep = 0.0
            p_status = "NOT_PAID"
            overdue_val = exp_amt
        elif exp_amt > 0 and rep_val == exp_amt:
            rep = rep_val
            p_status = "PAID"
            overdue_val = 0.0
        elif exp_amt > 0 and rep_val > exp_amt:
            rep = rep_val
            p_status = "EXCESS"
            overdue_val = 0.0
        elif exp_amt > 0 and rep_val < exp_amt and rep_val > 0:
            rep = rep_val
            p_status = "PART_PAID"
            overdue_val = max(0.0, exp_amt - rep_val)
        else:
            rep = rep_val
            p_status = "PAID"
            overdue_val = 0.0
        return rep, p_status, overdue_val

    def test_not_paid_marked(self):
        rep, status, overdue = self.classify_collection(10250.0, 10250.0, is_marked_not_paid=True)
        self.assertEqual(rep, 0.0)
        self.assertEqual(status, "NOT_PAID")
        self.assertEqual(overdue, 10250.0)

    def test_not_paid_zero_val(self):
        rep, status, overdue = self.classify_collection(0.0, 10250.0, is_marked_not_paid=False)
        self.assertEqual(rep, 0.0)
        self.assertEqual(status, "NOT_PAID")
        self.assertEqual(overdue, 10250.0)

    def test_full_paid(self):
        rep, status, overdue = self.classify_collection(10250.0, 10250.0, is_marked_not_paid=False)
        self.assertEqual(rep, 10250.0)
        self.assertEqual(status, "PAID")
        self.assertEqual(overdue, 0.0)

    def test_part_paid(self):
        rep, status, overdue = self.classify_collection(5000.0, 10250.0, is_marked_not_paid=False)
        self.assertEqual(rep, 5000.0)
        self.assertEqual(status, "PART_PAID")
        self.assertEqual(overdue, 5250.0)

    def test_excess_paid(self):
        rep, status, overdue = self.classify_collection(20000.0, 10250.0, is_marked_not_paid=False)
        self.assertEqual(rep, 20000.0)
        self.assertEqual(status, "EXCESS")
        self.assertEqual(overdue, 0.0)

if __name__ == '__main__':
    unittest.main()
