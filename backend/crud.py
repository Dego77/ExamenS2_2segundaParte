from sqlalchemy.orm import Session
from passlib.context import CryptContext
import models_shared, models_tenant, schemas

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password):
    return pwd_context.hash(password)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

# --- CRUD Cliente ---

# Operaciones Master (Globales)
def get_cliente_master(db: Session, cliente_id: int):
    return db.query(models_shared.Cliente).filter(models_shared.Cliente.id_cliente == cliente_id).first()

def get_cliente_master_by_email(db: Session, email: str):
    return db.query(models_shared.Cliente).filter(models_shared.Cliente.correo == email).first()

def get_clientes_master(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models_shared.Cliente).offset(skip).limit(limit).all()

# Operaciones Tenant (Locales por Taller)
def get_cliente_tenant(db: Session, cliente_id: int):
    return db.query(models_tenant.Cliente).filter(models_tenant.Cliente.id_cliente == cliente_id).first()

def create_cliente_master(db: Session, cliente: schemas.ClienteCreate):
    hashed_password = get_password_hash(cliente.password)
    db_cliente = models_shared.Cliente(
        nombres=cliente.nombres,
        apellidos=cliente.apellidos,
        ci_dni=cliente.ci_dni,
        telefono=cliente.telefono,
        correo=cliente.correo,
        password_hash=hashed_password
    )
    db.add(db_cliente)
    db.commit()
    db.refresh(db_cliente)
    return db_cliente

def sync_cliente_to_tenant(tenant_db: Session, master_cliente: models_shared.Cliente):
    # Verifica si ya existe en el tenant (por ID global o correo)
    db_cliente = tenant_db.query(models_tenant.Cliente).filter(models_tenant.Cliente.id_cliente == master_cliente.id_cliente).first()
    if not db_cliente:
        db_cliente = models_tenant.Cliente(
            id_cliente=master_cliente.id_cliente,
            nombres=master_cliente.nombres,
            apellidos=master_cliente.apellidos,
            ci_dni=master_cliente.ci_dni,
            telefono=master_cliente.telefono,
            correo=master_cliente.correo,
            password_hash=master_cliente.password_hash # Copiamos el hash
        )
        tenant_db.add(db_cliente)
        tenant_db.commit()
        tenant_db.refresh(db_cliente)
    return db_cliente

def sync_vehiculo_to_tenant(tenant_db: Session, master_vehiculo: models_shared.Vehiculo, tenant_cliente_id: int):
    db_vehiculo = tenant_db.query(models_tenant.Vehiculo).filter(models_tenant.Vehiculo.id_vehiculo == master_vehiculo.id_vehiculo).first()
    if not db_vehiculo:
        db_vehiculo = models_tenant.Vehiculo(
            id_vehiculo=master_vehiculo.id_vehiculo,
            id_cliente=tenant_cliente_id,
            placa=master_vehiculo.placa,
            marca=master_vehiculo.marca,
            modelo=master_vehiculo.modelo,
            año=master_vehiculo.año,
            color=master_vehiculo.color,
            tipo_transmision=master_vehiculo.tipo_transmision,
            tipo_combustible=master_vehiculo.tipo_combustible
        )
        tenant_db.add(db_vehiculo)
        tenant_db.commit()
        tenant_db.refresh(db_vehiculo)
    return db_vehiculo

def create_taller(db: Session, taller: schemas.TallerCreate, db_name: str):
    hashed_password = get_password_hash(taller.password)
    db_taller = models_shared.Taller(
        razon_social=taller.razon_social,
        nombre_representante=taller.nombre_representante,
        nit=taller.nit,
        correo=taller.correo,
        ubicacion_base_latitud=taller.ubicacion_base_latitud,
        ubicacion_base_longitud=taller.ubicacion_base_longitud,
        direccion_fisica=taller.direccion_fisica,
        telefono_taller=taller.telefono_taller,
        logo_url=taller.logo_url,
        es_24_7=taller.es_24_7,
        horario_apertura=taller.horario_apertura,
        horario_cierre=taller.horario_cierre,
        horario_cierre_sabado=taller.horario_cierre_sabado,
        foto_nit_url=taller.foto_nit_url,
        foto_local_url=taller.foto_local_url,
        cuenta_bancaria=taller.cuenta_bancaria,
        password_hash=hashed_password,
        db_name=db_name
    )
    db.add(db_taller)
    db.commit()
    db.refresh(db_taller)
    return db_taller

def get_talleres(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models_shared.Taller).offset(skip).limit(limit).all()

# Se mantiene create_cliente original apuntando a Master para compatibilidad
def create_cliente(db: Session, cliente: schemas.ClienteCreate):
    return create_cliente_master(db, cliente)

# --- Operaciones en DB de Taller (Tenant) ---

def create_tecnico(db: Session, tecnico: schemas.TecnicoCreate):
    hashed_password = get_password_hash(tecnico.password)
    
    # 1. Crear en el Tenant (Local)
    db_tecnico_tenant = models_tenant.Tecnico(
        nombres=tecnico.nombres,
        apellidos=tecnico.apellidos,
        ci_tecnico=tecnico.ci_tecnico,
        telefono_contacto=tecnico.telefono_contacto,
        correo=tecnico.correo,
        password_hash=hashed_password
    )
    db.add(db_tecnico_tenant)
    db.commit()
    db.refresh(db_tecnico_tenant)
    
    # 2. Sincronizar con la Maestra (Global para Login)
    # Obtenemos la sesión maestra (esto es un poco ineficiente pero necesario para el login global)
    from database import MasterSessionLocal
    master_db = MasterSessionLocal()
    try:
        db_tecnico_master = models_shared.Tecnico(
            id_taller=tecnico.id_taller,
            nombres=tecnico.nombres,
            apellidos=tecnico.apellidos,
            ci_tecnico=tecnico.ci_tecnico,
            telefono_contacto=tecnico.telefono_contacto,
            correo=tecnico.correo,
            password_hash=hashed_password
        )
        master_db.add(db_tecnico_master)
        master_db.commit()
    finally:
        master_db.close()
        
    return db_tecnico_tenant

def get_tecnico_by_email(db: Session, email: str):
    # Por defecto busca en la base de datos que se le pase (usualmente la Maestra para login)
    # Pero primero intentamos en models_shared por si es el login global
    import models_shared
    return db.query(models_shared.Tecnico).filter(models_shared.Tecnico.correo == email).first()

def get_tecnicos_by_taller(db: Session):
    return db.query(models_tenant.Tecnico).all()

def create_incidente_master(db: Session, incidente: schemas.IncidenteCreate):
    db_incidente = models_shared.Incidente(
        id_cliente=incidente.id_cliente,
        id_vehiculo=incidente.id_vehiculo,
        ubicacion_latitud=incidente.ubicacion_latitud,
        ubicacion_longitud=incidente.ubicacion_longitud,
        tipo_problema=incidente.tipo_problema,
        descripcion_manual=incidente.descripcion_manual,
        nivel_prioridad=incidente.nivel_prioridad,
        estado_solicitud='Pendiente'
    )
    db.add(db_incidente)
    db.commit()
    db.refresh(db_incidente)
    return db_incidente

def create_incidente_tenant(db: Session, incidente_data: dict):
    db_incidente = models_tenant.Incidente(**incidente_data)
    db.add(db_incidente)
    db.commit()
    db.refresh(db_incidente)
    return db_incidente

def create_incidente(db: Session, incidente: schemas.IncidenteCreate):
    # Por defecto los incidentes nuevos se crean en la Maestra
    return create_incidente_master(db, incidente)
