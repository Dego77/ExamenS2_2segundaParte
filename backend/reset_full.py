import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv
from passlib.context import CryptContext

load_dotenv()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password):
    return pwd_context.hash(password)

MASTER_URL = os.getenv("DATABASE_URL")
engine = create_engine(MASTER_URL)

email = "juanperez_tg@asiscar.com"
h = get_password_hash("123456")

# 1. Update Master DB
with engine.connect() as conn:
    conn.execute(text("UPDATE tecnicos SET password_hash = :h, primer_login = True WHERE correo = :e"), {"h": h, "e": email})
    conn.commit()
    print("Master DB reseteado")

# 2. Update Tenant DB
tenant_url = MASTER_URL.rsplit('/', 1)[0] + "/taller_tallergatito2"
tenant_engine = create_engine(tenant_url)
with tenant_engine.connect() as conn:
    conn.execute(text("UPDATE tecnicos SET password_hash = :h, primer_login = True WHERE correo = :e"), {"h": h, "e": email})
    conn.commit()
    print("Tenant DB reseteado")
