import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

def diagnostic():
    load_dotenv()
    url = os.getenv("DATABASE_URL")
    print(f"Probando conexión a: {url}")
    try:
        engine = create_engine(url)
        with engine.connect() as conn:
            print("✅ Conexión exitosa a la base de datos.")
            
            # Listar tablas
            result = conn.execute(text("SELECT table_name FROM information_schema.tables WHERE table_schema='public'"))
            tables = [row[0] for row in result]
            print(f"Tablas encontradas: {tables}")
            
            if "clientes" in tables:
                result = conn.execute(text("SELECT correo, nombres FROM clientes"))
                rows = list(result)
                print(f"Número de clientes: {len(rows)}")
                for row in rows:
                    print(f" - Correo: {row[0]}, Nombre: {row[1]}")
            else:
                print("❌ La tabla 'clientes' no existe.")
                
            if "talleres" in tables:
                result = conn.execute(text("SELECT correo, razon_social FROM talleres"))
                print(f"Talleres registrados: {[row for row in result]}")
            else:
                print("❌ La tabla 'talleres' no existe.")
                
    except Exception as e:
        print(f"❌ Error de conexión: {e}")

if __name__ == "__main__":
    diagnostic()
