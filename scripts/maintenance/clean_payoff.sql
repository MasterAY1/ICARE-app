INSERT INTO loan_payoff_excess_records (id, repayment_id, loan_id, client_id, officer_id, branch_id, date, record_type, amount_paid, expected_installment, active_credit_settled, excess_amount, remaining_balance_before, remaining_balance_after, notes, created_at)
VALUES
('b4989ae5-a17a-5ba6-b46a-1e43757c35d4', '72e2d794-6897-5a0e-80be-5d8e9296b85a', '24ae3f4e-3531-5acc-b526-66d9edc42c81', '762c7043-30f7-5d1c-99a6-64fe4fce25f3', '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-09', 'FULL_PAYOFF', 1650.0, 1650.0, 99000.0, 0.0, 1650.0, 0.0, 'Full loan completion settlement', NOW()),
('53cc1982-39f8-5094-b361-4186feb2faf3', 'b1cf9120-f919-5916-ba1e-aed85cb65f67', '73087939-d83b-54c9-8729-655db6d33b34', '16da0205-b8a5-5df9-bfbb-3d05669968ba', '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-06', 'FULL_PAYOFF', 8250.0, 8250.0, 99000.0, 0.0, 8250.0, 0.0, 'Full loan completion settlement', NOW())
ON CONFLICT (id) DO UPDATE SET
    payoff_amount = EXCLUDED.payoff_amount,
    excess_amount = EXCLUDED.excess_amount;