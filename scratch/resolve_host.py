import socket

for name in [
    "zkphpwixqpebsctfklpd.supabase.co",
    "db.zkphpwixqpebsctfklpd.supabase.co",
    "aws-0-eu-central-1.pooler.supabase.com",
    "aws-0-us-east-1.pooler.supabase.com"
]:
    try:
        ip = socket.gethostbyname(name)
        print(f"{name} -> {ip}")
    except Exception as e:
        print(f"Could not resolve {name}: {e}")
