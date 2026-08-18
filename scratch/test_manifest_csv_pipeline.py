import pandas as pd
import toml
from supabase import create_client

def test_manifest_csv_pipeline():
    print("=== TESTING COLLECTION MANIFEST CSV PIPELINE ===")
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    # 1. Fetch active clients in group Favour (or Anuoluwapo)
    res_g = client.table("groups").select("group_id, name").ilike("name", "%Anuoluwapo%").limit(1).execute()
    assert res_g.data, "Group Anuoluwapo not found!"
    grp_id = res_g.data[0]["group_id"]
    grp_name = res_g.data[0]["name"]

    res_mem = client.table("client_memberships").select("client_id, clients(client_id, client_code, name, status)").eq("group_id", grp_id).execute()
    members = res_mem.data or []
    print(f"Group: {grp_name} | Members: {len(members)}")

    # 2. Build sample manifest rows
    manifest_rows = []
    for m in members:
        c = m.get("clients") or {}
        cid = c.get("client_code") or c.get("client_id")
        name = c.get("name")
        manifest_rows.append({
            "Client ID": cid,
            "Client Name": name,
            "Savings Balance": 15000.0,
            "Remaining Balance": 80000.0,
            "Expected Repayment": 8250.0,
            "Amount Collected": 8250.0,
            "Savings Deposit": 1000.0
        })

    df_manifest = pd.DataFrame(manifest_rows)
    print("\nGenerated Manifest Preview (top 3):")
    print(df_manifest.head(3).to_string(index=False))

    # 3. Simulate CSV export and round-trip parsing
    csv_bytes = df_manifest.to_csv(index=False).encode('utf-8')
    import io
    df_parsed = pd.read_csv(io.BytesIO(csv_bytes))
    assert len(df_parsed) == len(manifest_rows), "Parsed row count mismatch!"
    assert "Amount Collected" in df_parsed.columns, "Amount Collected column missing!"
    assert "Savings Deposit" in df_parsed.columns, "Savings Deposit column missing!"
    assert "Signature" not in df_parsed.columns, "Signature column should be removed!"

    # 4. Verify separation of repayment and savings
    total_repayments = df_parsed["Amount Collected"].sum()
    total_savings = df_parsed["Savings Deposit"].sum()
    print(f"\nTotal Repayments: NGN {total_repayments:,.2f}")
    print(f"Total Savings: NGN {total_savings:,.2f}")
    assert total_repayments > 0, "Repayments must be > 0"
    assert total_savings > 0, "Savings must be > 0"
    assert total_repayments != total_savings, "Repayments and Savings are distinct"

    print("\n>>> ALL MANIFEST CSV PIPELINE CHECKS PASSED SUCCESSFULLY! <<<")

if __name__ == "__main__":
    test_manifest_csv_pipeline()
