import bcrypt
import getpass

def main():
    print("=== ICARE Emergency Password Hasher ===")
    print("Use this tool to generate a bcrypt hash for manual insertion into Supabase.")
    print("---------------------------------------------------------")
    
    try:
        password = getpass.getpass("Enter the new password to hash (input will be hidden): ")
    except Exception:
        # Fallback if getpass fails in certain terminal environments
        password = input("Enter the new password to hash: ")
    
    if not password:
        print("Error: Password cannot be empty.")
        return
        
    print("\nGenerating hash...")
    # Generate bcrypt hash
    hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    
    print("\nSUCCESS! Copy the exact string below and paste it into the Supabase 'password' column:")
    print("=" * 65)
    print(hashed)
    print("=" * 65)
    print("Note: Make sure you do not accidentally copy any extra spaces.")

if __name__ == "__main__":
    main()
