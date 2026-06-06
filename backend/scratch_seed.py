from database import SessionLocal
import routers.talleres as talleres

print("Conectando a Supabase PostgreSQL...")
db = SessionLocal()
try:
    print("Actualizando Catalogo de Servicios del Taller en Supabase...")
    servicios = talleres.get_all_servicios(db)
    print(f"Exito. Servicios registrados: {len(servicios)}")

    print("Actualizando Catalogo de Especialidades de Tecnicos en Supabase...")
    especialidades = talleres.get_especialidades_disponibles(db)
    print(f"Exito. Especialidades registradas: {len(especialidades)}")
finally:
    db.close()
    print("Conexion cerrada.")
