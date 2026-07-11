import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Let's do a multi_replace for `calculate_loan_setup` and the Origination Form

def_calculate = """def calculate_loan_setup(amount, product_type, product_category="Finance"):
    \"\"\"Calculate loan setup parameters\"\"\"
    if product_category == "Asset":
        if "Cash and Carry" in str(product_type):
            rate = 0.0
            duration = 1
            freq = "One-Time"
            round_step = 1
            force_gap = False
        elif "60-Day" in str(product_type):
            rate = 0.12
            duration = 60
            freq = "Daily"
            round_step = 50
            force_gap = False
        else:
            rate = 0.21
            duration = 120
            freq = "Daily"
            round_step = 50
            force_gap = False
            
        interest = amount * rate
        # For assets, upfront fee determines actual repayment later.
        # We'll return 0 for gap and a default loan_repayment assuming 0 upfront.
        gap = 0
        loan_repayment = (amount + interest) / duration
        return {
            "freq": freq,
            "duration": duration,
            "interest": interest,
            "initial_payment": gap,
            "loan_repayment": loan_repayment
        }
        
    # Finance Product Logic
    if "Daily" in str(product_type):
        rate = 0.12
        duration = 60
        freq = "Daily"
        round_step = 50
        force_gap = False
    elif "12 Weeks" in str(product_type):
        rate = 0.12
        duration = 12
        freq = "Weekly"
        round_step = 50
        force_gap = True
    else:
        rate = 0.21
        duration = 24
        freq = "Weekly"
        round_step = 50
        force_gap = True
    
    interest = amount * rate
    raw_val = amount / duration
    
    if raw_val.is_integer():
        loan_repayment = int(raw_val)
        gap = 0
    else:
        loan_repayment = math.floor(raw_val / round_step) * round_step
        while True:
            gap = amount - (loan_repayment * duration)
            is_valid = True if gap >= 0 else False
            if force_gap and (gap % 1000 != 0 or gap < 1000):
                is_valid = False
            if is_valid:
                break
            loan_repayment -= round_step
            if loan_repayment <= 0:
                loan_repayment = 0
                gap = amount
                break
    
    return {
        "freq": freq,
        "duration": duration,
        "interest": interest,
        "initial_payment": gap,
        "loan_repayment": loan_repayment
    }
"""

# Replace the def calculate_loan_setup block
import re
content = re.sub(r'def calculate_loan_setup\(amount, product_type\):.*?return \{.*?"loan_repayment": loan_repayment\n    \}', def_calculate, content, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("calculate_loan_setup updated.")
