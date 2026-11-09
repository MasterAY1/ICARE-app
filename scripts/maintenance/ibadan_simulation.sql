INSERT INTO app_users (id, username, password_hash, full_name, branch_id, is_active, is_deleted, created_at, updated_at, extra_fields)
    VALUES 
        ('7ca80001-9077-4bef-8cf3-78cf26c30705', 'BM_Ibadan', '$2b$12$YHMh.p8FjAiY6tp86aFAYun2GaY.0pfCh7qKbvh5TuHuuWA6LF7cK', 'Ibrahim Babatunde', '7ca8250a-9077-4bef-8cf3-78cf26c30705', true, false, NOW(), NOW(), '{"allowed_products": ["Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W", "Monthly 3M", "Monthly 6M"], "must_change_password": false, "mfa_enabled": false}'::jsonb),
        ('7ca80002-9077-4bef-8cf3-78cf26c30705', 'IBA_CO1', '$2b$12$YHMh.p8FjAiY6tp86aFAYun2GaY.0pfCh7qKbvh5TuHuuWA6LF7cK', 'Kazeem Adeleke (Daily)', '7ca8250a-9077-4bef-8cf3-78cf26c30705', true, false, NOW(), NOW(), '{"allowed_products": ["Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W", "Monthly 3M", "Monthly 6M"], "must_change_password": false, "mfa_enabled": false}'::jsonb),
        ('7ca80003-9077-4bef-8cf3-78cf26c30705', 'IBA_CO2', '$2b$12$YHMh.p8FjAiY6tp86aFAYun2GaY.0pfCh7qKbvh5TuHuuWA6LF7cK', 'Folashade Alabi (Weekly/Monthly)', '7ca8250a-9077-4bef-8cf3-78cf26c30705', true, false, NOW(), NOW(), '{"allowed_products": ["Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W", "Monthly 3M", "Monthly 6M"], "must_change_password": false, "mfa_enabled": false}'::jsonb)
    ON CONFLICT (id) DO UPDATE SET 
        password_hash = EXCLUDED.password_hash,
        full_name = EXCLUDED.full_name,
        branch_id = EXCLUDED.branch_id,
        is_active = true,
        extra_fields = EXCLUDED.extra_fields;

DELETE FROM user_roles WHERE user_id IN ('7ca80001-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705');
    INSERT INTO user_roles (user_id, role_id)
    VALUES 
        ('7ca80001-9077-4bef-8cf3-78cf26c30705', '3ea1496a-0498-4a1d-872a-1c7ecdf77b06'),
        ('7ca80002-9077-4bef-8cf3-78cf26c30705', 'bd8790ee-c0eb-485a-8b6a-93f54519965d'),
        ('7ca80003-9077-4bef-8cf3-78cf26c30705', 'bd8790ee-c0eb-485a-8b6a-93f54519965d');

INSERT INTO area_manager_assignments (am_id, branch_id)
    VALUES ('e6a77cdb-6012-4506-8240-7e46e81d954d', '7ca8250a-9077-4bef-8cf3-78cf26c30705')
    ON CONFLICT DO NOTHING;

