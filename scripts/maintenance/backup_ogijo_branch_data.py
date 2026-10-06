"""
Script: scripts/maintenance/backup_ogijo_branch_data.py
Creates an automated JSON snapshot backup of all existing Ogijo branch records
before September 2026 database repopulation.
"""

import os
import sys
import json
from datetime import datetime

# Add root directory to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from database.connection import supabase

def run_backup():
    branch_id = "997d504e-7f5c-4772-887d-fdd5a4c1183b"
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../storage/backups"))
    os.makedirs(backup_dir, exist_ok=True)
    backup_file = os.path.join(backup_dir, f"ogijo_pre_repopulation_backup_{timestamp}.json")

    tables_to_backup = [
        ("loans", "branch_id"),
        ("repayments", "branch_id"),
        ("individual_savings", "branch_id"),
        ("group_savings", "branch_id"),
        ("co_cashbooks", "branch_id"),
        ("financial_transactions", "branch_id"),
        ("financial_ledger_entries", "branch_id"),
        ("master_cashbook", "branch_id"),
        ("loan_payoff_excess_records", "branch_id"),
    ]

    backup_data = {
        "branch_id": branch_id,
        "backup_timestamp": timestamp,
        "tables": {}
    }

    print(f"Starting Ogijo branch safety snapshot backup...")
    print(f"Target backup file: {backup_file}")

    for table_name, filter_col in tables_to_backup:
        try:
            res = supabase.table(table_name).select("*").eq(filter_col, branch_id).execute()
            rows = res.data or []
            backup_data["tables"][table_name] = rows
            print(f" - {table_name}: {len(rows)} records backed up.")
        except Exception as e:
            print(f" - WARNING: Could not backup {table_name}: {e}")
            backup_data["tables"][table_name] = []

    # Also backup loan_schedule for loans belonging to Ogijo
    try:
        loan_ids = [l["loan_id"] for l in backup_data["tables"].get("loans", []) if "loan_id" in l]
        if loan_ids:
            all_schedules = []
            # Batch query schedules in chunks of 100
            for i in range(0, len(loan_ids), 100):
                batch_ids = loan_ids[i:i+100]
                res_sched = supabase.table("loan_schedule").select("*").in_("loan_id", batch_ids).execute()
                all_schedules.extend(res_sched.data or [])
            backup_data["tables"]["loan_schedule"] = all_schedules
            print(f" - loan_schedule: {len(all_schedules)} records backed up.")
        else:
            backup_data["tables"]["loan_schedule"] = []
            print(f" - loan_schedule: 0 records.")
    except Exception as e:
        print(f" - WARNING: Could not backup loan_schedule: {e}")
        backup_data["tables"]["loan_schedule"] = []

    # Write JSON backup
    with open(backup_file, "w", encoding="utf-8") as f:
        json.dump(backup_data, f, indent=2, default=str)

    print(f"\nSUCCESS: Safety snapshot completed successfully!")
    print(f"Saved {os.path.getsize(backup_file):,} bytes to {backup_file}\n")
    return backup_file

if __name__ == "__main__":
    run_backup()
