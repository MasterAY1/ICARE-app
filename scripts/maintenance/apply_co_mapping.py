import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add load_co_mapping function after init_connection
loader_func = """
@st.cache_data(ttl=600)
def load_co_mapping():
    if not supabase:
        return {}, {}
    try:
        res = supabase.table("app_users").select("username, full_name").in_("role", ["CO", "Officer"]).execute()
        if res.data:
            name_map = {row["full_name"].strip(): row["username"] for row in res.data if row.get("full_name")}
            display_map = {v: k for k, v in name_map.items()}
            return name_map, display_map
    except Exception as e:
        print(f"Error loading CO mapping: {e}")
    return {}, {}
"""

if "def load_co_mapping()" not in content:
    # Insert after init_connection() definition
    content = content.replace(
        "def init_connection():\n    url = os.environ.get('SUPABASE_URL')",
        loader_func + "\n" + "def init_connection():\n    url = os.environ.get('SUPABASE_URL')"
    )

# 2. Add global initialization of CO_NAME_MAP and CO_DISPLAY_MAP after init_connection is called
init_vars = """
supabase = init_connection()
CO_NAME_MAP, CO_DISPLAY_MAP = load_co_mapping()
"""
content = content.replace("supabase = init_connection()", init_vars.strip())

# 3. Update Bulk Onboarding (~L1031)
bulk_target = """                                # Robust extraction of officer
                                officer_val = group_row.get('Credit Officer Name')
                                if pd.isna(officer_val) or str(officer_val).strip() == "" or str(officer_val).strip().lower() == "nan":
                                    officer_val = user_name
                                else:
                                    officer_val = str(officer_val).strip()"""

bulk_replacement = """                                # Robust extraction of officer with translation
                                officer_val = group_row.get('Credit Officer Name')
                                if pd.isna(officer_val) or str(officer_val).strip() == "" or str(officer_val).strip().lower() == "nan":
                                    officer_val = USER
                                else:
                                    raw_name = str(officer_val).strip()
                                    if raw_name in CO_NAME_MAP:
                                        officer_val = CO_NAME_MAP[raw_name]
                                    else:
                                        st.warning(f"⚠️ Unrecognized officer name: '{raw_name}' in Excel. Defaulting to logged-in user.")
                                        officer_val = USER"""

content = content.replace(bulk_target, bulk_replacement)

# 4. Update Sidebar Welcome (~L761)
sidebar_target = "<p style='color: white; margin: 0; font-size: 0.95rem; font-weight: 600;'>👤 {USER}</p>"
sidebar_replacement = "<p style='color: white; margin: 0; font-size: 0.95rem; font-weight: 600;'>👤 {CO_DISPLAY_MAP.get(USER, USER)}</p>"
content = content.replace(sidebar_target, sidebar_replacement)

# 5. Single Origination Dropdown (~L1128)
orig_target = """            if ROLE in ["Admin", "BM"]:
                assigned_officer = st.selectbox("Assign to Officer:", ["CO1", "CO2"])
            else:
                st.write(f"**Assigned Officer:** {USER}")
                assigned_officer = USER"""

orig_replacement = """            if ROLE in ["Admin", "BM"]:
                co_display_names = list(CO_NAME_MAP.keys())
                if co_display_names:
                    selected_display = st.selectbox("Assign to Officer:", co_display_names)
                    assigned_officer = CO_NAME_MAP.get(selected_display, selected_display)
                else:
                    assigned_officer = st.selectbox("Assign to Officer:", ["CO1", "CO2"]) # fallback
            else:
                st.write(f"**Assigned Officer:** {CO_DISPLAY_MAP.get(USER, USER)}")
                assigned_officer = USER"""
content = content.replace(orig_target, orig_replacement)

# 6. Daily Report Dropdown (~L1630)
daily_rep_target = """            unique_officers = daily_reps['Officer'].dropna().unique().tolist()
            if not unique_officers:
                st.info("No officers have records for today.")
                target_officer = "All Officers"
            else:
                target_officer = st.selectbox("Select Credit Officer", ["All Officers"] + unique_officers, key="daily_rep_co")
                
            if target_officer != "All Officers":"""

daily_rep_replacement = """            unique_officers = daily_reps['Officer'].dropna().unique().tolist()
            if not unique_officers:
                st.info("No officers have records for today.")
                target_officer = "All Officers"
            else:
                display_options = ["All Officers"] + [CO_DISPLAY_MAP.get(o, o) for o in unique_officers]
                selected_display = st.selectbox("Select Credit Officer", display_options, key="daily_rep_co")
                target_officer = "All Officers" if selected_display == "All Officers" else CO_NAME_MAP.get(selected_display, selected_display)
                
            if target_officer != "All Officers":"""
content = content.replace(daily_rep_target, daily_rep_replacement)

# 7. WhatsApp Cashbook Dropdown (~L1746)
wa_target = """            unique_officers = daily_reps['Officer'].dropna().unique().tolist()
            if unique_officers:
                selected_co = st.selectbox("Select Credit Officer", unique_officers, key="wa_cashbook_co")
                daily_reps = daily_reps[daily_reps['Officer'] == selected_co]"""

