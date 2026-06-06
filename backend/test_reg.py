import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
import crud, schemas, models_shared

def test_registration():
    load_dotenv()
    url = os.getenv("DATABASE_URL")
    engine = create_engine(url)
    Session = sessionmaker(bind=engine)
    db = Session()
    
    # Datos que el usuario mandó en Postman
    data = {
        "nombres": "Juan",
        "apellidos": "Perez",
        "ci_dni": "1234567",
        "telefono": "70010020",
        "correo": "juan@example.com",
        "password": "password123"
    }
    
    try:
        cliente_schema = schemas.ClienteCreate(**data)
        print("Intentando crear cliente...")
        new_cliente = crud.create_cliente_master(db, cliente_schema)
        print(f"✅ Cliente creado con ID: {new_cliente.id_cliente}")
    except Exception as e:
        print(f"❌ Error al crear cliente: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    test_registration()
