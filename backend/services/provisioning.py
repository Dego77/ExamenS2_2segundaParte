import os
from sqlalchemy import create_engine, text
from database import MASTER_DATABASE_URL
from models_tenant import Base as TenantBase

def create_tenant_database(db_name: str):
    # Para crear una base de datos en Postgres, necesitamos conectarnos a una DB existente (como 'postgres')
    # Extraemos la base de la URL maestra
    admin_url = MASTER_DATABASE_URL.rsplit('/', 1)[0] + "/postgres"
    engine = create_engine(admin_url, isolation_level="AUTOCOMMIT")
    
    with engine.connect() as conn:
        # Verificamos si ya existe
        try:
            result = conn.execute(text(f"SELECT 1 FROM pg_database WHERE datname='{db_name}'"))
            if not result.fetchone():
                print(f"🛠 Creando base de datos: {db_name}")
                conn.execute(text(f"CREATE DATABASE {db_name}"))
        except Exception as e:
            print(f"❌ Error al ejecutar CREATE DATABASE: {e}")
            raise e
            
    # Inicializamos las tablas en la nueva base de datos
    try:
        tenant_url = MASTER_DATABASE_URL.rsplit('/', 1)[0] + f"/{db_name}"
        tenant_engine = create_engine(tenant_url)
        TenantBase.metadata.create_all(bind=tenant_engine)
        print(f"✅ Base de datos {db_name} inicializada con éxito.")
    except Exception as e:
        print(f"❌ Error al inicializar tablas en {db_name}: {e}")
        raise e

def generate_db_name(razon_social: str):
    # Genera un nombre de DB válido a partir del nombre del taller
    clean_name = "".join(e for e in razon_social if e.isalnum()).lower()
    return f"taller_{clean_name}"