wa_replacement = """            unique_officers = daily_reps['Officer'].dropna().unique().tolist()
            if unique_officers:
                display_options = [CO_DISPLAY_MAP.get(o, o) for o in unique_officers]
                selected_display = st.selectbox("Select Credit Officer", display_options, key="wa_cashbook_co")
                selected_co = CO_NAME_MAP.get(selected_display, selected_display)
                daily_reps = daily_reps[daily_reps['Officer'] == selected_co]"""
content = content.replace(wa_target, wa_replacement)

# 8. WhatsApp Cashbook Header (~L1841)
header_target = """            co_name = USER if ROLE == "CO" else (selected_co if ROLE in ["BM", "AM"] and unique_officers else USER)
            co_loans = all_loans[all_loans['Officer'] == co_name]
            
            st.markdown("<hr style='margin: 15px 0; border-color: rgba(255,255,255,0.1);'>", unsafe_allow_html=True)
            st.subheader(f"Outflow Tracker — {co_name}")"""

header_replacement = """            co_name = USER if ROLE == "CO" else (selected_co if ROLE in ["BM", "AM"] and unique_officers else USER)
            co_display = CO_DISPLAY_MAP.get(co_name, co_name)
            co_loans = all_loans[all_loans['Officer'] == co_name]
            
            st.markdown("<hr style='margin: 15px 0; border-color: rgba(255,255,255,0.1);'>", unsafe_allow_html=True)
            st.subheader(f"Outflow Tracker — {co_display}")"""
content = content.replace(header_target, header_replacement)

# 9. Cash Book Page (~L1962)
cashbook_target = """    officers = sorted(branch_loans['Officer'].dropna().unique()) if not branch_loans.empty else []
    selected_officer = ctl3.selectbox("Officer Filter", ["All Officers"] + list(officers))
    
    if selected_officer != "All Officers":"""

cashbook_replacement = """    officers = sorted(branch_loans['Officer'].dropna().unique()) if not branch_loans.empty else []
    display_options = ["All Officers"] + [CO_DISPLAY_MAP.get(o, o) for o in officers]
    selected_display = ctl3.selectbox("Officer Filter", display_options)
    selected_officer = "All Officers" if selected_display == "All Officers" else CO_NAME_MAP.get(selected_display, selected_display)
    
    if selected_officer != "All Officers":"""
content = content.replace(cashbook_target, cashbook_replacement)

# 10. Data Editor update (~L421) and Data Editor column (~L2207)
# Update update_database_safe to map back Physical Names -> DB Names
db_safe_target = """    for _, row in edited_subset.iterrows():
        db_data = {UI_TO_DB_LOANS[k]: row[k] for k in row.keys() if k in UI_TO_DB_LOANS}
        supabase.table("loans").upsert(db_data).execute()"""

db_safe_replacement = """    for _, row in edited_subset.iterrows():
        db_data = {UI_TO_DB_LOANS[k]: row[k] for k in row.keys() if k in UI_TO_DB_LOANS}
        # Translate display name back to DB username before saving
        if "officer" in db_data:
            db_data["officer"] = CO_NAME_MAP.get(db_data["officer"], db_data["officer"])
        supabase.table("loans").upsert(db_data).execute()"""
content = content.replace(db_safe_target, db_safe_replacement)

# Update Data Editor displaying physical names
editor_target1 = """        display_df = pd.DataFrame(display_data)"""
editor_replacement1 = """        display_df = pd.DataFrame(display_data)
        if "Officer" in display_df.columns:
            display_df["Officer"] = display_df["Officer"].apply(lambda x: CO_DISPLAY_MAP.get(x, x))"""
content = content.replace(editor_target1, editor_replacement1)

editor_target2 = """                "Officer": st.column_config.SelectboxColumn("Officer", options=["CO1", "CO2", "System Admin"], disabled=(ROLE == "Officer")),"""
editor_replacement2 = """                "Officer": st.column_config.SelectboxColumn("Officer", options=list(CO_NAME_MAP.keys()) if CO_NAME_MAP else ["CO1", "CO2"], disabled=(ROLE == "Officer")),"""
content = content.replace(editor_target2, editor_replacement2)

# Officer Performance Report
perf_target = """        officers = my_loans['Officer'].unique() if not my_loans.empty else []
        selected_officer = st.selectbox("Select Officer:", ["All"] + list(officers))
        
        if selected_officer != "All":"""

perf_replacement = """        officers = my_loans['Officer'].unique() if not my_loans.empty else []
        display_options = ["All"] + [CO_DISPLAY_MAP.get(o, o) for o in officers]
        selected_display = st.selectbox("Select Officer:", display_options)
        selected_officer = "All" if selected_display == "All" else CO_NAME_MAP.get(selected_display, selected_display)
        
        if selected_officer != "All":"""
content = content.replace(perf_target, perf_replacement)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Finished patching app.py.")
