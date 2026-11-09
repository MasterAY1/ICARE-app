INSERT INTO loan_payoff_excess_records (id, repayment_id, loan_id, client_id, officer_id, branch_id, date, record_type, amount_paid, expected_installment, active_credit_settled, excess_amount, remaining_balance_before, remaining_balance_after, notes, created_at)
VALUES
('68d4cf6b-55b0-5e7c-a6ff-e512d7f39959', '0705115b-9c7d-5b87-a6a3-70e8ae6383d8', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-02', 'FULL_PAYOFF', 1650.0, 1650.0, 99000.0, 0.0, 1650.0, 0.0, 'Full loan completion settlement', NOW()),
('9a89945e-fb8b-5763-9f33-f1c46d07fdc6', '6c4d1a26-b290-550e-a4eb-0925075cea27', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-06', 'FULL_PAYOFF', 8250.0, 8250.0, 99000.0, 0.0, 8250.0, 0.0, 'Full loan completion settlement', NOW())
ON CONFLICT (id) DO UPDATE SET
    amount_paid = EXCLUDED.amount_paid,
    excess_amount = EXCLUDED.excess_amount;