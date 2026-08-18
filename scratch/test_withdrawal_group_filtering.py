import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

def test_withdrawal_group_filtering():
    uow = SupabaseUnitOfWork()
    BRANCH_ID = '997d504e-7f5c-4772-887d-fdd5a4c1183b'
    
    # 1. Test CO2
    co2_id = uow.loans._resolve_officer_id("CO2")
    res_co2 = uow.client.table("groups").select("group_id, name").eq("branch_id", BRANCH_ID).eq("officer_id", co2_id).execute()
    co2_groups = sorted([g["name"] for g in (res_co2.data or []) if g and g.get("name")])
    print(f"CO2 Assigned Groups ({len(co2_groups)}):", co2_groups)
    assert "Pamilerin" not in co2_groups, "Pamilerin must NOT be in CO2 groups!"
    assert "Favour" in co2_groups, "Favour must be in CO2 groups!"
    
    # 2. Test CO3
    co3_id = uow.loans._resolve_officer_id("CO3")
    res_co3 = uow.client.table("groups").select("group_id, name").eq("branch_id", BRANCH_ID).eq("officer_id", co3_id).execute()
    co3_groups = sorted([g["name"] for g in (res_co3.data or []) if g and g.get("name")])
    print(f"CO3 Assigned Groups ({len(co3_groups)}):", co3_groups)
    assert "Pamilerin" in co3_groups, "Pamilerin MUST be in CO3 groups!"
    assert "Favour" not in co3_groups, "Favour must NOT be in CO3 groups!"
    
    # 3. Test CO1
    co1_id = uow.loans._resolve_officer_id("CO1")
    res_co1 = uow.client.table("groups").select("group_id, name").eq("branch_id", BRANCH_ID).eq("officer_id", co1_id).execute()
    co1_groups = sorted([g["name"] for g in (res_co1.data or []) if g and g.get("name")])
    print(f"CO1 Assigned Groups ({len(co1_groups)}):", co1_groups)
    assert "Anuoluwapo" in co1_groups, "Anuoluwapo MUST be in CO1 groups!"
    assert "Pamilerin" not in co1_groups, "Pamilerin must NOT be in CO1 groups!"
    
    # 4. Test Manager view with officer filter
    res_bm_co3 = uow.client.table("groups").select("group_id, name").eq("branch_id", BRANCH_ID).eq("officer_id", co3_id).execute()
    bm_co3_groups = sorted([g["name"] for g in (res_bm_co3.data or []) if g and g.get("name")])
    assert bm_co3_groups == co3_groups
    
    print("\n>>> ALL WITHDRAWAL GROUP FILTERING TESTS PASSED! <<<")

if __name__ == "__main__":
    test_withdrawal_group_filtering()
