import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. REMOVE OLD AUTHENTICATION
import re
content = re.sub(r'# --- PASSWORD HASHING ---.*?def get_user_info\(username: str\):.*?return FALLBACK_USERS.get\(username\.lower\(\)\)', 
"""# --- RBAC AUTHENTICATION ---
def authenticate_user(username, password):
    if not supabase:
        return None
    try:
        res = supabase.table("app_users").select("*").eq("username", username).eq("password", password).execute()
        if res.data and len(res.data) > 0:
            user = res.data[0]
            return {
                'user_name': user['username'],
                'user_role': user['role'],
                'branch_name': user['branch_name']
            }
    except Exception as e:
        st.error(f"Auth error: {e}")
    return None""", content, flags=re.DOTALL)

# 2. UPDATE LOAD_LOANS AND LOAD_REPAYMENTS
# load_loans
def_load_loans = """def load_loans():
    \"\"\"Load loans filtered by RBAC\"\"\"
    if not supabase:
        return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))
    try:
        query = supabase.table("loans").select("*")
        
        # RBAC Filters
        if st.session_state.get('user_role') == 'CO':
            query = query.eq('Officer', st.session_state.get('user_name'))
        elif st.session_state.get('user_role') == 'BM':
            query = query.eq('Branch', st.session_state.get('branch_name'))
            
        response = query.execute()
        if not response.data:
            return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))
        df = pd.DataFrame(response.data).rename(columns=DB_TO_UI_LOANS)
        num_cols = ['Loan Amount', 'Active Credit', 'Loan Repay', 'Total Due']
        for c in num_cols:
            df[c] = pd.to_numeric(df[c], errors='coerce').fillna(0)
        return df
    except Exception as e:
        st.error(f"Database Error: {e}")
        return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))"""
content = re.sub(r'def load_loans\(\):.*?return pd\.DataFrame\(columns=list\(DB_TO_UI_LOANS\.values\(\)\)\)', def_load_loans, content, flags=re.DOTALL, count=1)

# load_repayments
def_load_repayments = """def load_repayments():
    \"\"\"Load repayments filtered by RBAC\"\"\"
    if not supabase:
        return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
    try:
        query = supabase.table("repayments").select("*")
        
        # RBAC Filters
        if st.session_state.get('user_role') == 'CO':
            query = query.eq('Officer', st.session_state.get('user_name'))
        elif st.session_state.get('user_role') == 'BM':
            query = query.eq('Branch', st.session_state.get('branch_name'))
            
        response = query.execute()
        if not response.data:
            return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
        df = pd.DataFrame(response.data).rename(columns=DB_TO_UI_REP)
        
        return df
    except Exception as e:
        st.error(f"Database Error: {e}")
        return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))"""
content = re.sub(r'def load_repayments\(\):.*?return pd\.DataFrame\(columns=list\(DB_TO_UI_REP\.values\(\)\)\)', def_load_repayments, content, flags=re.DOTALL, count=1)

# 3. SET UP LOGIN WALL AND SESSION STATE
# Around line 700 we have:
# USER = "CO1"  # Hardcoded for now
# BRANCH = "Ogijo"
# ROLE = "Officer" # "Officer", "BM", "Admin"
login_wall = """# --- INITIALIZE SESSION STATE ---
if 'logged_in' not in st.session_state:
    st.session_state['logged_in'] = False

# --- LOGIN WALL ---
if not st.session_state['logged_in']:
    st.markdown("<br><br><br>", unsafe_allow_html=True)
    col1, col2, col3 = st.columns([1, 1.2, 1])
    with col2:
        st.markdown("<div class='card' style='text-align: center;'>", unsafe_allow_html=True)
        st.markdown("<h2 style='color: #2E7D32;'>🌱 ICARE Microfinance</h2>", unsafe_allow_html=True)
        st.markdown("<p style='color: #666;'>Secure Portal Login</p>", unsafe_allow_html=True)
        st.markdown("---")
        
        with st.form("login_form"):
            username_input = st.text_input("Username")
            password_input = st.text_input("Password", type="password")
            submit_btn = st.form_submit_button("Sign In", use_container_width=True)
            
            if submit_btn:
                if username_input and password_input:
                    auth_data = authenticate_user(username_input, password_input)
                    if auth_data:
                        st.session_state['logged_in'] = True
                        st.session_state['user_name'] = auth_data['user_name']
                        st.session_state['user_role'] = auth_data['user_role']
                        st.session_state['branch_name'] = auth_data['branch_name']
                        st.rerun()
                    else:
                        st.error("Invalid username or password.")
                else:
                    st.warning("Please enter both username and password.")
        st.markdown("</div>", unsafe_allow_html=True)
    st.stop()  # Halt execution until logged in

# Extract session variables
USER = st.session_state['user_name']
BRANCH = st.session_state['branch_name']
ROLE = st.session_state['user_role']

"""
content = re.sub(r'USER = "CO1".*?ROLE = "Officer" # "Officer", "BM", "Admin"', login_wall, content, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Auth and Loaders updated.")
