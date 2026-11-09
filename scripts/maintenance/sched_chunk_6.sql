INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b8260fa4-f661-5c43-81cb-5b2c626e4f13', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 1, '2026-10-13', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-13', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a124f0f2-6b7f-5353-8fbd-417895791463', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 2, '2026-10-20', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-20', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('95e4477d-cb5a-50e6-ab78-e0ec64c1b15c', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 3, '2026-10-27', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-27', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('31e04bb1-f188-5807-9836-dc731e04c8aa', '93473da5-7219-5e20-8d2a-0e1e85c43db4', 4, '2026-11-03', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-11-03', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
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
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('607751aa-b9c8-54ec-81de-bd68b8af6e4b', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 1, '2026-10-13', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-10-13', 4000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6e5c9a0b-1e25-55d1-870a-ac8c5c62b852', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 2, '2026-10-20', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-10-20', 4000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2b8fb545-0381-5e23-9e79-d332f4b08c84', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 3, '2026-10-27', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-10-27', 4000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5f2cbcc8-e819-5c07-a235-9895b864a9cb', 'ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 4, '2026-11-03', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-11-03', 4000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
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
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('48ca6378-3a82-5e00-91db-cb96d1d97785', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 1, '2026-10-13', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-10-13', 16500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a100ac29-ea86-5536-84eb-a9535e51659e', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 2, '2026-10-20', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-10-20', 16500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f947f67f-e71f-569e-ac55-d04633b8e68b', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 3, '2026-10-27', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-10-27', 16500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('026914b9-a008-5966-97b4-45dd549f52ec', '2613e9b5-9fba-553f-87e8-ff6f0705648c', 4, '2026-11-03', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-11-03', 16500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
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
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7ddc794f-dbdf-5e67-b899-35cdeaf8c0d6', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 1, '2026-07-21', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-07-21', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('09133ed5-11d9-59bf-bb93-c3776f0b62fb', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 2, '2026-07-28', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-07-28', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('64784f00-dee1-5ee3-b81d-dcc7ffee8c58', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 3, '2026-08-04', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-04', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('578a19bb-0a6c-5f51-91d6-cf6907aa7400', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 4, '2026-08-11', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-11', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6b82f174-c3ae-5cf1-9b9c-47c73c8f8bf7', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 5, '2026-08-18', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-18', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('76543e8f-6f58-5d7c-89c3-c36befad1b63', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 6, '2026-08-25', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-25', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53bf4f66-77ed-595b-8dba-88fdd537aa9e', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 7, '2026-09-01', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-01', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('401d2273-693a-5e06-ba1a-71b00364fe4e', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 8, '2026-09-08', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-08', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c598ed0b-ecd9-5ead-918b-170eedd9c3b4', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 9, '2026-09-15', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-15', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4143651b-5454-5776-b39d-0d53c9fd7515', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 10, '2026-09-22', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-22', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cb27f64e-d18c-5b8e-94a4-9c5db195a539', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 11, '2026-09-29', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-29', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bd8c497e-04ab-53e2-8ff0-3e0ec6f2ff70', 'bdf55216-7f97-53cf-babf-35c1e9eeb38b', 12, '2026-10-06', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-06', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d1b0b099-872c-548e-b3b0-f7d49af00d9c', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 1, '2026-10-22', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-22', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c89187ef-a466-5e96-9174-e0d7005160bb', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 2, '2026-10-29', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-29', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2b5fc15d-01d9-5861-83ec-195a2148b194', '3cd518a9-ef78-51e0-99c7-e8f6fef984a8', 3, '2026-11-05', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-11-05', 8250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
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
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9b16d32d-666a-5390-816a-3a988a84c02f', '570d9a60-a540-5324-b5e6-6afe471a72aa', 1, '2026-10-22', 6250.0, 0.0, 0.0, 6250.0, 'Paid', '2026-10-22', 6250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('949fc0e8-04c3-5273-8a71-30ebb970dcb0', '570d9a60-a540-5324-b5e6-6afe471a72aa', 2, '2026-10-29', 6250.0, 0.0, 0.0, 6250.0, 'Paid', '2026-10-29', 6250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1aca15ef-c984-5a7d-ac41-ee6c6b52c012', '570d9a60-a540-5324-b5e6-6afe471a72aa', 3, '2026-11-05', 6250.0, 0.0, 0.0, 6250.0, 'Paid', '2026-11-05', 6250.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
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
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d500fe6a-8128-5914-a229-6e88c712cde0', '248a0bd4-1eeb-5b2b-bbe7-c327eedb78db', 1, '2026-10-01', 100000.0, 0.0, 0.0, 100000.0, 'Paid', '2026-10-01', 100000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('60a73d87-307d-50b5-934f-cde97cd5dfdf', '248a0bd4-1eeb-5b2b-bbe7-c327eedb78db', 2, '2026-10-31', 100000.0, 0.0, 0.0, 100000.0, 'Paid', '2026-10-31', 100000.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('35504e14-69a2-5d76-9f1d-0ddb292e59f3', '248a0bd4-1eeb-5b2b-bbe7-c327eedb78db', 3, '2026-11-30', 100000.0, 0.0, 0.0, 100000.0, 'Pending', NULL, 0.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c665a8bf-f676-54a1-a313-16f239acf33b', '21ae0d38-f881-5684-87a0-5dda9152aae9', 1, '2026-09-03', 16600.0, 0.0, 0.0, 16600.0, 'Paid', '2026-09-03', 16600.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b78fa03b-21a5-5905-944c-67ff9866ebe2', '21ae0d38-f881-5684-87a0-5dda9152aae9', 2, '2026-10-03', 16600.0, 0.0, 0.0, 16600.0, 'Paid', '2026-10-03', 16600.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b0669886-4916-5c44-8c15-ea758da49def', '21ae0d38-f881-5684-87a0-5dda9152aae9', 3, '2026-11-02', 16600.0, 0.0, 0.0, 16600.0, 'Paid', '2026-11-02', 16600.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;
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
