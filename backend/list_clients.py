import os
import models_shared
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    DATABASE_URL = "postgresql://postgres:Acnologia123.@localhost/emergencias_vehiculares_master"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)

def list_clients():
    db = SessionLocal()
    try:
        clients = db.query(models_shared.Cliente).limit(10).all()
        print("📋 Clientes (Coductores) registrados:")
        for c in clients:
            print(f"- {c.nombres} {c.apellidos} | Correo: {c.correo} | CI: {c.ci_dni}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    list_clients()
