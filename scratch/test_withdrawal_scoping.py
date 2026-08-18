import sys
import os

# Test scoping logic
def test_group_scoping_logic():
    print("Testing group scoping logic...")
    
    # Mock data
    groups_in_branch = [
        {"group_id": "g1", "name": "Pamilerin", "officer_id": "off-1", "branch_id": "b1"},
        {"group_id": "g2", "name": "Favour", "officer_id": "off-2", "branch_id": "b1"},
        {"group_id": "g3", "name": "Anuoluwapo", "officer_id": "off-1", "branch_id": "b1"},
    ]
    
    clients_off1 = [
        {"client_id": "c1", "officer_id": "off-1", "client_memberships": [{"group_id": "g1", "groups": {"group_id": "g1", "name": "Pamilerin"}}]}
    ]
    
    # When officer off-2 logs in:
    target_officer_id = "off-2"
    direct = [g for g in groups_in_branch if g["officer_id"] == target_officer_id]
    group_opts = {g["name"]: g for g in direct}
    
    print(f"Officer off-2 scoped groups: {list(group_opts.keys())}")
    assert list(group_opts.keys()) == ["Favour"], f"Expected ['Favour'], got {list(group_opts.keys())}"
    
    # When officer off-1 logs in:
    target_officer_id = "off-1"
    direct = [g for g in groups_in_branch if g["officer_id"] == target_officer_id]
    group_opts = {g["name"]: g for g in direct}
    for c in clients_off1:
        for m in c.get("client_memberships", []):
            if m.get("groups"):
                group_opts[m["groups"]["name"]] = m["groups"]
    print(f"Officer off-1 scoped groups: {list(group_opts.keys())}")
    assert set(group_opts.keys()) == {"Pamilerin", "Anuoluwapo"}, f"Expected Pamilerin and Anuoluwapo, got {list(group_opts.keys())}"
    
    print(">>> All group scoping assertions passed! <<<")

if __name__ == "__main__":
    test_group_scoping_logic()
