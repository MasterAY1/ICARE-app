INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 99000.0, 1650.0, 99000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('395e6390-6de1-59c3-8229-41242ee4a2df', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 1, '2026-10-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-13', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('684ccad4-b114-577d-b0db-d1edd4941f6e', '2026-10-13 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b3ba2144-7b85-5104-a665-7d23ee9d8d99', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 2, '2026-10-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-14', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('b1b853dd-ad1e-5ebd-863e-47e089a30b92', '2026-10-14 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e874ec84-913d-5b39-ac5b-c701e8a52eac', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 3, '2026-10-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-15', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('2bde9cf4-d434-5964-b48a-a50dc4f9ea7d', '2026-10-15 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('62524169-c3eb-5308-a155-377f988caa66', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 4, '2026-10-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-16', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e81b5f60-acda-5e6d-9b8a-e955da938e44', '2026-10-16 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ea4f8043-e719-5a43-8b02-d8e417ecf2be', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 5, '2026-10-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-19', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('69dd059f-b45a-54bc-bc36-b66026f2a74a', '2026-10-19 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('15dde16e-66dc-5aef-8b03-a1016019ca29', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 6, '2026-10-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-20', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ee820527-f42f-50d3-8b12-dbcd3d6605e9', '2026-10-20 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fe72cec2-6c74-5913-87b7-fff8b0f2e2fb', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 7, '2026-10-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-21', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3ddf7d9c-086e-592b-82ae-5e9d542c455b', '2026-10-21 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d6a13ff6-3a80-55e0-befb-ad52867a5df9', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 8, '2026-10-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-22', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('9bacd33c-1c46-5928-b3ad-22df4df93e35', '2026-10-22 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('678214b6-d206-58b6-a5d8-8c46aaee1cbb', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 9, '2026-10-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-23', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('06a6ff08-8218-5305-8164-5da431eb6c5f', '2026-10-23 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eb33df74-1c2e-5a0b-a78e-764c244167b1', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 10, '2026-10-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-26', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('36ace730-9cb0-5afa-898b-9c92e05cb23a', '2026-10-26 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('533b796b-723b-59ab-9a03-366e94bb0036', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 11, '2026-10-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-27', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ca024afd-66cd-5272-aca7-f83f3e6b81eb', '2026-10-27 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0f1a0d11-a1f0-557d-9d15-f79e959a8a02', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 12, '2026-10-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-28', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('c61f825d-bf85-563b-b0e2-9349b5d09e3e', '2026-10-28 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0a8815e2-0ecd-54e5-baf4-2cfc1ba2d133', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 13, '2026-10-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-29', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('5804922c-44f7-55c9-b78b-baf8b634245b', '2026-10-29 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6b1db706-a0cf-5156-b707-fa3fcedcc40f', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 14, '2026-10-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-30', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ec5082df-65df-55f8-a5e5-37b7010b6c90', '2026-10-30 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e1c1391d-769c-5d0c-bd50-8d76d3796d19', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 15, '2026-11-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-02', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('80039371-cebe-5fef-8625-40c44801496e', '2026-11-02 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('62d18bd9-911e-5c09-99f1-2b6c428bf5cf', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 16, '2026-11-03', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-03', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('695998f1-2724-5172-a3cd-cd88d329575e', '2026-11-03 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fa22bdd6-df4d-5c73-8b4f-a454a9afd895', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 17, '2026-11-04', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-04', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('f1214518-de94-5245-8445-33c50a99dda6', '2026-11-04 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a8429395-f0b5-5212-b114-2c770fd3f884', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 18, '2026-11-05', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-05', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('2ad35303-666e-5a7e-8533-b6b60a58b0a6', '2026-11-05 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7bcb19f6-06b1-5dab-a4b6-7ae795e47e1e', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 19, '2026-11-06', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-06', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('7b7d1ec9-d8a0-5917-994e-07ca231e74e2', '2026-11-06 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('51295e16-aa96-536c-88b8-44ee2f1b88a1', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 20, '2026-11-09', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-09', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('56de0c84-f1dd-5efe-8d4c-d91d98ab8318', '2026-11-09 10:00:00+00', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ff958df6-a17b-5f31-89d0-d705c0d450b2', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 21, '2026-11-10', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d9c3e26d-8e4c-5127-ba33-d8662c6a855c', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 22, '2026-11-11', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5d902043-5d3c-5ed3-97b8-4d8bf262dff3', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 23, '2026-11-12', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2ab59e75-6d77-586b-960d-16e117f514b5', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 24, '2026-11-13', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('781575c5-1a19-597f-9a8f-22435239b858', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 25, '2026-11-16', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d2fdb2f4-45c9-50f6-b182-531c57ef47ea', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 26, '2026-11-17', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8f10e42f-6c1f-5985-81d1-29f990439dc2', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 27, '2026-11-18', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('12801f74-968c-5def-b195-b9e0330129ae', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 28, '2026-11-19', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a719309f-8fde-5f98-81f1-18d665f7f916', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 29, '2026-11-20', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1d623d45-1e54-5032-b3ae-92b4a5d617f2', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 30, '2026-11-23', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('801161ee-b90d-57b9-974b-3dd0cbb2b960', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 31, '2026-11-24', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c270af85-cba0-5de0-90b9-e600a83d5508', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 32, '2026-11-25', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3dc8d276-7dcf-5786-add6-b7eb58d4023f', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 33, '2026-11-26', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c20a6cde-5b6b-54d6-be3d-c2733e059ab9', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 34, '2026-11-27', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('10f85429-d942-5c20-bf21-91d49c9d6391', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 35, '2026-11-30', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9e8badb8-230a-5d03-a5f7-1d3a0fde301d', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 36, '2026-12-01', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('80f888f5-498f-57bc-820e-4fea9192aec9', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 37, '2026-12-02', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0227fdc2-7301-50b6-88df-0ba29a2b7f49', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 38, '2026-12-03', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3e15b3bf-b9bd-5cb4-8ee0-1fb0404e0990', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 39, '2026-12-04', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f6a4f918-916c-5cdd-a8d3-af011e142b92', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 40, '2026-12-07', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8f1d1b86-ac49-5106-9dca-c0042d828be7', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 41, '2026-12-08', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bc37d860-3fd9-5e9e-ba4c-0b5da05ec2d2', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 42, '2026-12-09', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3af1a51c-d3d7-5259-a257-45eec3d8093b', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 43, '2026-12-10', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5b11c6eb-ab86-5db6-8eaa-ce4abd4893e3', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 44, '2026-12-11', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('057e78e5-cd48-59e7-8bab-aeadaa4192f9', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 45, '2026-12-14', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('baba85c6-5ae7-57c6-8f14-d89af9ca33c1', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 46, '2026-12-15', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('621b01a5-d417-5810-9c26-ef784650361a', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 47, '2026-12-16', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0c71f677-8d8a-559a-acb9-a38f539e8bee', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 48, '2026-12-17', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('252bd444-8a38-5e40-8466-dff427d5fa99', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 49, '2026-12-18', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5cedb3ff-b542-5877-826d-7d829e2d183f', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 50, '2026-12-21', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fa012c0a-19e6-574b-9466-db16c5f48920', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 51, '2026-12-22', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2f2341f5-d23d-5421-a5fe-3fe298cfc236', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 52, '2026-12-23', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('695ad01f-0b32-5392-b114-25dbba594dad', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 53, '2026-12-24', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5572c428-658c-51fb-8d21-4f714e8ccd6a', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 54, '2026-12-25', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('018cde72-1ea0-525b-888a-8bb165bd3a8b', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 55, '2026-12-28', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('40805ada-1b8a-5de3-ad21-ff145bbafc14', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 56, '2026-12-29', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ac3dda23-06bf-5e28-98e5-43816278a142', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 57, '2026-12-30', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('15344ad4-c2f8-508d-8efc-191ccecc0288', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 58, '2026-12-31', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6436a1be-1334-5223-bd14-d1e176526f82', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 59, '2027-01-01', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('68be188d-db1b-5cbd-905c-d7c38fef8ca1', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 60, '2027-01-04', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 'c41b5775-6e19-4302-bd42-c14342f52592', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 96000.0, 800.0, 96000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-04-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fde7fcac-09fa-5096-8fd9-443d87b757d8', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 1, '2026-10-13', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-13', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('b91d4464-b3e2-5867-9d11-bbba60fb8603', '2026-10-13 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('42afabd9-81e9-509d-9a5c-1d4b0e0ff649', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 2, '2026-10-14', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-14', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('8d0e67c3-57ca-5c21-8f8d-9ad001ffb3d1', '2026-10-14 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('64ddc768-553e-54b0-bc2a-d9e066b0d89f', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 3, '2026-10-15', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-15', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('a143f399-8c6e-5c41-9eeb-22209fd9bd87', '2026-10-15 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cc72d44a-b743-53ec-9eb8-a97776dc313e', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 4, '2026-10-16', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-16', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('1da5ce46-1b28-519c-80d6-faaafd403f23', '2026-10-16 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e8d4f751-6fc3-5fc6-8450-9d6a84e3df02', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 5, '2026-10-19', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-19', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('261963e8-5e98-59ac-9e1f-c5b182b3e3dc', '2026-10-19 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c18d45b7-bfe4-57c0-a067-d9df3eedc3de', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 6, '2026-10-20', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-20', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('5ea1f6ad-ecb0-5bb6-b578-2b8ebfe72b67', '2026-10-20 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c7c7c236-f8ac-5deb-82cb-04d6b9eca84f', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 7, '2026-10-21', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-21', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('a0d8eb18-bc8c-59f1-b8f7-f8803a307a66', '2026-10-21 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1315a2da-2ba8-5c16-afb9-df7c35356a1a', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 8, '2026-10-22', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-22', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('fcb276e8-1427-5d29-a7f7-0ee3dba40027', '2026-10-22 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6c0c2d07-58ec-5610-8ca0-a470f7b30cb5', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 9, '2026-10-23', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-23', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('f49c5402-4ca0-5835-85b7-600d851665f4', '2026-10-23 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d3eafc1b-1cf6-5dae-92f4-1c8010a241fc', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 10, '2026-10-26', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-26', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('835e75e8-7b17-511a-a246-5a34f7499100', '2026-10-26 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('39dc8193-ac35-5ac1-9076-9eb0c6734dfa', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 11, '2026-10-27', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-27', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('08e22d8f-63d7-5d52-9465-d605eb597ca7', '2026-10-27 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1ae91c9a-3ef7-5ed6-b7f6-f15d6cf1b4af', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 12, '2026-10-28', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-28', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e8b788a9-a56b-5301-90ab-398af488939c', '2026-10-28 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('32bc33c1-0dbd-5dc2-b835-e57d35ce22d8', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 13, '2026-10-29', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-29', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e46991bc-a290-53a3-ae32-c06391df7f3a', '2026-10-29 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cc9158ff-1129-59f9-ad73-bb0184159083', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 14, '2026-10-30', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-30', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('55b869e2-a317-542b-b7ea-4610cd5af818', '2026-10-30 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('54209e82-db72-5334-8994-90fe4c3b596d', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 15, '2026-11-02', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-02', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('a2e61ee3-8c38-5088-9936-3e305ce37d6a', '2026-11-02 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b98b5fb4-3f57-5e01-97e3-9491a4bf66fb', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 16, '2026-11-03', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-03', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ea3df389-3b8d-5a83-b7d0-ebffd87d684a', '2026-11-03 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a1f3ab5a-dac6-53d8-a7dd-034e6e3e4cb2', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 17, '2026-11-04', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-04', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('dade25ce-f111-5256-9386-2179d1c7ff76', '2026-11-04 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7cdbc7c2-de7d-5c3a-9f8f-d52bab460ee3', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 18, '2026-11-05', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-05', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('165f77df-29a0-58e3-ab46-d6c40965b830', '2026-11-05 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9e370936-7840-5b9b-b0da-eb119593a309', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 19, '2026-11-06', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-06', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('4d136f05-fb78-51ac-92ae-e346d61ecd44', '2026-11-06 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e4ce9eb3-160a-5470-95d3-898aeb0b17e0', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 20, '2026-11-09', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-09', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('57bd0e1b-2de4-594f-9430-5af0cfd6c660', '2026-11-09 10:00:00+00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('50f405ad-4f9e-53c9-b313-0b99d5c6d4d4', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 21, '2026-11-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6b7cbdbe-ea15-52fc-a9af-6d582b487ae7', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 22, '2026-11-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9f07116f-5631-5cc0-a7a0-ba466815fa47', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 23, '2026-11-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dded8f5d-7809-5cff-8d42-f7f72cbd6e00', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 24, '2026-11-13', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('79fb3ced-343e-5dc7-a4b9-a804a23b966b', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 25, '2026-11-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1585d8db-3fe3-5b6c-866e-c397abc364ba', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 26, '2026-11-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3756ae29-67e0-5d84-804e-c4b1df249553', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 27, '2026-11-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b2f99f9a-6eb5-5ef6-b57b-017212db1c1e', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 28, '2026-11-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cc58d878-96db-5680-ad18-9e64499b580f', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 29, '2026-11-20', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5f31ee02-de2a-5005-8fb0-376134c84602', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 30, '2026-11-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('feeecd77-6350-571f-a243-582b91fcc7ad', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 31, '2026-11-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('137a8952-3649-52ee-985a-4d620b4367c1', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 32, '2026-11-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9410f8f7-eacb-58ee-8f6d-7dc32efd8e21', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 33, '2026-11-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6e31c158-fcee-5db2-bbd0-fd5fdd0373d4', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 34, '2026-11-27', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bd51a844-e65c-5932-af44-bf043a12ea22', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 35, '2026-11-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('27ebe67b-0d87-56d5-97bc-f5c008307cec', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 36, '2026-12-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7ba56fda-5713-5c3c-8954-79c359d1ab71', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 37, '2026-12-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('34ac645c-7ddc-5101-9d72-7e39f290fd4d', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 38, '2026-12-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('68ddc085-ab30-5758-8122-184505ce1115', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 39, '2026-12-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('477b04d7-36c4-5427-932c-b3e2adaeb99d', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 40, '2026-12-07', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('61f944cc-ee47-558d-921b-6f5026570b77', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 41, '2026-12-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bfeb98e2-59ac-5be2-aa94-732e9536e24f', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 42, '2026-12-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2ac0794b-f939-5814-86c7-0d047a661833', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 43, '2026-12-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('55ad8c8b-013a-5280-8f99-40a1c5c4f028', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 44, '2026-12-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('de8a715e-a594-52d0-8c4e-e0382059e6ae', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 45, '2026-12-14', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('91d076c7-518b-5a19-bb3e-d33521644f6f', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 46, '2026-12-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('10f25b92-0afd-591f-a1c6-0036f16e9410', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 47, '2026-12-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('062b4a81-8b7d-5660-a585-da110c8d6a5c', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 48, '2026-12-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('68a4364f-06a7-5574-b7b2-1baee8fa9349', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 49, '2026-12-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('59433c58-37fa-527f-97f8-7c3f5f044d2e', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 50, '2026-12-21', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('70936c07-55c3-5ce3-b696-66e7886294f5', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 51, '2026-12-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6580d3d3-8a55-53f8-a84f-d1cf240d6918', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 52, '2026-12-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8e649903-cc5d-5ec6-9e3d-9255abff071a', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 53, '2026-12-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('90b60900-c336-525c-9e04-dc13c39e4237', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 54, '2026-12-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('26639ce6-6f04-50a2-9a07-ddf2507c6c82', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 55, '2026-12-28', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fed6ffb0-d825-5ba0-a16b-a0b9e3540fa4', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 56, '2026-12-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fcb46dbb-c9a8-5eb0-8fb1-cd44405f2300', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 57, '2026-12-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a53923a7-15b0-5b5d-aebc-b09eb6d5ccd6', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 58, '2026-12-31', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a670d07f-6b38-5fa1-a39e-c56a620f3806', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 59, '2027-01-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('76112443-1e9a-583f-a6bc-c3b5be438543', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 60, '2027-01-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c638e26f-8298-5b51-a753-3a6bb82d7d7c', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 61, '2027-01-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e739ee9e-b703-5a65-acc6-744810751a7a', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 62, '2027-01-06', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d48d0bd8-e245-52de-a501-610674873ff4', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 63, '2027-01-07', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3d122ff4-c33b-5209-936f-8a96db763a77', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 64, '2027-01-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f9ca694c-d697-573b-9c32-8d30fe54d078', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 65, '2027-01-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5040568c-80c9-5c88-aca9-e43df0193fa2', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 66, '2027-01-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('13b64047-9a00-5829-a70b-58aef2a01468', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 67, '2027-01-13', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5f91ba66-2861-5d82-bd7e-6088c222638a', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 68, '2027-01-14', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('44c9e88d-9a50-50b9-9aec-af9d3f48d4f9', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 69, '2027-01-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f9c2b00b-12ab-51a7-add7-f9ed099a51d7', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 70, '2027-01-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53776cff-b1b0-5a16-8047-99d5868c7bb6', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 71, '2027-01-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1dd540e9-ac31-5c8a-8cb6-07ab469d5a63', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 72, '2027-01-20', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fc3b2710-79cc-5b23-9698-c46ba232c904', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 73, '2027-01-21', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a301c01c-5289-5a07-ad98-34e6cd77c959', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 74, '2027-01-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('abf9432a-34fa-579a-ab68-28e06ccea319', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 75, '2027-01-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('989a7951-2f5f-54d4-b0fd-95e9361aaf95', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 76, '2027-01-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0d237ce2-6261-5b43-9bde-224446a20cc4', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 77, '2027-01-27', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('20a8f39d-ad12-5db0-8132-1eb8682353ba', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 78, '2027-01-28', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('352e96e6-8f90-5cc0-9f64-2a775ac7d377', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 79, '2027-01-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ace22d0b-259c-55eb-bf93-43bc8b588ac0', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 80, '2027-02-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b7dd84a6-817d-5b6a-8fd5-dbf93b3532d6', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 81, '2027-02-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5e37eac4-a397-563a-bb5c-03614b2bf9e4', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 82, '2027-02-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('76dfada6-8247-56b6-b505-80b18da9c870', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 83, '2027-02-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a8744e5d-b4a1-5b22-b01d-fda064599f5a', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 84, '2027-02-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('55c4a722-b7b7-56c1-a40b-b0cb99de3e22', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 85, '2027-02-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6c2c450d-8737-570e-8d5e-2c18fba566ae', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 86, '2027-02-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3304e44f-5783-50ef-aa39-01dcc9dd8a71', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 87, '2027-02-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4fe8752f-5f51-5d3c-bb20-38605dba1104', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 88, '2027-02-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3f038b22-acf6-5b8b-a299-a35792254457', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 89, '2027-02-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('63ca5fe6-a32b-5910-bd37-d73c25a947b3', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 90, '2027-02-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('52129d44-67e4-5128-b89e-bb969ed66739', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 91, '2027-02-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3b637c82-309a-57da-82de-a044a4fdf586', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 92, '2027-02-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5a25b977-635b-5b96-a99e-c04eda8a0d02', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 93, '2027-02-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d7dc7f69-bc71-5c12-a6a9-000a5e77a138', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 94, '2027-02-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c552e234-1101-5cf6-b573-7e18e4b9324f', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 95, '2027-02-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('64ae645f-5a83-59e0-88e5-5aa3f2d8d19f', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 96, '2027-02-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5d3f4272-7bf7-5cbd-900f-fc6c4bd95cfb', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 97, '2027-02-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8b6d9b07-8274-5421-9bc2-37a656e5bd79', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 98, '2027-02-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('88e0b446-2eb2-5975-83a6-ea6a0668a774', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 99, '2027-02-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('72d423cf-1a68-5c95-95d8-cca49a7940c2', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 100, '2027-03-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('29677d00-e113-5042-913b-13319e81d0b0', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 101, '2027-03-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9e506cb3-1627-516a-b82a-6cd9d4a85be2', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 102, '2027-03-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a3df5333-c697-5682-a918-b78cb6dfd2e3', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 103, '2027-03-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('579b66c8-27aa-5e52-a3f6-47e9ad83ddff', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 104, '2027-03-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('10b2f9b6-592b-5c14-bbd6-00f75f1f0e1a', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 105, '2027-03-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('49784da1-57a1-5335-b002-dc21d3b8a0bd', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 106, '2027-03-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5a3ea272-e3a2-5252-91fd-96e397907fae', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 107, '2027-03-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cebb739f-2ecc-5da3-aa41-26402f626269', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 108, '2027-03-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4b4a0915-419e-57b4-a848-ec5ee25efc1c', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 109, '2027-03-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('56ba43e4-dd1a-5d49-8453-e5e8bb51f0b9', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 110, '2027-03-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bce35cd2-1c29-5793-9086-7f3831127d39', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 111, '2027-03-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7710acd5-bda6-5331-aa97-673387fce1bf', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 112, '2027-03-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0c2ea87a-64ed-55f9-b6ed-86803303ed33', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 113, '2027-03-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fb519aab-538f-561c-a1a4-ac47c249cb95', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 114, '2027-03-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('32850815-494f-53f9-97c2-82806a5ef7fc', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 115, '2027-03-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cdec5300-ecaf-56b4-a97d-e92c2e63508c', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 116, '2027-03-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('746205d4-5647-5eae-853a-706242ba9b63', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 117, '2027-03-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6a1bff82-0fb8-5099-a3ba-8df0a8dfeb9d', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 118, '2027-03-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d6bd94c1-2ee6-5887-9e44-8d8a537a61be', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 119, '2027-03-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5c8ca0a2-41a1-5586-bba8-311fc0868187', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 120, '2027-03-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 50000.0, 48000.0, 800.0, 48000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b46a94a5-b9d5-53ac-9f89-78f0d5bc2c91', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 1, '2026-10-13', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-13', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('acc7d1e4-b1c8-5dcc-ac68-6a2cebaf05c9', '2026-10-13 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7266e107-e6ed-5cd0-a92c-e4bdba743932', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 2, '2026-10-14', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-14', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('0cd4f983-80af-5e14-87a8-9ea8da33dec5', '2026-10-14 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e9529e9f-21d0-5d29-8fad-28e98f72684a', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 3, '2026-10-15', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-15', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('a9f6752f-b01c-59a0-be91-ba4664bf2901', '2026-10-15 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5f83b84d-cf73-5b39-9c28-5d145717c75b', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 4, '2026-10-16', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-16', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d5680879-77c3-5413-9a14-fffceccca794', '2026-10-16 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4d60a7f7-b5e3-5dfb-8833-4e68788637fa', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 5, '2026-10-19', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-19', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('85689e75-97e9-53a0-ac5b-10d3b94a6bbc', '2026-10-19 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('82f2a9f1-ec84-5848-8efe-876ab860d620', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 6, '2026-10-20', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-20', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('7b0c9734-b15f-57d3-bff8-5c8f628ab2d1', '2026-10-20 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d8990498-ff18-5228-95d2-b29f16df8b98', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 7, '2026-10-21', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-21', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('48cb7b52-55ca-5793-9782-92a8a3ed8bc8', '2026-10-21 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fdeef6ee-e857-5405-9389-1bf1f26495b8', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 8, '2026-10-22', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-22', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('2085732e-917e-5ef1-86bd-a009cac2ed1a', '2026-10-22 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c863e6c7-9c57-5b38-8453-dded5853d880', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 9, '2026-10-23', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-23', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('a8f937a7-1fc6-5c85-a1ee-f8f531275fb7', '2026-10-23 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9e18c04f-18a3-55bc-b143-73538116cbc3', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 10, '2026-10-26', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-26', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('94ba61bd-d395-5972-ad05-248bf2025719', '2026-10-26 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('203a3773-f9d8-5554-9280-8bc6a2877e80', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 11, '2026-10-27', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-27', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('4c94d975-c443-5dc3-9ab1-f0b02ac1bb7e', '2026-10-27 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d058936b-8753-5d0d-9d1d-e0d3314c747a', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 12, '2026-10-28', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-28', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('cb6f6db4-dc8f-5041-a24a-5aba5a8a7eb5', '2026-10-28 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('414d3e36-a60b-58f6-be77-a6843fa4a7f8', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 13, '2026-10-29', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-29', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('471eaa79-523f-542c-a271-37536f052890', '2026-10-29 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('becaca6e-f794-5df8-9c2a-7e1242b3ca18', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 14, '2026-10-30', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-30', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('cce5b826-5465-5a47-85d6-0de471ffdfa4', '2026-10-30 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('94968134-2b82-5f5e-94a6-ee8a048f3587', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 15, '2026-11-02', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-02', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('28dd54aa-86d2-5097-93b2-19c454ab98ce', '2026-11-02 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('71fa43f0-a253-5943-ba11-65d5630397ab', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 16, '2026-11-03', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-03', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e47a824b-79f9-5365-b9ec-4ad4276f366e', '2026-11-03 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fb06d9d8-1cb0-5895-a1c6-ce5e0dbf7cdc', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 17, '2026-11-04', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-04', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d76dd884-fdc6-5825-a14d-8e307db9db78', '2026-11-04 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4ac0fa9e-3e33-5e71-9e8b-b924d5348ed4', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 18, '2026-11-05', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-05', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('2fb47bd7-24ca-5a48-8b85-2293c9b82004', '2026-11-05 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a4701591-39bb-5c9d-83cf-e506191a2f19', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 19, '2026-11-06', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-06', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ac645026-82f9-5c36-a58c-c38fc96e83b5', '2026-11-06 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0248df91-ed16-5b46-839d-b8683dcf9ba0', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 20, '2026-11-09', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-09', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('7e6bc59f-21f1-5df0-9925-e31a65f28ac3', '2026-11-09 10:00:00+00', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fda70f64-32a7-5a2a-a7ba-64b7962222c2', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 21, '2026-11-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d2bce08d-165c-530c-b5b9-e2adef45499e', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 22, '2026-11-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2e9de1a2-7eb3-5814-be88-347587942914', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 23, '2026-11-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3cf1f719-faf7-552d-b92f-be55af1cfc69', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 24, '2026-11-13', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('007761f0-0a81-549f-a960-0a5fda9130a5', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 25, '2026-11-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('95c0c043-afdc-5cfd-8d22-4ded052b7679', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 26, '2026-11-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8b8504b4-384e-53e1-888a-64742964e0cc', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 27, '2026-11-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0271eea6-42e2-5d38-87e5-2a0ddf3edd7f', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 28, '2026-11-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2bb2bf74-9366-528b-b453-21e159762fc0', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 29, '2026-11-20', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('068eb800-787d-5b40-b60e-8375ac7f36d9', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 30, '2026-11-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('425594bb-8a4d-58f6-b83a-6dd58c33b3c5', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 31, '2026-11-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('89d370bd-3fda-5b17-b8d2-dc56447d827b', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 32, '2026-11-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b357d7dd-0a3f-56e0-8e91-a87bf2100250', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 33, '2026-11-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('36b1a5bd-6410-5a06-afa6-29de8d39fc08', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 34, '2026-11-27', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('58b7799c-e126-5078-a2a5-1575f83356e1', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 35, '2026-11-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('356613ab-b1f5-5e2c-9c68-6da6633b0123', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 36, '2026-12-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('585f2152-4fa7-55fd-8659-cbe95c1dbb7e', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 37, '2026-12-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('01c122fe-385c-558d-8181-060cde481bb1', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 38, '2026-12-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c1892b9d-11c7-5e67-ae1b-887690037cc7', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 39, '2026-12-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('26d95679-db1a-578c-95e8-4b1b67be8e44', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 40, '2026-12-07', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1ef9fe5b-cb8d-5d21-86b1-346924529552', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 41, '2026-12-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b3c9bfd9-d4bd-5bd4-a10f-ae7f3e625bbf', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 42, '2026-12-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('89903de4-8b48-522d-a61b-8aa859be0457', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 43, '2026-12-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('29fceba2-09b2-50d8-ad3f-c3c586dd6a56', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 44, '2026-12-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4c32733b-d4ed-54d0-9ea1-7135f266e42e', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 45, '2026-12-14', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53c3ac6b-884e-536d-8eb8-d79c0806e0e6', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 46, '2026-12-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ce4b6233-6205-550b-baa8-911f5d151f54', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 47, '2026-12-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0012bcab-543e-58b8-89a3-310ab12ad990', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 48, '2026-12-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('806877f3-dbc7-5d46-ba14-e2ca1a5ae079', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 49, '2026-12-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d31749e4-ee49-5e53-99d1-3d2ec953b46d', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 50, '2026-12-21', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9e820c06-f1eb-558c-b2b1-10c16ac25279', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 51, '2026-12-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('35548719-056d-52fd-b081-c00037ad9ec0', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 52, '2026-12-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d29c3197-f3d1-528f-92a5-66ac12e08f4e', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 53, '2026-12-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f14b7189-fb00-565c-8cfd-9a063a17e52f', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 54, '2026-12-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('54d449bf-af51-5bec-8e7f-8055182dd77d', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 55, '2026-12-28', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b341f0ca-3da2-511e-a830-b1e452b74da8', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 56, '2026-12-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('37be3052-43b3-59db-bbb4-1bdc2669c4dc', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 57, '2026-12-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('70362fe8-09d2-57e4-9dac-625a5de1e296', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 58, '2026-12-31', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e4fe7208-93d5-5cd0-afe8-b90a87827181', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 59, '2027-01-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8688ecd5-9c80-5a10-9498-506c491f67aa', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 60, '2027-01-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-10', 100000.0, 99000.0, 1650.0, 99000.0, 'Completed', 'Finance', '2026-08-10', '2026-08-11', '2026-11-09', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d486fb25-47c9-542c-9ea2-f954c5a335c3', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 1, '2026-08-11', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-11', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('2728136f-5f1d-5dab-96d0-769e575fa0ab', '2026-08-11 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d909b8d3-bb6d-5f6f-8024-00398484dcc8', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 2, '2026-08-12', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-12', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('8f145d18-982c-5097-817c-3b2401132f3f', '2026-08-12 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c33d64bf-b8c8-50e2-a098-c2d1a17fe546', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 3, '2026-08-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-13', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('c70c7179-6e32-5f70-b6fd-999840bb3ea9', '2026-08-13 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('263fdc11-dbcb-5b7c-90bf-6e57dbb9be6f', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 4, '2026-08-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-14', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e323c6f5-59f7-59d5-b71c-0ce510943ff6', '2026-08-14 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('17e3619a-8da0-5810-9b80-ff882bb05fca', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 5, '2026-08-17', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-17', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('2b25649a-827a-5bb4-954d-01356600644c', '2026-08-17 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9fa236a5-31b1-594a-9130-05489ac5a42d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 6, '2026-08-18', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-18', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('28a94ef9-94c7-59ed-b59a-1da512e26c84', '2026-08-18 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c3f951c7-a9a0-5482-860a-6cd01345bbda', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 7, '2026-08-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-19', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('89711c8a-8160-562b-aac9-8d85887aa8f3', '2026-08-19 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cb65d725-351b-540e-a9ef-17bc98ad5251', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 8, '2026-08-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-20', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('6f9a882e-95b4-599e-96d6-e49952d2596a', '2026-08-20 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('91867e66-93ee-538a-aec1-e590882d81b9', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 9, '2026-08-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-21', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3881c0d7-67dd-59c0-ba25-f2c53ab8f671', '2026-08-21 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('797e4dee-4339-5cfd-94da-a2ea0efaf3e1', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 10, '2026-08-24', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-24', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('fca5f0a1-1b20-5a04-9efa-9f68ba5797f7', '2026-08-24 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bd35a8cc-3352-5985-bd95-9a5e3b674c3e', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 11, '2026-08-25', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-25', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('b90dcca6-0b77-59fb-ad18-3d0dec41bf3e', '2026-08-25 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e6e18b25-f60d-567a-a9f9-3fc0dac3d281', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 12, '2026-08-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-26', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('f1814c50-bc89-5dd0-862f-70f853200d8e', '2026-08-26 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a97db454-8894-5755-9359-ae712dfc2020', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 13, '2026-08-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-27', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('0c514fb6-72e6-5d68-bea4-9a824415254b', '2026-08-27 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a8eeda4d-41ed-5c8c-86c1-b1232a282dc8', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 14, '2026-08-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-28', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('1af5b1d3-39f5-5935-addb-493e49ffe1d8', '2026-08-28 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f8cc0dc1-9f4d-55e4-9a3a-a068a8b34a8e', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 15, '2026-08-31', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-31', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('0c445acc-b2ba-5a21-ba4f-6707e27d3835', '2026-08-31 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ffcf1d2a-e9f4-5f00-a0a5-584a89fb9ffa', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 16, '2026-09-01', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-01', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('f44addab-6fca-5d03-8131-2cfb72134745', '2026-09-01 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('201a19f6-8246-594c-9b19-9517acfd604d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 17, '2026-09-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-02', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d7428cf7-9bdd-50a4-bbe0-41aeaf21bc22', '2026-09-02 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2b2e11ef-bd9c-556c-9991-cb6ac934b10d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 18, '2026-09-03', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-03', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e0e70d4b-11a2-5db6-b5c8-b3d1d2e84bbd', '2026-09-03 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cc8b8380-4454-5619-bbc5-be30eedacdf0', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 19, '2026-09-04', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-04', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e82c88b4-6cd0-5539-96db-d0192710413b', '2026-09-04 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d0f842fe-bcba-5adc-944a-96e372ed5733', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 20, '2026-09-07', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-07', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('fd26329a-658d-507e-91e5-fabe5d270812', '2026-09-07 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('86883473-cf8d-5261-a84a-a599a94f0615', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 21, '2026-09-08', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-08', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('dfbfb3f6-f1f5-5bbd-bbd3-c8dbbe771340', '2026-09-08 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #21 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7d1abccc-dac1-5b2a-9c94-a8b053e8f8f2', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 22, '2026-09-09', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-09', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('07aa9940-94d0-5a44-9d03-69dda1cc1d43', '2026-09-09 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #22 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a46d9a8e-4581-5316-8009-5cc35bec3055', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 23, '2026-09-10', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-10', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3765f73c-4a22-5694-b5f2-f5f4f141f8f0', '2026-09-10 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #23 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6ca2bc24-3803-534d-9880-47d5c27220f1', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 24, '2026-09-11', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-11', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e77507ad-d452-568d-97e2-4d5dcd745efb', '2026-09-11 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #24 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('895f6f01-9e66-51ce-bb10-1bc07ecee5dc', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 25, '2026-09-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-14', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d6f26d73-f8b1-5987-9170-acfbe5b10d36', '2026-09-14 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #25 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('264f3200-a587-500d-b375-5fb99f8b8b5a', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 26, '2026-09-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-15', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('4cb477dd-7503-58d7-8acd-3912b9e3319f', '2026-09-15 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #26 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('14bd5ee9-077e-5234-bc54-809b916a8098', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 27, '2026-09-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-16', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('cfe47fa8-977b-5621-a632-a6b845577d25', '2026-09-16 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #27 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8f401917-14ce-58bb-91dc-83be67ababe2', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 28, '2026-09-17', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-17', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('15efc21b-3340-53aa-b586-e0df0558764b', '2026-09-17 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #28 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('36dc6320-5e89-5523-84d1-2c8607de390d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 29, '2026-09-18', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-18', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('7cb2da7a-2e7e-59bd-bed0-766bd9c7c894', '2026-09-18 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #29 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e8bd85cd-64ba-5d7a-a2eb-78040b5df0f2', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 30, '2026-09-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-21', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('4385a44e-d068-56ef-863e-fc99e707f01b', '2026-09-21 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #30 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a2840eda-7c1c-5675-8504-3bfbb17f02bb', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 31, '2026-09-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-22', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ee2746b3-ca4d-5df5-a802-64bb4859e264', '2026-09-22 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #31 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('64b1d681-9d1f-524b-9372-d476bcae3d68', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 32, '2026-09-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-23', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('9d37ae56-23ed-54bb-bd32-473fc3555a88', '2026-09-23 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #32 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('62839c82-a14f-574b-ae6f-8a8f675fc1bf', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 33, '2026-09-24', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-24', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('23b8d1ba-d721-54d0-9f0b-24fd8f50ea6a', '2026-09-24 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #33 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5db55ddb-f5ac-5c31-86c6-dc9d7090b539', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 34, '2026-09-25', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-25', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d64f54ec-0b41-5f34-9521-235cb2f54e41', '2026-09-25 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #34 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4f538a1d-6abb-5950-a1a1-81a09df2673b', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 35, '2026-09-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-28', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('c4eb723d-2573-5deb-8d48-896e77869c99', '2026-09-28 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #35 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b756ee7f-9e84-5130-a7f7-a8e1bb263ee6', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 36, '2026-09-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-29', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('1360fe45-0f35-5903-910a-78d17983d760', '2026-09-29 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #36 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('137645de-c2a4-5feb-8025-af1dd0e2f186', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 37, '2026-09-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-30', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('f8f097bf-e0ba-54c0-8277-b042a394f2b9', '2026-09-30 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #37 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b96c0cbd-59ff-58b4-bbf6-3bc1ccbf5b97', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 38, '2026-10-01', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-01', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('74e7fcf4-5a15-5967-a308-d60fb618e60e', '2026-10-01 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #38 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('40d1aba5-e365-5ade-acc7-16164e06c71d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 39, '2026-10-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-02', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('266c8ea1-099f-5051-8793-91853302f13c', '2026-10-02 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #39 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3b9cb90f-2cc0-5e38-9bbc-6c103a58c22d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 40, '2026-10-05', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-05', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('327b7dfa-e344-5309-adf0-bb1f19236ab2', '2026-10-05 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #40 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1b3ffeaa-5962-51fb-9bf8-19ee8f9ad839', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 41, '2026-10-06', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-06', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('edafb697-7ea8-54e3-be44-e4aa6ee55818', '2026-10-06 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #41 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eb8ab406-a0ff-55b5-a994-06eddbf9ef6d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 42, '2026-10-07', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-07', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('a9341bbb-a368-5b59-a840-6eff5810d692', '2026-10-07 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #42 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('81104a19-4f7b-5dab-a6ae-df1216cff6b5', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 43, '2026-10-08', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-08', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('43b40a8c-21d9-5145-abaf-08c101640009', '2026-10-08 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #43 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('36803020-0fe5-51d8-b910-a5b16d459377', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 44, '2026-10-09', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-09', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('1f251623-186e-5dba-ae4a-611e4f8e61a7', '2026-10-09 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #44 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('80868b14-b397-54aa-a821-586d16091c19', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 45, '2026-10-12', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-12', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d6aa9db3-ef81-5201-b165-a165a35b2f08', '2026-10-12 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #45 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('65f72a96-c5cf-508e-8d1d-76473277d628', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 46, '2026-10-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-13', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3da55edc-03b9-5dad-8f5f-ebe1487e2384', '2026-10-13 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #46 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('58caa4e2-d81b-579c-be88-46229d5846b5', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 47, '2026-10-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-14', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('02274fd0-74fc-52c2-9325-a7b2e70f5925', '2026-10-14 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #47 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('af7ae6d2-6705-52ae-8597-f8babf4ffe77', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 48, '2026-10-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-15', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('827f78da-3690-538b-bcd4-e99b1ad23b66', '2026-10-15 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #48 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1991cdb3-e385-5814-9770-9f65371f4728', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 49, '2026-10-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-16', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('8186eec9-0c9f-5364-94a8-9c64ae16bb00', '2026-10-16 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #49 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('14e3c47c-a565-5d4f-8819-c0203b1bd71a', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 50, '2026-10-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-19', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d2f4a903-493a-521b-956e-3b917f189ae2', '2026-10-19 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #50 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7ba8a04a-c3aa-59bf-a5ae-f083305ec2de', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 51, '2026-10-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-20', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('b1cd4023-baad-5e22-8872-b7c62df9d184', '2026-10-20 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #51 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0156a8e6-e2bd-5197-940f-65126b7ecf40', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 52, '2026-10-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-21', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('77ae6fff-a9d8-558f-8692-d51e9ba397e1', '2026-10-21 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #52 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('894dc3dd-f438-50f1-963b-da0725b6c3a5', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 53, '2026-10-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-22', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ebb34770-c0ac-5ca2-9bb1-7ce11d7e5b8d', '2026-10-22 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #53 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0bb78e22-4de9-5f64-b442-6580c370803a', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 54, '2026-10-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-23', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('de6b7b2b-ca12-5acd-a280-fc5587aa0043', '2026-10-23 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #54 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('52da10dc-0fd9-5336-8b75-0a16de0c9e4f', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 55, '2026-10-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-26', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('c9820a4f-5278-5a82-aaff-c7363e9355cd', '2026-10-26 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #55 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7011f564-3262-5ed5-bcf9-b0851240548f', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 56, '2026-10-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-27', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('7dca3c37-0c08-5d77-805c-9274846b1cd2', '2026-10-27 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #56 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('820a75a3-f1aa-59d6-bae5-40e5399062f2', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 57, '2026-10-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-28', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('05922073-81e5-5f6a-9865-21fd87b7708d', '2026-10-28 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #57 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('60903d90-62d3-5a0b-a0f3-8374c2a517ed', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 58, '2026-10-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-29', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('bc63a983-8739-5e64-8b12-74d9bdff3101', '2026-10-29 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #58 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d32d441d-0845-535a-a4aa-83dcb8273a2f', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 59, '2026-10-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-30', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('7691746d-432c-593c-94a8-bb0299cc40d8', '2026-10-30 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #59 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8f577396-8042-5604-b4a9-5562738ccb2d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 60, '2026-11-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-02', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('0705115b-9c7d-5b87-a6a3-70e8ae6383d8', '2026-11-02 10:00:00+00', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #60 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_payoff_excess_records (id, repayment_id, loan_id, client_id, officer_id, branch_id, date, record_type, amount_paid, expected_installment, active_credit_settled, excess_amount, remaining_balance_before, remaining_balance_after, notes, created_at)
                        VALUES ('68d4cf6b-55b0-5e7c-a6ff-e512d7f39959', '0705115b-9c7d-5b87-a6a3-70e8ae6383d8', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-02', 'FULL_PAYOFF', 1650.0, 1650.0, 99000.0, 0.0, 1650.0, 0.0, 'Full loan completion settlement', NOW())
                        ON CONFLICT (id) DO NOTHING;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 150000.0, 150000.0, 2500.0, 150000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5b41e60f-9818-594f-a7bd-3d29e91ef18f', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 1, '2026-10-13', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-13', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e6f999cb-d356-5986-90e4-94ad2db97b90', '2026-10-13 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ea9d0860-3f1b-5b66-b180-6a3e38cba875', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 2, '2026-10-14', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-14', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('36ea0164-787c-5655-b458-17ec06ee2ece', '2026-10-14 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53d55902-1a52-5ea2-9923-99e436a6a24e', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 3, '2026-10-15', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-15', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('affdf56f-53b0-5226-b525-d1a569e91d37', '2026-10-15 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b0d94b31-820b-5117-8194-4a8fed4b3d81', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 4, '2026-10-16', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-16', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('119fb3f0-dc39-53a3-a7df-b119dd325d49', '2026-10-16 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('228b7ad3-b1e7-5b05-b22e-725b93d0b5cd', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 5, '2026-10-19', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-19', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('094d1d4d-b9dc-5bca-8fe9-2abb94ba42f5', '2026-10-19 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c9c3d8c5-06fb-5d8b-9499-a075693f5839', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 6, '2026-10-20', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-20', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('bdfa1017-8337-59d6-8659-0dccfe5e2b79', '2026-10-20 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6537c368-739e-54a6-9d06-04a43faad36b', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 7, '2026-10-21', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-21', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3a22c670-adc4-599c-a3a0-6a05ff670f3f', '2026-10-21 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e772f37c-4c03-5749-ae8d-173de8b635b2', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 8, '2026-10-22', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-22', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('4b1f2c59-f482-5bd4-9ff8-035ae0e6dbbc', '2026-10-22 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8504dc5c-c0be-5d82-9456-bfbb43c6f1d9', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 9, '2026-10-23', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-23', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('94b7b6a8-5a1e-5152-891c-a09acd24c064', '2026-10-23 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b3bef3b9-8314-57ff-8b52-8cfb62bdd649', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 10, '2026-10-26', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-26', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('9aaf6cd7-410b-59ad-a8ac-36bf6dcf8535', '2026-10-26 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1a70bc07-307d-515a-9227-14d0e83adbbf', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 11, '2026-10-27', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-27', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e80c1cea-2095-572f-999d-1d8f7a1fbbd5', '2026-10-27 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3716eb38-e119-5c13-8126-99a41e5b5f17', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 12, '2026-10-28', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-28', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('c768bab0-2b66-5cb4-8595-4408aa12b7ce', '2026-10-28 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('37e84111-8fdd-5ba8-bdb6-954dc8880651', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 13, '2026-10-29', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-29', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d0aa52b2-6cd4-5945-93e3-15a611e5c910', '2026-10-29 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('14d3261b-ebc5-5666-a1d6-5fd08087f1ed', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 14, '2026-10-30', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-30', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('a8f8dc11-edfa-59bb-919e-60d1ae3ad9bc', '2026-10-30 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2e618503-f5fc-5326-9a8e-0ba511510a05', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 15, '2026-11-02', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-02', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('f1655ca7-aa9e-586e-867e-10ecdc1ab030', '2026-11-02 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cee4fc30-a823-583c-9db3-4fcc01642173', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 16, '2026-11-03', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-03', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e5cee168-c615-56c1-aaee-71cc6e1bbf39', '2026-11-03 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('94c47bfb-cfb1-506d-9ad2-cb047e2d8946', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 17, '2026-11-04', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-04', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('b49d04d2-f0ec-50ff-a6cf-dd144091e5c6', '2026-11-04 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('49da808f-32fc-5541-9653-10f400902f65', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 18, '2026-11-05', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-05', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e0fed25d-8a4c-555d-9cb4-1065d6e5e6c8', '2026-11-05 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3c04d735-edf7-54f1-ab8e-7c33ad52688a', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 19, '2026-11-06', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-06', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('f9afaddb-67a2-542c-bb52-03200f27e392', '2026-11-06 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b8c88486-ff1a-5801-a695-99f0ce1b1a84', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 20, '2026-11-09', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-09', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d982e7f2-5737-5d52-b847-f63469cde9fe', '2026-11-09 10:00:00+00', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('525b8332-f0ae-572d-b320-30d7c086c626', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 21, '2026-11-10', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2d9fc6e2-89d7-5d45-abec-1c291c5d6eb0', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 22, '2026-11-11', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('06530406-78f1-5568-a353-62e07fa8e100', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 23, '2026-11-12', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3eff68d4-83ba-577a-b4a9-c0da8dfeb93a', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 24, '2026-11-13', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eec6c500-b1df-5ef6-b23d-6bc337862933', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 25, '2026-11-16', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0dcf09b7-f2c1-5b5e-87ab-f149564b5c23', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 26, '2026-11-17', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d4bb71fe-f4f5-57a1-8508-66def4053739', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 27, '2026-11-18', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e6437283-e05a-5ca9-ad4e-b0cf95f74395', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 28, '2026-11-19', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5046ea00-6285-57b9-a0bb-5f41493de1fd', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 29, '2026-11-20', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a2a359ff-0787-569c-971f-c103a0971cef', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 30, '2026-11-23', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8e646278-ad84-5346-878c-6368316bad81', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 31, '2026-11-24', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('45204614-9f74-5b99-8e76-8a47118e9336', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 32, '2026-11-25', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ddd19c2b-9cb1-5aac-b58b-9c8b80ae95d5', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 33, '2026-11-26', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b08b87f3-c8c6-5265-9c01-124acc36c3b6', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 34, '2026-11-27', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4bdd68a3-0e52-5424-8618-547194cc65e2', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 35, '2026-11-30', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f7f836d6-e5ae-59ca-b596-566833cf6b2e', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 36, '2026-12-01', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('855d8f97-04a6-52f9-b1b1-daa6d62f87da', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 37, '2026-12-02', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4f306404-b713-5b2e-bba2-5be8fcecd1bc', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 38, '2026-12-03', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fef75bc2-b15f-50e2-8f84-415c29350c1b', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 39, '2026-12-04', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('31dfc227-8a3c-5795-87f9-78b147d29c45', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 40, '2026-12-07', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6987a4b7-f1dd-5f63-9ac6-316df8ec9a7a', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 41, '2026-12-08', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('737167a1-7cc7-54fe-af65-839dfcb2b598', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 42, '2026-12-09', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8d67026d-858e-544c-ac91-f166c7a00ac1', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 43, '2026-12-10', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1168ac38-1462-55a3-9482-c4703b2ae0ed', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 44, '2026-12-11', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a1935d96-6b67-5780-872d-59b38f8552eb', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 45, '2026-12-14', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c0f6fd3e-ef16-5f71-9506-eb776741309f', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 46, '2026-12-15', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bd85277d-c325-5340-a058-28059d777e66', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 47, '2026-12-16', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('279ce9fb-5186-567f-bb78-56977bd1e22e', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 48, '2026-12-17', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6e270fa5-cfd6-5265-938c-94445e4f9a98', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 49, '2026-12-18', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2fc7aa92-e1b5-5c64-81b5-040880fd3911', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 50, '2026-12-21', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c89be8af-f4c2-5ee7-b537-303ee4776d93', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 51, '2026-12-22', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7fc31b40-b6a0-5961-bd5b-0abb81825979', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 52, '2026-12-23', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('42bc8967-e7e1-5b41-96db-91718909f1d3', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 53, '2026-12-24', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2ec2660c-e8ea-52ba-9f95-80fee93e7c26', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 54, '2026-12-25', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eefedf6a-7916-5791-9fdf-6efae4bca870', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 55, '2026-12-28', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1d7dc7d6-670f-51c4-a8f8-8f1f98861bd8', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 56, '2026-12-29', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4732b119-6700-5b5a-be7a-648ff20cca8a', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 57, '2026-12-30', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d3e4fbb8-34ac-5607-a0c2-774d25c981fd', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 58, '2026-12-31', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f0586374-2d0b-59ab-a95e-9267c38297c5', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 59, '2027-01-01', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('69e50dfb-1ee6-5911-9dc9-cba2eede79aa', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 60, '2027-01-04', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 'c41b5775-6e19-4302-bd42-c14342f52592', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 96000.0, 800.0, 96000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-04-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ddf6836a-1996-5e2e-8578-26dae631a619', '01f734b0-0674-5545-aaa3-e873e622d8d4', 1, '2026-10-13', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-13', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('10f2132b-fad2-5433-9f40-f1159eb74e6e', '2026-10-13 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f5998baa-3c44-5da5-9e5d-995b0a60787a', '01f734b0-0674-5545-aaa3-e873e622d8d4', 2, '2026-10-14', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-14', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('52d984a2-0d4b-5d21-9ede-cd882de74ff0', '2026-10-14 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d2020604-ebe1-5f33-90a7-34d404505584', '01f734b0-0674-5545-aaa3-e873e622d8d4', 3, '2026-10-15', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-15', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('7a0e0591-d8f0-5f33-8381-c2da8ef97443', '2026-10-15 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9719e1bd-1654-5023-a077-5ce08bb66218', '01f734b0-0674-5545-aaa3-e873e622d8d4', 4, '2026-10-16', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-16', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('2eb246ba-c443-5144-a0fa-4439c296149b', '2026-10-16 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dfc7cee0-5e03-537b-9f16-f2752b28ea16', '01f734b0-0674-5545-aaa3-e873e622d8d4', 5, '2026-10-19', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-19', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e18c4200-8348-5b0a-9576-dca4cf6a3b7c', '2026-10-19 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2cf88766-e59e-5d3b-bd13-6023cf96dded', '01f734b0-0674-5545-aaa3-e873e622d8d4', 6, '2026-10-20', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-20', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ae03b894-1ad5-5889-9583-243de4590af1', '2026-10-20 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dd49ba43-8339-5a53-8fa7-e4c2def95ae3', '01f734b0-0674-5545-aaa3-e873e622d8d4', 7, '2026-10-21', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-21', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('9bfb2b7c-74a0-50d2-b763-38d78a3bb94b', '2026-10-21 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('47bde037-5d7e-5662-afd8-325c81548fe3', '01f734b0-0674-5545-aaa3-e873e622d8d4', 8, '2026-10-22', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-22', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('4297286e-5223-5663-a39a-815d2cf14466', '2026-10-22 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5b73f907-2508-5caa-9c9b-e1eedfa018d8', '01f734b0-0674-5545-aaa3-e873e622d8d4', 9, '2026-10-23', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-23', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('80f4e39c-6480-5b47-b7c1-c60788de0a56', '2026-10-23 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('147ba5d3-4fe4-590a-b029-7773dea82347', '01f734b0-0674-5545-aaa3-e873e622d8d4', 10, '2026-10-26', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-26', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('37f2c0f6-1fff-5bae-b8c1-d3f6ff1667d0', '2026-10-26 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a344c271-dbb9-511c-a41b-04aa678aa701', '01f734b0-0674-5545-aaa3-e873e622d8d4', 11, '2026-10-27', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-27', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('321893f7-2f27-5ae0-b5b8-f8c1c1efb188', '2026-10-27 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('55f101cb-8328-5376-b49b-b9d59698c014', '01f734b0-0674-5545-aaa3-e873e622d8d4', 12, '2026-10-28', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-28', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('b0a7d9fb-3a6d-5838-9a72-823ec8892e52', '2026-10-28 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7696ada2-0a9f-56b0-860a-175e5a3dd28f', '01f734b0-0674-5545-aaa3-e873e622d8d4', 13, '2026-10-29', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-29', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3cfad5d7-310e-5990-b56d-fddb3b52f1d9', '2026-10-29 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ce98842c-5ff7-5e8b-bf68-20b5c6d493c5', '01f734b0-0674-5545-aaa3-e873e622d8d4', 14, '2026-10-30', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-30', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('2d2c46be-0698-5e03-8b1b-4057f066e014', '2026-10-30 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5e642736-fb0d-570d-ab34-bfe94bdfc0a5', '01f734b0-0674-5545-aaa3-e873e622d8d4', 15, '2026-11-02', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-02', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('c29c657b-57f6-592f-8a89-8f90a5e4678d', '2026-11-02 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('108e3d9d-10fa-56a0-afb4-1e77aa2b71bc', '01f734b0-0674-5545-aaa3-e873e622d8d4', 16, '2026-11-03', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-03', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('b1b1f364-857d-5a1b-be3a-8a74b950945d', '2026-11-03 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0e0722ba-66e1-52a3-9570-efbd5f0d4686', '01f734b0-0674-5545-aaa3-e873e622d8d4', 17, '2026-11-04', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-04', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('a660d748-4cec-5511-b5f5-4a010175bada', '2026-11-04 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('19dfc375-6356-5913-a358-c83b55d69f22', '01f734b0-0674-5545-aaa3-e873e622d8d4', 18, '2026-11-05', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-05', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d15675cd-4572-570b-9001-606367f10dbd', '2026-11-05 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('38197799-1f41-5024-8188-f80ae2195b24', '01f734b0-0674-5545-aaa3-e873e622d8d4', 19, '2026-11-06', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-06', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('2ddbc949-e592-597d-9f42-8ca2b9d4008f', '2026-11-06 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('81f8f94d-1096-5811-b7e5-4392bd39b657', '01f734b0-0674-5545-aaa3-e873e622d8d4', 20, '2026-11-09', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-09', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('bda23e91-9ebd-561e-a029-d164d6dbb394', '2026-11-09 10:00:00+00', '01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d087cff2-bd31-57cb-9fac-9dcf3e900c4a', '01f734b0-0674-5545-aaa3-e873e622d8d4', 21, '2026-11-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('17ebb680-6f68-566d-bc31-ff0dc005826f', '01f734b0-0674-5545-aaa3-e873e622d8d4', 22, '2026-11-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('70eb0c90-9145-5424-a524-050f6dd709db', '01f734b0-0674-5545-aaa3-e873e622d8d4', 23, '2026-11-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2057c8b0-02f5-574d-9d6e-949aa44901e7', '01f734b0-0674-5545-aaa3-e873e622d8d4', 24, '2026-11-13', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('090d976c-9974-59e8-8ef7-a601d6942f2a', '01f734b0-0674-5545-aaa3-e873e622d8d4', 25, '2026-11-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('63279bba-3d4e-5d89-ac0a-ef6ab07291d6', '01f734b0-0674-5545-aaa3-e873e622d8d4', 26, '2026-11-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b13b0628-36f5-5c4f-8759-903e93ab8709', '01f734b0-0674-5545-aaa3-e873e622d8d4', 27, '2026-11-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0bc99046-9fec-52a2-ac99-fabfca08475e', '01f734b0-0674-5545-aaa3-e873e622d8d4', 28, '2026-11-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2a93ff1d-1ecd-56fe-8f9d-428996c47653', '01f734b0-0674-5545-aaa3-e873e622d8d4', 29, '2026-11-20', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f3b23b8a-1561-503d-9424-ccea700c3bdb', '01f734b0-0674-5545-aaa3-e873e622d8d4', 30, '2026-11-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('db3fe8e6-e32e-5059-a5ac-6a74941b95f0', '01f734b0-0674-5545-aaa3-e873e622d8d4', 31, '2026-11-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('aaba4056-a22a-5ba3-88f3-17fbcb49427d', '01f734b0-0674-5545-aaa3-e873e622d8d4', 32, '2026-11-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2a8362ce-ac8f-58b6-986e-3ea846f718dd', '01f734b0-0674-5545-aaa3-e873e622d8d4', 33, '2026-11-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('56fec905-d0b8-5b08-bbb6-f892702c16bf', '01f734b0-0674-5545-aaa3-e873e622d8d4', 34, '2026-11-27', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cedef1d4-b3d4-5ff4-b7bf-df783358ea62', '01f734b0-0674-5545-aaa3-e873e622d8d4', 35, '2026-11-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('95c693f1-c38d-55f4-b6b1-d454335b82c3', '01f734b0-0674-5545-aaa3-e873e622d8d4', 36, '2026-12-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3891aa6a-7bde-5ce6-95ec-ad7fcee8453a', '01f734b0-0674-5545-aaa3-e873e622d8d4', 37, '2026-12-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('97a571f4-ab56-5395-8bb7-5b5b9da1e00b', '01f734b0-0674-5545-aaa3-e873e622d8d4', 38, '2026-12-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9fcdb633-5c0c-531d-a587-7389813417da', '01f734b0-0674-5545-aaa3-e873e622d8d4', 39, '2026-12-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6e97ed06-c16f-57d8-972e-8f922c118023', '01f734b0-0674-5545-aaa3-e873e622d8d4', 40, '2026-12-07', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('271ec186-cebd-5e27-aa57-597a464b8152', '01f734b0-0674-5545-aaa3-e873e622d8d4', 41, '2026-12-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5920ec01-53a7-5114-8698-c213062f0c1f', '01f734b0-0674-5545-aaa3-e873e622d8d4', 42, '2026-12-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('642b4e4d-b72e-5690-944a-9c37164206b1', '01f734b0-0674-5545-aaa3-e873e622d8d4', 43, '2026-12-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dc5fa10c-805a-507e-814b-bf71a5f8ab8a', '01f734b0-0674-5545-aaa3-e873e622d8d4', 44, '2026-12-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e910e0ea-ce78-5bcb-8184-41f8a0b2849b', '01f734b0-0674-5545-aaa3-e873e622d8d4', 45, '2026-12-14', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e9ac2501-f207-5558-b9ed-a24be76925a9', '01f734b0-0674-5545-aaa3-e873e622d8d4', 46, '2026-12-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9b7c87c3-167e-57dd-8294-52459fc6221c', '01f734b0-0674-5545-aaa3-e873e622d8d4', 47, '2026-12-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a7ed2419-e33f-51c3-9761-2521b8a8b13e', '01f734b0-0674-5545-aaa3-e873e622d8d4', 48, '2026-12-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('409ca2a5-a83f-599f-9884-992b3327a9f4', '01f734b0-0674-5545-aaa3-e873e622d8d4', 49, '2026-12-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9b540e5f-f638-56b2-afb3-8044b7f150e9', '01f734b0-0674-5545-aaa3-e873e622d8d4', 50, '2026-12-21', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('88300655-7c77-56ea-b6ef-096b09ea2e0e', '01f734b0-0674-5545-aaa3-e873e622d8d4', 51, '2026-12-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8ac49b68-69b6-5f27-bf2c-083e66acab9c', '01f734b0-0674-5545-aaa3-e873e622d8d4', 52, '2026-12-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9e0248fd-1058-5367-a3e6-94e30722fe19', '01f734b0-0674-5545-aaa3-e873e622d8d4', 53, '2026-12-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e7b6bf37-79fe-5811-9b5e-d921d1f79410', '01f734b0-0674-5545-aaa3-e873e622d8d4', 54, '2026-12-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d71a0e3d-6633-5fd0-8a37-434516574aec', '01f734b0-0674-5545-aaa3-e873e622d8d4', 55, '2026-12-28', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5686aa27-a8e2-54d9-a48b-850bf47c0a69', '01f734b0-0674-5545-aaa3-e873e622d8d4', 56, '2026-12-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dd3dd971-467f-59fc-9c51-1d57d00eefce', '01f734b0-0674-5545-aaa3-e873e622d8d4', 57, '2026-12-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5fba36b4-a93b-5397-aca1-eded3d43c30e', '01f734b0-0674-5545-aaa3-e873e622d8d4', 58, '2026-12-31', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('43d8909c-a644-5bfd-a83c-c84dcab8cdb8', '01f734b0-0674-5545-aaa3-e873e622d8d4', 59, '2027-01-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e9519ec8-d513-5e55-a0ee-cdcf4a5800a9', '01f734b0-0674-5545-aaa3-e873e622d8d4', 60, '2027-01-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f080e699-9c3e-56b0-8263-86db88296ca5', '01f734b0-0674-5545-aaa3-e873e622d8d4', 61, '2027-01-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('267410dc-6d38-55b1-ae5f-71ee4f94f963', '01f734b0-0674-5545-aaa3-e873e622d8d4', 62, '2027-01-06', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('12e01174-4486-5b3f-993c-6258058dd402', '01f734b0-0674-5545-aaa3-e873e622d8d4', 63, '2027-01-07', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1e1f3cbd-c262-59cf-9a5e-026d3e7dace8', '01f734b0-0674-5545-aaa3-e873e622d8d4', 64, '2027-01-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6ee54d2e-cf53-5628-8fbb-924f9937dedd', '01f734b0-0674-5545-aaa3-e873e622d8d4', 65, '2027-01-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bd01584e-463b-5cb4-b028-06ca903be9dd', '01f734b0-0674-5545-aaa3-e873e622d8d4', 66, '2027-01-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('044d9e53-0d0d-5444-ad6e-3835a9900243', '01f734b0-0674-5545-aaa3-e873e622d8d4', 67, '2027-01-13', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8e79314e-c51c-5682-94a0-53ffff8dbee4', '01f734b0-0674-5545-aaa3-e873e622d8d4', 68, '2027-01-14', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6d313887-e89e-50fc-9cfa-9bff5e81e18f', '01f734b0-0674-5545-aaa3-e873e622d8d4', 69, '2027-01-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('80caf190-afde-5532-ba7c-12d0108ab3a2', '01f734b0-0674-5545-aaa3-e873e622d8d4', 70, '2027-01-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('058b5715-43dc-5faf-9551-4c6f83e441cd', '01f734b0-0674-5545-aaa3-e873e622d8d4', 71, '2027-01-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('835c2ae0-f0fb-5433-9adf-68b8fc4f1308', '01f734b0-0674-5545-aaa3-e873e622d8d4', 72, '2027-01-20', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d6586bb9-5c51-54e1-b3cb-950294cd3751', '01f734b0-0674-5545-aaa3-e873e622d8d4', 73, '2027-01-21', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('33fd4394-6113-560e-a252-021d2550d659', '01f734b0-0674-5545-aaa3-e873e622d8d4', 74, '2027-01-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1aa6401c-22b6-5d93-91f2-462a048fd735', '01f734b0-0674-5545-aaa3-e873e622d8d4', 75, '2027-01-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fab0d9a3-b98a-5ee1-aee0-988e9d6af7f1', '01f734b0-0674-5545-aaa3-e873e622d8d4', 76, '2027-01-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7c91c7ce-4793-5e21-96a7-1eaebed8f13e', '01f734b0-0674-5545-aaa3-e873e622d8d4', 77, '2027-01-27', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('09e5f5a6-026f-551b-b182-4b32ef85b467', '01f734b0-0674-5545-aaa3-e873e622d8d4', 78, '2027-01-28', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9b180581-7fe8-5167-bb3a-b1464287923a', '01f734b0-0674-5545-aaa3-e873e622d8d4', 79, '2027-01-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6229fbd1-608a-52a3-a478-420799ca5de8', '01f734b0-0674-5545-aaa3-e873e622d8d4', 80, '2027-02-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9fb98867-81cb-5b0a-b2fd-655e030b525e', '01f734b0-0674-5545-aaa3-e873e622d8d4', 81, '2027-02-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('170095eb-95dc-5a27-b149-a7292d375e18', '01f734b0-0674-5545-aaa3-e873e622d8d4', 82, '2027-02-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3c2e438b-ab5c-52c6-99ad-c2fe5b43bcac', '01f734b0-0674-5545-aaa3-e873e622d8d4', 83, '2027-02-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7fef1982-8797-54cf-86cb-e8647ea616db', '01f734b0-0674-5545-aaa3-e873e622d8d4', 84, '2027-02-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6eaa224e-9500-5e57-a516-a6b9870d3995', '01f734b0-0674-5545-aaa3-e873e622d8d4', 85, '2027-02-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b5d810a4-ebb3-563a-81e2-35886de6c3b1', '01f734b0-0674-5545-aaa3-e873e622d8d4', 86, '2027-02-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('86810559-4740-51bc-a7d9-cd3880c47aa7', '01f734b0-0674-5545-aaa3-e873e622d8d4', 87, '2027-02-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a1ccae9c-eed7-5412-9a26-515fe929df89', '01f734b0-0674-5545-aaa3-e873e622d8d4', 88, '2027-02-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5ee84c5c-fb21-5c38-adac-f1426a236057', '01f734b0-0674-5545-aaa3-e873e622d8d4', 89, '2027-02-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f8785733-4e19-5ec5-a652-d68364c27435', '01f734b0-0674-5545-aaa3-e873e622d8d4', 90, '2027-02-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d573e09d-8a69-5464-a909-396c49766ae3', '01f734b0-0674-5545-aaa3-e873e622d8d4', 91, '2027-02-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('00647061-4d73-5d69-b21f-d68f2075c2f2', '01f734b0-0674-5545-aaa3-e873e622d8d4', 92, '2027-02-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8bf3fcae-65da-56ba-b1ce-e0fa52d79db2', '01f734b0-0674-5545-aaa3-e873e622d8d4', 93, '2027-02-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('afe639ea-6e8f-50a0-9eaf-ebd1b5e4ae94', '01f734b0-0674-5545-aaa3-e873e622d8d4', 94, '2027-02-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('431a0c28-b47b-5710-9e38-53677a58d33d', '01f734b0-0674-5545-aaa3-e873e622d8d4', 95, '2027-02-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('43f000d0-b95d-5b3d-a7bd-f0f33e6b7974', '01f734b0-0674-5545-aaa3-e873e622d8d4', 96, '2027-02-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c4f99a08-7f1f-546a-b48d-7e21691573ef', '01f734b0-0674-5545-aaa3-e873e622d8d4', 97, '2027-02-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ccac2c85-2994-5518-8444-c733216b571f', '01f734b0-0674-5545-aaa3-e873e622d8d4', 98, '2027-02-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ab35992b-9047-5bfc-8323-5d306786901d', '01f734b0-0674-5545-aaa3-e873e622d8d4', 99, '2027-02-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('51e7c922-554b-5cda-9574-a8d42c3a696c', '01f734b0-0674-5545-aaa3-e873e622d8d4', 100, '2027-03-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c76aa1a9-2477-550a-a669-74dbb37e70c2', '01f734b0-0674-5545-aaa3-e873e622d8d4', 101, '2027-03-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c3735079-c488-5724-be02-9f263772f0ff', '01f734b0-0674-5545-aaa3-e873e622d8d4', 102, '2027-03-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b7627aab-72ae-5825-8d02-9dce71a080c2', '01f734b0-0674-5545-aaa3-e873e622d8d4', 103, '2027-03-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('16ac3a2a-3d13-5859-a9ea-5a6548d2249c', '01f734b0-0674-5545-aaa3-e873e622d8d4', 104, '2027-03-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('38591d6a-21df-5327-8890-a31d4a145bc0', '01f734b0-0674-5545-aaa3-e873e622d8d4', 105, '2027-03-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('364bd502-5d87-58f1-8d7d-8557d58f57b2', '01f734b0-0674-5545-aaa3-e873e622d8d4', 106, '2027-03-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('13913424-b524-572b-a218-9baab8c6129a', '01f734b0-0674-5545-aaa3-e873e622d8d4', 107, '2027-03-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('222376d5-7a9c-5360-8b47-4d0b56a6a647', '01f734b0-0674-5545-aaa3-e873e622d8d4', 108, '2027-03-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6345990b-5509-57ef-93ee-4950b6cd5226', '01f734b0-0674-5545-aaa3-e873e622d8d4', 109, '2027-03-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d402af78-f845-5d5f-b3ef-c3e4da9da84a', '01f734b0-0674-5545-aaa3-e873e622d8d4', 110, '2027-03-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8e68f92e-b374-519e-8366-af8053b013d4', '01f734b0-0674-5545-aaa3-e873e622d8d4', 111, '2027-03-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2324327b-2ad1-54e1-88a0-ae5701950250', '01f734b0-0674-5545-aaa3-e873e622d8d4', 112, '2027-03-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ed8cbec0-b15d-5fa0-8db8-f2ae83063505', '01f734b0-0674-5545-aaa3-e873e622d8d4', 113, '2027-03-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('56156c48-365a-5b16-9c17-8a0713002335', '01f734b0-0674-5545-aaa3-e873e622d8d4', 114, '2027-03-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a554d4a2-e7cc-56a3-aa10-c84b2155adea', '01f734b0-0674-5545-aaa3-e873e622d8d4', 115, '2027-03-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53d4d8bb-075d-5bd8-a422-87856c49f9ba', '01f734b0-0674-5545-aaa3-e873e622d8d4', 116, '2027-03-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b2bc3c23-1d59-5868-982e-373bb260c4ea', '01f734b0-0674-5545-aaa3-e873e622d8d4', 117, '2027-03-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2f6ebf5c-72a7-51e9-abb6-83659b49d53a', '01f734b0-0674-5545-aaa3-e873e622d8d4', 118, '2027-03-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('90292eef-8bfa-546a-8c92-6fd523dd107e', '01f734b0-0674-5545-aaa3-e873e622d8d4', 119, '2027-03-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('be726e4c-ab54-51e2-a610-504419c90f34', '01f734b0-0674-5545-aaa3-e873e622d8d4', 120, '2027-03-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 99000.0, 1650.0, 99000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('17c8bf1a-2851-5df7-a0ce-c1b9865d82cd', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 1, '2026-10-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-13', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('013a0f8a-7c97-5ab3-9e6f-b1993ec547be', '2026-10-13 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4bd6350b-1aaf-58ae-aeea-f8ca2afb0f3e', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 2, '2026-10-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-14', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('9d42bcf6-52a0-5548-bbc1-49ac6c00ad66', '2026-10-14 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fb32afc1-f5bf-5deb-8ab9-d41e33f55a58', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 3, '2026-10-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-15', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('be54cf82-a539-5a31-846a-1a8a5341d3bc', '2026-10-15 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a1f54872-6e14-5957-bfee-3111aa993550', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 4, '2026-10-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-16', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('23b6f670-6454-5ca4-a9a0-ab399b8aa1fb', '2026-10-16 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('84a9c686-233b-5eed-aca1-09c605f23736', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 5, '2026-10-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-19', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('950f50b6-5ef0-5fbf-8650-8b92bf2c95a3', '2026-10-19 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0a97557a-c2ac-52eb-8b45-1b9b2369f527', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 6, '2026-10-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-20', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('c9ee7a12-2e05-561b-bbc4-515639097036', '2026-10-20 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('38db3394-80cb-554f-97b4-35081980ad22', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 7, '2026-10-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-21', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3b04ff10-f142-55db-b70d-b3318129bf8d', '2026-10-21 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('45af7a5e-ce04-55c0-9332-aaf13b0671ca', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 8, '2026-10-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-22', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ba916b6e-16e7-5ca3-bd69-7f9b8428746b', '2026-10-22 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a574af07-35c8-501e-9ff1-95bbd414539c', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 9, '2026-10-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-23', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3b6dc70d-8111-5b8d-be3e-39b780e2c8c9', '2026-10-23 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('89a1052c-9f2c-5ab6-86af-7e7062848364', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 10, '2026-10-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-26', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('70851f92-36b5-538c-9992-d99dc501b664', '2026-10-26 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('17532a51-683e-58df-9661-cf33a0ea0299', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 11, '2026-10-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-27', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('efc9fab8-fdae-5182-85ee-a1a13074a419', '2026-10-27 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b051ebbc-2508-5dfe-b002-cb8d650b702b', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 12, '2026-10-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-28', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('d7ebae0a-f056-5a2b-bc84-f7ba40927fe9', '2026-10-28 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b0bb98dd-01f6-5647-8de3-b2cba1ae9c0a', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 13, '2026-10-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-29', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('4214330c-efea-5e8a-ab55-8f0cd8d07da3', '2026-10-29 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('57bf514c-bbe6-5365-b579-8c3410c0450d', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 14, '2026-10-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-30', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('27ba8442-769e-5b4d-aa39-7acfa9286cf1', '2026-10-30 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fe16f6c9-8f24-500d-9d21-d152f8b5d599', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 15, '2026-11-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-02', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('b8161f5c-e231-55b8-a1de-b8581fe91074', '2026-11-02 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('690bd203-2345-504e-abdd-5d48894a4a70', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 16, '2026-11-03', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-03', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('0f0ccf7a-ce8c-5605-a9fe-addccad59d49', '2026-11-03 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f0c36da7-8998-53b1-ae21-f5bddc96defd', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 17, '2026-11-04', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-04', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3d30bbd1-6394-56e6-bad4-cb57441f433f', '2026-11-04 10:00:00+00', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d9a9ea04-15b3-5dd1-abae-ce4f73d9aa9f', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 18, '2026-11-05', 1650.0, 0.0, 0.0, 1650.0, 'Overdue', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1869adb2-f2bf-5773-8a5a-336c96e8ce98', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 19, '2026-11-06', 1650.0, 0.0, 0.0, 1650.0, 'Overdue', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6204a60b-0714-5b8c-9e9d-cd5c9c10b2b3', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 20, '2026-11-09', 1650.0, 0.0, 0.0, 1650.0, 'Overdue', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('19535c49-b4e3-5e6f-8962-2dea01b3d3a5', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 21, '2026-11-10', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('967666f8-84e7-564e-a51b-e54b608302dc', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 22, '2026-11-11', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f4d7c352-6860-5658-85d4-f4bf11a070b5', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 23, '2026-11-12', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bbc56afa-9234-5ade-bf52-858849c7864f', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 24, '2026-11-13', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('de23bc09-285d-56e6-8945-a65011a37705', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 25, '2026-11-16', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('57b938b8-a85b-57b8-b769-211777747733', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 26, '2026-11-17', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ab9d2c41-8595-52b4-8bec-804c9f2ccdd2', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 27, '2026-11-18', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8838814c-185c-5e0d-9dd9-34cbf31cba30', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 28, '2026-11-19', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('57eac21e-fabf-51ab-a350-fc8d28dee05f', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 29, '2026-11-20', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b4aee404-574d-5643-9eac-0d785d38d552', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 30, '2026-11-23', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('32f19d3d-56a9-5fd1-b536-92549246f767', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 31, '2026-11-24', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a5f45b83-6c8a-5101-850b-70eb97807072', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 32, '2026-11-25', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d5d5312d-ba3a-5e5a-8bba-3e7173a2ac33', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 33, '2026-11-26', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c8d21e5b-3b9a-5fd3-aa8e-39addcc7573c', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 34, '2026-11-27', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('04fe3516-dc00-5315-a011-d487c546c1b0', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 35, '2026-11-30', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cb9e6e84-76b1-5957-b401-c40c9f5149ec', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 36, '2026-12-01', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8ce277c3-b1b6-50e6-ba00-26c7b620686d', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 37, '2026-12-02', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('29032335-feda-581f-a173-51f984643d5d', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 38, '2026-12-03', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bbd72bd6-54ad-552a-b8e9-c48dd0347487', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 39, '2026-12-04', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ae3a0bc9-038d-5b19-881a-622edd874461', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 40, '2026-12-07', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('79afa916-1c8d-5587-afa1-f03d0c55bb1f', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 41, '2026-12-08', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5228a15c-1c57-55eb-92cf-afdccfbad6c9', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 42, '2026-12-09', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e1f6e9b1-12a3-59fb-a33c-1481363db36e', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 43, '2026-12-10', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('683ce10e-ce0b-5ff7-9c8a-4c362293a6ca', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 44, '2026-12-11', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('334751a6-704f-5122-9f61-b3edeb7bff0b', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 45, '2026-12-14', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9d1d6376-edd4-5b1b-87ad-b11519edf8da', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 46, '2026-12-15', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('12141800-3cc3-5889-ad90-356af8762c9c', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 47, '2026-12-16', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('985522cd-f5fe-5196-a2be-abcc3f2ca557', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 48, '2026-12-17', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1ee97489-c789-5457-aad6-6ee689caf29a', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 49, '2026-12-18', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('482535c7-73a9-5122-8b8b-fe9550f6eaaa', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 50, '2026-12-21', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('29b7a736-85b4-5bff-878f-4ee7c6794b5d', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 51, '2026-12-22', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ab187549-f2ae-59d2-9773-1c016631cce5', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 52, '2026-12-23', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eb2df32e-17bb-5274-93c7-f2f0932507d5', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 53, '2026-12-24', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ad4f0c6c-27f3-5725-a522-fea821989ad3', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 54, '2026-12-25', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('18b42958-f7b0-5c62-954c-e7b3dd715031', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 55, '2026-12-28', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b687fa93-4e68-5982-9651-447ab48886c5', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 56, '2026-12-29', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f9b33de0-343e-5e4c-95cc-5942133aebd2', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 57, '2026-12-30', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('efa6058b-a5d0-50f8-bab8-76c7b9e09735', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 58, '2026-12-31', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2ac47ec5-23d8-5dda-81c6-ba6239fa3b08', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 59, '2027-01-01', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b644cf53-4fc2-56c8-b6ca-b66c4a039b47', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 60, '2027-01-04', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('93473da5-7219-5e20-8d2a-0e1e85c43db4', '730e9395-6b7f-553d-9b1a-35b6349c1fee', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 99000.0, 8250.0, 99000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-05', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b8260fa4-f661-5c43-81cb-5b2c626e4f13', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 1, '2026-10-13', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-13', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('f29e422b-bc56-5d20-8ae6-8d71714eb6ed', '2026-10-13 10:00:00+00', '93473da5-7219-5e20-8d2a-0e1e85c43db4', '730e9395-6b7f-553d-9b1a-35b6349c1fee', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a124f0f2-6b7f-5353-8fbd-417895791463', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 2, '2026-10-20', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-20', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('4d19e3c5-7981-5edd-a175-87be988bcf62', '2026-10-20 10:00:00+00', '93473da5-7219-5e20-8d2a-0e1e85c43db4', '730e9395-6b7f-553d-9b1a-35b6349c1fee', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('95e4477d-cb5a-50e6-ab78-e0ec64c1b15c', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 3, '2026-10-27', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-27', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3a778272-d77c-5506-9999-37d826f2d24a', '2026-10-27 10:00:00+00', '93473da5-7219-5e20-8d2a-0e1e85c43db4', '730e9395-6b7f-553d-9b1a-35b6349c1fee', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('31e04bb1-f188-5807-9836-dc731e04c8aa', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 4, '2026-11-03', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-11-03', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('83061c1a-341c-5b5b-8fcc-8755bd729cd4', '2026-11-03 10:00:00+00', '93473da5-7219-5e20-8d2a-0e1e85c43db4', '730e9395-6b7f-553d-9b1a-35b6349c1fee', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d4c45ff4-aa79-5e2d-a2dc-a592f39dbad5', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 5, '2026-11-10', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('661c8bb0-0bbd-5571-86f2-400af4a1cbec', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 6, '2026-11-17', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a582aaa3-727e-5700-b0a6-c84ba4a83dff', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 7, '2026-11-24', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fb1f9aa5-6e9d-57ef-8089-9dd999664cb5', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 8, '2026-12-01', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8e386f46-5c40-5115-ae62-af53972d92d7', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 9, '2026-12-08', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('30c435dc-cce1-5a3c-9a14-f8c5e70079ce', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 10, '2026-12-15', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e5aa2ac5-9c54-5250-a1ef-09f45f966d8b', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 11, '2026-12-22', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ff8218b5-fa0d-5756-8081-2b4e2ccc66a0', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 12, '2026-12-29', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 'a5800f83-0be5-5dc9-8608-f799cf95820b', 'c090f418-d2c1-4855-ab87-88e25589c471', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 96000.0, 4000.0, 96000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-03-30', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('607751aa-b9c8-54ec-81de-bd68b8af6e4b', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 1, '2026-10-13', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-10-13', 4000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e2439c87-5d6d-5621-a6ad-a19778bac105', '2026-10-13 10:00:00+00', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 'a5800f83-0be5-5dc9-8608-f799cf95820b', 4000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6e5c9a0b-1e25-55d1-870a-ac8c5c62b852', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 2, '2026-10-20', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-10-20', 4000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('8e98983b-d186-5a25-8d9d-edefb68c851d', '2026-10-20 10:00:00+00', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 'a5800f83-0be5-5dc9-8608-f799cf95820b', 4000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2b8fb545-0381-5e23-9e79-d332f4b08c84', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 3, '2026-10-27', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-10-27', 4000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('06d5fe16-887c-540d-9782-d680d9a1576a', '2026-10-27 10:00:00+00', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 'a5800f83-0be5-5dc9-8608-f799cf95820b', 4000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5f2cbcc8-e819-5c07-a235-9895b864a9cb', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 4, '2026-11-03', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-11-03', 4000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ed73ff84-4b89-59c1-a71f-489c2ce27981', '2026-11-03 10:00:00+00', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 'a5800f83-0be5-5dc9-8608-f799cf95820b', 4000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c0175494-ad40-5215-b784-42af66ea84fd', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 5, '2026-11-10', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('286f94da-d92c-5580-88f7-5a083774c13e', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 6, '2026-11-17', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5344c6c9-4c4a-564e-9761-64640967e61d', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 7, '2026-11-24', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5608fec0-8fc7-516e-8870-41489c9fb22d', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 8, '2026-12-01', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b5084fe9-acb2-51e1-b776-39883767d3c5', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 9, '2026-12-08', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5750f992-4df7-576f-bb23-2964428b7a46', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 10, '2026-12-15', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('27447f87-b5f4-5d22-8592-9ca2e9b6b876', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 11, '2026-12-22', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('14e1865b-30f9-52a5-808d-7a1295b6623c', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 12, '2026-12-29', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8f7cd4f3-8558-5ca7-89b7-9d77b05ee0f1', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 13, '2027-01-05', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6371fff3-dbad-55ac-b5ac-34fa102997cc', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 14, '2027-01-12', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8e2d2046-8e56-5f53-a264-9ea2e4d51226', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 15, '2027-01-19', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3c800d25-8c81-5a33-aee9-fadeebaf789d', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 16, '2027-01-26', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('18201b33-7584-537c-a44b-d1bf307a94d7', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 17, '2027-02-02', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4a709f2d-a32c-5728-98d6-4a560723b649', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 18, '2027-02-09', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e16353cf-a795-5344-b909-6e40042b07a8', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 19, '2027-02-16', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('191841b0-c706-5457-9c2d-06aaa9a3c311', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 20, '2027-02-23', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f54b0ff7-d793-588b-9002-5180645acc76', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 21, '2027-03-02', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('437f22f9-b4c1-5d30-9fa9-2ee25b342f6c', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 22, '2027-03-09', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1006ed95-e967-5d46-8e35-aaf8cccb0a27', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 23, '2027-03-16', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('40cd20b3-7ebb-5d40-886d-44a3b512b860', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 24, '2027-03-23', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('2613e9b5-9fba-553f-87e8-ff6f0705648c', 'be500c02-686f-5de5-aa3c-9494991fbb57', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 200000.0, 198000.0, 16500.0, 198000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-05', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('48ca6378-3a82-5e00-91db-cb96d1d97785', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 1, '2026-10-13', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-10-13', 16500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('3bcbf15e-244b-5c33-9bb4-f29fa2cada91', '2026-10-13 10:00:00+00', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 'be500c02-686f-5de5-aa3c-9494991fbb57', 16500.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a100ac29-ea86-5536-84eb-a9535e51659e', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 2, '2026-10-20', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-10-20', 16500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('c8d2f058-876e-5da6-b0b0-b1a3a4a52069', '2026-10-20 10:00:00+00', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 'be500c02-686f-5de5-aa3c-9494991fbb57', 16500.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f947f67f-e71f-569e-ac55-d04633b8e68b', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 3, '2026-10-27', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-10-27', 16500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('1765f6da-14a5-541d-a917-9546e98b2f7a', '2026-10-27 10:00:00+00', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 'be500c02-686f-5de5-aa3c-9494991fbb57', 16500.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('026914b9-a008-5966-97b4-45dd549f52ec', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 4, '2026-11-03', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-11-03', 16500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('840c2441-2442-590f-8a63-95a54ff43dc1', '2026-11-03 10:00:00+00', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 'be500c02-686f-5de5-aa3c-9494991fbb57', 16500.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('261c0e71-9796-551e-848e-7ad0ad94ec08', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 5, '2026-11-10', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cb4bc1ab-742a-545f-b147-0833173f267c', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 6, '2026-11-17', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d7ce1054-44ab-5f39-854e-a2021b145f1b', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 7, '2026-11-24', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bf21bd45-be86-5a0e-b7bb-f4e26cb83d9b', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 8, '2026-12-01', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b4a4272f-2cda-5e51-9285-b22c865ae117', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 9, '2026-12-08', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a0e287b2-4be5-5578-ad7a-b6649eb31d6a', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 10, '2026-12-15', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b08220ab-4b19-5cd0-970b-dfde8b5a55ee', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 11, '2026-12-22', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9cfda8f2-b546-5c9e-b81c-d3b58adf34dc', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 12, '2026-12-29', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-07-20', 100000.0, 99000.0, 8250.0, 99000.0, 'Completed', 'Finance', '2026-07-20', '2026-07-21', '2026-10-13', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7ddc794f-dbdf-5e67-b899-35cdeaf8c0d6', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 1, '2026-07-21', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-07-21', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('1b8a283d-ea97-5726-86f8-7ede933f91f9', '2026-07-21 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('09133ed5-11d9-59bf-bb93-c3776f0b62fb', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 2, '2026-07-28', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-07-28', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('04471da3-5976-5720-9214-a4ff650183f5', '2026-07-28 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('64784f00-dee1-5ee3-b81d-dcc7ffee8c58', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 3, '2026-08-04', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-04', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('a7fc210e-d8ed-5e71-80fc-3c6a769449ed', '2026-08-04 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('578a19bb-0a6c-5f51-91d6-cf6907aa7400', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 4, '2026-08-11', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-11', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('8fae48c6-f247-5b26-a08d-972c7826b307', '2026-08-11 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6b82f174-c3ae-5cf1-9b9c-47c73c8f8bf7', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 5, '2026-08-18', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-18', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('73c6d4d7-9a86-54dd-b018-17d89b030122', '2026-08-18 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('76543e8f-6f58-5d7c-89c3-c36befad1b63', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 6, '2026-08-25', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-25', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('df60b06d-dc57-57aa-aa9a-7c7148f77642', '2026-08-25 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53bf4f66-77ed-595b-8dba-88fdd537aa9e', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 7, '2026-09-01', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-01', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('972b6aa3-17d0-5194-a74c-028ec72c3862', '2026-09-01 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('401d2273-693a-5e06-ba1a-71b00364fe4e', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 8, '2026-09-08', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-08', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('63318bbb-5d81-5bf5-8170-8d3468c47013', '2026-09-08 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c598ed0b-ecd9-5ead-918b-170eedd9c3b4', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 9, '2026-09-15', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-15', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('387d8315-9d66-51c2-b0da-7e422fad0445', '2026-09-15 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4143651b-5454-5776-b39d-0d53c9fd7515', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 10, '2026-09-22', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-22', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('957737bc-d040-5790-a111-4b30c5a5996f', '2026-09-22 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cb27f64e-d18c-5b8e-94a4-9c5db195a539', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 11, '2026-09-29', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-29', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('2b669869-a5b0-5766-9c3c-b397a3d1cb33', '2026-09-29 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bd8c497e-04ab-53e2-8ff0-3e0ec6f2ff70', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 12, '2026-10-06', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-06', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('6c4d1a26-b290-550e-a4eb-0925075cea27', '2026-10-06 10:00:00+00', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_payoff_excess_records (id, repayment_id, loan_id, client_id, officer_id, branch_id, date, record_type, amount_paid, expected_installment, active_credit_settled, excess_amount, remaining_balance_before, remaining_balance_after, notes, created_at)
                        VALUES ('9a89945e-fb8b-5763-9f33-f1c46d07fdc6', '6c4d1a26-b290-550e-a4eb-0925075cea27', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-06', 'FULL_PAYOFF', 8250.0, 8250.0, 99000.0, 0.0, 8250.0, 0.0, 'Full loan completion settlement', NOW())
                        ON CONFLICT (id) DO NOTHING;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('3cd518a9-ef78-51e0-99c7-e8f6fef984a8', '06a30779-7559-5d85-b6b2-79d33e18db06', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-19', 100000.0, 99000.0, 8250.0, 99000.0, 'Active', 'Finance', '2026-10-19', '2026-10-22', '2027-01-14', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d1b0b099-872c-548e-b3b0-f7d49af00d9c', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 1, '2026-10-22', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-22', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('759df8e3-ddfc-5129-91cf-b7aa0d3469fe', '2026-10-22 10:00:00+00', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', '06a30779-7559-5d85-b6b2-79d33e18db06', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c89187ef-a466-5e96-9174-e0d7005160bb', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 2, '2026-10-29', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-29', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('726c8398-6830-5881-a532-9b7833deb34b', '2026-10-29 10:00:00+00', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', '06a30779-7559-5d85-b6b2-79d33e18db06', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2b5fc15d-01d9-5861-83ec-195a2148b194', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 3, '2026-11-05', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-11-05', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('9ea9ded9-b19a-5304-8b8e-e2673e577388', '2026-11-05 10:00:00+00', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', '06a30779-7559-5d85-b6b2-79d33e18db06', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('559671ab-d628-53d7-9e86-d1aebcd4c792', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 4, '2026-11-12', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('da1f5b61-566c-5dd7-8810-05de1dd1b08f', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 5, '2026-11-19', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0714c7a9-4797-5561-8209-043265ac33c9', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 6, '2026-11-26', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d9c47f5d-7439-5307-a537-a4b22d59689d', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 7, '2026-12-03', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b191a254-c9e9-5675-81a0-2eaf08d9d682', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 8, '2026-12-10', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('28ba87a0-79c2-5183-bd91-daaa3131a355', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 9, '2026-12-17', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3b7882af-b14c-572a-9bd4-7e23996f7359', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 10, '2026-12-24', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6437dd6b-0787-5085-a8cb-7927937c806a', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 11, '2026-12-31', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2b3fae77-f523-5e32-8427-b8d549fc9f0e', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 12, '2027-01-07', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('570d9a60-a540-5324-b5e6-6afe471a72aa', 'f98fecb1-40fc-5c7d-a3c7-7bb4d9bd983f', 'c090f418-d2c1-4855-ab87-88e25589c471', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-19', 150000.0, 150000.0, 6250.0, 150000.0, 'Active', 'Finance', '2026-10-19', '2026-10-22', '2027-04-08', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9b16d32d-666a-5390-816a-3a988a84c02f', '570d9a60-a540-5324-b5e6-6afe471a72aa', 1, '2026-10-22', 6250.0, 0.0, 0.0, 6250.0, 'Paid', '2026-10-22', 6250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('c363ef21-622a-59e9-bf98-58b3f8ee3bd3', '2026-10-22 10:00:00+00', '570d9a60-a540-5324-b5e6-6afe471a72aa', 'f98fecb1-40fc-5c7d-a3c7-7bb4d9bd983f', 6250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('949fc0e8-04c3-5273-8a71-30ebb970dcb0', '570d9a60-a540-5324-b5e6-6afe471a72aa', 2, '2026-10-29', 6250.0, 0.0, 0.0, 6250.0, 'Paid', '2026-10-29', 6250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('cc71a28b-7dcc-5481-b645-bfb84074a6b4', '2026-10-29 10:00:00+00', '570d9a60-a540-5324-b5e6-6afe471a72aa', 'f98fecb1-40fc-5c7d-a3c7-7bb4d9bd983f', 6250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1aca15ef-c984-5a7d-ac41-ee6c6b52c012', '570d9a60-a540-5324-b5e6-6afe471a72aa', 3, '2026-11-05', 6250.0, 0.0, 0.0, 6250.0, 'Paid', '2026-11-05', 6250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('a60652d4-88f9-5cc8-81da-82fa5f6249ac', '2026-11-05 10:00:00+00', '570d9a60-a540-5324-b5e6-6afe471a72aa', 'f98fecb1-40fc-5c7d-a3c7-7bb4d9bd983f', 6250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e1846a83-089b-51d9-9e8c-1ded5f71e70d', '570d9a60-a540-5324-b5e6-6afe471a72aa', 4, '2026-11-12', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('545e32d8-d528-5677-8be4-ba58894d7109', '570d9a60-a540-5324-b5e6-6afe471a72aa', 5, '2026-11-19', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3d887066-87ac-5475-a073-aa99d03c0948', '570d9a60-a540-5324-b5e6-6afe471a72aa', 6, '2026-11-26', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6b44003b-b2ae-5422-8ac5-1e80990a015a', '570d9a60-a540-5324-b5e6-6afe471a72aa', 7, '2026-12-03', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e752c2b4-0f0a-59de-afcf-689011fe2507', '570d9a60-a540-5324-b5e6-6afe471a72aa', 8, '2026-12-10', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ec707c07-67a6-5e52-ae2a-aea232adc18b', '570d9a60-a540-5324-b5e6-6afe471a72aa', 9, '2026-12-17', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1be7c3ba-e810-5d6c-ad69-bb903bac8f1b', '570d9a60-a540-5324-b5e6-6afe471a72aa', 10, '2026-12-24', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('37baca38-0e28-56fa-b7bb-1f18f7361722', '570d9a60-a540-5324-b5e6-6afe471a72aa', 11, '2026-12-31', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53da684c-8146-524a-ab18-e3eecfd07e98', '570d9a60-a540-5324-b5e6-6afe471a72aa', 12, '2027-01-07', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8a84c915-7a58-5077-add8-4d4d98e33cc2', '570d9a60-a540-5324-b5e6-6afe471a72aa', 13, '2027-01-14', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cec73341-3738-5a74-869a-a5a0981321a9', '570d9a60-a540-5324-b5e6-6afe471a72aa', 14, '2027-01-21', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a3267fdc-9c7e-5f77-98bc-857c17630493', '570d9a60-a540-5324-b5e6-6afe471a72aa', 15, '2027-01-28', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0e2a91a2-cb9e-5e92-a760-6db3ebd18b5e', '570d9a60-a540-5324-b5e6-6afe471a72aa', 16, '2027-02-04', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f2a24dc2-e3e2-5187-9a80-7e8005ffcdb6', '570d9a60-a540-5324-b5e6-6afe471a72aa', 17, '2027-02-11', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2ce2d9f8-1f7f-5b4f-bc8c-04e2fbd506e0', '570d9a60-a540-5324-b5e6-6afe471a72aa', 18, '2027-02-18', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('acb334b0-5bbb-5423-8b8d-7d14a1f062a6', '570d9a60-a540-5324-b5e6-6afe471a72aa', 19, '2027-02-25', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('17a7faff-cfc9-5566-bf71-3defed17601a', '570d9a60-a540-5324-b5e6-6afe471a72aa', 20, '2027-03-04', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('38fa930e-e384-5d74-b9e5-5699bc23da52', '570d9a60-a540-5324-b5e6-6afe471a72aa', 21, '2027-03-11', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('896dd1c4-62f6-5182-9d9c-7cabc564e0e1', '570d9a60-a540-5324-b5e6-6afe471a72aa', 22, '2027-03-18', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d501bd3b-b577-501d-86c3-117d7df3a2f5', '570d9a60-a540-5324-b5e6-6afe471a72aa', 23, '2027-03-25', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('06073e63-e7cf-5474-a2de-beaecb57e1f2', '570d9a60-a540-5324-b5e6-6afe471a72aa', 24, '2027-04-01', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('391235c7-4fce-5754-a6e8-c5e9f85e3803', '3fd0f263-f637-5ff2-9277-061272d1ad70', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-11-09', 100000.0, 99000.0, 8250.0, 99000.0, 'Pending', 'Finance', '2026-11-09', '2026-11-12', '2027-02-04', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('248a0bd4-1eeb-5b2b-bbe7-c327eedb78db', '8e383916-78ef-5914-b578-11b7e05dbde2', 'b788e502-3787-4d51-8eb7-0ac9ea88c7a9', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-09-01', 300000.0, 300000.0, 100000.0, 300000.0, 'Active', 'Finance', '2026-09-01', '2026-10-01', '2026-12-30', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d500fe6a-8128-5914-a229-6e88c712cde0', '248a0bd4-1eeb-5b2b-bbe7-c327eedb78db', 1, '2026-10-01', 100000.0, 0.0, 0.0, 100000.0, 'Paid', '2026-10-01', 100000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('dcdcb21a-5f47-5732-bb3d-02d4bc1eb906', '2026-10-01 10:00:00+00', '248a0bd4-1eeb-5b2b-bbe7-c327eedb78db', '8e383916-78ef-5914-b578-11b7e05dbde2', 100000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('60a73d87-307d-50b5-934f-cde97cd5dfdf', '248a0bd4-1eeb-5b2b-bbe7-c327eedb78db', 2, '2026-10-31', 100000.0, 0.0, 0.0, 100000.0, 'Paid', '2026-10-31', 100000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('6812166a-ede8-5d3b-bf9d-7171d29cc69d', '2026-10-31 10:00:00+00', '248a0bd4-1eeb-5b2b-bbe7-c327eedb78db', '8e383916-78ef-5914-b578-11b7e05dbde2', 100000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('35504e14-69a2-5d76-9f1d-0ddb292e59f3', '248a0bd4-1eeb-5b2b-bbe7-c327eedb78db', 3, '2026-11-30', 100000.0, 0.0, 0.0, 100000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('21ae0d38-f881-5684-87a0-5dda9152aae9', '2e53acb4-886b-5e6c-964a-95cbefc587a2', '7cb6379d-43e7-4984-9223-1f45aee6e3ab', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-03', 100000.0, 99600.0, 16600.0, 99600.0, 'Active', 'Finance', '2026-08-03', '2026-09-03', '2027-03-02', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c665a8bf-f676-54a1-a313-16f239acf33b', '21ae0d38-f881-5684-87a0-5dda9152aae9', 1, '2026-09-03', 16600.0, 0.0, 0.0, 16600.0, 'Paid', '2026-09-03', 16600.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('ea32969f-983f-5c18-ac64-3502f2780c78', '2026-09-03 10:00:00+00', '21ae0d38-f881-5684-87a0-5dda9152aae9', '2e53acb4-886b-5e6c-964a-95cbefc587a2', 16600.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b78fa03b-21a5-5905-944c-67ff9866ebe2', '21ae0d38-f881-5684-87a0-5dda9152aae9', 2, '2026-10-03', 16600.0, 0.0, 0.0, 16600.0, 'Paid', '2026-10-03', 16600.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('e0d72813-d8c3-50da-8237-45a8b81fc940', '2026-10-03 10:00:00+00', '21ae0d38-f881-5684-87a0-5dda9152aae9', '2e53acb4-886b-5e6c-964a-95cbefc587a2', 16600.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b0669886-4916-5c44-8c15-ea758da49def', '21ae0d38-f881-5684-87a0-5dda9152aae9', 3, '2026-11-02', 16600.0, 0.0, 0.0, 16600.0, 'Paid', '2026-11-02', 16600.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, created_at)
                    VALUES ('fa006e9d-df7c-5999-8285-838eb588a081', '2026-11-02 10:00:00+00', '21ae0d38-f881-5684-87a0-5dda9152aae9', '2e53acb4-886b-5e6c-964a-95cbefc587a2', 16600.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', NOW())
                    ON CONFLICT (id) DO NOTHING;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('46a7391a-db27-5efa-a9c3-b10b04e9c0fe', '21ae0d38-f881-5684-87a0-5dda9152aae9', 4, '2026-12-02', 16600.0, 0.0, 0.0, 16600.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('98cdf5c5-e8a7-5d36-9e3c-fdecc6cc8480', '21ae0d38-f881-5684-87a0-5dda9152aae9', 5, '2027-01-01', 16600.0, 0.0, 0.0, 16600.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('58dee6a4-7f5e-55f8-8fc8-049fbf8721b6', '21ae0d38-f881-5684-87a0-5dda9152aae9', 6, '2027-01-31', 16600.0, 0.0, 0.0, 16600.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;