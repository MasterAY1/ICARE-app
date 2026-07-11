import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

lines = content.split('\n')

for i, line in enumerate(lines):
    if 'active_credit = amount - manual_gap' in line:
        new_block = """            if product_category == "Asset":
                if "Cash and Carry" in product:
                    active_credit = 0
                    final_repay = 0
                else:
                    active_credit = remaining_balance
                    final_repay = math.ceil(actual_repayment / 10) * 10
            else:
                active_credit = amount - manual_gap
                raw_repay = active_credit / setup['duration']
                final_repay = math.ceil(raw_repay / 10) * 10"""
        lines[i:i+3] = new_block.split('\n')
        break

with open(file_path, "w", encoding="utf-8") as f:
    f.write('\n'.join(lines))
    
print("Updated active_credit and final_repay logic")