DELETE FROM master_cashbook WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM co_cashbooks WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM withdrawal_requests WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM repayments WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM loan_schedule WHERE loan_id IN (SELECT loan_id FROM loans WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705');
    DELETE FROM loan_payoff_excess_records WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM loans WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM individual_savings WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM group_savings WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM laps_savings WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM client_memberships WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM clients WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';
    DELETE FROM financial_ledger_entries WHERE branch_id = '7ca8250a-9077-4bef-8cf3-78cf26c30705';

INSERT INTO groups (group_id, name, meeting_day, branch_id, officer_id, status, group_number, current_member_sequence, leader_name, created_at, updated_at, version, is_deleted)
        VALUES ('7ca80011-9077-4bef-8cf3-78cf26c30705', 'Ibadan Bodija Daily Market Group', 'Daily', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'Active', '1', 5, 'Adebayo Ojo', NOW(), NOW(), 1, false)
        ON CONFLICT (group_id) DO UPDATE SET
            name = EXCLUDED.name,
            meeting_day = EXCLUDED.meeting_day,
            officer_id = EXCLUDED.officer_id,
            status = 'Active';

INSERT INTO groups (group_id, name, meeting_day, branch_id, officer_id, status, group_number, current_member_sequence, leader_name, created_at, updated_at, version, is_deleted)
        VALUES ('7ca80012-9077-4bef-8cf3-78cf26c30705', 'Ibadan Dugbe Daily Artisans Group', 'Daily', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'Active', '2', 5, 'Rasheedat Bello', NOW(), NOW(), 1, false)
        ON CONFLICT (group_id) DO UPDATE SET
            name = EXCLUDED.name,
            meeting_day = EXCLUDED.meeting_day,
            officer_id = EXCLUDED.officer_id,
            status = 'Active';

INSERT INTO groups (group_id, name, meeting_day, branch_id, officer_id, status, group_number, current_member_sequence, leader_name, created_at, updated_at, version, is_deleted)
        VALUES ('7ca80013-9077-4bef-8cf3-78cf26c30705', 'Ibadan Mokola Weekly Traders', 'Tuesday', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Active', '3', 5, 'Funmilayo Lawal', NOW(), NOW(), 1, false)
        ON CONFLICT (group_id) DO UPDATE SET
            name = EXCLUDED.name,
            meeting_day = EXCLUDED.meeting_day,
            officer_id = EXCLUDED.officer_id,
            status = 'Active';

INSERT INTO groups (group_id, name, meeting_day, branch_id, officer_id, status, group_number, current_member_sequence, leader_name, created_at, updated_at, version, is_deleted)
        VALUES ('7ca80014-9077-4bef-8cf3-78cf26c30705', 'Ibadan Challenge Weekly Unity', 'Thursday', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Active', '4', 5, 'Kehinde Ogundele', NOW(), NOW(), 1, false)
        ON CONFLICT (group_id) DO UPDATE SET
            name = EXCLUDED.name,
            meeting_day = EXCLUDED.meeting_day,
            officer_id = EXCLUDED.officer_id,
            status = 'Active';

INSERT INTO groups (group_id, name, meeting_day, branch_id, officer_id, status, group_number, current_member_sequence, leader_name, created_at, updated_at, version, is_deleted)
        VALUES ('7ca80015-9077-4bef-8cf3-78cf26c30705', 'Ibadan Ring Road Monthly Enterprise', 'Monthly', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Active', '5', 5, 'Olumide Bakare', NOW(), NOW(), 1, false)
        ON CONFLICT (group_id) DO UPDATE SET
            name = EXCLUDED.name,
            meeting_day = EXCLUDED.meeting_day,
            officer_id = EXCLUDED.officer_id,
            status = 'Active';

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('d1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 'Adebayo Ojo', '08031110001', 'Ibadan, Oyo State', 'General Commerce', 'IBA-01-001', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('d657f140-cb4a-4954-a833-3d83247a73da', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('62ecda7d-8b9a-478e-9567-d3a711b32dc4', '2026-10-01', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('dede7647-257b-43a3-a160-b37f44b9e12c', 'Kudirat Salami', '08031110002', 'Ibadan, Oyo State', 'General Commerce', 'IBA-01-002', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('8f6101a7-9d12-4319-90ac-076cf1f8a115', 'dede7647-257b-43a3-a160-b37f44b9e12c', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('267c1201-af12-4cc7-8c24-d9357617c64b', '2026-10-01', 'dede7647-257b-43a3-a160-b37f44b9e12c', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 8500.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('d073e519-1c98-49a6-9e3c-820d2df7f728', 'Taofeek Sanusi', '08031110003', 'Ibadan, Oyo State', 'General Commerce', 'IBA-01-003', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('7bee5bff-0db3-4fa6-928e-84cc3a64603a', 'd073e519-1c98-49a6-9e3c-820d2df7f728', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('97018822-0ac1-486f-a28e-d911de42133f', '2026-10-01', 'd073e519-1c98-49a6-9e3c-820d2df7f728', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 12000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('05476019-cadc-4307-8a18-2eadb5439239', 'Morufat Balogun', '08031110004', 'Ibadan, Oyo State', 'General Commerce', 'IBA-01-004', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'Completed', '11111111-1111-1111-1111-111111110004', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('b951f452-792a-49cb-8f20-8f338a5c885e', '05476019-cadc-4307-8a18-2eadb5439239', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('abb942c0-3488-4750-b4fc-c0dda2b825f9', '2026-10-01', '05476019-cadc-4307-8a18-2eadb5439239', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 22000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('af50bf5e-9314-4d5e-8e58-a3669019a8c5', 'Zainab Jimoh', '08031110005', 'Ibadan, Oyo State', 'General Commerce', 'IBA-01-005', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'Registered', '11111111-1111-1111-1111-111111110001', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('6943a928-7b24-42e4-a023-3f1cd9df7b61', 'af50bf5e-9314-4d5e-8e58-a3669019a8c5', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('16a80bfe-7a5c-48a3-bfe5-ec0e6edf0caf', '2026-10-01', 'af50bf5e-9314-4d5e-8e58-a3669019a8c5', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 5000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('f90c5e3b-cd87-41a7-8676-8749861fb0aa', 'Rasheedat Bello', '08031110006', 'Ibadan, Oyo State', 'General Commerce', 'IBA-02-001', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('6e98bd64-c283-4bc2-a43b-35c82fa735f7', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('5bc70f2b-7b71-4e76-ba1f-ae793d92d682', '2026-10-01', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 18000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('c3c95953-af7a-480a-93ef-f488d7b2dba6', 'Ganiyu Ajayi', '08031110007', 'Ibadan, Oyo State', 'General Commerce', 'IBA-02-002', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('aa761331-d067-4de3-9d10-c9115c9d1ed3', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('21b69eb4-0efe-4c76-b55e-4cfc2e1076fc', '2026-10-01', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 9000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('8ee891ff-b77c-4068-9d73-5528259e485f', 'Bolanle Shittu', '08031110008', 'Ibadan, Oyo State', 'General Commerce', 'IBA-02-003', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'Defaulter', '11111111-1111-1111-1111-111111110009', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('ed67337a-ea3b-41b8-88bf-4da935e653a8', '8ee891ff-b77c-4068-9d73-5528259e485f', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('8a943c49-9748-4887-8712-de8980ca6134', '2026-10-01', '8ee891ff-b77c-4068-9d73-5528259e485f', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 3500.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('d289e5b1-23cb-4d46-a90d-fa1108472715', 'Sulaimon Adeleke', '08031110009', 'Ibadan, Oyo State', 'General Commerce', 'IBA-02-004', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 'Inactive (Savings Only)', '11111111-1111-1111-1111-111111110006', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('d36d6292-1947-41be-ba34-34664cc35df7', 'd289e5b1-23cb-4d46-a90d-fa1108472715', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('ef63aa65-c7f3-480a-9d76-36302b107923', '2026-10-01', 'd289e5b1-23cb-4d46-a90d-fa1108472715', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 35000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO withdrawal_requests (id, savings_type, operation_type, client_id, client_name, group_name, loan_id, branch_id, requested_by, amount, reference, remarks, payout_method, status, operational_date, created_at)
            VALUES ('cb5cb7e2-c3ac-459b-b36a-ce60245d996a', 'Individual', 'Withdrawal', 'd289e5b1-23cb-4d46-a90d-fa1108472715', 'Sulaimon Adeleke', 'Ibadan Dugbe Daily Artisans Group', NULL, '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'IBA_CO1', 5000.00, 'WTH-IBA-001', 'Emergency medical expense request', 'Cash', 'Pending', '2026-11-06', NOW());

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('746b4c5d-8760-4a6f-9284-d3c584d4146e', 'Funmilayo Lawal', '08031110010', 'Ibadan, Oyo State', 'General Commerce', 'IBA-03-001', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('0e8e5f6e-2329-4fef-82c8-b5dd64ad3566', '746b4c5d-8760-4a6f-9284-d3c584d4146e', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('df888382-c2fb-4796-9b70-77f68a3ef3a6', '2026-10-01', '746b4c5d-8760-4a6f-9284-d3c584d4146e', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 14000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('53bed5f0-0a20-432e-9f88-bb2ebbdb00f4', 'Musibau Alao', '08031110011', 'Ibadan, Oyo State', 'General Commerce', 'IBA-03-002', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('1252ec6d-32ca-4178-8bda-e684bc55179c', '53bed5f0-0a20-432e-9f88-bb2ebbdb00f4', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('a42cdbc0-785b-4be5-a728-ea530f15b04b', '2026-10-01', '53bed5f0-0a20-432e-9f88-bb2ebbdb00f4', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 11000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('0a969dba-e37a-453a-a272-8d50dd5004f2', 'Bisi Adeleke', '08031110012', 'Ibadan, Oyo State', 'General Commerce', 'IBA-03-003', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('dacd806d-8cba-4ea0-99f7-8a0fdf59057f', '0a969dba-e37a-453a-a272-8d50dd5004f2', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('db5d2218-488d-42f5-9dfe-530c77fc3949', '2026-10-01', '0a969dba-e37a-453a-a272-8d50dd5004f2', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 16500.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 'Idris Oladipo', '08031110013', 'Ibadan, Oyo State', 'General Commerce', 'IBA-03-004', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Completed', '11111111-1111-1111-1111-111111110004', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('9e6014f2-7cff-4185-9ece-04de4773fb5e', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('9bd2003a-db53-403e-8f16-3d953ae2324b', '2026-10-01', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 28000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('184dac24-2290-47ba-8b75-23df8d1176ce', 'Kehinde Ogundele', '08031110014', 'Ibadan, Oyo State', 'General Commerce', 'IBA-04-001', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('7fece014-386a-46a6-864a-7038a6385661', '184dac24-2290-47ba-8b75-23df8d1176ce', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('89627f29-89e9-47aa-a881-e8055871c1d7', '2026-10-01', '184dac24-2290-47ba-8b75-23df8d1176ce', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 19000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('3cf908c1-bfaa-4846-910e-35ab9d813b03', 'Taiwo Ogundele', '08031110015', 'Ibadan, Oyo State', 'General Commerce', 'IBA-04-002', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('7594dbca-96e3-4d19-85cf-4c4072041e46', '3cf908c1-bfaa-4846-910e-35ab9d813b03', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('afe7666c-9091-4ece-a2d4-08f67546bde2', '2026-10-01', '3cf908c1-bfaa-4846-910e-35ab9d813b03', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 19000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('cfdb6e59-421f-4cb6-a59c-8d7c34ac9b97', 'Khadijat Mustapha', '08031110016', 'Ibadan, Oyo State', 'General Commerce', 'IBA-04-003', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Registered', '11111111-1111-1111-1111-111111110001', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('7d878fd5-ba00-4926-a8be-d10a2af1c143', 'cfdb6e59-421f-4cb6-a59c-8d7c34ac9b97', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('cf331258-f3e0-4355-8f40-24084b346a55', '2026-10-01', 'cfdb6e59-421f-4cb6-a59c-8d7c34ac9b97', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 6000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('57f0e54a-b385-4f51-81d5-901201891974', 'Shukurat Babalola', '08031110017', 'Ibadan, Oyo State', 'General Commerce', 'IBA-04-004', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Pending Loan', '11111111-1111-1111-1111-111111110002', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('1139cf0a-4b59-4254-95ee-c3e3ab8963bf', '57f0e54a-b385-4f51-81d5-901201891974', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('a45b52fb-2133-4f40-a137-12ccfbfe9a5a', '2026-10-01', '57f0e54a-b385-4f51-81d5-901201891974', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 10000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('5932eaff-c7a6-4175-a001-c75eea53b5d0', 'Olumide Bakare', '08031110018', 'Ibadan, Oyo State', 'General Commerce', 'IBA-05-001', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('f1a62832-668a-4905-bc95-c1fa1fd05856', '5932eaff-c7a6-4175-a001-c75eea53b5d0', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('41244147-e7e6-4c8f-8ac7-f14aa081fbf9', '2026-10-01', '5932eaff-c7a6-4175-a001-c75eea53b5d0', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 45000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('58a54856-a5e4-4814-a743-d780063290d8', 'Folake Adeyemi', '08031110019', 'Ibadan, Oyo State', 'General Commerce', 'IBA-05-002', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'On Loan', '11111111-1111-1111-1111-111111110003', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('84fa46ab-5722-4183-b6b2-dcd1a235a432', '58a54856-a5e4-4814-a743-d780063290d8', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('4b103620-3398-4cc4-ad0d-1a2d9114fb98', '2026-10-01', '58a54856-a5e4-4814-a743-d780063290d8', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 50000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO clients (client_id, name, phone, address, business_type, client_code, registration_date, branch_id, group_id, officer_id, status, status_id, status_changed_at, version, is_deleted)
        VALUES ('f2faf37a-7b91-46ba-94eb-318dbfb38121', 'Babatunde Awolowo', '08031110020', 'Ibadan, Oyo State', 'General Commerce', 'IBA-05-003', '2026-08-01', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 'Inactive (Savings Only)', '11111111-1111-1111-1111-111111110006', NOW(), 1, false);

INSERT INTO client_memberships (membership_id, client_id, group_id, branch_id, officer_id, start_date, created_at, version)
        VALUES ('c4299f52-4d88-4a2f-a904-cfe1cd7c3c7f', 'f2faf37a-7b91-46ba-94eb-318dbfb38121', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-01', NOW(), 1);

INSERT INTO individual_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('5a208043-8f6f-4ff0-b51e-204bb71a5cc8', '2026-10-01', 'f2faf37a-7b91-46ba-94eb-318dbfb38121', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 60000.0, 0.0, 'INIT-DEP', 'Initial savings accumulation', NOW(), 1, 'NGN');

INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('f99ba85e-ce28-4e49-9fbe-2a21ca6cadbb', '2026-10-01', '7ca80011-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN');

INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('eb41f04d-9f17-4ba9-bb9c-4f8500e9a08b', '2026-10-01', '7ca80012-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN');

INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('07d3f319-1819-4c7a-ab2f-a271c3c11d4b', '2026-10-01', '7ca80013-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN');

INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('2cb081dd-bf60-42cc-a134-f2421332fdce', '2026-10-01', '7ca80014-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN');

INSERT INTO group_savings (id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
        VALUES ('e1e58b25-b657-497a-9eda-76fd5ab0ecf1', '2026-10-01', '7ca80015-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 15000.0, 0.0, 'GRP-DEP', 'Group joint contribution', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('41c2d9ea-2318-49b5-8fea-f87a6c6997b4', '2026-10-01', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('4325fa04-1da8-478a-86c7-f9cbaec6605f', '2026-10-01', 'dede7647-257b-43a3-a160-b37f44b9e12c', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('2b45d1f9-4bf5-4db0-b9f0-64cd4b9b212c', '2026-10-01', 'd073e519-1c98-49a6-9e3c-820d2df7f728', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('e79c99b9-e884-4efe-8d87-b6c3fa36e3fc', '2026-10-01', '05476019-cadc-4307-8a18-2eadb5439239', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('f2b00303-1350-468f-9d2c-0375da7930bd', '2026-10-01', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('c7aa16d2-72ee-40d9-b55b-fd6430785b21', '2026-10-01', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('84ffb4b3-d298-4580-bee8-86f467cbb828', '2026-10-01', '8ee891ff-b77c-4068-9d73-5528259e485f', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('ac6b8c85-5d9c-4bc3-b245-8b0b87ed1e2d', '2026-10-01', '746b4c5d-8760-4a6f-9284-d3c584d4146e', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('3270f299-3709-4657-ab27-39dd2ed6276a', '2026-10-01', '53bed5f0-0a20-432e-9f88-bb2ebbdb00f4', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('c4a53fde-3956-42bb-a161-4ef9c5912a8d', '2026-10-01', '0a969dba-e37a-453a-a272-8d50dd5004f2', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('80fdc2b9-c94e-4565-a490-f2f5dcbfe374', '2026-10-01', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('696056fd-82ec-4dda-b297-c0e823359a93', '2026-10-01', '184dac24-2290-47ba-8b75-23df8d1176ce', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('edfe4f2c-1359-4fe3-ae5a-13e6c3628901', '2026-10-01', '3cf908c1-bfaa-4846-910e-35ab9d813b03', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('4393e879-e457-498c-a9cd-ae08c5b477e0', '2026-10-01', '57f0e54a-b385-4f51-81d5-901201891974', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('b13b69a4-3039-4dd2-8c4a-e85170242cfd', '2026-10-01', '5932eaff-c7a6-4175-a001-c75eea53b5d0', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO laps_savings (id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at, version, currency_code)
            VALUES ('688b8a78-6cde-4ec3-bb22-9c0207b1be96', '2026-10-01', '58a54856-a5e4-4814-a743-d780063290d8', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', 2500.0, 0.0, 'LAPS-RES', 'Compulsory loan collateral reserve', NOW(), 1, 'NGN');

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 99000.0, 1650.0, 99000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4d01cefc-c2ff-4357-af98-fe1b8dd394f8', 'be73659f-1149-4f20-a118-35a96e0bc085', 1, '2026-10-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-13', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('728a4481-b034-4ff7-9708-766f66ecc16b', '2026-10-13 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9bf44755-ce58-4979-abb5-a70c9eb2059d', 'be73659f-1149-4f20-a118-35a96e0bc085', 2, '2026-10-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-14', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('11df249a-db12-4fa4-8c20-8e564a6f59dd', '2026-10-14 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('520fc0fe-f617-494f-94dc-8893c7e1ae93', 'be73659f-1149-4f20-a118-35a96e0bc085', 3, '2026-10-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-15', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('97bf870b-f22e-4011-bfb9-b889c04c119c', '2026-10-15 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a941ea4f-2737-4ce7-a2cf-1d4b44d17be2', 'be73659f-1149-4f20-a118-35a96e0bc085', 4, '2026-10-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-16', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('cb9bfce3-a9da-49f3-8ec1-b3498fe8f588', '2026-10-16 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4a410a26-7112-4579-bebc-4c7edbdbdfe0', 'be73659f-1149-4f20-a118-35a96e0bc085', 5, '2026-10-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-19', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('4fd4b304-2cb4-4bbe-9c44-f0345610d0d1', '2026-10-19 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fd641d04-8411-4520-8dfb-3e82697ca9fe', 'be73659f-1149-4f20-a118-35a96e0bc085', 6, '2026-10-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-20', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('8d5e9c54-302d-4539-b5ad-81ef66f27c70', '2026-10-20 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d3722820-502d-43da-b40e-0c454d3b96b0', 'be73659f-1149-4f20-a118-35a96e0bc085', 7, '2026-10-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-21', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c6cf1cb1-c800-49ba-812a-e1d0ab449a99', '2026-10-21 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('28f5d2e7-3f3a-42cb-b1a1-08d50c9876df', 'be73659f-1149-4f20-a118-35a96e0bc085', 8, '2026-10-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-22', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('3a66faa1-3a90-4e14-9f7d-ff01ba9d9aa9', '2026-10-22 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d95935c0-cefb-4a3c-b4f5-27ad8d964a97', 'be73659f-1149-4f20-a118-35a96e0bc085', 9, '2026-10-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-23', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('bfa96b5b-6e66-4402-9815-3ef6ac4c2437', '2026-10-23 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('309b8de6-5895-4fc0-8c8f-1a9ad02bf4bd', 'be73659f-1149-4f20-a118-35a96e0bc085', 10, '2026-10-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-26', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('56cd1473-9c0c-4894-b391-4b73214d9424', '2026-10-26 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ab99abb8-3b18-4a9b-b2d1-b0b096444e9e', 'be73659f-1149-4f20-a118-35a96e0bc085', 11, '2026-10-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-27', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('7889843d-6f7b-4246-883f-06e7b97504b3', '2026-10-27 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a2338610-67d5-4272-874c-4746f8a2379e', 'be73659f-1149-4f20-a118-35a96e0bc085', 12, '2026-10-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-28', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('bf15985e-cb77-4693-9c44-cb7b9609d427', '2026-10-28 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a3f613f3-b713-4b3b-bb50-fe49e8934a63', 'be73659f-1149-4f20-a118-35a96e0bc085', 13, '2026-10-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-29', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('4396d228-0f96-43fc-bfae-a636fb4a13e3', '2026-10-29 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ac3eb375-b555-4ff3-b1e0-9d5275018470', 'be73659f-1149-4f20-a118-35a96e0bc085', 14, '2026-10-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-30', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('abc34b08-d794-46e9-aa00-e251951df593', '2026-10-30 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('734ce569-8906-4cdc-8b3a-ae3c2b13aed5', 'be73659f-1149-4f20-a118-35a96e0bc085', 15, '2026-11-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-02', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('176de99b-46a1-4e9d-abce-21cf1289df3a', '2026-11-02 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('00580fc0-aa28-4cb9-80be-c87ec3a5c3a7', 'be73659f-1149-4f20-a118-35a96e0bc085', 16, '2026-11-03', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-03', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('fa855d25-23ff-4234-904c-b274aa67199a', '2026-11-03 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8b6a5324-1ea8-4945-a36f-cf445cb15c8a', 'be73659f-1149-4f20-a118-35a96e0bc085', 17, '2026-11-04', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-04', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('42ce3aa6-2c28-4878-b3d6-0699e37c14df', '2026-11-04 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0cc6e039-df7f-4c37-af03-5d4e37038802', 'be73659f-1149-4f20-a118-35a96e0bc085', 18, '2026-11-05', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-05', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('44c3d991-606a-4c65-ac47-017ac63e3e19', '2026-11-05 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('293bc891-710f-4bec-b8a7-61e739e3661d', 'be73659f-1149-4f20-a118-35a96e0bc085', 19, '2026-11-06', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-06', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9ce9c9de-6abb-433e-a7a7-dbfeb4f5d157', '2026-11-06 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b13b9a70-6f97-4f18-9b25-df3a42288c5e', 'be73659f-1149-4f20-a118-35a96e0bc085', 20, '2026-11-09', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-09', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ebbc6fc2-131b-4704-9bb1-af669449b8de', '2026-11-09 10:00:00+00', 'be73659f-1149-4f20-a118-35a96e0bc085', 'd1595e7d-9fcd-4f22-aff0-3c5a29c69e54', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1d0384ab-2f44-4183-8add-ccf8c3d7428c', 'be73659f-1149-4f20-a118-35a96e0bc085', 21, '2026-11-10', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('76d52f41-5cd3-46c8-9d02-7a39f92023ed', 'be73659f-1149-4f20-a118-35a96e0bc085', 22, '2026-11-11', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4afc9074-164d-48b0-a290-c16d799d9a42', 'be73659f-1149-4f20-a118-35a96e0bc085', 23, '2026-11-12', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3c2f6348-007a-4ea7-b743-2a23cbe12b75', 'be73659f-1149-4f20-a118-35a96e0bc085', 24, '2026-11-13', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a371bdac-45ff-44b5-8b97-e82503e445c3', 'be73659f-1149-4f20-a118-35a96e0bc085', 25, '2026-11-16', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5609a87b-ed69-4b4b-9633-f2ca0a5e3167', 'be73659f-1149-4f20-a118-35a96e0bc085', 26, '2026-11-17', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c54085e9-4b11-4b5f-8ae8-85689662638b', 'be73659f-1149-4f20-a118-35a96e0bc085', 27, '2026-11-18', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7ae13f5e-093f-4698-b5b2-8da7d84fd917', 'be73659f-1149-4f20-a118-35a96e0bc085', 28, '2026-11-19', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8ff5dab9-2273-4ab4-b1f2-998c8eefffa0', 'be73659f-1149-4f20-a118-35a96e0bc085', 29, '2026-11-20', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('91841685-42f8-4494-81f6-e12289d9adc4', 'be73659f-1149-4f20-a118-35a96e0bc085', 30, '2026-11-23', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3acd1863-32b8-450e-afa8-0912c6ca7f3d', 'be73659f-1149-4f20-a118-35a96e0bc085', 31, '2026-11-24', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eb632b66-2525-4814-92e8-c75e7a284321', 'be73659f-1149-4f20-a118-35a96e0bc085', 32, '2026-11-25', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ebc1b3a2-3842-4ab4-99ea-4ef702d4e57d', 'be73659f-1149-4f20-a118-35a96e0bc085', 33, '2026-11-26', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5e518afc-8601-4217-8570-495ed78eb3d0', 'be73659f-1149-4f20-a118-35a96e0bc085', 34, '2026-11-27', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d56f5e3e-286b-4f3c-863e-d078dc7cfd7d', 'be73659f-1149-4f20-a118-35a96e0bc085', 35, '2026-11-30', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f7a25c97-2bfc-40e9-ab4b-2274b4a325d7', 'be73659f-1149-4f20-a118-35a96e0bc085', 36, '2026-12-01', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('23e94c08-8ab8-41b7-801e-edb33ce517dc', 'be73659f-1149-4f20-a118-35a96e0bc085', 37, '2026-12-02', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f939dadf-474a-43f5-87a2-2fda2ead382f', 'be73659f-1149-4f20-a118-35a96e0bc085', 38, '2026-12-03', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('db72c785-af69-49c2-b154-6dd12aa0539a', 'be73659f-1149-4f20-a118-35a96e0bc085', 39, '2026-12-04', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7c47717f-2aa0-4679-bfb4-121e709506fc', 'be73659f-1149-4f20-a118-35a96e0bc085', 40, '2026-12-07', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ef51729e-c577-49e4-ad7a-fc77e9883f59', 'be73659f-1149-4f20-a118-35a96e0bc085', 41, '2026-12-08', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0f603ea6-8d9c-419b-9622-c369ebcb706c', 'be73659f-1149-4f20-a118-35a96e0bc085', 42, '2026-12-09', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('55c955b6-f4b9-4a64-9ea9-e94831d65f34', 'be73659f-1149-4f20-a118-35a96e0bc085', 43, '2026-12-10', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8b90cfb7-04f3-4250-8eb9-93ba44242d5f', 'be73659f-1149-4f20-a118-35a96e0bc085', 44, '2026-12-11', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4336cb9f-e68a-45eb-92df-6aec2257aa48', 'be73659f-1149-4f20-a118-35a96e0bc085', 45, '2026-12-14', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('da109415-e099-4061-bc44-0918b0bd23bf', 'be73659f-1149-4f20-a118-35a96e0bc085', 46, '2026-12-15', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ec6321e4-46e4-42e4-9ff2-6b03282c02d1', 'be73659f-1149-4f20-a118-35a96e0bc085', 47, '2026-12-16', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cdf25d2e-cd6e-4711-9914-1931376efd8b', 'be73659f-1149-4f20-a118-35a96e0bc085', 48, '2026-12-17', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c3fd06db-fc63-427c-8f6b-4d72394e8c79', 'be73659f-1149-4f20-a118-35a96e0bc085', 49, '2026-12-18', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('93044b78-698d-44c0-9d9a-134e7784ef84', 'be73659f-1149-4f20-a118-35a96e0bc085', 50, '2026-12-21', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f5b16e10-4207-4580-bce4-7302e5cc57dd', 'be73659f-1149-4f20-a118-35a96e0bc085', 51, '2026-12-22', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1686af6b-f2c1-4fb8-afe3-ddf020310faf', 'be73659f-1149-4f20-a118-35a96e0bc085', 52, '2026-12-23', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('631c9778-7612-4464-8d77-b8e397f9d4d8', 'be73659f-1149-4f20-a118-35a96e0bc085', 53, '2026-12-24', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9a24d4fc-0c4e-4850-9948-fe63e5b932d6', 'be73659f-1149-4f20-a118-35a96e0bc085', 54, '2026-12-25', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c12c785a-3246-4a21-8419-5c5d8df5b1cd', 'be73659f-1149-4f20-a118-35a96e0bc085', 55, '2026-12-28', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9466c777-1733-49f4-8292-0278a2703ecd', 'be73659f-1149-4f20-a118-35a96e0bc085', 56, '2026-12-29', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('03bfc47f-dc90-41f6-8f1e-06681acd2462', 'be73659f-1149-4f20-a118-35a96e0bc085', 57, '2026-12-30', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d8aabac2-8936-49db-82b7-12f9cd078f41', 'be73659f-1149-4f20-a118-35a96e0bc085', 58, '2026-12-31', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5e63c324-4d71-4725-97c4-ff43f6e36305', 'be73659f-1149-4f20-a118-35a96e0bc085', 59, '2027-01-01', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5d1e561e-4d8a-422c-90c6-c0f51650fc1b', 'be73659f-1149-4f20-a118-35a96e0bc085', 60, '2027-01-04', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 'c41b5775-6e19-4302-bd42-c14342f52592', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 96000.0, 800.0, 96000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-04-11', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bd153228-d364-4fd5-b51f-7b1664f22702', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 1, '2026-10-13', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-13', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('335f1673-8a2c-4bae-8a31-6c4060ce16e9', '2026-10-13 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dcbfd278-b7d3-4cb8-8b3e-5ce8e564fa78', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 2, '2026-10-14', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-14', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c5d04d89-9954-412e-a09c-317d4630832e', '2026-10-14 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('888441d8-37e0-4158-967f-bda3a18c48c2', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 3, '2026-10-15', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-15', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('20dc6b25-b4b3-4217-8e54-f20dd3dd3363', '2026-10-15 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a4cd1a10-5bd8-451f-97dc-2524a1aee8af', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 4, '2026-10-16', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-16', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('edfd6507-365b-4c8f-82ce-5ff9b8da331e', '2026-10-16 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('894305eb-1578-44f7-be91-4ac31185adc6', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 5, '2026-10-19', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-19', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('05a95c74-ccd4-478d-bcab-5e33d3950e72', '2026-10-19 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0bbd8721-63ad-454a-a6d2-8f49a4f342a7', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 6, '2026-10-20', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-20', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('cb8acce1-3b8c-4bad-9e2f-b3c76d11f879', '2026-10-20 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dba68906-4cb3-4005-a28b-291ea20395e1', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 7, '2026-10-21', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-21', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('1ccb393d-630a-4c9f-b1bc-37a4e7101016', '2026-10-21 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('45e701b3-7f5a-474a-8113-5a23be7a3a1b', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 8, '2026-10-22', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-22', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('d2f4cb96-c9f9-4a45-add8-da13e71cbc96', '2026-10-22 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eea90de6-c6d6-44c5-8a65-bd0c5b4f6521', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 9, '2026-10-23', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-23', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('02adcec7-11a2-4829-aa7c-b19958a9b1c3', '2026-10-23 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9e4138b7-a45c-43ef-9ff8-9843c6b5fe53', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 10, '2026-10-26', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-26', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ef954659-85c0-4e17-b019-e0abf413783f', '2026-10-26 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c055ae3e-2cc1-4f1d-997e-c40288aaae2a', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 11, '2026-10-27', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-27', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('0a5241d9-ba48-4415-9ea1-2feb111e19c5', '2026-10-27 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c9f29816-c227-4513-a011-2c65f7fd3f93', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 12, '2026-10-28', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-28', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('dcf23dce-7047-4385-9704-9c54e48144eb', '2026-10-28 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a9876cfd-dd49-402b-bc6b-4ed3f017ce14', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 13, '2026-10-29', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-29', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('d50fdee5-f0ea-4720-b3d4-f1decdb4ed29', '2026-10-29 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('34776336-eda2-4d8d-b5b7-a75ee3a16dbf', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 14, '2026-10-30', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-30', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('cc8eabc2-7789-4426-ac6c-90c90c43ffe7', '2026-10-30 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9bfad6e6-d938-42b2-8c6b-8a2d74946204', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 15, '2026-11-02', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-02', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('a4e993e7-1bb9-4605-ad1b-4a0a5db13585', '2026-11-02 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('75a2b2ec-cccb-4c76-b007-d34d5c698870', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 16, '2026-11-03', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-03', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('e7a6eb40-13a3-4383-88d0-4b61c84e9fd8', '2026-11-03 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('390cb5b4-0b30-4a26-8788-0a714e94b389', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 17, '2026-11-04', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-04', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('3a6071b4-b6ca-4dcc-898c-796fabaa2acc', '2026-11-04 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5f247601-2ac3-4761-806b-171c832fde26', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 18, '2026-11-05', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-05', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ec733fc7-12c7-4ff3-ade2-ab0ad7d817de', '2026-11-05 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fbe35c59-a7ae-45fd-988e-4451fc28a8f8', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 19, '2026-11-06', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-06', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c4a29839-e304-427d-aafb-e0fd763f660e', '2026-11-06 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7cfc0b3d-cc92-407a-ada1-7a9f889c9019', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 20, '2026-11-09', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-09', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('da49fcff-5a3e-4b69-8414-5155f8ca944c', '2026-11-09 10:00:00+00', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 'dede7647-257b-43a3-a160-b37f44b9e12c', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('00cc2ac9-ca88-47b8-8e53-2bde72abeff9', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 21, '2026-11-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('83669cff-9cc3-4fad-9491-d57955eab6e8', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 22, '2026-11-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ebcff6da-3365-45c7-abe9-281b36910581', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 23, '2026-11-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7358fe1c-08d0-46f6-8b4d-bb2148f83d73', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 24, '2026-11-13', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('73d19183-45d4-421f-ac46-e37650fff758', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 25, '2026-11-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a1f6f19d-d723-4d29-a07c-94656ef16015', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 26, '2026-11-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bf5f7cc8-80b7-4a15-9448-f3220cd64a7d', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 27, '2026-11-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2a49eba7-b5b8-48c2-bc62-3dfadeec9375', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 28, '2026-11-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6327ff1b-af78-4ad0-b999-c987b5a9faf0', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 29, '2026-11-20', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('360df0a1-658e-49d6-b7bb-c0ee5cc662e5', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 30, '2026-11-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a991572a-cd57-4fa2-aaee-14c331d74ef7', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 31, '2026-11-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('00a49d0e-2f8a-4870-9e64-243d25a96136', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 32, '2026-11-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('19972321-7213-4584-9438-8a3649a8f333', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 33, '2026-11-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c7b7210b-61f2-4daf-b8d7-61461a4e7663', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 34, '2026-11-27', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b22e603d-5de5-49f9-9028-e4b20d79b65a', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 35, '2026-11-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('011bc11b-f702-4aef-8cae-b858521f0092', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 36, '2026-12-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('da38a674-5f9f-4064-b211-397f1017ddf7', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 37, '2026-12-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('862e0fd3-9ceb-40be-b177-ced8dbc8154f', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 38, '2026-12-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eeda100f-fdf1-44b1-a92d-fdd718c253c6', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 39, '2026-12-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8a3d9190-1b26-4465-99a9-40a8ee2f86ff', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 40, '2026-12-07', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1a9311b8-9ad7-4a27-8c30-965b5096fb99', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 41, '2026-12-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('42b227b9-a706-4937-81a0-8c694e474b78', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 42, '2026-12-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('08302ecd-9c69-4b59-acb8-2432ad8a379d', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 43, '2026-12-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6999039d-e1cf-4545-9f85-84f0b01f7242', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 44, '2026-12-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c14d4639-8587-48d9-b51d-ab54f75cc4a4', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 45, '2026-12-14', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fc035e68-c337-431a-a7f5-653684666ac7', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 46, '2026-12-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b5da903b-7021-4df8-aaab-03b95565b8bb', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 47, '2026-12-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d15c2147-1989-456a-9864-0c4ead6c1536', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 48, '2026-12-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1cfdacdd-0af5-492c-9695-18c49e99f28c', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 49, '2026-12-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('320fec12-ac3e-4973-bd81-bbcc353823dc', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 50, '2026-12-21', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6f1423ce-1dac-471a-a30c-20d3812a9cd0', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 51, '2026-12-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('978c3fa9-f7a1-4126-8aa0-cd3e17183468', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 52, '2026-12-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8c759f9a-e855-4f8e-8a70-b9bbbd0a5e29', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 53, '2026-12-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4dfc15fc-30f1-40ab-b0b8-521e06edc8ae', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 54, '2026-12-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c8b60ead-bfe4-4175-826e-f033f4786dc8', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 55, '2026-12-28', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('98305ebb-2657-46e0-8ec4-5faeedc07339', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 56, '2026-12-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('830906a4-6bf3-4082-9c6c-3771f6b61cbb', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 57, '2026-12-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('de0c20e9-9221-4788-aee8-6c3f6e1d72f0', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 58, '2026-12-31', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('153a04af-3308-422d-b285-e1f5a0875fc6', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 59, '2027-01-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('944533a0-5d34-4c1d-a2b0-c8f292753859', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 60, '2027-01-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b351636b-ae4d-48e7-8205-1ed28b7846ca', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 61, '2027-01-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9bc0bcd4-ea43-47d4-8335-cae5baf9bbe0', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 62, '2027-01-06', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('792b732e-bee4-45ef-bf3f-d905517921ce', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 63, '2027-01-07', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3e2a73be-d351-4ff5-b89a-4b74600ea21a', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 64, '2027-01-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8813f73c-86f4-46cf-b457-b38049eae84f', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 65, '2027-01-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6c456178-80c7-4819-b25c-5f7203676463', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 66, '2027-01-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('97966544-5c4f-422f-957e-4b9b5d0cac54', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 67, '2027-01-13', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e9a06ad7-ee76-411e-add8-bfb3d1180128', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 68, '2027-01-14', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2d55afec-526e-42e7-b608-70d9692fdc28', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 69, '2027-01-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e592cc78-f033-476d-9d2d-a2648968c874', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 70, '2027-01-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2b2b4280-2ece-4448-a9e8-0d9a0bbe5333', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 71, '2027-01-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('230f7647-17c8-43fe-9537-36d3ffbb0535', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 72, '2027-01-20', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e04f809c-9385-4aed-8eb9-800d2beb95c3', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 73, '2027-01-21', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7a405d27-1bab-4f06-9666-6b2a94b31c12', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 74, '2027-01-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e3ba8784-4e61-4faf-a1f8-39a6ebba8527', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 75, '2027-01-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('92051043-b49f-47ca-b403-877462eaf059', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 76, '2027-01-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bb257e8d-ecbd-4528-ae48-4fe35d094527', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 77, '2027-01-27', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f1dc3e54-62cc-4aef-9d79-a2040d2e4313', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 78, '2027-01-28', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('87e4c784-fb54-496c-801b-4c7c0d26b950', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 79, '2027-01-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d89059d9-0193-4652-8f2b-5cfed99eec58', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 80, '2027-02-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d8b3567d-c368-4707-b27e-177f728b120e', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 81, '2027-02-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('797444c9-5f67-4d85-8a28-8240ae2c6db9', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 82, '2027-02-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('62c93efc-d1d3-484b-9a90-7b1194b174af', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 83, '2027-02-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c5f57623-d616-4a69-b782-ba16aac3a3a3', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 84, '2027-02-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3051c9db-a1d8-4edf-a608-133538d9644b', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 85, '2027-02-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fec927cb-fdc9-4f7e-99ba-93746d64824c', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 86, '2027-02-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8da6953a-081e-4c79-a52e-8ebcadd1812d', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 87, '2027-02-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4296d102-17d3-4f80-af3f-d46e366a70be', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 88, '2027-02-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('579bce81-b4f1-40a2-b7cb-959512465f10', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 89, '2027-02-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4de5fd50-e6c4-4a1f-91dd-f88b4d0aeb74', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 90, '2027-02-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5ba71adc-034c-43cd-aa50-3e6482d4bbd9', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 91, '2027-02-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a40dc394-6133-45ac-b2c5-d7a2faceaeaf', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 92, '2027-02-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('411df943-23d2-4369-a717-b63542f543e5', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 93, '2027-02-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('da12a037-a5d7-475d-b63e-549e658f1f03', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 94, '2027-02-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b53a3d2a-95e7-4271-ba9a-69110787604f', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 95, '2027-02-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e0a5b717-d77e-4335-a922-48da76b71f3c', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 96, '2027-02-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e61a00f4-2ae2-4414-a16e-01e6df3d6de9', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 97, '2027-02-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7651cf18-a9e5-420c-9c5c-79e8a63b8887', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 98, '2027-02-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4fd4a9f0-2863-48eb-9041-5e089d9817ad', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 99, '2027-02-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a52ff7e6-2be4-4493-a917-354da8ffce3f', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 100, '2027-03-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('513f031a-217c-4591-a6b5-9efdfeefa534', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 101, '2027-03-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bc5e574e-c5b4-41bf-9024-109922bf4e5d', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 102, '2027-03-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d63e7c24-a988-4a90-8c72-a8b4df9edd53', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 103, '2027-03-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('13f8ffb5-c8fe-46c0-944f-6102b30edcf3', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 104, '2027-03-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2bb8db24-47fd-446f-885a-6efcce4a895e', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 105, '2027-03-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9980c005-ad03-4177-ba7e-8c6ac632e655', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 106, '2027-03-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cdc545b3-a64b-458e-afc1-5a1da4ca4c40', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 107, '2027-03-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('517926a8-3c50-479a-963e-cfe912160eaa', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 108, '2027-03-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3defe930-52a2-42fe-9c7d-e69750a1637a', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 109, '2027-03-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d9122a84-8bef-4258-85b6-50527a98f4af', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 110, '2027-03-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9f6f0476-1ef6-4be1-9352-03f8b3d30a0b', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 111, '2027-03-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('07557c6f-d613-4373-8a91-2b9338a16759', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 112, '2027-03-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9ad94868-aaa2-4e71-b4cf-b8de92dfc6e1', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 113, '2027-03-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b7c2830c-60b3-4bf3-af98-826aa19e537e', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 114, '2027-03-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('41aef545-c964-4637-8f0b-7e97986d480c', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 115, '2027-03-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cd1e3edf-6da4-4f00-bd7a-e43fe9910f4f', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 116, '2027-03-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('47fbefac-a099-4a21-b011-b624c1b3f442', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 117, '2027-03-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d12b1307-889d-45be-b175-6f51c8ce982a', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 118, '2027-03-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d2960d11-8fa1-4bd5-95e1-14f2d8d9c49d', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 119, '2027-03-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f0f3e51b-a655-4cd2-9488-f9213ce1f163', '78d21a4c-a09f-4c3d-b08e-f0f740edeb17', 120, '2027-03-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 50000.0, 48000.0, 800.0, 48000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('edc8fc38-afe7-4273-9a99-479bca8ec0c5', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 1, '2026-10-13', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-13', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('f343f17f-f003-4717-8d21-53328564038d', '2026-10-13 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('08c8e43a-bbc9-452b-a68a-0670b179fbcd', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 2, '2026-10-14', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-14', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('0f7ce880-5c22-4415-a91e-3dcec0187cd9', '2026-10-14 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a17fc5c0-54bb-41c0-9d3b-831b478c3400', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 3, '2026-10-15', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-15', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9f7c099f-c8df-4b0b-be35-6f2f8188faf9', '2026-10-15 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7af0fbdf-1ad4-4c9e-b9c9-41a480cb6cd3', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 4, '2026-10-16', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-16', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('75ccba5d-0fe4-46e0-a299-e796324308ff', '2026-10-16 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6ccbdd7b-08e4-434d-ab21-0e36339bd9a5', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 5, '2026-10-19', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-19', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('73525586-730e-4ad4-a5f4-681de6dffa5a', '2026-10-19 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('95591d16-b4ce-4860-8ae2-3a96aea13caf', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 6, '2026-10-20', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-20', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('24e80005-8eba-438d-b1b7-01bf5030a7ef', '2026-10-20 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4ceaf081-49b4-464c-8761-a48532594a34', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 7, '2026-10-21', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-21', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('130a64f1-f42b-460e-ac91-931981630bac', '2026-10-21 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dd424abf-e258-47fb-99ac-bd1d44d5c5cd', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 8, '2026-10-22', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-22', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9b157d2c-16cf-4764-a176-26e64af61cdd', '2026-10-22 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('df8550b6-cc0b-4eb0-a5f7-d119eb912e8a', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 9, '2026-10-23', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-23', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('0661e76f-d801-4dc8-ac4b-9577e784ff3c', '2026-10-23 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('de0a1e06-3dea-4bc0-b8b3-c772589de6e1', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 10, '2026-10-26', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-26', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ed6a4fe0-9c22-407a-9e7a-78683f1b6e61', '2026-10-26 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0455474b-7a67-41be-8435-84dfdc63a8a4', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 11, '2026-10-27', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-27', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('89640d06-e58e-41b9-bf36-c4ed1e8a3a55', '2026-10-27 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cb6eabe7-5858-4cc3-80de-7a542e21eaf7', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 12, '2026-10-28', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-28', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('7a154176-6ebf-435c-9534-5a9bab52cd7b', '2026-10-28 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1328021a-c308-4bf8-a0e7-759040cf5418', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 13, '2026-10-29', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-29', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('613a07e4-e192-4021-85df-a7514ca5ee84', '2026-10-29 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2884e474-a06d-42c3-b57d-f374ff2be41c', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 14, '2026-10-30', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-30', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('93e7daae-47d5-432b-98b4-7814ff988a92', '2026-10-30 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7a9c1db5-2ad7-4b42-bada-dddafc6ee779', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 15, '2026-11-02', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-02', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('88d37aad-3a63-4426-a079-c2d108d7de35', '2026-11-02 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b0b06427-897b-4f57-825d-03be5194f653', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 16, '2026-11-03', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-03', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('6b8de72f-7f20-4299-9c4a-d248eb0032a2', '2026-11-03 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b48e8235-e51b-413b-8410-4ec93c80b0a5', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 17, '2026-11-04', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-04', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('a4d56950-5c5a-40cc-90e7-b0029ee1dce7', '2026-11-04 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('06dfe84d-101d-4d79-80f2-e6c998c8491a', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 18, '2026-11-05', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-05', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c8dae934-ac6d-4da9-a91c-f654aed39cda', '2026-11-05 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9ed701a5-6445-4b5b-9321-30f3559e6598', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 19, '2026-11-06', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-06', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('10d809d5-7b40-4ca7-bcd5-bdf05f23c7ed', '2026-11-06 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bfcd51e9-d93a-477c-8a3e-40c2b448e9de', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 20, '2026-11-09', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-09', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('d86c1272-20d3-4c0b-a023-7d156845ea03', '2026-11-09 10:00:00+00', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 'd073e519-1c98-49a6-9e3c-820d2df7f728', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6b17360e-3445-4991-9296-e63555c9111a', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 21, '2026-11-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e9b931bb-111f-4dbd-a629-d1eb750accb1', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 22, '2026-11-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2d74d962-a65f-4e71-8e4c-2d964b835ebb', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 23, '2026-11-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0cdc8927-fb8c-407b-be45-f2a163676f68', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 24, '2026-11-13', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a845cb58-3673-45e7-a16e-c95f62d8ee7c', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 25, '2026-11-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6f1317a8-aa72-4b1a-993b-642d94d161e2', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 26, '2026-11-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('36c96005-03f2-473c-9e28-7f670743f9a5', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 27, '2026-11-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4de0257d-26a0-4627-83e5-469ae3dba78d', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 28, '2026-11-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c6b6ad46-f5bf-4ead-818a-6a73c82aa47f', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 29, '2026-11-20', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('23b105db-68c8-493d-91dc-1a38a3c948fa', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 30, '2026-11-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4a98faad-ee9e-49a1-9ddf-f956c66a3d1e', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 31, '2026-11-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('43fefdea-6323-4d6b-bbab-4450dc171408', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 32, '2026-11-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e1bf93ca-47f9-4ad1-b733-7af2d4e305d0', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 33, '2026-11-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7940314a-baf0-4864-ac01-fc7a56d7a55a', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 34, '2026-11-27', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('40d55a49-7e53-481b-bf6e-c7404b891e1a', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 35, '2026-11-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b9ff3214-b091-47b1-9756-d3a4cb71022f', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 36, '2026-12-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('85d86646-43a3-4e79-92d3-9702def60159', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 37, '2026-12-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0e6f2136-8b73-4408-bcac-94332851c0d7', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 38, '2026-12-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c42ab2b9-1087-4c46-8036-8cb60994e647', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 39, '2026-12-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3011b093-aafb-4e9e-813e-19aeda7f5f2f', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 40, '2026-12-07', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d1f37e83-766b-424a-8000-6c0072b50dc8', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 41, '2026-12-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a2076109-de17-40fc-8ad9-e961dfb4f869', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 42, '2026-12-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c8e59ddf-9e0f-438d-941b-e2165f0a2199', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 43, '2026-12-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4445f3a1-4587-42ff-89ac-2a8f7c7ed487', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 44, '2026-12-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('de549457-9486-4de1-ab86-7d0a78befeba', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 45, '2026-12-14', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1ad27e58-9d0e-4f15-8c5e-802234ea4f64', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 46, '2026-12-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('41bf30f0-1b34-4f49-b6af-acafbcb28159', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 47, '2026-12-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9f0035c7-2fd3-46fc-9d03-d24db981e2ed', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 48, '2026-12-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('83795714-cd78-448f-b7cf-57ee5b29559e', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 49, '2026-12-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0c5848f9-ddeb-451a-af02-fbc95bce9e60', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 50, '2026-12-21', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('42b20010-46b6-45af-b81d-e954f1464474', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 51, '2026-12-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8fe53518-77e6-4f1a-a992-ccac10118047', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 52, '2026-12-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2e12e10e-acda-4d37-ba6d-1f3837ef4c0a', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 53, '2026-12-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fa5393d1-383f-45b0-967a-9fd701bf8a1c', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 54, '2026-12-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('466c213c-a958-4694-9b1b-9dff3e47cdf8', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 55, '2026-12-28', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('30eec86a-5bfb-4f6b-915b-fe59bdc23a12', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 56, '2026-12-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('51ee0a80-a108-46aa-aa85-252a4834d92e', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 57, '2026-12-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5eb81be4-be69-48d2-a433-d7b07213a82a', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 58, '2026-12-31', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c99ddf1f-54a3-4444-8785-7b641b5cc997', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 59, '2027-01-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4d69dc54-6b98-4594-9d11-b3bfff473ee8', '7d77d168-e581-45a4-94e5-081c5deb7ef5', 60, '2027-01-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-10', 100000.0, 99000.0, 1650.0, 99000.0, 'Completed', 'Finance', '2026-08-10', '2026-08-11', '2026-11-09', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('79b128bd-484c-4c22-a3e2-f90a55b95cc7', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 1, '2026-08-11', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-11', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('aae36d1f-dacc-47d7-88bf-a0384c05123d', '2026-08-11 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8ff82f89-5b71-4d75-84c4-0ceeca94a52c', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 2, '2026-08-12', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-12', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('0dd7c4e3-e245-439c-928b-f3d8f970a5f1', '2026-08-12 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b46c50f1-ecfd-4460-a5c1-c08044c02a31', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 3, '2026-08-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-13', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('0976d160-156a-4662-87a2-63c48cce7d17', '2026-08-13 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e3e80cf3-747b-4e17-823b-abe7a52daf4f', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 4, '2026-08-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-14', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('3b99f851-7e66-4dc7-b31a-b7f6767a0f8a', '2026-08-14 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fbebbf5c-93bd-4b07-bcc6-66e5ddd96246', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 5, '2026-08-17', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-17', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('1679ff79-2d33-470f-9f7d-088b49dfed63', '2026-08-17 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('acd3c979-d9a0-444a-8269-5446ee31beb6', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 6, '2026-08-18', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-18', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('2698f647-1e37-40b7-964e-3eb617f032d4', '2026-08-18 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6e8a14a8-f6e8-4698-8367-7b1a2aaa19b9', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 7, '2026-08-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-19', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('242c0534-02ca-423d-92f2-7276f80c6582', '2026-08-19 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('af28e1a5-e4f4-4173-9bcd-6d7b24025421', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 8, '2026-08-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-20', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('8cb62e15-953f-4ea3-9fdb-3a921866fda0', '2026-08-20 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f6f6113c-436a-4a6e-b265-2d77963df0c6', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 9, '2026-08-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-21', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('b0e86d37-d4f2-4da4-9fed-62b2e09b1891', '2026-08-21 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('566549b1-3be9-4b0d-a0bd-c7bb0aadcde0', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 10, '2026-08-24', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-24', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('97814c37-b534-4f6c-a47f-0b9c780f3bc6', '2026-08-24 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('34bd7d90-ec87-4397-b49d-3ec26ac7d2ff', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 11, '2026-08-25', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-25', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('409fd2ea-cc6b-44e5-b436-cb0048064db8', '2026-08-25 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dff1c2bd-85b7-4e1c-aa17-0c1bd4a1b980', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 12, '2026-08-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-26', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('cf6558b9-f5eb-4d15-81ac-610ddaa8ef25', '2026-08-26 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('19329168-0880-4b5a-8f05-3a93b161ad1e', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 13, '2026-08-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-27', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('2372a88f-7e65-4749-b9b8-bcd10f6003d2', '2026-08-27 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1ddd9c6a-f3b7-46b5-b59d-a961efcfa767', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 14, '2026-08-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-28', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('f5d48d58-1054-4fd1-b12d-36b9c95ccb3e', '2026-08-28 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('685e2837-baa2-4b8e-a8d9-518ee6787e54', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 15, '2026-08-31', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-08-31', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('39bba242-8a17-4926-9a53-275a79c9480f', '2026-08-31 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('de601432-c998-4f0b-91ef-6f44cd6b996c', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 16, '2026-09-01', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-01', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('a40c079c-2dd3-4078-bfb5-d9aac8492b18', '2026-09-01 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('008b5235-dd8e-49be-bb50-2ad14bc914cc', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 17, '2026-09-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-02', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('85765781-824d-4a01-87d7-3248f2f3b259', '2026-09-02 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a483ccc2-1a2d-472a-8b4b-d8829f6b9610', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 18, '2026-09-03', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-03', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('7b0180bf-f202-4092-a68c-e1a9805aa9ec', '2026-09-03 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e0ad290e-ff46-406b-a85a-f942ec009341', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 19, '2026-09-04', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-04', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('eb7e8e5a-c4c6-4370-bc75-95a599d63e77', '2026-09-04 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('45652e95-3c52-4a8e-b3c3-06e4f2b55c04', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 20, '2026-09-07', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-07', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('7d431d0e-c495-44c0-8fdb-7f52203e4df5', '2026-09-07 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9b0cb84e-0e0a-45d6-97b9-3ba3e411249b', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 21, '2026-09-08', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-08', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('8db06e5b-fa16-44cb-82cc-d72557e49bc1', '2026-09-08 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #21 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b19cf3d0-a4f5-4442-aba3-90a3432ab4ca', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 22, '2026-09-09', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-09', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('5c3be174-40c8-4e99-b54e-9163804fec0f', '2026-09-09 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #22 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cd783256-2ab9-4d31-9e78-e5e6bf0e5a6f', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 23, '2026-09-10', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-10', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('647104e2-7ccc-4ef5-8850-d67430493cec', '2026-09-10 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #23 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ace2e3cf-b13d-453e-9302-76b87e1c3101', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 24, '2026-09-11', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-11', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('68c9251f-94b2-409e-adb0-a0e9f953f25d', '2026-09-11 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #24 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d15f68e0-0308-4d5f-907d-8073f65cbf13', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 25, '2026-09-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-14', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('e6b64203-246d-47bc-b6b6-3f8fb69d30f1', '2026-09-14 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #25 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('61267a11-2ccf-49eb-9aa0-6b869700ae98', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 26, '2026-09-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-15', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('74ce22b0-7161-47ed-8ff2-95f680a525e9', '2026-09-15 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #26 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('af911303-5ebe-4d34-857e-9ee8256fab48', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 27, '2026-09-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-16', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c03eab3f-a8de-4084-9a49-8e7d5776181b', '2026-09-16 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #27 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5b313370-950d-452f-b3d1-0defa1ad644c', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 28, '2026-09-17', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-17', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('4de7bd33-16c8-4df5-a52d-328b50da4744', '2026-09-17 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #28 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c7008754-1d4a-46fb-897f-ff85966bc79d', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 29, '2026-09-18', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-18', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('b845c762-0754-46a1-8c61-94cdb59fc5c3', '2026-09-18 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #29 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53581a1f-aef3-4344-a0c6-76643d7462be', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 30, '2026-09-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-21', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('e3d28f5e-88f7-4a92-a681-d6622c7dcaf4', '2026-09-21 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #30 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('39bb09e8-7213-4a91-9e7d-ffb485221e49', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 31, '2026-09-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-22', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('472199b3-b0a0-42b5-86ba-51675a8b49d9', '2026-09-22 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #31 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('414ee9bb-d07a-4584-9295-5c502d8228ed', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 32, '2026-09-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-23', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('7ff9b72e-e202-4443-8f38-9f2c6164813e', '2026-09-23 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #32 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7da48c0f-f1ae-4cb9-b082-16d35c7bcb78', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 33, '2026-09-24', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-24', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('5de85fdd-d6cc-4114-94e4-d6caa4155690', '2026-09-24 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #33 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b910fc4a-770d-4478-b87c-43470f3b248f', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 34, '2026-09-25', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-25', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('54fb987e-9e42-443f-814d-7ccec2f6c2be', '2026-09-25 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #34 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b7343ca9-e815-4d9f-8f3a-6e3381d313d3', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 35, '2026-09-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-28', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('b07054ec-58c7-4f60-97ce-52e3c9f072da', '2026-09-28 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #35 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a1d8d942-6685-429d-b939-c5c9d36145a0', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 36, '2026-09-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-29', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('375677ec-ff30-4cab-b7d3-10bf88c41d30', '2026-09-29 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #36 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7fc09cf2-1327-44eb-825b-d15da036055b', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 37, '2026-09-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-09-30', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('58dc342a-6a61-47ea-b27b-b30295fd63c2', '2026-09-30 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #37 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c207e400-0341-4354-92aa-096deee72945', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 38, '2026-10-01', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-01', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('99cb51e3-df8b-41a3-8119-7f0aa29bb9e5', '2026-10-01 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #38 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('27e6db98-0c74-45f0-8b4c-d953310f525b', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 39, '2026-10-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-02', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('00304a85-e32f-44c8-8c7d-3a6b7693d2af', '2026-10-02 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #39 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c24fe47e-9c16-40d2-a06e-102ba81dbd83', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 40, '2026-10-05', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-05', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('8549cd44-d9b8-418a-ab20-7d2a07658395', '2026-10-05 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #40 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('64cb0db3-efa2-4674-bc8f-194161be5f99', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 41, '2026-10-06', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-06', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('4963dde8-a907-49cb-a65c-3d0d2f626e8a', '2026-10-06 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #41 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c700b61e-4aa2-4cdf-b5aa-bcec88ed6e67', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 42, '2026-10-07', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-07', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9f0f3eb0-26c9-4546-9f67-298b599c3b8d', '2026-10-07 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #42 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('20c29090-f7a0-4ba3-97da-39b3c02aac6e', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 43, '2026-10-08', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-08', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('78d709cd-7be5-4e6c-ad44-0d8aace61a94', '2026-10-08 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #43 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ff4e3047-43bd-4547-b31a-6846e632938b', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 44, '2026-10-09', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-09', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('54789ded-f180-44f3-ab62-fe9d341f213f', '2026-10-09 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #44 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a598b802-c02c-424f-842d-bf64bab637eb', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 45, '2026-10-12', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-12', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('b563a696-ad2c-457a-86e0-54e89f0bb43c', '2026-10-12 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #45 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b93d6b12-9d84-4349-9ddd-e2ff3639edea', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 46, '2026-10-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-13', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c2822cac-5502-42d2-91d5-19298bbe088a', '2026-10-13 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #46 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f5367e83-5fbd-4f75-a342-b05dcad9bbd4', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 47, '2026-10-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-14', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('99768837-111e-41bd-b7e4-9feeb76bea3a', '2026-10-14 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #47 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b916cb1a-a2a3-4419-b58e-54efb908d326', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 48, '2026-10-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-15', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('2e62e55e-280a-456a-a85a-63b3d6ac0b88', '2026-10-15 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #48 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('07124327-da71-4be3-8980-9996f79105d2', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 49, '2026-10-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-16', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('7bfdd272-03de-4ccc-9f8f-e9415ccdddda', '2026-10-16 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #49 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('64f86e40-c7d8-4cc4-bb30-daf092c05b3a', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 50, '2026-10-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-19', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('a17c0737-78c0-45ad-8ffe-b030699a7005', '2026-10-19 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #50 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('69c20e2d-944a-4f92-81cb-daa2909754f3', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 51, '2026-10-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-20', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('697e298f-7c88-4688-8b02-5d596e615772', '2026-10-20 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #51 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cfe00656-bfab-45c8-a3b2-f42bd05ed138', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 52, '2026-10-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-21', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('6cc69d8c-722c-4ca8-9f71-c09f0046e74e', '2026-10-21 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #52 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cc76ef32-2960-4e32-9993-0fe85f9fb6b4', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 53, '2026-10-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-22', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('5ed174bd-23d1-4ece-a35b-9499ece24b29', '2026-10-22 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #53 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ae64cf55-47fb-4c6d-8ac7-5df73b3e7684', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 54, '2026-10-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-23', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('3da53df2-a66d-45b5-8563-b47af24b66fc', '2026-10-23 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #54 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1963614d-c410-40d2-a1fb-53f7e4c4bc81', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 55, '2026-10-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-26', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('12828413-5800-4a29-bf06-bf4461221791', '2026-10-26 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #55 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9f583915-ac49-41a8-86c4-09b6d70d817d', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 56, '2026-10-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-27', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('a2a206f6-0d2d-470c-aab1-341c734bd8f7', '2026-10-27 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #56 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d07e188d-3913-4036-9364-80e8bb84e042', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 57, '2026-10-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-28', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('acf98162-99b5-476f-a22c-e4d903af099b', '2026-10-28 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #57 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d777ac94-00fe-4f17-a875-48e94c31d48d', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 58, '2026-10-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-29', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('007db7a9-59c0-47d2-bf5b-29bea1389b2e', '2026-10-29 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #58 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2873ba6b-fc93-46da-ae68-1f9eb39ea318', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 59, '2026-10-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-30', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('220cc216-4e78-4173-ac47-18050b980c6c', '2026-10-30 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #59 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0cb877a1-54c1-42f6-8a13-6d835a8853d8', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', 60, '2026-11-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-02', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('4f3dd48b-a96b-4a77-aa6d-492dbf424a89', '2026-11-02 10:00:00+00', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #60 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_payoff_excess_records (id, repayment_id, loan_id, client_id, officer_id, branch_id, date, record_type, amount_paid, expected_installment, active_credit_settled, excess_amount, remaining_balance_before, remaining_balance_after, notes, created_at)
                        VALUES ('df3e8c68-2d19-4804-a3dc-34a36450343c', '4f3dd48b-a96b-4a77-aa6d-492dbf424a89', '6e9d1633-c60e-4f66-a57e-60a68b93d8b2', '05476019-cadc-4307-8a18-2eadb5439239', '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-02', 'PAYOFF', 1650.0, 1650.0, 99000.0, 0.0, 1650.0, 0.0, 'Full loan completion settlement', NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 150000.0, 150000.0, 2500.0, 150000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('05a1a18c-ba60-4509-9611-b8d4c9d9d949', '4484816d-7354-4316-aa7a-fd0b19509b85', 1, '2026-10-13', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-13', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('b7a1e3ac-f075-459b-b93e-ffcfe900ead9', '2026-10-13 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5c42d4ca-2030-424f-9b4d-b9b67d4241f5', '4484816d-7354-4316-aa7a-fd0b19509b85', 2, '2026-10-14', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-14', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ac1bcb14-d9f2-421a-b732-a9a5717c9d79', '2026-10-14 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('df2e3c26-82e8-42e2-9584-4da13feade07', '4484816d-7354-4316-aa7a-fd0b19509b85', 3, '2026-10-15', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-15', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('86cff0f3-6508-47d1-9ad9-8884a1d04aa3', '2026-10-15 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cfa661ff-5c62-4de4-bf21-8834b50b40ff', '4484816d-7354-4316-aa7a-fd0b19509b85', 4, '2026-10-16', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-16', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('a67e2168-2bc5-4444-b1b8-b99f675844f8', '2026-10-16 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('390e0c1c-c721-4a7b-8d76-0239cb485608', '4484816d-7354-4316-aa7a-fd0b19509b85', 5, '2026-10-19', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-19', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('7abac994-dcaf-4e07-a7f5-e6a2a72a8721', '2026-10-19 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c60fe12e-e4ff-4fec-9632-24a60d20a0c5', '4484816d-7354-4316-aa7a-fd0b19509b85', 6, '2026-10-20', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-20', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('e7c83047-5008-412a-8c8e-6bf7bba19405', '2026-10-20 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d9298640-e4b9-41c7-82f5-35de60705348', '4484816d-7354-4316-aa7a-fd0b19509b85', 7, '2026-10-21', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-21', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ab3a664f-e2b6-4a62-be2a-4cdb8b03e7be', '2026-10-21 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('34050777-727d-44b1-bc8d-b3494f65163c', '4484816d-7354-4316-aa7a-fd0b19509b85', 8, '2026-10-22', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-22', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('8534f69a-9d09-4429-8369-b2e7df5203f2', '2026-10-22 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ad0f054b-03c3-46fd-b3aa-b210feb639a5', '4484816d-7354-4316-aa7a-fd0b19509b85', 9, '2026-10-23', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-23', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('f89f1e21-8c3b-439b-b8d1-c5c42cc47bcd', '2026-10-23 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8e01ac24-806a-46b0-94b7-51f6844d5e6a', '4484816d-7354-4316-aa7a-fd0b19509b85', 10, '2026-10-26', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-26', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('63a711d6-5bc5-4e05-964d-86a6e55369c4', '2026-10-26 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('865ac4d8-1c52-433a-adc1-23138f458eed', '4484816d-7354-4316-aa7a-fd0b19509b85', 11, '2026-10-27', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-27', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('afd48a96-7607-44a7-8778-78a644d40755', '2026-10-27 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5c20734f-aa24-405e-9bf7-4a30d99f9c2c', '4484816d-7354-4316-aa7a-fd0b19509b85', 12, '2026-10-28', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-28', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('bc0c85e0-23dc-43e7-852c-11f245b04014', '2026-10-28 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('437189eb-ae3b-4ed5-b617-1cc73a1b2d86', '4484816d-7354-4316-aa7a-fd0b19509b85', 13, '2026-10-29', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-29', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('21d9cd89-dd1e-4648-b964-e46a2903b5b4', '2026-10-29 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e4e085a3-a6ce-4c7f-8a6c-d14db84c4af0', '4484816d-7354-4316-aa7a-fd0b19509b85', 14, '2026-10-30', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-10-30', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('d896048f-1ce5-4442-a07c-c5d90ce4240f', '2026-10-30 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7d76918e-801f-429f-a4f7-ac430465087b', '4484816d-7354-4316-aa7a-fd0b19509b85', 15, '2026-11-02', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-02', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('18f19da0-85d9-4afe-9e36-825993ea2c1d', '2026-11-02 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('08a4cb65-e2f5-4ae6-93df-3c04f9ce4ba1', '4484816d-7354-4316-aa7a-fd0b19509b85', 16, '2026-11-03', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-03', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('fce18cc9-feb9-491b-8bdc-5959f58a53c4', '2026-11-03 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bf6c2ea4-f32a-448e-bde4-ef58774d3af5', '4484816d-7354-4316-aa7a-fd0b19509b85', 17, '2026-11-04', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-04', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('55f53e10-3e60-4e14-a174-dcdc5eaa5bfc', '2026-11-04 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4aa2a93a-742c-44ca-822d-37f204c187fd', '4484816d-7354-4316-aa7a-fd0b19509b85', 18, '2026-11-05', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-05', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c97375d0-b73a-4854-97e6-6280703d2ad3', '2026-11-05 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b1d3117d-bef2-4650-8823-0ccf198c4002', '4484816d-7354-4316-aa7a-fd0b19509b85', 19, '2026-11-06', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-06', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('612ae2b7-734d-4a72-8af8-5cffa69d6df8', '2026-11-06 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0813d3f5-2c12-499b-8a12-3537eff00a2c', '4484816d-7354-4316-aa7a-fd0b19509b85', 20, '2026-11-09', 2500.0, 0.0, 0.0, 2500.0, 'Paid', '2026-11-09', 2500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('e93dd4ed-7174-4aeb-af58-665d0776429e', '2026-11-09 10:00:00+00', '4484816d-7354-4316-aa7a-fd0b19509b85', 'f90c5e3b-cd87-41a7-8676-8749861fb0aa', 2500.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', 'PAID', 2500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c719ef37-1fb7-4975-846f-ab2c9d585b2a', '4484816d-7354-4316-aa7a-fd0b19509b85', 21, '2026-11-10', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3a4f61f5-0040-4ef5-ba67-89f1429b2792', '4484816d-7354-4316-aa7a-fd0b19509b85', 22, '2026-11-11', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('05603983-a4c3-4de1-afd3-149f64fc0e81', '4484816d-7354-4316-aa7a-fd0b19509b85', 23, '2026-11-12', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53d23d90-ad0b-42d4-a88a-a40881def1c5', '4484816d-7354-4316-aa7a-fd0b19509b85', 24, '2026-11-13', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('acbc79f9-5534-4096-a8ac-b9997b0cc7f2', '4484816d-7354-4316-aa7a-fd0b19509b85', 25, '2026-11-16', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('52cbd36f-1f4e-401b-82fb-d2fc67acea31', '4484816d-7354-4316-aa7a-fd0b19509b85', 26, '2026-11-17', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('150b8d91-cf20-4143-ab5d-8ab0e8f6b627', '4484816d-7354-4316-aa7a-fd0b19509b85', 27, '2026-11-18', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6f3be3aa-df2b-4d17-a013-3699d6d72a93', '4484816d-7354-4316-aa7a-fd0b19509b85', 28, '2026-11-19', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ecc9e76f-5b6d-4763-af47-0b58a67501a8', '4484816d-7354-4316-aa7a-fd0b19509b85', 29, '2026-11-20', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('09403d04-07fc-46e4-8e55-6a21eb8d79b5', '4484816d-7354-4316-aa7a-fd0b19509b85', 30, '2026-11-23', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('57ca9cb4-700e-43dc-aaad-758b4c00e8b9', '4484816d-7354-4316-aa7a-fd0b19509b85', 31, '2026-11-24', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('87e47792-b9b5-4093-aa35-02335c0684dc', '4484816d-7354-4316-aa7a-fd0b19509b85', 32, '2026-11-25', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('846462c4-5790-4594-96cf-80bb1b6d7ab8', '4484816d-7354-4316-aa7a-fd0b19509b85', 33, '2026-11-26', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5f82033d-47f2-4062-af84-12151bf3dac3', '4484816d-7354-4316-aa7a-fd0b19509b85', 34, '2026-11-27', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('feace997-1e67-4fd8-bfad-23824a125508', '4484816d-7354-4316-aa7a-fd0b19509b85', 35, '2026-11-30', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('acd6d8d8-dc64-48a6-b496-088f04bb9203', '4484816d-7354-4316-aa7a-fd0b19509b85', 36, '2026-12-01', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('27eb8011-5f1d-4ec8-bb22-74373e37e6af', '4484816d-7354-4316-aa7a-fd0b19509b85', 37, '2026-12-02', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d81090c1-023c-4f22-a278-7cca2590c8ce', '4484816d-7354-4316-aa7a-fd0b19509b85', 38, '2026-12-03', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5062df0a-1f65-4b96-8f0c-d3189aacdd1f', '4484816d-7354-4316-aa7a-fd0b19509b85', 39, '2026-12-04', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2c2ab773-b0c4-49d4-a961-5cb32f3c7a9b', '4484816d-7354-4316-aa7a-fd0b19509b85', 40, '2026-12-07', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('939c3455-78a5-4fc1-be45-d8db136f7bf8', '4484816d-7354-4316-aa7a-fd0b19509b85', 41, '2026-12-08', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('63f44526-415a-4745-9ec3-66e465b373d0', '4484816d-7354-4316-aa7a-fd0b19509b85', 42, '2026-12-09', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1cb5dc89-9980-4c21-a0de-66efaa0644bd', '4484816d-7354-4316-aa7a-fd0b19509b85', 43, '2026-12-10', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eb3d84f9-b440-432c-ae40-be896804e1d3', '4484816d-7354-4316-aa7a-fd0b19509b85', 44, '2026-12-11', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0f797a59-c3e3-4eff-9a60-9ab083f33797', '4484816d-7354-4316-aa7a-fd0b19509b85', 45, '2026-12-14', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1aa9a0c5-0d6c-4eea-9517-914599484a0f', '4484816d-7354-4316-aa7a-fd0b19509b85', 46, '2026-12-15', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a067cc89-53a5-4f63-8df7-02fb95e95a32', '4484816d-7354-4316-aa7a-fd0b19509b85', 47, '2026-12-16', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8463d826-7b7a-4e4b-ab8e-d7dcaf3c1860', '4484816d-7354-4316-aa7a-fd0b19509b85', 48, '2026-12-17', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7fbc56a8-68d4-4aae-b56f-bc6aae59289e', '4484816d-7354-4316-aa7a-fd0b19509b85', 49, '2026-12-18', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2ff90d15-a06b-487e-be6e-ef995d5439d6', '4484816d-7354-4316-aa7a-fd0b19509b85', 50, '2026-12-21', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('24f3d578-6b81-49f0-978c-1875d5d8802d', '4484816d-7354-4316-aa7a-fd0b19509b85', 51, '2026-12-22', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7ed86b06-1fdb-4d11-875d-b541f72630b9', '4484816d-7354-4316-aa7a-fd0b19509b85', 52, '2026-12-23', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('02d454af-145d-42cd-aba7-af886e350f7d', '4484816d-7354-4316-aa7a-fd0b19509b85', 53, '2026-12-24', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a62a512e-5a87-4f12-89c6-7b16b225445d', '4484816d-7354-4316-aa7a-fd0b19509b85', 54, '2026-12-25', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8d6f70f0-1fed-4736-b1a5-cac58a568e28', '4484816d-7354-4316-aa7a-fd0b19509b85', 55, '2026-12-28', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('516588a7-25f6-4b0d-bcf7-5b602572676d', '4484816d-7354-4316-aa7a-fd0b19509b85', 56, '2026-12-29', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4cc08d89-3677-4279-8ba9-a6cdf0991776', '4484816d-7354-4316-aa7a-fd0b19509b85', 57, '2026-12-30', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4c50a094-fa14-40be-929f-bf2d6532fdb5', '4484816d-7354-4316-aa7a-fd0b19509b85', 58, '2026-12-31', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d0315840-ab3a-4e9a-97ca-a792ca71320a', '4484816d-7354-4316-aa7a-fd0b19509b85', 59, '2027-01-01', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('79df108e-a125-48e9-9717-ed7253913984', '4484816d-7354-4316-aa7a-fd0b19509b85', 60, '2027-01-04', 2500.0, 0.0, 0.0, 2500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 'c41b5775-6e19-4302-bd42-c14342f52592', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 96000.0, 800.0, 96000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-04-11', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e9fe19d0-7cdf-4b70-a8e1-23923e9fc47b', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 1, '2026-10-13', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-13', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('79883ec7-43cb-4148-909c-a1457b5b70c2', '2026-10-13 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d20a68f6-409b-4dfd-97d7-98314c936ab9', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 2, '2026-10-14', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-14', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('a9e1850c-9d82-4d48-b067-8f8bdca2f829', '2026-10-14 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3f0d90fe-2ad6-4718-ae22-1e1b0d314733', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 3, '2026-10-15', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-15', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('cf8e7f15-4e25-446b-aee5-b6bb0ff78495', '2026-10-15 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a312cde4-cd43-4e0d-bd8e-6a431a61deb0', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 4, '2026-10-16', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-16', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('022224e2-27e4-405d-aff7-db209a7ae1af', '2026-10-16 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('494cb33b-a5c1-4ff6-87dc-774e85dc98a6', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 5, '2026-10-19', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-19', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ea5e2dd1-4277-47d2-899d-168dba8d9cc0', '2026-10-19 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7afcc81e-da86-4a4e-89f5-196067a6e2b1', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 6, '2026-10-20', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-20', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('8e9f2696-db30-4457-8667-7750fcf0f2bf', '2026-10-20 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('18961e3d-5917-4861-9f89-047c50e6a9e5', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 7, '2026-10-21', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-21', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('51d700d0-e525-4b95-968e-7aeda3e326e5', '2026-10-21 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4b5c7600-e799-4fc7-9a68-78a0d8a6a386', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 8, '2026-10-22', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-22', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('4b16e9d0-17e9-4e7c-9cfb-ddbc2dfef503', '2026-10-22 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('66261e13-8cb6-46fb-b791-6a225477f3d3', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 9, '2026-10-23', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-23', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('32003bfe-c00a-4004-9a04-4a6a01ae5f0a', '2026-10-23 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('43fe8c0c-0ff8-4906-ae87-51f5349fca80', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 10, '2026-10-26', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-26', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('4cc64a76-f37c-44c2-bee7-c8da19826074', '2026-10-26 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a7271335-7b85-4feb-95fc-6fb9d1998326', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 11, '2026-10-27', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-27', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('1946d3f3-cfe4-46f7-82fa-f9db65fb92ba', '2026-10-27 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7daf2600-584b-4271-9ebb-99720230e9fe', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 12, '2026-10-28', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-28', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('b03e253f-e957-47fa-9ba0-cd3122ac69d9', '2026-10-28 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('de8b556e-99cc-4223-9073-15b7a6280c63', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 13, '2026-10-29', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-29', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('4d0e1bb2-d6c2-434b-bc97-98c50c076f91', '2026-10-29 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2935dce0-e921-48c0-8802-d6281d540577', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 14, '2026-10-30', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-10-30', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('51143bc8-b2d8-4728-85f0-e53a85e0b0fa', '2026-10-30 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a3345834-9bdd-4b8a-b696-642a9b5f8e8c', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 15, '2026-11-02', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-02', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('496dbf33-0299-46ca-9535-59fb0a799e09', '2026-11-02 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('01751ada-0658-4d3e-904c-d85335d1b4ab', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 16, '2026-11-03', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-03', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('f6fc728f-cad0-455c-8291-c0f3949e0a7e', '2026-11-03 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('44792142-8ae8-44b3-9dad-b80336a0c8df', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 17, '2026-11-04', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-04', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('531a968a-6c90-4264-8293-3b9bd3dda084', '2026-11-04 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c85794ea-27e9-4deb-ba50-81132257af1c', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 18, '2026-11-05', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-05', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('26030a20-28c1-48db-abb1-be154d94fcdb', '2026-11-05 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #18 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b6ddda28-253b-48f5-bda4-e2f1cc519819', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 19, '2026-11-06', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-06', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c8d532da-a2c5-4a9e-8fce-86b07026ad1e', '2026-11-06 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #19 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('434cdf3a-b894-4563-bbd2-2da3857326f0', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 20, '2026-11-09', 800.0, 0.0, 0.0, 800.0, 'Paid', '2026-11-09', 800.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ab06b20a-3b4f-4d3e-ac1f-0ab4e3553377', '2026-11-09 10:00:00+00', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 'c3c95953-af7a-480a-93ef-f488d7b2dba6', 800.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #20 Collection', 'Cash', 'PAID', 800.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dd2711ff-7434-42aa-8738-68b48e7e8c4d', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 21, '2026-11-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c1034ec6-2c99-41a9-b61f-f73e7bef2778', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 22, '2026-11-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('95d1701e-4061-4c52-a6bb-dc0f8f370ff3', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 23, '2026-11-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('26c14976-aa6f-4931-986c-320f343d0374', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 24, '2026-11-13', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f66b2d34-1919-4887-adf6-be29ded9d774', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 25, '2026-11-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a48f2976-9193-4767-b271-6c17338c74b2', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 26, '2026-11-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e9a3eeae-4864-4b39-93d2-af376e8ed6c6', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 27, '2026-11-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4ad01150-eb57-4af0-956d-f5e2e251edae', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 28, '2026-11-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e65ad33f-33a3-466d-9bbd-0a2857e0e766', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 29, '2026-11-20', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e3076cad-e470-462d-97d1-b90cdd415aef', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 30, '2026-11-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('89f53978-d75b-4f42-98b2-1a42d9ecc8f2', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 31, '2026-11-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c8d79c6b-fd3a-494a-abc2-97ab14c8c8d6', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 32, '2026-11-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3b04c6f2-4652-4a1c-88bb-4818bbee6a66', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 33, '2026-11-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9b154198-ba81-49a3-a0f2-2d7d69d334af', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 34, '2026-11-27', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fae7b0ec-4ea8-4492-8fa6-ac26c42be2a3', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 35, '2026-11-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('013b9e63-ae46-4173-85ea-66e1bc24fe3f', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 36, '2026-12-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('689e92aa-244c-4bc8-a711-b577ffef29eb', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 37, '2026-12-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('22dc6680-6235-4fa0-86f7-20803d8c11a0', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 38, '2026-12-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('099ce96c-13fe-4e3d-9b01-fce92fc33f1d', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 39, '2026-12-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6bb46747-21b6-4afd-b266-0d36a5f4ecff', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 40, '2026-12-07', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e6510d86-99c2-4e98-94db-d8809dd9c4cb', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 41, '2026-12-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6b1791d7-9b3b-4dac-85fc-dac722770919', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 42, '2026-12-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ac975c56-ccd5-44c9-b23b-5e00b17b0214', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 43, '2026-12-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('13e1f467-a0b8-402c-b231-89ae8b3289cf', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 44, '2026-12-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1d9739cf-9de3-4010-8af9-359d5365a283', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 45, '2026-12-14', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d92beb5a-2443-40b5-a723-bca7a8059244', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 46, '2026-12-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7570c6b0-f788-4248-92b2-c0ad2bc7e416', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 47, '2026-12-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1963bc5e-13fd-4221-b6d7-71c41d41e7a7', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 48, '2026-12-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('306e164a-c724-4384-b34d-ef2b3d8a2a3a', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 49, '2026-12-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2d82171a-da97-440e-8a0e-dda44d87fb44', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 50, '2026-12-21', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7ab770df-3677-4b24-949d-6e4ef2a5689d', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 51, '2026-12-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('76415edf-d65a-4bf4-baa8-198b02edd62e', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 52, '2026-12-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53aa8fc7-78f2-45cf-9ec7-e3aa42f49fcd', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 53, '2026-12-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fe38b002-d82d-4d83-8fc5-21a2a2fe5288', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 54, '2026-12-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8d4130ee-0bed-478c-848f-ba7d8ef9a485', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 55, '2026-12-28', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4756192c-8dd2-4963-8f4c-1d892dfdcf13', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 56, '2026-12-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('63056972-dda0-419a-8558-c00f0dcf5107', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 57, '2026-12-30', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8c6c138d-8b39-4acb-a54b-cb63d8d6f6c0', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 58, '2026-12-31', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f3facfbc-0801-46b2-838e-7dbb2840d245', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 59, '2027-01-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5f05e6c4-7c4c-4ff2-9e23-95dbe5b22d4b', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 60, '2027-01-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fbdeca14-ce31-404b-9589-fd27eb4c420a', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 61, '2027-01-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fa282cfa-537e-4396-9842-4bd71fb502db', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 62, '2027-01-06', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('80c44d71-5bcb-40b7-b787-d6d0c50ca907', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 63, '2027-01-07', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f5fe1a0c-de65-4b1b-aaf4-c4d71a9b26ab', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 64, '2027-01-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7d0891e4-e66a-4fda-89e5-8bb817601122', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 65, '2027-01-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('985917a2-d520-4a80-ad92-9e5ab012a509', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 66, '2027-01-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a7f60a8a-3d74-46d2-bb0b-37d0b6b2c06b', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 67, '2027-01-13', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('74a52724-127c-4b94-b76c-f0323644acc5', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 68, '2027-01-14', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('25192552-f13d-420c-aa3e-57ca7df3b9dd', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 69, '2027-01-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b2e90492-ab1e-44b0-8562-cb5c13fc0905', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 70, '2027-01-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('428e5ec4-a205-4f50-a0df-ddba20bd74bc', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 71, '2027-01-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bcf5369a-1799-4afc-813e-1103dad078f5', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 72, '2027-01-20', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('203d39de-115d-4c78-a7d8-c4462a5a6816', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 73, '2027-01-21', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('eae94e2c-376d-460e-90dc-e9f77dcd7b9f', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 74, '2027-01-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('034dfd6d-687d-4e5a-8f5d-0a43513cc772', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 75, '2027-01-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2ecb6ba8-3c38-49ed-8993-e97b5340c704', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 76, '2027-01-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('17b98340-fc35-4716-8c5f-2a7d1c7cd017', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 77, '2027-01-27', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a8a46dc1-3b7d-407e-b083-37e8581dc024', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 78, '2027-01-28', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6abf9f22-1ecc-4b1e-8e8e-6bf884f1073d', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 79, '2027-01-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3c8808f2-b33d-45eb-8c9c-912b733ef092', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 80, '2027-02-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9338c7c2-b174-4f67-af09-0cc0b91493f2', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 81, '2027-02-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('134dff9c-1a75-499c-b846-37ca47026dbf', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 82, '2027-02-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('266050f3-cadc-47e9-98b9-6e09ab8f68b8', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 83, '2027-02-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ed9e313f-aa34-41a1-80c2-b4993165c776', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 84, '2027-02-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b8797b8c-79d0-4e31-aa0f-d5bbe56c4622', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 85, '2027-02-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d803787e-f2cd-415c-a822-5e381adbcac3', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 86, '2027-02-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bfcb648a-8210-4af4-bd8a-3f01258ce33f', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 87, '2027-02-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e1488ac1-2eda-419b-9e61-30376965067a', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 88, '2027-02-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('86e9a254-c5cb-49e2-b11d-620046a2d113', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 89, '2027-02-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b3db8cbf-2a32-4137-9082-c8b2844bc7a5', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 90, '2027-02-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1df6860d-369e-4113-8c09-345ec6982bfe', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 91, '2027-02-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e5583cef-feb5-436c-853b-c66140432f88', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 92, '2027-02-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('438c5f71-f449-4ff3-90ec-8c52c67e7ab6', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 93, '2027-02-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b6d86ab3-65a3-4739-aa07-add89450f2cc', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 94, '2027-02-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5ddab9ae-5029-463e-8ded-ebd5ebd04f9a', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 95, '2027-02-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f2123596-1067-4fde-a8cd-584010e0ad04', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 96, '2027-02-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e21c2da9-07c8-4e16-9b16-e188d19841e4', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 97, '2027-02-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fd8ad9f4-ff71-4290-a194-8c996f77edb5', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 98, '2027-02-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('07477ba9-2619-4429-843f-2316f91cea62', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 99, '2027-02-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ed62696f-a122-4496-8850-e2ff27e6aa28', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 100, '2027-03-01', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9f58e970-c8b6-44ee-adaf-fb37d65f58cb', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 101, '2027-03-02', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dda9f337-4b63-4cd7-8552-18dcb7569e36', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 102, '2027-03-03', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('aa904059-8563-48af-ba0a-374d3bbca9bf', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 103, '2027-03-04', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dabf762a-8554-452b-b55e-ac3d3c05eed2', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 104, '2027-03-05', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('532a641a-61f4-4872-b205-4d50c257b224', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 105, '2027-03-08', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bc6bb056-51c2-4522-838c-a7790ec8fdca', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 106, '2027-03-09', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5eca6d88-9ba9-49fc-ad99-24b2adfd22f2', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 107, '2027-03-10', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a2ac689d-2b39-454a-8830-a9f58d3c9f65', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 108, '2027-03-11', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b5f5b83a-18ac-4901-ab5c-bccb32d769a1', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 109, '2027-03-12', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fcfbfafa-3d9f-4214-a570-89feec9ebc18', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 110, '2027-03-15', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('18a290b0-dfca-4d96-a25e-7eb9255282f7', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 111, '2027-03-16', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('92a4dd43-eb16-4449-9131-3efd5459253e', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 112, '2027-03-17', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b90ec8a2-7bf7-41ee-9484-9e5466844f31', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 113, '2027-03-18', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('93f4880c-582b-4923-895a-36b9a5915f02', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 114, '2027-03-19', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8d7c0c98-91b0-4aa7-9a7a-a2d8af7a8230', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 115, '2027-03-22', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6b0c5220-a34b-4bd0-9115-497803a6cf45', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 116, '2027-03-23', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('224ec30b-6487-49ae-8441-deb968a09d6d', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 117, '2027-03-24', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('655e2501-c28d-4a3b-b138-79c8a54ffb96', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 118, '2027-03-25', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2b2a58e4-4151-4a8c-b51d-0922fe1f3632', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 119, '2027-03-26', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('53321ae4-dfbe-46c9-99df-c875fc97b813', 'bf02a664-700d-4bac-bc24-3a00c3087dd5', 120, '2027-03-29', 800.0, 0.0, 0.0, 800.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 99000.0, 1650.0, 99000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('15bb8c36-b01e-49b9-b97b-43259e692896', 'c207f34b-f9a2-4602-8840-01308d241aa1', 1, '2026-10-13', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-13', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('05a80c7c-3a1e-4609-a4b5-12446d2841a8', '2026-10-13 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8d208955-35ae-466a-898b-644135a4f45a', 'c207f34b-f9a2-4602-8840-01308d241aa1', 2, '2026-10-14', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-14', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('76df885f-dbce-4551-891e-bab3b94e14f8', '2026-10-14 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a8a22dac-0d00-4531-8bd8-7d21e4953fc0', 'c207f34b-f9a2-4602-8840-01308d241aa1', 3, '2026-10-15', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-15', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('1fb52401-740c-4def-857f-42431d05d5b0', '2026-10-15 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dae6462c-cdaa-4dfe-882e-0167a9675930', 'c207f34b-f9a2-4602-8840-01308d241aa1', 4, '2026-10-16', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-16', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('fa881f5a-82d2-46ac-b847-f48d505f4f40', '2026-10-16 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('23c18dc4-801b-4822-9c6b-abdf89030783', 'c207f34b-f9a2-4602-8840-01308d241aa1', 5, '2026-10-19', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-19', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('b3de0317-91dd-4740-9cc7-23ec73d3ae67', '2026-10-19 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b9ba2d19-0afe-40d0-b64a-11f950f52ac7', 'c207f34b-f9a2-4602-8840-01308d241aa1', 6, '2026-10-20', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-20', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('b54e488b-3e19-4707-9fb0-0368e49efe66', '2026-10-20 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0f876fb5-a903-4416-b1ee-35a943138b29', 'c207f34b-f9a2-4602-8840-01308d241aa1', 7, '2026-10-21', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-21', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('084b32c4-bece-4c2d-bbfe-9e37d33a59b1', '2026-10-21 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c0c29b40-8b75-48c7-95e4-a854392de303', 'c207f34b-f9a2-4602-8840-01308d241aa1', 8, '2026-10-22', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-22', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('379897cc-1219-45da-b960-96c0ff1663f7', '2026-10-22 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e17595eb-e38e-4740-ac11-b10a3ec15133', 'c207f34b-f9a2-4602-8840-01308d241aa1', 9, '2026-10-23', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-23', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('5869e509-f4fd-44b1-a2fa-351d6773ec33', '2026-10-23 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d7250ef2-2111-4577-aa20-2457b3dd27b0', 'c207f34b-f9a2-4602-8840-01308d241aa1', 10, '2026-10-26', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-26', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('479e3707-ff80-45a4-b5e0-289cdae1164d', '2026-10-26 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('deb91ecc-60ab-4010-a471-0e212e5742c6', 'c207f34b-f9a2-4602-8840-01308d241aa1', 11, '2026-10-27', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-27', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9b0043c5-99ab-46c1-a2ab-1bb5f89225da', '2026-10-27 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ba88bb4a-3720-41eb-be7a-f073263ec124', 'c207f34b-f9a2-4602-8840-01308d241aa1', 12, '2026-10-28', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-28', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c8d8fc8a-43e0-4402-968d-40c1b896ef17', '2026-10-28 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2df7b5e4-72b6-4d7b-bac4-2c4d4c1f44cc', 'c207f34b-f9a2-4602-8840-01308d241aa1', 13, '2026-10-29', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-29', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('8fa46f41-bba4-4eb1-ad06-721a0f9ac4d0', '2026-10-29 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #13 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b9256366-579d-418a-b4aa-357d08b67a38', 'c207f34b-f9a2-4602-8840-01308d241aa1', 14, '2026-10-30', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-10-30', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('dae34305-097e-4d75-be30-d5898625d7e8', '2026-10-30 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #14 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ccac2125-e718-489d-8986-9c47319aeeca', 'c207f34b-f9a2-4602-8840-01308d241aa1', 15, '2026-11-02', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-02', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ca84b0ab-a6e1-4791-a67a-6f46cb028e36', '2026-11-02 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #15 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cd86ce16-e441-4fb5-8ed5-f989f5c427e1', 'c207f34b-f9a2-4602-8840-01308d241aa1', 16, '2026-11-03', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-03', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('b127d459-dca7-4f1f-ab47-2bd69ce1033c', '2026-11-03 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #16 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c7b2dc63-7376-480c-9acd-766592162f0a', 'c207f34b-f9a2-4602-8840-01308d241aa1', 17, '2026-11-04', 1650.0, 0.0, 0.0, 1650.0, 'Paid', '2026-11-04', 1650.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('85c3ab0d-37db-4f87-b90e-6af28413566b', '2026-11-04 10:00:00+00', 'c207f34b-f9a2-4602-8840-01308d241aa1', '8ee891ff-b77c-4068-9d73-5528259e485f', 1650.0, '7ca80002-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #17 Collection', 'Cash', 'PAID', 1650.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('57333445-392c-4672-9858-c46067a47085', 'c207f34b-f9a2-4602-8840-01308d241aa1', 18, '2026-11-05', 1650.0, 0.0, 0.0, 1650.0, 'Overdue', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cce4d3f3-9e08-4745-b734-fd1d47907b30', 'c207f34b-f9a2-4602-8840-01308d241aa1', 19, '2026-11-06', 1650.0, 0.0, 0.0, 1650.0, 'Overdue', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('aee4fc6a-313e-4b89-8c3e-2721df97088a', 'c207f34b-f9a2-4602-8840-01308d241aa1', 20, '2026-11-09', 1650.0, 0.0, 0.0, 1650.0, 'Overdue', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a344a6c4-587e-4ed1-9789-64cd50372f05', 'c207f34b-f9a2-4602-8840-01308d241aa1', 21, '2026-11-10', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b9cc7cb4-844b-43c9-b8f7-8258d0709d09', 'c207f34b-f9a2-4602-8840-01308d241aa1', 22, '2026-11-11', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9fbd7183-99bf-433c-bb4c-4d4051e915f2', 'c207f34b-f9a2-4602-8840-01308d241aa1', 23, '2026-11-12', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('dd0ddd64-1b97-44e7-9e29-43777f62d338', 'c207f34b-f9a2-4602-8840-01308d241aa1', 24, '2026-11-13', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ec20b105-c054-45f1-8654-c7cc5d71469f', 'c207f34b-f9a2-4602-8840-01308d241aa1', 25, '2026-11-16', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e8ae1dc0-463d-4239-8a99-39dc6a904f75', 'c207f34b-f9a2-4602-8840-01308d241aa1', 26, '2026-11-17', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f130a0ab-84cf-4362-b2b0-03637a795fc6', 'c207f34b-f9a2-4602-8840-01308d241aa1', 27, '2026-11-18', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a1eae75f-1d37-4f5d-9a03-a50994329f0e', 'c207f34b-f9a2-4602-8840-01308d241aa1', 28, '2026-11-19', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3327f84b-b956-43cc-92e5-453dbb79b4c3', 'c207f34b-f9a2-4602-8840-01308d241aa1', 29, '2026-11-20', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5f9197f0-b98c-4448-b9d5-fb185581ea43', 'c207f34b-f9a2-4602-8840-01308d241aa1', 30, '2026-11-23', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('14e2448f-730a-4499-b6ac-8896e6ef4251', 'c207f34b-f9a2-4602-8840-01308d241aa1', 31, '2026-11-24', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('14a16886-a4df-43d4-a646-f976baae7959', 'c207f34b-f9a2-4602-8840-01308d241aa1', 32, '2026-11-25', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('818e6811-f688-48cc-8a86-166838e9ab89', 'c207f34b-f9a2-4602-8840-01308d241aa1', 33, '2026-11-26', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bc742850-e554-4676-b1bd-67a1af85c68d', 'c207f34b-f9a2-4602-8840-01308d241aa1', 34, '2026-11-27', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4f301aa1-70d0-4547-b6f7-87a03f26c518', 'c207f34b-f9a2-4602-8840-01308d241aa1', 35, '2026-11-30', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c4d029b6-9df2-416f-83da-9837ac933ca6', 'c207f34b-f9a2-4602-8840-01308d241aa1', 36, '2026-12-01', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('06efc7a9-d70e-4c07-8ffc-e3069a908da6', 'c207f34b-f9a2-4602-8840-01308d241aa1', 37, '2026-12-02', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b1bbc0da-63aa-4472-aae4-be4b7a71e804', 'c207f34b-f9a2-4602-8840-01308d241aa1', 38, '2026-12-03', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8f07ef86-2c80-46ec-9eba-91eac704adbd', 'c207f34b-f9a2-4602-8840-01308d241aa1', 39, '2026-12-04', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('904fe74f-bff7-40e1-aab3-59461d6aa912', 'c207f34b-f9a2-4602-8840-01308d241aa1', 40, '2026-12-07', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('682ad375-0e9f-4ec2-8410-8ba8ef383fff', 'c207f34b-f9a2-4602-8840-01308d241aa1', 41, '2026-12-08', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fad52d4d-54e1-47b5-9166-65598d035fc1', 'c207f34b-f9a2-4602-8840-01308d241aa1', 42, '2026-12-09', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('04633d36-2e1c-430e-bf28-65c76b5ffedf', 'c207f34b-f9a2-4602-8840-01308d241aa1', 43, '2026-12-10', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('119d2e43-ab6d-4395-83c9-3652ca9b7439', 'c207f34b-f9a2-4602-8840-01308d241aa1', 44, '2026-12-11', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0e8cac52-21d8-4dc1-b886-52ccaf2f7700', 'c207f34b-f9a2-4602-8840-01308d241aa1', 45, '2026-12-14', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5eed1b09-5117-4ff6-b92b-39f96d329e0e', 'c207f34b-f9a2-4602-8840-01308d241aa1', 46, '2026-12-15', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('660f42b6-6429-4f23-bc4d-d5333806aa81', 'c207f34b-f9a2-4602-8840-01308d241aa1', 47, '2026-12-16', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4f8e7f9d-8aa4-48cc-970b-9f8cac8b17ae', 'c207f34b-f9a2-4602-8840-01308d241aa1', 48, '2026-12-17', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2a3be260-31e5-45db-b427-4fedc290bbbc', 'c207f34b-f9a2-4602-8840-01308d241aa1', 49, '2026-12-18', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5d3b4c4f-daca-434c-ae43-c175431fb287', 'c207f34b-f9a2-4602-8840-01308d241aa1', 50, '2026-12-21', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2c9110bf-b677-4911-96a5-91acb1ab6445', 'c207f34b-f9a2-4602-8840-01308d241aa1', 51, '2026-12-22', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a9037d8b-9eb5-43de-95b2-503d2701ef83', 'c207f34b-f9a2-4602-8840-01308d241aa1', 52, '2026-12-23', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e55f7123-b74a-460e-b994-169ed00a43bd', 'c207f34b-f9a2-4602-8840-01308d241aa1', 53, '2026-12-24', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a4d0c3db-d4e3-400d-8114-e7a72b41c65d', 'c207f34b-f9a2-4602-8840-01308d241aa1', 54, '2026-12-25', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8e8afd4c-9002-40cf-a017-69d04449059d', 'c207f34b-f9a2-4602-8840-01308d241aa1', 55, '2026-12-28', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f12acbbe-bffe-4a64-bb67-bad24466a3f9', 'c207f34b-f9a2-4602-8840-01308d241aa1', 56, '2026-12-29', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('30e4c06d-287e-432e-a91c-e0766974ce30', 'c207f34b-f9a2-4602-8840-01308d241aa1', 57, '2026-12-30', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8fa03c05-ebea-4c17-90c0-3f44e5cd6d3a', 'c207f34b-f9a2-4602-8840-01308d241aa1', 58, '2026-12-31', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('de067d15-d3ed-4300-9693-236188e1e445', 'c207f34b-f9a2-4602-8840-01308d241aa1', 59, '2027-01-01', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d9910cb3-1110-4eba-ad4c-796939445d5d', 'c207f34b-f9a2-4602-8840-01308d241aa1', 60, '2027-01-04', 1650.0, 0.0, 0.0, 1650.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('dc122bf3-016d-43f4-931e-1c8d045fc1d5', '746b4c5d-8760-4a6f-9284-d3c584d4146e', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 99000.0, 8250.0, 99000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-05', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ddc8c43b-23ff-4637-8c82-a6c79b666b80', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 1, '2026-10-13', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-13', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('5e90660f-a2bb-433d-b06f-70f73e2f8413', '2026-10-13 10:00:00+00', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', '746b4c5d-8760-4a6f-9284-d3c584d4146e', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('cfdd0719-6f40-4da4-8315-6e8e2206cba2', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 2, '2026-10-20', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-20', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9af2dc48-0c79-4856-a4f5-941bdf5df4fd', '2026-10-20 10:00:00+00', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', '746b4c5d-8760-4a6f-9284-d3c584d4146e', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7a2dd4ae-9e0a-47f5-9ef5-67400fca8674', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 3, '2026-10-27', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-27', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9474166c-c2dc-47b1-8ddc-1a3c0147915f', '2026-10-27 10:00:00+00', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', '746b4c5d-8760-4a6f-9284-d3c584d4146e', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a1a3bede-372c-437a-879b-8d8a005e2d20', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 4, '2026-11-03', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-11-03', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('f7b133ba-3ad7-4680-99aa-f3540743ee73', '2026-11-03 10:00:00+00', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', '746b4c5d-8760-4a6f-9284-d3c584d4146e', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4b6444d4-d462-4c2b-ab78-35c8523a4fae', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 5, '2026-11-10', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c04eb96f-adb3-4675-8d49-c4eddfdcf69b', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 6, '2026-11-17', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('83e35291-4d88-43bb-932a-1082c3f85008', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 7, '2026-11-24', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a0f88fb2-7ace-4873-96ee-ce0412540226', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 8, '2026-12-01', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0a186429-c7e3-41f0-b60c-09146c35c03d', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 9, '2026-12-08', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2ccc1745-f033-4ca3-995a-59adc95a18bc', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 10, '2026-12-15', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('007773af-60c9-48fb-b406-0ac4703a4be8', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 11, '2026-12-22', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('99d553c9-3ff0-4a22-b820-74e1d526b313', 'dc122bf3-016d-43f4-931e-1c8d045fc1d5', 12, '2026-12-29', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('11a48b0a-084e-4762-9f4e-29c86b82cacd', '53bed5f0-0a20-432e-9f88-bb2ebbdb00f4', 'c090f418-d2c1-4855-ab87-88e25589c471', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 96000.0, 4000.0, 96000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-03-30', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('34021b05-e312-40db-af24-e047960f2ef6', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 1, '2026-10-13', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-10-13', 4000.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('53d7522c-83bc-49de-9532-83e0f283df27', '2026-10-13 10:00:00+00', '11a48b0a-084e-4762-9f4e-29c86b82cacd', '53bed5f0-0a20-432e-9f88-bb2ebbdb00f4', 4000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 4000.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5202e28c-450e-4d36-a94b-0b9553f441c2', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 2, '2026-10-20', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-10-20', 4000.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('7d78b7b9-df6a-4a28-a085-c04fa2f6ed51', '2026-10-20 10:00:00+00', '11a48b0a-084e-4762-9f4e-29c86b82cacd', '53bed5f0-0a20-432e-9f88-bb2ebbdb00f4', 4000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 4000.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d292fc65-f78c-46eb-8c80-01bf5de91059', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 3, '2026-10-27', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-10-27', 4000.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('3dd1acc2-43e8-467f-8bfb-3869f1fd93f1', '2026-10-27 10:00:00+00', '11a48b0a-084e-4762-9f4e-29c86b82cacd', '53bed5f0-0a20-432e-9f88-bb2ebbdb00f4', 4000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 4000.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('84225bb5-093d-4370-b886-cea160be3df4', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 4, '2026-11-03', 4000.0, 0.0, 0.0, 4000.0, 'Paid', '2026-11-03', 4000.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c0e45408-84ab-4a53-9509-8c3897cba895', '2026-11-03 10:00:00+00', '11a48b0a-084e-4762-9f4e-29c86b82cacd', '53bed5f0-0a20-432e-9f88-bb2ebbdb00f4', 4000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 4000.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('18d6cba2-70c4-454f-8a31-3f82b1e2330d', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 5, '2026-11-10', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('43ea99ae-6c0f-418e-ba6f-ac775d812281', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 6, '2026-11-17', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('724b00f1-a8e2-478f-ab04-aa2e53459b7a', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 7, '2026-11-24', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('77df920e-3533-4bef-ab60-f2b08c0617da', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 8, '2026-12-01', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6fd93361-2112-44b3-98a5-a2101c26cf3e', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 9, '2026-12-08', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f2734102-72d1-41a0-8ca7-9297550ccc06', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 10, '2026-12-15', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('90bc0af9-39dc-4c13-9446-5558396f2af2', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 11, '2026-12-22', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ce35be40-08a2-4443-8f03-d7c0781e98fb', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 12, '2026-12-29', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0bdf3871-be64-4082-9ac6-13004e65a01a', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 13, '2027-01-05', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f5028b45-1aeb-4faf-9c5c-929f850205f5', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 14, '2027-01-12', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('691d1bed-0288-4693-b93f-f35426d08c01', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 15, '2027-01-19', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('f29de2b3-a9d5-4d37-8a10-d182e9d25664', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 16, '2027-01-26', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('194ebe84-d233-417a-98f5-a79f58a2ea7b', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 17, '2027-02-02', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('69db0745-5c64-49b4-928f-0f9f0fc585d6', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 18, '2027-02-09', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('47624c94-72fe-4731-a3dd-881d4921b4fe', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 19, '2027-02-16', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6e7a0a61-a25f-4ad1-944d-6d243959d939', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 20, '2027-02-23', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4dc6d56d-12cd-4e69-acf8-a88d99a8b28d', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 21, '2027-03-02', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0749b470-c484-4e11-937d-9904bdf01361', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 22, '2027-03-09', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e860540b-7f81-4246-8c81-d7d56a331785', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 23, '2027-03-16', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('42ba4144-868e-407b-ad33-72455c043a8a', '11a48b0a-084e-4762-9f4e-29c86b82cacd', 24, '2027-03-23', 4000.0, 0.0, 0.0, 4000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('2ff6f759-c8f8-4780-8ed5-dda4477efc6c', '0a969dba-e37a-453a-a272-8d50dd5004f2', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 200000.0, 198000.0, 16500.0, 198000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-05', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1fd0d38f-e607-4a91-8c48-e61004b71c94', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 1, '2026-10-13', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-10-13', 16500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c22d8ddd-cfa6-49cf-a3e1-076aae531f35', '2026-10-13 10:00:00+00', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', '0a969dba-e37a-453a-a272-8d50dd5004f2', 16500.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 16500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('5e9f33dd-039a-44f0-ad65-84f94a7d6ef0', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 2, '2026-10-20', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-10-20', 16500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('8ff99d81-a3bc-4f21-9340-20ffed21ef66', '2026-10-20 10:00:00+00', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', '0a969dba-e37a-453a-a272-8d50dd5004f2', 16500.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 16500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7904d826-ec2e-4976-b33a-0ebaf070cdcf', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 3, '2026-10-27', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-10-27', 16500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('543b55d4-562c-4ddb-bbc6-a28764623abc', '2026-10-27 10:00:00+00', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', '0a969dba-e37a-453a-a272-8d50dd5004f2', 16500.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 16500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1c131d58-57fc-444a-b705-d26932dc5812', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 4, '2026-11-03', 16500.0, 0.0, 0.0, 16500.0, 'Paid', '2026-11-03', 16500.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('706c5f27-7305-45ab-9ab4-7304f0c56126', '2026-11-03 10:00:00+00', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', '0a969dba-e37a-453a-a272-8d50dd5004f2', 16500.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 16500.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9b3a7230-8b52-4b75-a745-3a7ab182e939', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 5, '2026-11-10', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8bb93893-8ea4-4863-802c-94aa15a7ef69', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 6, '2026-11-17', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2a1543c1-1348-47fb-9da9-ddac0a1f8fcb', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 7, '2026-11-24', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('891d56a8-dd7e-414e-a790-f8a699140487', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 8, '2026-12-01', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('9bff3daf-997d-4c1d-b828-f93aae8d9c78', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 9, '2026-12-08', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('57402666-e603-4ac5-bf76-f67f9ad74fc0', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 10, '2026-12-15', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2a9e9b12-1ea6-43a9-b657-ba2e5b2b091c', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 11, '2026-12-22', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('91b0466d-7cd1-4e70-906a-948f15e8fa6b', '2ff6f759-c8f8-4780-8ed5-dda4477efc6c', 12, '2026-12-29', 16500.0, 0.0, 0.0, 16500.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-07-20', 100000.0, 99000.0, 8250.0, 99000.0, 'Completed', 'Finance', '2026-07-20', '2026-07-21', '2026-10-13', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4608c3b0-0c1f-4eeb-adaa-1e1aaabded5f', 'a2f7e95e-6211-495c-b111-21d749f7b582', 1, '2026-07-21', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-07-21', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('fc619151-7b70-4a4e-b535-9e17d8ce1546', '2026-07-21 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('91f9a935-f059-4de3-ad55-39bcebece979', 'a2f7e95e-6211-495c-b111-21d749f7b582', 2, '2026-07-28', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-07-28', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('8c3b7598-4064-429f-8ab6-2e0acdd1fa28', '2026-07-28 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('aef6ecd3-b138-401e-b894-c693f1a8853e', 'a2f7e95e-6211-495c-b111-21d749f7b582', 3, '2026-08-04', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-04', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('fdaf3853-c856-4b5d-94bb-4e58389c1a03', '2026-08-04 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3a20aaaa-c671-4976-97da-a97918719565', 'a2f7e95e-6211-495c-b111-21d749f7b582', 4, '2026-08-11', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-11', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('25357e87-a1a3-4051-82c6-1446aa399093', '2026-08-11 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #4 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a4042b3b-0b82-4206-b36a-773001f4e338', 'a2f7e95e-6211-495c-b111-21d749f7b582', 5, '2026-08-18', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-18', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('44a38642-9d9b-412a-a74e-1bc3ed511aba', '2026-08-18 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #5 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('c80e20cd-42ac-44b3-9b98-bc0ed80d0b63', 'a2f7e95e-6211-495c-b111-21d749f7b582', 6, '2026-08-25', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-08-25', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('77022efd-ea0d-4377-930b-340b2bcea2ef', '2026-08-25 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #6 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d6b932d5-5ace-4c90-a9a1-585cc7f8c4a0', 'a2f7e95e-6211-495c-b111-21d749f7b582', 7, '2026-09-01', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-01', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9510bec6-7527-485b-b22b-6887285e4aff', '2026-09-01 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #7 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('40d7c8d0-e311-40b5-82a4-4b3ff85df219', 'a2f7e95e-6211-495c-b111-21d749f7b582', 8, '2026-09-08', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-08', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('64b49bf1-ea16-4649-9a6d-40aae46c2852', '2026-09-08 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #8 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('d53bd764-0847-45ad-82ed-1b2d366b3a27', 'a2f7e95e-6211-495c-b111-21d749f7b582', 9, '2026-09-15', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-15', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('2fcfc12d-a499-411c-9bab-d15395086d38', '2026-09-15 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #9 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('37ade9fd-6b40-41ac-8e4e-5e10c840a5e8', 'a2f7e95e-6211-495c-b111-21d749f7b582', 10, '2026-09-22', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-22', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('10736659-0726-49f1-8a6c-f4bbc013f47e', '2026-09-22 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #10 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e0d7b474-cee6-4e2b-9a89-4e052f82eef1', 'a2f7e95e-6211-495c-b111-21d749f7b582', 11, '2026-09-29', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-09-29', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9c826159-5da2-435c-ba0b-935c198c1a4f', '2026-09-29 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #11 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e3f12c27-3f3b-4519-bdb9-8be199769dfb', 'a2f7e95e-6211-495c-b111-21d749f7b582', 12, '2026-10-06', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-06', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('96cc9ab1-3fbb-4234-acd2-5c1f9ad16a9a', '2026-10-06 10:00:00+00', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #12 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_payoff_excess_records (id, repayment_id, loan_id, client_id, officer_id, branch_id, date, record_type, amount_paid, expected_installment, active_credit_settled, excess_amount, remaining_balance_before, remaining_balance_after, notes, created_at)
                        VALUES ('3012016b-ae1e-41e3-bebb-add3b0ad0367', '96cc9ab1-3fbb-4234-acd2-5c1f9ad16a9a', 'a2f7e95e-6211-495c-b111-21d749f7b582', 'b1373c4d-ed5d-40b5-9e90-fbd197b0e63d', '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-06', 'PAYOFF', 8250.0, 8250.0, 99000.0, 0.0, 8250.0, 0.0, 'Full loan completion settlement', NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('c296715d-c7e5-447b-80c1-6679cf3dcc29', '184dac24-2290-47ba-8b75-23df8d1176ce', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-19', 100000.0, 99000.0, 8250.0, 99000.0, 'Active', 'Finance', '2026-10-19', '2026-10-22', '2027-01-14', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('38d2de83-5793-4cf9-942b-36484708be9c', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 1, '2026-10-22', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-22', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('f76b0b7c-097b-42c5-a6e5-bc7073dab3c1', '2026-10-22 10:00:00+00', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', '184dac24-2290-47ba-8b75-23df8d1176ce', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('2c979ffe-bca2-4794-9149-aa360315557b', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 2, '2026-10-29', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-10-29', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('0d0dd7c3-876f-45ce-a6f2-4e4bba542275', '2026-10-29 10:00:00+00', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', '184dac24-2290-47ba-8b75-23df8d1176ce', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('df8f9d89-b9d6-43d4-ae14-fa779e122dbc', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 3, '2026-11-05', 8250.0, 0.0, 0.0, 8250.0, 'Paid', '2026-11-05', 8250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('6b0f35fc-89b2-44c4-aad4-da0bf2125f93', '2026-11-05 10:00:00+00', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', '184dac24-2290-47ba-8b75-23df8d1176ce', 8250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 8250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('26989455-1570-4ce9-8cd2-a3f5636c1b4e', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 4, '2026-11-12', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ec19d920-154e-47d4-aaf0-ed67a1db4c0b', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 5, '2026-11-19', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('10fa06ce-f649-4bb2-9b04-46a2e0ef0c9b', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 6, '2026-11-26', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ebeb7f3d-bd13-45cf-b53f-bc3d303ae4e8', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 7, '2026-12-03', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('662522ca-2ef5-46a0-9a49-3c11c2c81546', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 8, '2026-12-10', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('58d77e16-be43-4c9d-8ded-80daae2debd9', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 9, '2026-12-17', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4340944b-ff3c-4ca5-bff7-0f3adda73f4e', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 10, '2026-12-24', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('36d5edfb-bbcf-4497-a689-4fb931bb6aa6', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 11, '2026-12-31', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('72bf3e3a-2bbf-47cd-b5db-899b6d92e01c', 'c296715d-c7e5-447b-80c1-6679cf3dcc29', 12, '2027-01-07', 8250.0, 0.0, 0.0, 8250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('fd79c064-e883-479e-8eb7-986a26c1aeb7', '3cf908c1-bfaa-4846-910e-35ab9d813b03', 'c090f418-d2c1-4855-ab87-88e25589c471', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-19', 150000.0, 150000.0, 6250.0, 150000.0, 'Active', 'Finance', '2026-10-19', '2026-10-22', '2027-04-08', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1301dcc6-c57b-4e1c-a549-a91345f190fb', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 1, '2026-10-22', 6250.0, 0.0, 0.0, 6250.0, 'Paid', '2026-10-22', 6250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ebdcaf5d-00f6-4cea-8425-e723c2346c87', '2026-10-22 10:00:00+00', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', '3cf908c1-bfaa-4846-910e-35ab9d813b03', 6250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 6250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('7a1e7bca-89ba-431d-bcee-f7000b948714', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 2, '2026-10-29', 6250.0, 0.0, 0.0, 6250.0, 'Paid', '2026-10-29', 6250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('ba0cc042-5bf0-4686-937b-cd6fb7a16207', '2026-10-29 10:00:00+00', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', '3cf908c1-bfaa-4846-910e-35ab9d813b03', 6250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 6250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bf0cc625-f350-49f4-94e2-f985b07140ea', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 3, '2026-11-05', 6250.0, 0.0, 0.0, 6250.0, 'Paid', '2026-11-05', 6250.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('c2738515-e975-4ef0-bf93-785b85212a61', '2026-11-05 10:00:00+00', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', '3cf908c1-bfaa-4846-910e-35ab9d813b03', 6250.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 6250.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8480ddce-ed23-4787-8719-6dd3eeb06cae', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 4, '2026-11-12', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6036bddd-4b61-48ee-aee8-62bfe45aee26', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 5, '2026-11-19', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6b7863f2-8504-4142-9298-9dec42ad95dc', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 6, '2026-11-26', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('051228e3-9b4c-4aa5-bb7c-376d72f45362', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 7, '2026-12-03', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('274dcca5-2f83-4a0b-8839-128445b81899', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 8, '2026-12-10', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('472b5c2a-0b29-4c9b-bb5f-f979774f6b88', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 9, '2026-12-17', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('02a26efd-d0a1-48fe-8557-e255d869c122', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 10, '2026-12-24', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('abc937cb-90e7-4ebf-8fa8-c37007ff7948', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 11, '2026-12-31', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('6ef48564-c0af-442d-91bb-8cb911619e43', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 12, '2027-01-07', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('05c34105-b558-4e0c-b50b-4e3abf0b3ec9', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 13, '2027-01-14', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('936e9188-bbd9-46d4-8492-d6d60b8acd8d', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 14, '2027-01-21', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('fbb15f14-e9a7-4b01-8161-38c579ea2497', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 15, '2027-01-28', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e712bb70-20e8-4c2e-a38a-ed02b64b6457', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 16, '2027-02-04', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('37b750b4-b9a8-4fc1-888e-7f66398fab1b', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 17, '2027-02-11', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('4334848f-3d94-4c05-ba7c-e619976fdff1', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 18, '2027-02-18', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('28c9e1c5-76b0-4809-bcf5-e59aee5b0bb8', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 19, '2027-02-25', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('e6d4afee-5f63-4c23-ab29-7d2c62599eab', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 20, '2027-03-04', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('35ecb11b-9743-42f9-b10d-95920508454c', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 21, '2027-03-11', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('b249ec93-dd58-45f3-bf35-34edb3e7f795', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 22, '2027-03-18', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('898a330e-b9c2-4a64-8038-6fe2fdb3df91', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 23, '2027-03-25', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('3820fa58-5f12-46bb-97c2-7926f47b848f', 'fd79c064-e883-479e-8eb7-986a26c1aeb7', 24, '2027-04-01', 6250.0, 0.0, 0.0, 6250.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('cf3127e9-c709-4fd7-a5f1-aec38ac2d79e', '57f0e54a-b385-4f51-81d5-901201891974', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-11-09', 100000.0, 99000.0, 8250.0, 99000.0, 'Pending', 'Finance', '2026-11-09', '2026-11-12', '2027-02-04', 1, 'NGN', NOW(), NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('3a089a2d-503e-46f3-8d2e-db6618c980f7', '5932eaff-c7a6-4175-a001-c75eea53b5d0', 'b788e502-3787-4d51-8eb7-0ac9ea88c7a9', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-09-01', 300000.0, 300000.0, 100000.0, 300000.0, 'Active', 'Finance', '2026-09-01', '2026-10-01', '2026-12-30', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0280b1d1-0adf-4400-9bdf-7092ba66e6df', '3a089a2d-503e-46f3-8d2e-db6618c980f7', 1, '2026-10-01', 100000.0, 0.0, 0.0, 100000.0, 'Paid', '2026-10-01', 100000.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('cbb7ee21-0633-478d-b012-b907403c5f0b', '2026-10-01 10:00:00+00', '3a089a2d-503e-46f3-8d2e-db6618c980f7', '5932eaff-c7a6-4175-a001-c75eea53b5d0', 100000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 100000.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('8291f218-aafb-412e-bc07-4d5847a0fcff', '3a089a2d-503e-46f3-8d2e-db6618c980f7', 2, '2026-10-31', 100000.0, 0.0, 0.0, 100000.0, 'Paid', '2026-10-31', 100000.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9f158a73-f5e7-4788-b78c-4fa1894be7b0', '2026-10-31 10:00:00+00', '3a089a2d-503e-46f3-8d2e-db6618c980f7', '5932eaff-c7a6-4175-a001-c75eea53b5d0', 100000.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 100000.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('ee3e8c9d-3e1a-4173-9bd0-686fd63541bd', '3a089a2d-503e-46f3-8d2e-db6618c980f7', 3, '2026-11-30', 100000.0, 0.0, 0.0, 100000.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('5fe367af-d671-4f31-870d-5cb857787c23', '58a54856-a5e4-4814-a743-d780063290d8', '7cb6379d-43e7-4984-9223-1f45aee6e3ab', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-03', 100000.0, 99600.0, 16600.0, 99600.0, 'Active', 'Finance', '2026-08-03', '2026-09-03', '2027-03-02', 1, 'NGN', NOW(), NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('0b2f40f8-feb8-4813-8035-05963f18e0a2', '5fe367af-d671-4f31-870d-5cb857787c23', 1, '2026-09-03', 16600.0, 0.0, 0.0, 16600.0, 'Paid', '2026-09-03', 16600.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('3d947cc4-a14c-47fc-ba52-5f44df46cd10', '2026-09-03 10:00:00+00', '5fe367af-d671-4f31-870d-5cb857787c23', '58a54856-a5e4-4814-a743-d780063290d8', 16600.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #1 Collection', 'Cash', 'PAID', 16600.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('13cf0e76-598a-4a12-b027-daaba308c65d', '5fe367af-d671-4f31-870d-5cb857787c23', 2, '2026-10-03', 16600.0, 0.0, 0.0, 16600.0, 'Paid', '2026-10-03', 16600.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('9865a3cf-750c-45d8-a8aa-3bebfdbaeb58', '2026-10-03 10:00:00+00', '5fe367af-d671-4f31-870d-5cb857787c23', '58a54856-a5e4-4814-a743-d780063290d8', 16600.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #2 Collection', 'Cash', 'PAID', 16600.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('1112c0a6-ea06-4afa-b667-9913ae838a13', '5fe367af-d671-4f31-870d-5cb857787c23', 3, '2026-11-02', 16600.0, 0.0, 0.0, 16600.0, 'Paid', '2026-11-02', 16600.0, 1, NOW());

INSERT INTO repayments (id, date, loan_id, client_id, amount_paid, officer_id, branch_id, note, transaction_type, payment_status, expected_amount, created_at)
                    VALUES ('cc86bca6-4286-4f5f-9e8f-678862ed10c3', '2026-11-02 10:00:00+00', '5fe367af-d671-4f31-870d-5cb857787c23', '58a54856-a5e4-4814-a743-d780063290d8', 16600.0, '7ca80003-9077-4bef-8cf3-78cf26c30705', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 'Installment #3 Collection', 'Cash', 'PAID', 16600.0, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('a4bbb355-14d3-4a88-a8f8-351fd44d2706', '5fe367af-d671-4f31-870d-5cb857787c23', 4, '2026-12-02', 16600.0, 0.0, 0.0, 16600.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('751227dd-c0d1-4c73-a4ff-404a374eac71', '5fe367af-d671-4f31-870d-5cb857787c23', 5, '2027-01-01', 16600.0, 0.0, 0.0, 16600.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO loan_schedule (id, loan_id, installment_number, due_date, principal, interest, fees, total_due, status, paid_date, paid_amount, version, created_at)
                VALUES ('bd6e0f77-ed9a-4e0a-8f53-f95ee27afd01', '5fe367af-d671-4f31-870d-5cb857787c23', 6, '2027-01-31', 16600.0, 0.0, 0.0, 16600.0, 'Pending', NULL, 0.0, 1, NOW());

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('95f2ad22-7210-48f9-a790-0a1f774fc5e4', '30c4b908-eb16-4b5a-a806-6369b82bc9a2', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Debit', 2000000.0, 'Capital', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-08-01 08:00:00+00'),
        ('5bacc29a-be34-4f90-b518-793277bad70b', '30c4b908-eb16-4b5a-a806-6369b82bc9a2', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '3100', 'Credit', 2000000.0, 'Capital', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-08-01 08:00:00+00');

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('54e5486e-96bd-46fe-9c1b-001623b3a2b8', '3c0d5e1b-37f7-4e95-b8c4-02aff0e28573', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1200', 'Debit', 1850000.0, 'Disbursement', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-12 09:00:00+00'),
        ('d5e7cede-5c11-43dc-a13f-376431592f86', '3c0d5e1b-37f7-4e95-b8c4-02aff0e28573', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Credit', 1850000.0, 'Disbursement', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-12 09:00:00+00');

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('deacadd0-2941-4c92-9727-5be0e8f28fea', 'd1f88f2b-0e40-4bb9-a52f-d5c7695d0622', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Debit', 293900.0, 'FeeIncome', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-12 09:30:00+00'),
        ('6e04f163-2a0e-4466-be7d-059ec3af7d42', 'd1f88f2b-0e40-4bb9-a52f-d5c7695d0622', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '3000', 'Credit', 293900.0, 'FeeIncome', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-12 09:30:00+00');

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('55f88c42-3d7c-4b2f-bc8a-b44811186b70', '2a4456e3-0b8b-4e7e-b6b7-b0bedd165da4', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Debit', 765350.0, 'Repayment', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-06 16:00:00+00'),
        ('623b8d7f-3554-4346-9ffc-c415f5c03cbe', '2a4456e3-0b8b-4e7e-b6b7-b0bedd165da4', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1200', 'Credit', 765350.0, 'Repayment', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-06 16:00:00+00');

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('ddcccc86-65db-4785-8cde-ec1551302f8b', '1cd39542-c9d8-41ed-955b-ddc3e41db3e0', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Debit', 521500.0, 'Savings', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-01 10:00:00+00'),
        ('63643826-d796-4043-972a-c1bd37438bdc', '1cd39542-c9d8-41ed-955b-ddc3e41db3e0', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2000', 'Credit', 406500.0, 'Savings', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-01 10:00:00+00'),
        ('e0b8d86a-4e9d-45b4-a730-313a3ef6d67d', '1cd39542-c9d8-41ed-955b-ddc3e41db3e0', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2010', 'Credit', 75000.0, 'Savings', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-01 10:00:00+00'),
        ('594b360e-9095-4e47-875d-ad6342a8d729', '1cd39542-c9d8-41ed-955b-ddc3e41db3e0', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2030', 'Credit', 40000.0, 'Savings', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-10-01 10:00:00+00');

INSERT INTO financial_ledger_entries (entry_id, transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id, created_at)
    VALUES 
        ('2fca08c1-0013-4a65-ae9a-f5bc573c1bf1', '174f27fc-7f0c-4235-bd66-9adfb8b9de43', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1050', 'Debit', 1380750.0, 'Remittance', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-06 17:00:00+00'),
        ('79815ba6-8419-401d-9df3-2484bd5cf7ca', '174f27fc-7f0c-4235-bd66-9adfb8b9de43', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '1000', 'Credit', 1380750.0, 'Remittance', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '2026-11-06 17:00:00+00');

INSERT INTO master_cashbook (id, date, branch_id, opening_balance, total_inflows, total_outflows, closing_balance, status, version, created_at)
    VALUES 
        ('d430fa07-d19a-4c21-8434-277aa802c0ee', '2026-11-06', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 0.0, 350000.0, 0.0, 350000.0, 'Closed', 1, '2026-11-06 18:00:00+00'),
        ('64a7792a-5778-467d-93c5-d1118d32dcb7', '2026-11-09', '7ca8250a-9077-4bef-8cf3-78cf26c30705', 350000.0, 0.0, 0.0, 350000.0, 'Open', 1, '2026-11-09 07:00:00+00');