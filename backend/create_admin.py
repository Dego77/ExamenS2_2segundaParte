import sys
import os

# Asegurarnos de que el script pueda importar módulos del backend
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
import models
import schemas
from crud import get_password_hash

def create_super_admin():
    db = SessionLocal()
    try:
        # Verificar si ya existe
        admin_existente = db.query(models.Admin).filter(models.Admin.correo == "asiscar.asistente@gmail.com").first()
        if admin_existente:
            print("El superusuario ya existe en la base de datos.")
            return

        # Crear nuevo admin
        nuevo_admin = models.Admin(
            nombre="Limberth (SuperAdmin)",
            correo="asiscar.asistente@gmail.com",
            password_hash=get_password_hash("AsiscarAsistente2026"),
            rol="Admin"
        )
        db.add(nuevo_admin)
        db.commit()
        print("✅ ¡Superusuario creado exitosamente!")
        print("Correo: asiscar.asistente@gmail.com")
        print("Clave: AsiscarAsistente2026")
    except Exception as e:
        print(f"❌ Error al crear superusuario: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    create_super_admin()
