import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from passlib.context import CryptContext

def verify_junior():
    load_dotenv()
    url = os.getenv("DATABASE_URL")
    engine = create_engine(url)
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    
    with engine.connect() as conn:
        result = conn.execute(text("SELECT password_hash FROM clientes WHERE correo='junior@gmail.com'")).fetchone()
        if not result:
            print("❌ Junior no encontrado.")
            return
            
        hash_str = result[0]
        # Probamos con las posibles contraseñas que el usuario mencionó
        passwords = ["123456", "1234567"]
        print(f"Hash en DB: {hash_str}")
        for p in passwords:
            is_correct = pwd_context.verify(p, hash_str)
            print(f"Probando '{p}': {'✅ SI' if is_correct else '❌ NO'}")

if __name__ == "__main__":
    verify_junior()
