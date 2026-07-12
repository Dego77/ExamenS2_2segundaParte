import os
# pyrefly: ignore [missing-import]
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from passlib.context import CryptContext
#hola
def check():
    load_dotenv()
    url = os.getenv("DATABASE_URL")
    engine = create_engine(url)
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    
    with engine.connect() as conn:
        result = conn.execute(text("SELECT password_hash FROM talleres WHERE correo='gatito2@taller.com'")).fetchone()
        if not result:
            print("Workshop gatito2@taller.com not found.")
            return
            
        hash_str = result[0]
        print("Hash in DB:", hash_str)
        
        candidates = ["password123", "123456", "admin123", "gatito123", "gatito2", "gatito"]
        found = False
        for c in candidates:
            if pwd_context.verify(c, hash_str):
                print(f"Password for gatito2@taller.com is: {c}")
                found = True
                break
        
        if not found:
            print("Password does not match common candidates. Updating password to 'password123' for ease of testing...")
            new_hash = pwd_context.hash("password123")
            conn.execute(text("UPDATE talleres SET password_hash = :h WHERE correo = 'gatito2@taller.com'"), {"h": new_hash})
            conn.commit()
            print("Password successfully updated to 'password123'.")

if __name__ == "__main__":
    check()
