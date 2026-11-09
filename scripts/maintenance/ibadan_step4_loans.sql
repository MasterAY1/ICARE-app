INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('3b4dbfff-22ca-5168-b7d1-c69fc147499f', 'd5e349e1-5cc9-5ac2-a7c5-028d225029be', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 99000.0, 1650.0, 99000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('691d3ba0-2d8e-5093-bcbb-44f6214fda49', '887086db-2676-548e-970f-b9347386fd13', 'c41b5775-6e19-4302-bd42-c14342f52592', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 96000.0, 800.0, 96000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-04-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('11cc6a1c-8d91-532e-98fb-f37ac8078be0', 'e42120d0-5d0f-5ac6-bcde-794078ba9032', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 50000.0, 48000.0, 800.0, 48000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('fa2b1929-e324-5ce1-ae67-8a3296234213', 'a8215623-24c1-5b85-96d2-6f823bc98cc1', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-08-10', 100000.0, 99000.0, 1650.0, 99000.0, 'Completed', 'Finance', '2026-08-10', '2026-08-11', '2026-11-09', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('bc3a1fc9-fa76-5760-aa82-87c51f26b081', '3b077386-a0d5-5085-bdbf-1def58badad4', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 150000.0, 150000.0, 2500.0, 150000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('01f734b0-0674-5545-aaa3-e873e622d8d4', '462d1ae6-5e0a-5b78-9fff-ce6d76b6845d', 'c41b5775-6e19-4302-bd42-c14342f52592', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 96000.0, 800.0, 96000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-04-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('3d8fc20d-42d4-5596-a26e-5ea82b477ced', 'dfb85fdf-1b68-539a-982c-865018dd4fb6', '2493f7d4-82d3-4004-8f67-537e6eb880dd', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80002-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 99000.0, 1650.0, 99000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-11', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('93473da5-7219-5e20-8d2a-0e1e85c43db4', '730e9395-6b7f-553d-9b1a-35b6349c1fee', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 99000.0, 8250.0, 99000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-05', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('ac593bc1-9b30-5d95-9e8e-7630ce1a8f4d', 'a5800f83-0be5-5dc9-8608-f799cf95820b', 'c090f418-d2c1-4855-ab87-88e25589c471', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 100000.0, 96000.0, 4000.0, 96000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-03-30', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('2613e9b5-9fba-553f-87e8-ff6f0705648c', 'be500c02-686f-5de5-aa3c-9494991fbb57', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-12', 200000.0, 198000.0, 16500.0, 198000.0, 'Active', 'Finance', '2026-10-12', '2026-10-13', '2027-01-05', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('bdf55216-7f97-53cf-babf-35c1e9eeb38b', 'ac597b4b-3e72-5769-ae2c-31c9c4c31850', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-07-20', 100000.0, 99000.0, 8250.0, 99000.0, 'Completed', 'Finance', '2026-07-20', '2026-07-21', '2026-10-13', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('3cd518a9-ef78-51e0-99c7-e8f6fef984a8', '06a30779-7559-5d85-b6b2-79d33e18db06', 'd466e92b-d35f-46b2-acdb-2c55aabf9fb3', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-19', 100000.0, 99000.0, 8250.0, 99000.0, 'Active', 'Finance', '2026-10-19', '2026-10-22', '2027-01-14', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('570d9a60-a540-5324-b5e6-6afe471a72aa', 'f98fecb1-40fc-5c7d-a3c7-7bb4d9bd983f', 'c090f418-d2c1-4855-ab87-88e25589c471', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-10-19', 150000.0, 150000.0, 6250.0, 150000.0, 'Active', 'Finance', '2026-10-19', '2026-10-22', '2027-04-08', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;

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

INSERT INTO loans (loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, active_credit, loan_repay, total_due, status, product_category, disbursement_date, start_date, expected_end_date, version, currency_code, created_at, updated_at)
        VALUES ('21ae0d38-f881-5684-87a0-5dda9152aae9', '2e53acb4-886b-5e6c-964a-95cbefc587a2', '7cb6379d-43e7-4984-9223-1f45aee6e3ab', '7ca8250a-9077-4bef-8cf3-78cf26c30705', '7ca80003-9077-4bef-8cf3-78cf26c30705', '2026-08-03', 100000.0, 99600.0, 16600.0, 99600.0, 'Active', 'Finance', '2026-08-03', '2026-09-03', '2027-03-02', 1, 'NGN', NOW(), NOW())
        ON CONFLICT (loan_id) DO UPDATE SET
            status = EXCLUDED.status,
            active_credit = EXCLUDED.active_credit,
            loan_repay = EXCLUDED.loan_repay;
