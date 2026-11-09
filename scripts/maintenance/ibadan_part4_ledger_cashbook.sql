INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('606339c3-30dd-57db-b376-4ce94be258c2', '94198d96-ddd2-5967-864b-8790bcc55152', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Debit', 2000000.0, 'Capital', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-08-01 08:00:00+00'),
        ('a4f8826d-ce7e-5bf6-a9ce-6918c13f888c', '94198d96-ddd2-5967-864b-8790bcc55152', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '3100', 'Credit', 2000000.0, 'Capital', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-08-01 08:00:00+00')
    ON CONFLICT (entry_id) DO NOTHING;

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('f2ff738e-67c2-578d-b56e-07c779ebbb91', 'af98aa70-a363-56d9-bab7-19f5f44940d5', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1200', 'Debit', 1850000.0, 'Disbursement', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-12 09:00:00+00'),
        ('cadea3b2-fcf5-5bcb-9796-0309275128dc', 'af98aa70-a363-56d9-bab7-19f5f44940d5', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Credit', 1850000.0, 'Disbursement', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-12 09:00:00+00')
    ON CONFLICT (entry_id) DO NOTHING;

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('385948ca-76a1-5a27-8532-102965b7aee4', '4f9ce13c-80c7-5f3a-be7f-3c4e640ad731', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Debit', 293900.0, 'FeeIncome', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-12 09:30:00+00'),
        ('6524bf5d-8129-550c-b1d6-7e5ff6a1ba8e', '4f9ce13c-80c7-5f3a-be7f-3c4e640ad731', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '3000', 'Credit', 293900.0, 'FeeIncome', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-12 09:30:00+00')
    ON CONFLICT (entry_id) DO NOTHING;

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('74944163-d88b-52c2-9989-4746279ccf37', 'd9c4c220-b9a3-5871-9aa1-34f139f811d2', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Debit', 765350.0, 'Repayment', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-06 16:00:00+00'),
        ('3442ca69-dbef-5223-9530-fa5a459fd447', 'd9c4c220-b9a3-5871-9aa1-34f139f811d2', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1200', 'Credit', 765350.0, 'Repayment', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-06 16:00:00+00')
    ON CONFLICT (entry_id) DO NOTHING;

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('4f7c6113-7a74-594e-8b5c-b4aee2a8221d', '3120c33e-41c4-5b24-a76e-faba92a10c34', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Debit', 521500.0, 'Savings', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-01 10:00:00+00'),
        ('562f5d9c-bb67-53d8-9979-1c736851e9ae', '3120c33e-41c4-5b24-a76e-faba92a10c34', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2000', 'Credit', 406500.0, 'Savings', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-01 10:00:00+00'),
        ('7ed773bb-64cf-5284-b522-5ea19576bcb3', '3120c33e-41c4-5b24-a76e-faba92a10c34', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2010', 'Credit', 75000.0, 'Savings', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-01 10:00:00+00'),
        ('5e676e50-b736-5447-8d3a-69424a25fe1e', '3120c33e-41c4-5b24-a76e-faba92a10c34', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2030', 'Credit', 40000.0, 'Savings', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-01 10:00:00+00')
    ON CONFLICT (entry_id) DO NOTHING;

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('70c3e483-09e9-5e1f-bad8-ed85c149b5d2', 'acc8a9cd-bb38-5644-ac90-81961f526430', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1050', 'Debit', 1380750.0, 'Remittance', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-06 17:00:00+00'),
        ('c6a6130b-d9a3-5310-8330-4e6308394ad5', 'acc8a9cd-bb38-5644-ac90-81961f526430', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Credit', 1380750.0, 'Remittance', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-06 17:00:00+00')
    ON CONFLICT (entry_id) DO NOTHING;

INSERT INTO master_cashbook (id, date, branch_id, opening_balance, total_inflows, total_outflows, closing_balance, status, version, created_at)
    VALUES 
        ('1d9814f6-fdb3-5613-ab1b-c4c8b3d27438', '2026-11-06', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 0.0, 350000.0, 0.0, 350000.0, 'Closed', 1, '2026-11-06 18:00:00+00'),
        ('dac08c7c-6f47-5d97-9b88-026873619d86', '2026-11-09', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 350000.0, 0.0, 0.0, 350000.0, 'Open', 1, '2026-11-09 07:00:00+00')
    ON CONFLICT (id) DO UPDATE SET
        opening_balance = EXCLUDED.opening_balance,
        closing_balance = EXCLUDED.closing_balance,
        status = EXCLUDED.status;