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
