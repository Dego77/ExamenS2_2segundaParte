import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv
from passlib.context import CryptContext

load_dotenv()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

MASTER_URL = os.getenv("DATABASE_URL")
engine = create_engine(MASTER_URL)

email = "juanperez_tg@asiscar.com"

with engine.connect() as conn:
    res = conn.execute(text("SELECT password_hash, primer_login FROM tecnicos WHERE correo = :e"), {"e": email})
    row = res.fetchone()
    if row:
        stored_hash = row[0]
        primer_login = row[1]
        print(f"Stored Hash: {stored_hash}")
        print(f"Primer Login: {primer_login}")
        print(f"Matches 123456? {verify_password('123456', stored_hash)}")
        print(f"Matches 654321? {verify_password('654321', stored_hash)}")
    else:
        print("User NOT found")
