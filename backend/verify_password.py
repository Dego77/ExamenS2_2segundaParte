import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from passlib.context import CryptContext

def verify_manual():
    load_dotenv()
    url = os.getenv("DATABASE_URL")
    engine = create_engine(url)
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    
    with engine.connect() as conn:
        result = conn.execute(text("SELECT password_hash FROM clientes WHERE correo='conductor@test.com'")).fetchone()
        if not result:
            print("❌ Usuario no encontrado.")
            return
            
        hash_str = result[0]
        password = "password123"
        is_correct = pwd_context.verify(password, hash_str)
        print(f"Hash en DB: {hash_str}")
        print(f"Password: {password}")
        print(f"¿Es correcto?: {is_correct}")

if __name__ == "__main__":
    verify_manual()
