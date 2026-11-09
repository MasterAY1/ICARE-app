INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('395e6390-6de1-59c3-8229-41242ee4a2df', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 1, '2026-10-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-13', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b3ba2144-7b85-5104-a665-7d23ee9d8d99', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 2, '2026-10-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-14', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e874ec84-913d-5b39-ac5b-c701e8a52eac', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 3, '2026-10-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-15', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('62524169-c3eb-5308-a155-377f988caa66', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 4, '2026-10-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-16', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ea4f8043-e719-5a43-8b02-d8e417ecf2be', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 5, '2026-10-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-19', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('15dde16e-66dc-5aef-8b03-a1016019ca29', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 6, '2026-10-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-20', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fe72cec2-6c74-5913-87b7-fff8b0f2e2fb', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 7, '2026-10-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-21', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d6a13ff6-3a80-55e0-befb-ad52867a5df9', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 8, '2026-10-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-22', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('678214b6-d206-58b6-a5d8-8c46aaee1cbb', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 9, '2026-10-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-23', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eb33df74-1c2e-5a0b-a78e-764c244167b1', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 10, '2026-10-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-26', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('533b796b-723b-59ab-9a03-366e94bb0036', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 11, '2026-10-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-27', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0f1a0d11-a1f0-557d-9d15-f79e959a8a02', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 12, '2026-10-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-28', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0a8815e2-0ecd-54e5-baf4-2cfc1ba2d133', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 13, '2026-10-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-29', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6b1db706-a0cf-5156-b707-fa3fcedcc40f', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 14, '2026-10-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-30', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e1c1391d-769c-5d0c-bd50-8d76d3796d19', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 15, '2026-11-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-02', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('62d18bd9-911e-5c09-99f1-2b6c428bf5cf', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 16, '2026-11-03', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-03', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fa22bdd6-df4d-5c73-8b4f-a454a9afd895', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 17, '2026-11-04', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-04', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a8429395-f0b5-5212-b114-2c770fd3f884', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 18, '2026-11-05', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-05', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7bcb19f6-06b1-5dab-a4b6-7ae795e47e1e', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 19, '2026-11-06', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-06', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('51295e16-aa96-536c-88b8-44ee2f1b88a1', '3b4dbfff-22ca-5168-b7d1-c69fc147499f', 20, '2026-11-09', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-09', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

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

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fde7fcac-09fa-5096-8fd9-443d87b757d8', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 1, '2026-10-13', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-13', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('42afabd9-81e9-509d-9a5c-1d4b0e0ff649', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 2, '2026-10-14', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-14', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('64ddc768-553e-54b0-bc2a-d9e066b0d89f', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 3, '2026-10-15', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-15', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cc72d44a-b743-53ec-9eb8-a97776dc313e', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 4, '2026-10-16', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-16', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e8d4f751-6fc3-5fc6-8450-9d6a84e3df02', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 5, '2026-10-19', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-19', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c18d45b7-bfe4-57c0-a067-d9df3eedc3de', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 6, '2026-10-20', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-20', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c7c7c236-f8ac-5deb-82cb-04d6b9eca84f', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 7, '2026-10-21', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-21', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1315a2da-2ba8-5c16-afb9-df7c35356a1a', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 8, '2026-10-22', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-22', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6c0c2d07-58ec-5610-8ca0-a470f7b30cb5', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 9, '2026-10-23', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-23', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d3eafc1b-1cf6-5dae-92f4-1c8010a241fc', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 10, '2026-10-26', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-26', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('39dc8193-ac35-5ac1-9076-9eb0c6734dfa', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 11, '2026-10-27', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-27', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1ae91c9a-3ef7-5ed6-b7f6-f15d6cf1b4af', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 12, '2026-10-28', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-28', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('32bc33c1-0dbd-5dc2-b835-e57d35ce22d8', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 13, '2026-10-29', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-29', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cc9158ff-1129-59f9-ad73-bb0184159083', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 14, '2026-10-30', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-30', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('54209e82-db72-5334-8994-90fe4c3b596d', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 15, '2026-11-02', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-02', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b98b5fb4-3f57-5e01-97e3-9491a4bf66fb', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 16, '2026-11-03', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-03', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a1f3ab5a-dac6-53d8-a7dd-034e6e3e4cb2', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 17, '2026-11-04', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-04', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7cdbc7c2-de7d-5c3a-9f8f-d52bab460ee3', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 18, '2026-11-05', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-05', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9e370936-7840-5b9b-b0da-eb119593a309', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 19, '2026-11-06', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-06', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e4ce9eb3-160a-5470-95d3-898aeb0b17e0', '691d3ba0-2d8e-5093-bcbb-44f6214fda49', 20, '2026-11-09', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-09', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

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

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b46a94a5-b9d5-53ac-9f89-78f0d5bc2c91', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 1, '2026-10-13', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-13', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7266e107-e6ed-5cd0-a92c-e4bdba743932', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 2, '2026-10-14', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-14', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e9529e9f-21d0-5d29-8fad-28e98f72684a', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 3, '2026-10-15', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-15', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5f83b84d-cf73-5b39-9c28-5d145717c75b', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 4, '2026-10-16', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-16', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4d60a7f7-b5e3-5dfb-8833-4e68788637fa', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 5, '2026-10-19', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-19', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('82f2a9f1-ec84-5848-8efe-876ab860d620', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 6, '2026-10-20', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-20', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d8990498-ff18-5228-95d2-b29f16df8b98', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 7, '2026-10-21', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-21', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fdeef6ee-e857-5405-9389-1bf1f26495b8', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 8, '2026-10-22', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-22', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c863e6c7-9c57-5b38-8453-dded5853d880', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 9, '2026-10-23', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-23', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9e18c04f-18a3-55bc-b143-73538116cbc3', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 10, '2026-10-26', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-26', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('203a3773-f9d8-5554-9280-8bc6a2877e80', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 11, '2026-10-27', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-27', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d058936b-8753-5d0d-9d1d-e0d3314c747a', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 12, '2026-10-28', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-28', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('414d3e36-a60b-58f6-be77-a6843fa4a7f8', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 13, '2026-10-29', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-29', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('becaca6e-f794-5df8-9c2a-7e1242b3ca18', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 14, '2026-10-30', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-30', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('94968134-2b82-5f5e-94a6-ee8a048f3587', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 15, '2026-11-02', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-02', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('71fa43f0-a253-5943-ba11-65d5630397ab', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 16, '2026-11-03', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-03', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fb06d9d8-1cb0-5895-a1c6-ce5e0dbf7cdc', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 17, '2026-11-04', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-04', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4ac0fa9e-3e33-5e71-9e8b-b924d5348ed4', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 18, '2026-11-05', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-05', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a4701591-39bb-5c9d-83cf-e506191a2f19', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 19, '2026-11-06', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-06', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0248df91-ed16-5b46-839d-b8683dcf9ba0', '11cc6a1c-8d91-532e-98fb-f37ac8078be0', 20, '2026-11-09', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-09', 800.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

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

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d486fb25-47c9-542c-9ea2-f954c5a335c3', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 1, '2026-08-11', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-11', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d909b8d3-bb6d-5f6f-8024-00398484dcc8', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 2, '2026-08-12', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-12', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c33d64bf-b8c8-50e2-a098-c2d1a17fe546', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 3, '2026-08-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-13', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('263fdc11-dbcb-5b7c-90bf-6e57dbb9be6f', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 4, '2026-08-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-14', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('17e3619a-8da0-5810-9b80-ff882bb05fca', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 5, '2026-08-17', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-17', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9fa236a5-31b1-594a-9130-05489ac5a42d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 6, '2026-08-18', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-18', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c3f951c7-a9a0-5482-860a-6cd01345bbda', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 7, '2026-08-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-19', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cb65d725-351b-540e-a9ef-17bc98ad5251', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 8, '2026-08-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-20', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('91867e66-93ee-538a-aec1-e590882d81b9', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 9, '2026-08-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-21', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('797e4dee-4339-5cfd-94da-a2ea0efaf3e1', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 10, '2026-08-24', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-24', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bd35a8cc-3352-5985-bd95-9a5e3b674c3e', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 11, '2026-08-25', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-25', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e6e18b25-f60d-567a-a9f9-3fc0dac3d281', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 12, '2026-08-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-26', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a97db454-8894-5755-9359-ae712dfc2020', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 13, '2026-08-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-27', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a8eeda4d-41ed-5c8c-86c1-b1232a282dc8', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 14, '2026-08-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-28', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f8cc0dc1-9f4d-55e4-9a3a-a068a8b34a8e', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 15, '2026-08-31', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-31', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ffcf1d2a-e9f4-5f00-a0a5-584a89fb9ffa', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 16, '2026-09-01', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-01', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('201a19f6-8246-594c-9b19-9517acfd604d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 17, '2026-09-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-02', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2b2e11ef-bd9c-556c-9991-cb6ac934b10d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 18, '2026-09-03', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-03', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cc8b8380-4454-5619-bbc5-be30eedacdf0', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 19, '2026-09-04', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-04', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d0f842fe-bcba-5adc-944a-96e372ed5733', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 20, '2026-09-07', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-07', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('86883473-cf8d-5261-a84a-a599a94f0615', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 21, '2026-09-08', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-08', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7d1abccc-dac1-5b2a-9c94-a8b053e8f8f2', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 22, '2026-09-09', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-09', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a46d9a8e-4581-5316-8009-5cc35bec3055', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 23, '2026-09-10', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-10', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6ca2bc24-3803-534d-9880-47d5c27220f1', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 24, '2026-09-11', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-11', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('895f6f01-9e66-51ce-bb10-1bc07ecee5dc', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 25, '2026-09-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-14', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('264f3200-a587-500d-b375-5fb99f8b8b5a', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 26, '2026-09-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-15', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('14bd5ee9-077e-5234-bc54-809b916a8098', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 27, '2026-09-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-16', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8f401917-14ce-58bb-91dc-83be67ababe2', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 28, '2026-09-17', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-17', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('36dc6320-5e89-5523-84d1-2c8607de390d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 29, '2026-09-18', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-18', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e8bd85cd-64ba-5d7a-a2eb-78040b5df0f2', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 30, '2026-09-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-21', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a2840eda-7c1c-5675-8504-3bfbb17f02bb', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 31, '2026-09-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-22', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('64b1d681-9d1f-524b-9372-d476bcae3d68', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 32, '2026-09-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-23', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('62839c82-a14f-574b-ae6f-8a8f675fc1bf', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 33, '2026-09-24', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-24', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5db55ddb-f5ac-5c31-86c6-dc9d7090b539', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 34, '2026-09-25', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-25', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4f538a1d-6abb-5950-a1a1-81a09df2673b', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 35, '2026-09-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-28', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b756ee7f-9e84-5130-a7f7-a8e1bb263ee6', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 36, '2026-09-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-29', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('137645de-c2a4-5feb-8025-af1dd0e2f186', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 37, '2026-09-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-30', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b96c0cbd-59ff-58b4-bbf6-3bc1ccbf5b97', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 38, '2026-10-01', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-01', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('40d1aba5-e365-5ade-acc7-16164e06c71d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 39, '2026-10-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-02', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3b9cb90f-2cc0-5e38-9bbc-6c103a58c22d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 40, '2026-10-05', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-05', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1b3ffeaa-5962-51fb-9bf8-19ee8f9ad839', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 41, '2026-10-06', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-06', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eb8ab406-a0ff-55b5-a994-06eddbf9ef6d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 42, '2026-10-07', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-07', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('81104a19-4f7b-5dab-a6ae-df1216cff6b5', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 43, '2026-10-08', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-08', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('36803020-0fe5-51d8-b910-a5b16d459377', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 44, '2026-10-09', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-09', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('80868b14-b397-54aa-a821-586d16091c19', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 45, '2026-10-12', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-12', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('65f72a96-c5cf-508e-8d1d-76473277d628', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 46, '2026-10-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-13', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('58caa4e2-d81b-579c-be88-46229d5846b5', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 47, '2026-10-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-14', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('af7ae6d2-6705-52ae-8597-f8babf4ffe77', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 48, '2026-10-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-15', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1991cdb3-e385-5814-9770-9f65371f4728', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 49, '2026-10-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-16', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('14e3c47c-a565-5d4f-8819-c0203b1bd71a', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 50, '2026-10-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-19', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7ba8a04a-c3aa-59bf-a5ae-f083305ec2de', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 51, '2026-10-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-20', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0156a8e6-e2bd-5197-940f-65126b7ecf40', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 52, '2026-10-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-21', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('894dc3dd-f438-50f1-963b-da0725b6c3a5', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 53, '2026-10-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-22', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0bb78e22-4de9-5f64-b442-6580c370803a', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 54, '2026-10-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-23', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('52da10dc-0fd9-5336-8b75-0a16de0c9e4f', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 55, '2026-10-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-26', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7011f564-3262-5ed5-bcf9-b0851240548f', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 56, '2026-10-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-27', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('820a75a3-f1aa-59d6-bae5-40e5399062f2', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 57, '2026-10-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-28', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('60903d90-62d3-5a0b-a0f3-8374c2a517ed', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 58, '2026-10-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-29', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d32d441d-0845-535a-a4aa-83dcb8273a2f', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 59, '2026-10-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-30', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8f577396-8042-5604-b4a9-5562738ccb2d', 'fa2b1929-e324-5ce1-ae67-8a3296234213', 60, '2026-11-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-02', 1650.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5b41e60f-9818-594f-a7bd-3d29e91ef18f', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 1, '2026-10-13', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-13', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ea9d0860-3f1b-5b66-b180-6a3e38cba875', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 2, '2026-10-14', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-14', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53d55902-1a52-5ea2-9923-99e436a6a24e', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 3, '2026-10-15', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-15', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b0d94b31-820b-5117-8194-4a8fed4b3d81', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 4, '2026-10-16', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-16', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('228b7ad3-b1e7-5b05-b22e-725b93d0b5cd', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 5, '2026-10-19', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-19', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c9c3d8c5-06fb-5d8b-9499-a075693f5839', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 6, '2026-10-20', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-20', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6537c368-739e-54a6-9d06-04a43faad36b', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 7, '2026-10-21', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-21', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e772f37c-4c03-5749-ae8d-173de8b635b2', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 8, '2026-10-22', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-22', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8504dc5c-c0be-5d82-9456-bfbb43c6f1d9', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 9, '2026-10-23', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-23', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b3bef3b9-8314-57ff-8b52-8cfb62bdd649', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 10, '2026-10-26', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-26', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1a70bc07-307d-515a-9227-14d0e83adbbf', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 11, '2026-10-27', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-27', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3716eb38-e119-5c13-8126-99a41e5b5f17', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 12, '2026-10-28', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-28', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('37e84111-8fdd-5ba8-bdb6-954dc8880651', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 13, '2026-10-29', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-29', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('14d3261b-ebc5-5666-a1d6-5fd08087f1ed', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 14, '2026-10-30', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-30', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2e618503-f5fc-5326-9a8e-0ba511510a05', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 15, '2026-11-02', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-02', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cee4fc30-a823-583c-9db3-4fcc01642173', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 16, '2026-11-03', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-03', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('94c47bfb-cfb1-506d-9ad2-cb047e2d8946', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 17, '2026-11-04', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-04', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('49da808f-32fc-5541-9653-10f400902f65', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 18, '2026-11-05', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-05', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3c04d735-edf7-54f1-ab8e-7c33ad52688a', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 19, '2026-11-06', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-06', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b8c88486-ff1a-5801-a695-99f0ce1b1a84', 'bc3a1fc9-fa76-5760-aa82-87c51f26b081', 20, '2026-11-09', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-09', 2500.0, 1, NOW())
                ON CONFLICT (id) DO UPDATE SET
                    status = EXCLUDED.status,
                    paid_date = EXCLUDED.paid_date,
                    paid_amount = EXCLUDED.paid_amount;

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
