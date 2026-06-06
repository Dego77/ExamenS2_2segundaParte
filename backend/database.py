import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

load_dotenv()

# Base de datos Maestra
MASTER_DATABASE_URL = os.getenv("DATABASE_URL")
if not MASTER_DATABASE_URL:
    MASTER_DATABASE_URL = "postgresql://postgres:Acnologia123.@localhost/emergencias_vehiculares_master"

master_engine = create_engine(MASTER_DATABASE_URL, pool_pre_ping=True)
MasterSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=master_engine)

# Caché de conexiones para Talleres
tenant_engines = {}

def get_tenant_engine(db_name: str):
    if db_name not in tenant_engines:
        base_url = MASTER_DATABASE_URL.rsplit('/', 1)[0]
        tenant_url = f"{base_url}/{db_name}"
        tenant_engines[db_name] = create_engine(tenant_url, pool_pre_ping=True)
    return tenant_engines[db_name]

def get_master_db():
    db = MasterSessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_taller_db(id_taller: int):
    master_db = MasterSessionLocal()
    # Importación diferida para evitar ciclos
    import models_shared
    try:
        taller = master_db.query(models_shared.Taller).filter(models_shared.Taller.id_taller == id_taller).first()
        if not taller or not taller.db_name:
            # Fallback a un nombre por defecto si no tiene uno (para migración de los que ya existen)
            db_name = f"taller_default_{id_taller}"
        else:
            db_name = taller.db_name
            
        engine = get_tenant_engine(db_name)
        Session = sessionmaker(bind=engine)
        db = Session()
        try:
            yield db
        finally:
            db.close()
    finally:
        master_db.close()

def get_tenant_session(db_name: str):
    engine = get_tenant_engine(db_name)
    Session = sessionmaker(bind=engine)
    return Session()

# Alias obligatorios para compatibilidad con routers antiguos
get_db = get_master_db
get_tenant_db = get_taller_db
