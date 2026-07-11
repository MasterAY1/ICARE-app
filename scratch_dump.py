import sys

with open('app.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if line.startswith('elif page == "Collections":'):
        start_idx = i
    if start_idx != -1 and line.startswith('elif page == "Disbursement":'):
        end_idx = i
        break

with open('temp_collections.py', 'w', encoding='utf-8') as f:
    f.writelines(lines[start_idx:end_idx])
print(f'Wrote {end_idx - start_idx} lines to temp_collections.py')
