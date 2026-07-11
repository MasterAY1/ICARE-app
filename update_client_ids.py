import os
import re

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add the helper function to app.py
helper_code = """
def generate_client_id(branch_name, group_string, member_num_or_index, is_bulk=False):
    import re
    # 1. Get branch prefix (first 3 letters, uppercase)
    b_prefix = str(branch_name)[:3].upper() if branch_name else "UNK"
    
    # 2. Get group prefix
    g_str = str(group_string).strip()
    if not g_str or g_str.lower() in ["none", "nan", "ungrouped"]:
        g_prefix = "IND" # Individual / Ungrouped
    else:
        # If it looks like 'GRP-02' or has digits, extract digits
        digits = re.findall(r'\d+', g_str)
        if digits:
            # Use the first number found, pad to 2 digits
            g_prefix = str(digits[0]).zfill(2)
        else:
            # Otherwise use the first 3 letters of the group name
            g_prefix = g_str[:3].upper()
            
    # 3. Get member number
    try:
        m_num = int(float(member_num_or_index))
    except:
        m_num = 1 # Fallback
        
    m_prefix = str(m_num).zfill(3)
    
    return f"{b_prefix}-{g_prefix}-{m_prefix}"
"""

# Insert helper code after imports (around line 22)
if "def generate_client_id" not in content:
    content = content.replace("from supabase import create_client, Client", "from supabase import create_client, Client\n" + helper_code)

# 2. Update Bulk Onboarding client_id generation
bulk_target = "client_id = str(uuid.uuid4())"
bulk_replacement = """
                                # Extract member number from the sheet if present
                                m_num_raw = member_row.get('Member Number')
                                try:
                                    m_num_val = int(float(m_num_raw))
                                except:
                                    m_num_val = index + 1 # fallback to row index
                                    
                                branch_val = str(group_row.get('Branch Name', BRANCH))
                                group_ref_val = str(member_row.get('Group Reference', ''))
                                
                                client_id = generate_client_id(branch_val, group_ref_val, m_num_val, is_bulk=True)
                                
                                # Safety check: If client_id already exists, append a random string to avoid duplicate errors
                                existing_check = supabase.table("loans").select("client_id").eq("client_id", client_id).execute()
                                if existing_check.data and len(existing_check.data) > 0:
                                    client_id = f"{client_id}-{str(uuid.uuid4())[:4]}"
"""
content = content.replace(bulk_target, bulk_replacement.strip('\n'))

# 3. Update Single Client Onboarding
single_target = "new_client_id = str(uuid.uuid4())"
single_replacement = """
                    # Generate structured ID for single client
                    g_val = group_name if group_name else "IND"
                    
                    # Count how many existing clients are in this group to assign the next member number
                    try:
                        # Assuming 'Group Name' is the column in Supabase that matches the input `group_name`
                        # This is a bit tricky, but we can query by Branch and Group Name to get a count
                        group_count_res = supabase.table("loans").select("client_id", count="exact").eq("Branch", BRANCH).eq("Group Name", group_name).execute()
                        next_num = group_count_res.count + 1 if group_count_res.count else 1
                    except:
                        next_num = 1
                        
                    new_client_id = generate_client_id(BRANCH, g_val, next_num)
                    
                    # Safety check
                    existing_check = supabase.table("loans").select("client_id").eq("client_id", new_client_id).execute()
                    if existing_check.data and len(existing_check.data) > 0:
                        new_client_id = f"{new_client_id}-{str(uuid.uuid4())[:4]}"
"""
content = content.replace(single_target, single_replacement.strip('\n'))

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Updated app.py with structured client_id generator.")
