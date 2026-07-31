from auth.authorization import get_nav_options
from domain.entities.user import User
from datetime import datetime

test_roles = ["Super Admin", "Admin", "Branch Manager", "BM", "Area Manager", "AM", "Credit Officer", "CO", "Officer"]

for r in test_roles:
    u = User(
        id="u1",
        username="test",
        full_name="Test User",
        role=r,
        branch_name="Ogijo",
        password_hash="hash",
        created_at=datetime.now(),
        branch_id="b1"
    )
    opts = get_nav_options(u)
    print(f"Role '{r}': Audit Center in nav_options -> {'Audit Center' in opts}. All options: {opts}")
