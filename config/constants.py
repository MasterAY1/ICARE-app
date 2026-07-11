# Loan Statuses
STATUS_PENDING = "Pending"
STATUS_APPROVED = "Approved"
STATUS_ACTIVE = "Active"
STATUS_COMPLETED = "Completed"
STATUS_CLOSED = "Closed"
STATUS_REJECTED = "Rejected"

# Product Categories
CATEGORY_FINANCE = "Finance"
CATEGORY_ASSET = "Asset"

# Finance Products
FINANCE_PRODUCTS = [
    "Daily 60 Days", 
    "Daily 120 Days", 
    "Weekly 12W", 
    "Weekly 24W", 
    "Monthly 3M", 
    "Monthly 6M"
]

# Asset Products
ASSET_PRODUCTS = [
    "60-Day Asset", 
    "120-Day Asset", 
    "Weekly 12W Asset", 
    "Weekly 24W Asset", 
    "Monthly 3M Asset", 
    "Monthly 6M Asset", 
    "Cash and Carry"
]

# Collection Types
COLLECTION_TYPES = ["Savings", "Loan", "Withdrawal", "Others", "Recovery"]

# Onboarding Required Columns
ONBOARDING_REQUIRED_COLUMNS = [
    "Member Name*", "Gender*", "Phone Number*", "Residential Address*",
    "BVN*", "NIN", "Guarantor Name*", "Guarantor Phone Number*",
    "Group Name", "Group Leader Name", "Group Savings Balance",
    "Branch Laps Savings Balance", "Misc Fees Savings Balance",
    "Loan Type (Product)*", "Principal loan", "Active Credit",
    "Current credit balance", "Member Savings Balance"
]
