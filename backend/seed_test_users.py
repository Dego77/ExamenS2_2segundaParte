from database import MasterSessionLocal, get_tenant_engine
from models_shared import Cliente, Taller
from models_tenant import Tecnico
from sqlalchemy.orm import sessionmaker
from crud import get_password_hash

def create_test_users():
    db_master = MasterSessionLocal()
    try:
        # 1. Crear Conductor (Cliente)
        cliente_email = "conductor@test.com"
        exists_c = db_master.query(Cliente).filter(Cliente.correo == cliente_email).first()
        if not exists_c:
            new_c = Cliente(
                nombres="Conductor",
                apellidos="De Prueba",
                ci_dni="1234567",
                telefono="70010020",
                correo=cliente_email,
                password_hash=get_password_hash("password123")
            )
            db_master.add(new_c)
            db_master.commit()
            print(f"Conductor creado: {cliente_email} / password123")
        else:
            print(f"El conductor {cliente_email} ya existe.")

        # 2. Crear Tecnico
        tecnico_email = "tecnico@test.com"
        taller = db_master.query(Taller).first() # Tomamos el primero disponible
        if taller:
            engine = get_tenant_engine(taller.db_name)
            Session = sessionmaker(bind=engine)
            db_t = Session()
            try:
                exists_te = db_t.query(Tecnico).filter(Tecnico.correo == tecnico_email).first()
                if not exists_te:
                    new_te = Tecnico(
                        id_taller=taller.id_taller,
                        nombres="Tecnico",
                        apellidos="De Prueba",
                        ci_tecnico="9998887",
                        telefono_contacto="70050060",
                        correo=tecnico_email,
                        password_hash=get_password_hash("password123")
                    )
                    db_t.add(new_te)
                    db_t.commit()
                    print(f"Tecnico creado en {taller.razon_social}: {tecnico_email} / password123")
                else:
                    print(f"El tecnico {tecnico_email} ya existe.")
            finally:
                db_t.close()
        else:
            print("No hay talleres registrados para crear un tecnico.")

    finally:
        db_master.close()

if __name__ == "__main__":
    create_test_users()
