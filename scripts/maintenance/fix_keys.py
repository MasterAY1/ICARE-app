import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("st.session_state.get('user_role')", "st.session_state.get('role')")
content = content.replace("st.session_state.get('user_name')", "st.session_state.get('user')")
content = content.replace("st.session_state.get('branch_name')", "st.session_state.get('branch')")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Keys fixed.")
