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

INSERT INTO user_roles (user_id, role_id)
    VALUES 
        ('7ca80001-9077-4bef-8cf3-78cf26c30705', '3ea1496a-0498-4a1d-872a-1c7ecdf77b06'),
        ('7ca80002-9077-4bef-8cf3-78cf26c30705', 'bd8790ee-c0eb-485a-8b6a-93f54519965d'),
        ('7ca80003-9077-4bef-8cf3-78cf26c30705', 'bd8790ee-c0eb-485a-8b6a-93f54519965d')
    ON CONFLICT DO NOTHING;

INSERT INTO area_manager_assignments (am_id, branch_id)
    VALUES ('e6a77cdb-6012-4506-8240-7e46e81d954d', '7ca8250a-9077-4bef-8cf3-78cf26c30705')
    ON CONFLICT DO NOTHING;

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