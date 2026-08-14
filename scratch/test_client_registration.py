import uuid
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.client import Client

uow = SupabaseUnitOfWork()

print("=== TESTING CLIENT REGISTRATION FLOW ===")

test_client_id = str(uuid.uuid4())
test_code = "TEST-REG-999"
test_loan_id = str(uuid.uuid4())
branch_id = uow.loans._resolve_branch_id("Ogijo")
officer_id = uow.loans._resolve_officer_id("CO2")

try:
    # 1. Create client
    client_entity = Client(
        id=test_client_id,
        name="Test New Client",
        client_code=test_code,
        nickname="Tester",
        phone="08012345678",
        address="123 Test St",
        business_address="456 Market St",
        dob=date(1990, 1, 1),
        gender="Female",
        marital_status="Single",
        occupation="Trader",
        business_type="Retail",
        id_means="NIN",
        id_number="1234567890",
        id_card_url="",
        next_of_kin="",
        passport_url="",
        signature_url="",
        registration_date=date.today(),
        branch_id=branch_id,
        group_id=None,
        officer_id=officer_id,
        status="Active",
        average_monthly_income=75000.0,
        other_obligations="None"
    )
    uow.clients.create(client_entity)
    print(">> Client created in clients table successfully!")

    # 2. Create pending dummy loan
    default_product_res = uow.client.table("loan_products").select("product_id").limit(1).execute()
    default_product_id = default_product_res.data[0]["product_id"] if default_product_res.data else None

    uow.client.table("loans").insert({
        "loan_id": test_loan_id,
        "client_id": client_entity.id,
        "product_id": default_product_id,
        "branch_id": branch_id,
        "officer_id": client_entity.officer_id,
        "date": date.today().isoformat(),
        "loan_amount": 0.0,
        "active_credit": 0.0,
        "loan_repay": 0.0,
        "total_due": 0.0,
        "status": "Pending",
        "extra_fields": {
            "guarantor_name": "Test Guarantor",
            "guarantor_nickname": "Guarantor Nick",
            "guarantor_phone": "08098765432",
            "guarantor_home_address": "789 Test Ave",
            "guarantor_marital_status": "Married",
            "guarantor_occupation": "Teacher",
            "guarantor_relationship": "Brother",
            "guarantor_office_address": "School Road",
            "nickname": client_entity.nickname,
            "marital_status": client_entity.marital_status,
            "average_monthly_income": client_entity.average_monthly_income,
            "other_obligations": client_entity.other_obligations
        },
        "guarantor_id_means": "NIN",
        "guarantor_id_number": "9876543210",
        "guarantor_id_card_url": "",
        "guarantor_passport_url": ""
    }).execute()
    print(">> Pending loan with guarantor details inserted successfully into loans table!")

    # 3. Clean up test records
    uow.client.table("loans").delete().eq("loan_id", test_loan_id).execute()
    uow.client.table("clients").delete().eq("client_id", test_client_id).execute()
    print(">> Cleaned up test client and loan records!")
    print(">> CLIENT REGISTRATION FLOW FULLY VERIFIED!")

except Exception as e:
    print(f"FAILED client registration test: {e}")
    # Cleanup in case of error
    uow.client.table("loans").delete().eq("loan_id", test_loan_id).execute()
    uow.client.table("clients").delete().eq("client_id", test_client_id).execute()
    raise e
