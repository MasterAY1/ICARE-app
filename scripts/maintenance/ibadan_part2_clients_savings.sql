INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('d5e349e1-5cc9-5ac2-a7c5-028d225029be', 'Adebayo Ojo', '08031110001', 'Ibadan, Oyo State', 'General Commerce', 'IBA-01-001', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('a937e8bc-8442-5889-8640-3b57d42af7a3', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('48ec0e0f-112f-5cd8-9a36-7f328148b384', '2026-10-01', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('887086db-2676-548e-970f-b9347386fd13', 'Kudirat Salami', '08031110002', 'Ibadan, Oyo State', 'General Commerce', 'IBA-01-002', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('0f9cc539-cbba-5ecc-994c-ce3a5527abb1', '887086db-2676-548e-970f-b9347386fd13', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('ea49e2d1-ad64-59c8-943b-5a2f0245718c', '2026-10-01', '887086db-2676-548e-970f-b9347386fd13', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 8500.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('e42120d0-5d0f-5ac6-bcde-794078ba9032', 'Taofeek Sanusi', '08031110003', 'Ibadan, Oyo State', 'General Commerce', 'IBA-01-003', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('3e61b015-23a0-5047-a62c-2d8302823f1a', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('0f33ae4e-e7de-5ea0-9030-a76750392ef7', '2026-10-01', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 12000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('a8215623-24c1-5b85-96d2-6f823bc98cc1', 'Morufat Balogun', '08031110004', 'Ibadan, Oyo State', 'General Commerce', 'IBA-01-004', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'Completed', '11111111-1111-1111-1111-111111110004', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('6dddeb7f-7cd9-5b46-89f3-2d4ff21b5158', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('1d7f2431-925d-55fa-9743-3c4a1b7a8cec', '2026-10-01', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 22000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('df441b51-862c-5fe3-ab37-565626bac0c8', 'Zainab Jimoh', '08031110005', 'Ibadan, Oyo State', 'General Commerce', 'IBA-01-005', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'Registered', '11111111-1111-1111-1111-111111110001', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('a32cebcb-0932-509f-b601-04156679cd8c', 'df441b51-862c-5fe3-ab37-565626bac0c8', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('472fbf2a-d973-53c3-834f-9e3d17e50db5', '2026-10-01', 'df441b51-862c-5fe3-ab37-565626bac0c8', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 5000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('3b077386-a0d5-5085-bdbf-1def58badad4', 'Rasheedat Bello', '08031110006', 'Ibadan, Oyo State', 'General Commerce', 'IBA-02-001', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('78605d4b-913f-56c8-900b-a98117edce33', '3b077386-a0d5-5085-bdbf-1def58badad4', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('acae758d-8de6-5911-ba03-bcc78d041496', '2026-10-01', '3b077386-a0d5-5085-bdbf-1def58badad4', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 18000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 'Ganiyu Ajayi', '08031110007', 'Ibadan, Oyo State', 'General Commerce', 'IBA-02-002', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('f58f1980-b8a0-5f71-a675-3c45fc7152d8', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('48b5630c-56b3-5202-ad56-84d3b9f3cfb3', '2026-10-01', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 9000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('dfb85fdf-1b68-539a-982c-865018dd4fb6', 'Bolanle Shittu', '08031110008', 'Ibadan, Oyo State', 'General Commerce', 'IBA-02-003', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'Defaulter', '11111111-1111-1111-1111-111111110009', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('66976eb1-37d5-5f53-b4be-4324b9515ae4', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('1390fce6-a07c-58e8-a6fd-9496227dd11d', '2026-10-01', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 3500.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('05fbc6ae-6b31-5de1-91db-2ce0e3160139', 'Sulaimon Adeleke', '08031110009', 'Ibadan, Oyo State', 'General Commerce', 'IBA-02-004', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'Inactive (Savings Only)', '11111111-1111-1111-1111-111111110006', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('da51545d-09d2-5f07-a91e-ccacde83c3c9', '05fbc6ae-6b31-5de1-91db-2ce0e3160139', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('8ce6efa5-5085-50ba-8055-a6b92befca0c', '2026-10-01', '05fbc6ae-6b31-5de1-91db-2ce0e3160139', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 35000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO withdrawal_requests (id, savings_type, operation_type, client_id, client_name, group_name, loan_id, branch_id, requested_by, amount, reference, remarks, payout_method, status, operational_date, created_at)
            VALUES ('c845bc3f-1860-59f4-aa49-82e90eff56f7', 'Individual', 'Withdrawal', '05fbc6ae-6b31-5de1-91db-2ce0e3160139', 'Sulaimon Adeleke', 'Ibadan Dugbe Daily Artisans Group', NULL, '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'IBA_CO1', 5000.00, 'WTH-IBA-001', 'Emergency medical expense request', 'Cash', 'Pending', '2026-11-06', NOW())
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('730e9395-6b7f-553d-9b1a-35b6349c1fee', 'Funmilayo Lawal', '08031110010', 'Ibadan, Oyo State', 'General Commerce', 'IBA-03-001', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('20111b9f-cc09-569d-924a-d0b71be32b2b', '730e9395-6b7f-553d-9b1a-35b6349c1fee', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('bb24f366-539b-5573-99d2-a1b5c6e000cf', '2026-10-01', '730e9395-6b7f-553d-9b1a-35b6349c1fee', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 14000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('a5800f83-0be5-5dc9-8608-f799cf95820b', 'Musibau Alao', '08031110011', 'Ibadan, Oyo State', 'General Commerce', 'IBA-03-002', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('cbaa9c8d-90de-51e2-82e3-a08b1f485d93', 'a5800f83-0be5-5dc9-8608-f799cf95820b', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('34c9ac96-7053-54f7-9924-3b175457ac3a', '2026-10-01', 'a5800f83-0be5-5dc9-8608-f799cf95820b', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 11000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('be500c02-686f-5de5-aa3c-9494991fbb57', 'Bisi Adeleke', '08031110012', 'Ibadan, Oyo State', 'General Commerce', 'IBA-03-003', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('2f169deb-fb60-57ff-acaa-947e99f29dd2', 'be500c02-686f-5de5-aa3c-9494991fbb57', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('acc1c87d-aef2-5a67-9a3b-8838688c95c4', '2026-10-01', 'be500c02-686f-5de5-aa3c-9494991fbb57', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 16500.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('ac597b4b-3e72-5769-ae2c-31c9c4c31850', 'Idris Oladipo', '08031110013', 'Ibadan, Oyo State', 'General Commerce', 'IBA-03-004', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Completed', '11111111-1111-1111-1111-111111110004', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('0c2fa9b7-5597-5d93-a6c4-358ad9baec95', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('605fa6aa-f129-5a7a-940e-ed9d366710d2', '2026-10-01', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 28000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('06a30779-7559-5d85-b6b2-79d33e18db06', 'Kehinde Ogundele', '08031110014', 'Ibadan, Oyo State', 'General Commerce', 'IBA-04-001', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('209437e9-c8ce-5c0b-8190-67a9600c8745', '06a30779-7559-5d85-b6b2-79d33e18db06', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('68f558a5-59d9-5a43-8622-4005c678b258', '2026-10-01', '06a30779-7559-5d85-b6b2-79d33e18db06', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 19000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('f98fecb1-40fc-5c7d-a3c7-7bb4d9bd983f', 'Taiwo Ogundele', '08031110015', 'Ibadan, Oyo State', 'General Commerce', 'IBA-04-002', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('cbe63c4e-5b66-576f-8e22-3b89dc71b0ee', 'f98fecb1-40fc-5c7d-a3c7-7bb4d9bd983f', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('30c448e2-0cd6-5dc3-a12f-a705c5c0c500', '2026-10-01', 'f98fecb1-40fc-5c7d-a3c7-7bb4d9bd983f', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 19000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('64fd175b-a545-5b96-86de-818e2be58ad3', 'Khadijat Mustapha', '08031110016', 'Ibadan, Oyo State', 'General Commerce', 'IBA-04-003', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Registered', '11111111-1111-1111-1111-111111110001', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('12215ee1-e445-5cdc-8a3d-28964aa2555e', '64fd175b-a545-5b96-86de-818e2be58ad3', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('93bac2ca-5f1b-5b3e-a1d9-c3ed20e6e81f', '2026-10-01', '64fd175b-a545-5b96-86de-818e2be58ad3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 6000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('3fd0f263-f637-5ff2-9277-061272d1ad70', 'Shukurat Babalola', '08031110017', 'Ibadan, Oyo State', 'General Commerce', 'IBA-04-004', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Pending Loan', '11111111-1111-1111-1111-111111110002', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('e1738431-0a8f-54f4-b5d6-66cead15dfad', '3fd0f263-f637-5ff2-9277-061272d1ad70', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('bcda8eeb-5af7-50f1-8f08-9a652efc69ea', '2026-10-01', '3fd0f263-f637-5ff2-9277-061272d1ad70', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 10000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('8e383916-78ef-5914-b578-11b7e05dbde2', 'Olumide Bakare', '08031110018', 'Ibadan, Oyo State', 'General Commerce', 'IBA-05-001', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('b942e2ac-e2cf-5502-b3fb-7737d1a1e105', '8e383916-78ef-5914-b578-11b7e05dbde2', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('e2e28e88-af8e-5d59-96aa-caf1ae02bd55', '2026-10-01', '8e383916-78ef-5914-b578-11b7e05dbde2', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 45000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('2e53acb4-886b-5e6c-964a-95cbefc587a2', 'Folake Adeyemi', '08031110019', 'Ibadan, Oyo State', 'General Commerce', 'IBA-05-002', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('a7a4b791-debd-5c50-9bca-92ff6017d662', '2e53acb4-886b-5e6c-964a-95cbefc587a2', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('53866333-2ea5-5d0f-9f19-42766738e7e5', '2026-10-01', '2e53acb4-886b-5e6c-964a-95cbefc587a2', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 50000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('01cf1e2e-c59e-5e52-bb5b-7e5c3e003514', 'Babatunde Awolowo', '08031110020', 'Ibadan, Oyo State', 'General Commerce', 'IBA-05-003', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Inactive (Savings Only)', '11111111-1111-1111-1111-111111110006', NOW(), 1, false)
        ON CONFLICT (client_id) DO UPDATE SET
            status = EXCLUDED.status,
            status_id = EXCLUDED.status_id;

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('2ae80837-fdec-54a4-b834-22344485b1d7', '01cf1e2e-c59e-5e52-bb5b-7e5c3e003514', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1)
        ON CONFLICT (membership_id) DO NOTHING;

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('4804ea83-31ba-5080-a23b-c0d4ae78c44a', '2026-10-01', '01cf1e2e-c59e-5e52-bb5b-7e5c3e003514', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 60000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('2ad9ade2-9b74-5ecb-98cf-e7e0ebed56b2', '2026-10-01', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN')
        ON CONFLICT (id) DO NOTHING;

INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('64093283-4722-5674-86d6-fa77cf4d7c1d', '2026-10-01', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN')
        ON CONFLICT (id) DO NOTHING;

INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('fc096834-81f1-538d-a056-b18bcdb457d7', '2026-10-01', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN')
        ON CONFLICT (id) DO NOTHING;

INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('cd8efceb-a77c-58e3-96e3-3fed666104ad', '2026-10-01', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN')
        ON CONFLICT (id) DO NOTHING;

INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('3a670e1c-2069-589d-9329-66e76d008870', '2026-10-01', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN')
        ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('4be9a0e2-1fa4-5295-a49a-51655d0a076c', '2026-10-01', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('74529cb1-f13f-5730-ae68-715b92802a79', '2026-10-01', '887086db-2676-548e-970f-b9347386fd13', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('8e1f1a0d-6e1b-5f51-9279-788a3c5d4dfd', '2026-10-01', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('d59b25ab-9a04-5c43-9cc6-fa68179ed4f2', '2026-10-01', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('a83c6fb5-efa8-58cd-afeb-5efa3dd20c41', '2026-10-01', '3b077386-a0d5-5085-bdbf-1def58badad4', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('b3b2f3d5-d34c-557f-ba4c-3a3e12372166', '2026-10-01', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('e37c2746-8561-541d-aeb7-ac60dc99e385', '2026-10-01', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('40c1fbf2-c1e5-567f-9532-cbf583e401c4', '2026-10-01', '730e9395-6b7f-553d-9b1a-35b6349c1fee', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('902abd00-63f0-5500-a8bb-513a644a1071', '2026-10-01', 'a5800f83-0be5-5dc9-8608-f799cf95820b', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('425988e8-8214-5f96-a412-71b4b8393e72', '2026-10-01', 'be500c02-686f-5de5-aa3c-9494991fbb57', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('e75ffdf9-87c9-5c66-b204-bfa58bcb10d7', '2026-10-01', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('a123155f-d093-5999-a38f-c3e9ab0479f6', '2026-10-01', '06a30779-7559-5d85-b6b2-79d33e18db06', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('9ee3771c-ddf9-5b00-975e-8a3e583334d8', '2026-10-01', 'f98fecb1-40fc-5c7d-a3c7-7bb4d9bd983f', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('4700bd6b-7c11-5aa0-8f87-ddc2cbfe83e6', '2026-10-01', '3fd0f263-f637-5ff2-9277-061272d1ad70', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('9276a5fc-5a9d-5ea1-9431-cd1d06d47534', '2026-10-01', '8e383916-78ef-5914-b578-11b7e05dbde2', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('4f424d12-59da-5dfa-9b95-b4ef5a9697af', '2026-10-01', '2e53acb4-886b-5e6c-964a-95cbefc587a2', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN')
            ON CONFLICT (id) DO NOTHING;