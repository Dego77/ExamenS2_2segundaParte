import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    DATABASE_URL = "postgresql://postgres:Acnologia123.@localhost/emergencias_vehiculares_master"

engine = create_engine(DATABASE_URL)

def migrate():
    with engine.connect() as conn:
        print("🔍 Verificando columnas en tabla 'talleres'...")
        try:
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS db_name VARCHAR(100);"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS estado_aprobacion VARCHAR(20) DEFAULT 'Pendiente';"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS ubicacion_base_latitud FLOAT;"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS ubicacion_base_longitud FLOAT;"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS direccion_fisica VARCHAR(255);"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS telefono_taller VARCHAR(20);"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS logo_url VARCHAR(255);"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS es_24_7 BOOLEAN DEFAULT FALSE;"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS horario_apertura TIME;"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS horario_cierre TIME;"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS horario_cierre_sabado TIME;"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS foto_nit_url VARCHAR(255);"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS foto_local_url VARCHAR(255);"))
            conn.execute(text("ALTER TABLE talleres ADD COLUMN IF NOT EXISTS cuenta_bancaria VARCHAR(100);"))
            conn.commit()
            print("✅ Todas las columnas de Taller han sido añadidas con éxito.")
        except Exception as e:
            print(f"❌ Error durante la migración: {e}")

if __name__ == "__main__":
    migrate()
