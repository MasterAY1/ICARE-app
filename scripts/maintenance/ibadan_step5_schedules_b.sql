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

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ddf6836a-1996-5e2e-8578-26dae631a619', '01f734b0-0674-5545-aaa3-e873e622d8d4', 1, '2026-10-13', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-13', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f5998baa-3c44-5da5-9e5d-995b0a60787a', '01f734b0-0674-5545-aaa3-e873e622d8d4', 2, '2026-10-14', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-14', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d2020604-ebe1-5f33-90a7-34d404505584', '01f734b0-0674-5545-aaa3-e873e622d8d4', 3, '2026-10-15', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-15', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9719e1bd-1654-5023-a077-5ce08bb66218', '01f734b0-0674-5545-aaa3-e873e622d8d4', 4, '2026-10-16', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-16', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dfc7cee0-5e03-537b-9f16-f2752b28ea16', '01f734b0-0674-5545-aaa3-e873e622d8d4', 5, '2026-10-19', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-19', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2cf88766-e59e-5d3b-bd13-6023cf96dded', '01f734b0-0674-5545-aaa3-e873e622d8d4', 6, '2026-10-20', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-20', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dd49ba43-8339-5a53-8fa7-e4c2def95ae3', '01f734b0-0674-5545-aaa3-e873e622d8d4', 7, '2026-10-21', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-21', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('47bde037-5d7e-5662-afd8-325c81548fe3', '01f734b0-0674-5545-aaa3-e873e622d8d4', 8, '2026-10-22', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-22', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5b73f907-2508-5caa-9c9b-e1eedfa018d8', '01f734b0-0674-5545-aaa3-e873e622d8d4', 9, '2026-10-23', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-23', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('147ba5d3-4fe4-590a-b029-7773dea82347', '01f734b0-0674-5545-aaa3-e873e622d8d4', 10, '2026-10-26', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-26', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a344c271-dbb9-511c-a41b-04aa678aa701', '01f734b0-0674-5545-aaa3-e873e622d8d4', 11, '2026-10-27', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-27', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('55f101cb-8328-5376-b49b-b9d59698c014', '01f734b0-0674-5545-aaa3-e873e622d8d4', 12, '2026-10-28', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-28', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7696ada2-0a9f-56b0-860a-175e5a3dd28f', '01f734b0-0674-5545-aaa3-e873e622d8d4', 13, '2026-10-29', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-29', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ce98842c-5ff7-5e8b-bf68-20b5c6d493c5', '01f734b0-0674-5545-aaa3-e873e622d8d4', 14, '2026-10-30', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-30', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5e642736-fb0d-570d-ab34-bfe94bdfc0a5', '01f734b0-0674-5545-aaa3-e873e622d8d4', 15, '2026-11-02', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-02', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('108e3d9d-10fa-56a0-afb4-1e77aa2b71bc', '01f734b0-0674-5545-aaa3-e873e622d8d4', 16, '2026-11-03', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-03', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0e0722ba-66e1-52a3-9570-efbd5f0d4686', '01f734b0-0674-5545-aaa3-e873e622d8d4', 17, '2026-11-04', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-04', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('19dfc375-6356-5913-a358-c83b55d69f22', '01f734b0-0674-5545-aaa3-e873e622d8d4', 18, '2026-11-05', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-05', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('38197799-1f41-5024-8188-f80ae2195b24', '01f734b0-0674-5545-aaa3-e873e622d8d4', 19, '2026-11-06', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-06', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('81f8f94d-1096-5811-b7e5-4392bd39b657', '01f734b0-0674-5545-aaa3-e873e622d8d4', 20, '2026-11-09', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-09', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

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

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('17c8bf1a-2851-5df7-a0ce-c1b9865d82cd', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 1, '2026-10-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-13', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4bd6350b-1aaf-58ae-aeea-f8ca2afb0f3e', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 2, '2026-10-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-14', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fb32afc1-f5bf-5deb-8ab9-d41e33f55a58', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 3, '2026-10-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-15', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a1f54872-6e14-5957-bfee-3111aa993550', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 4, '2026-10-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-16', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('84a9c686-233b-5eed-aca1-09c605f23736', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 5, '2026-10-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-19', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0a97557a-c2ac-52eb-8b45-1b9b2369f527', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 6, '2026-10-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-20', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('38db3394-80cb-554f-97b4-35081980ad22', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 7, '2026-10-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-21', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('45af7a5e-ce04-55c0-9332-aaf13b0671ca', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 8, '2026-10-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-22', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a574af07-35c8-501e-9ff1-95bbd414539c', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 9, '2026-10-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-23', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('89a1052c-9f2c-5ab6-86af-7e7062848364', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 10, '2026-10-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-26', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('17532a51-683e-58df-9661-cf33a0ea0299', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 11, '2026-10-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-27', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b051ebbc-2508-5dfe-b002-cb8d650b702b', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 12, '2026-10-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-28', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b0bb98dd-01f6-5647-8de3-b2cba1ae9c0a', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 13, '2026-10-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-29', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('57bf514c-bbe6-5365-b579-8c3410c0450d', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 14, '2026-10-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-30', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fe16f6c9-8f24-500d-9d21-d152f8b5d599', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 15, '2026-11-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-02', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('690bd203-2345-504e-abdd-5d48894a4a70', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 16, '2026-11-03', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-03', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f0c36da7-8998-53b1-ae21-f5bddc96defd', '3d8fc20d-42d4-5596-a26e-5ea82b477ced', 17, '2026-11-04', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-04', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

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
                    paid_amount = EXCLUDED.paid_amount;;
