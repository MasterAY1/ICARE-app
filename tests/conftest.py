"""
Pytest configuration ensuring root directory is on sys.path.
"""
import sys
import os

root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if root_dir not in sys.path:
    sys.path.insert(0, root_dir)

# Ensure a secure test secret is available for test execution
os.environ.setdefault("ICARE_AUTH_SECRET", "test-isolated-icare-auth-secret-key-32bytes-minimum")
