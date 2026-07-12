from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import crud, schemas, schemas_auth
import models_shared as models
from database import get_master_db as get_db, get_tenant_db, get_taller_db
from services.provisioning import create_tenant_database, generate_db_name

router = APIRouter()

@router.post("/", response_model=schemas.TallerResponse)
def create_taller(taller: schemas.TallerCreate, db: Session = Depends(get_db)):
    # 1. Verificar si el correo ya existe
    existing_email = get_taller_by_email(db, taller.correo)
    if existing_email:
        raise HTTPException(
            status_code=400, 
            detail="Este correo electrónico ya está registrado en el sistema."
        )
    
    # 2. Verificar si el NIT ya existe
    existing_nit = db.query(models.Taller).filter(models.Taller.nit == taller.nit).first()
    if existing_nit:
        raise HTTPException(
            status_code=400, 
            detail=f"El NIT {taller.nit} ya se encuentra registrado."
        )

    # 3. Generar base de datos única para el taller
    db_name = generate_db_name(taller.razon_social)
    
    # 4. Crear el taller en la DB Maestra
    new_taller = crud.create_taller(db=db, taller=taller, db_name=db_name)
    
    # 5. La base de datos física se creará solo cuando el SuperAdmin apruebe la solicitud
    return new_taller

@router.get("/especialidades-disponibles")
def get_especialidades_disponibles_endpoint():
    return [] # Cada taller tiene sus propias especialidades ahora

@router.get("/{id_taller}", response_model=schemas.TallerResponse)
def read_taller(id_taller: int, db: Session = Depends(get_db)):
    taller = db.query(models.Taller).filter(models.Taller.id_taller == id_taller).first()
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
    return taller

@router.get("/", response_model=list[schemas.TallerResponse])
def read_talleres(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    talleres = crud.get_talleres(db, skip=skip, limit=limit)
    return talleres

def get_taller_by_email(db: Session, email: str):
    return db.query(models.Taller).filter(models.Taller.correo == email).first()

@router.post("/login")
def login(request: schemas_auth.LoginRequest, db: Session = Depends(get_db)):
    correo_limpio = request.correo.strip().lower()
    clave_limpia = request.password.strip()

    # 0. Cortocircuito para SuperAdmin (Garantiza velocidad y cero bloqueos)
    if correo_limpio == "admin@asistauto.com" and clave_limpia == "admin123":
        return {
            "access_token": "fake-jwt-token-admin",
            "token_type": "bearer",
            "user_id": 1,
            "user_name": "SuperAdmin",
            "role": "admin"
        }

    # 1. Intentar como Taller
    from sqlalchemy import func
    db_taller = db.query(models.Taller).filter(func.lower(models.Taller.correo) == correo_limpio).first()
    if not db_taller:
        raise HTTPException(status_code=404, detail="El usuario no existe")
        
    if not crud.verify_password(request.password, db_taller.password_hash):
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")

    return {
        "access_token": "fake-jwt-token-taller",
        "token_type": "bearer",
        "user_id": db_taller.id_taller,
        "user_name": db_taller.razon_social,
        "nit": db_taller.nit,
        "direccion": db_taller.direccion_fisica,
        "role": "taller"
    }
    
    # Crear admin por defecto si la tabla está vacía
    admins_count = db.query(models.Admin).count()
    if admins_count == 0:
        default_admin = models.Admin(
            nombre="SuperAdmin",
            correo="asiscar.asistente@gmail.com",
            password_hash=crud.pwd_context.hash("AsiscarAsistente2026")
        )
        db.add(default_admin)
        db.commit()
        
    db_admin = db.query(models.Admin).filter(models.Admin.correo == request.correo).first()
    if db_admin and crud.verify_password(request.password, db_admin.password_hash):
        return {
            "access_token": "fake-jwt-token-admin",
            "token_type": "bearer",
            "user_id": db_admin.id_admin,
            "user_name": db_admin.nombre,
            "role": "admin"
        }
        
    raise HTTPException(status_code=401, detail="Correo o contraseña incorrectos")

from fastapi import UploadFile, File
import os
import shutil

@router.post("/{id_taller}/upload-docs")
async def upload_documentos(
    id_taller: int,
    foto_nit: UploadFile = File(None),
    foto_local: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    import models
    taller = db.query(models.Taller).filter(models.Taller.id_taller == id_taller).first()
    
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")

    # TODO: Integración real con Supabase Storage. 
    # Por ahora, simularemos que subimos y obtenemos las URLs.
    
    if foto_nit:
        # Simulamos que subimos a Supabase y nos da esta URL:
        fake_url_nit = f"https://supabase.co/storage/v1/object/public/documentos_verificacion/nit_{id_taller}.jpg"
        taller.foto_nit_url = fake_url_nit
        
    if foto_local:
        # Simulamos que subimos a Supabase y nos da esta URL:
        fake_url_local = f"https://supabase.co/storage/v1/object/public/documentos_verificacion/local_{id_taller}.jpg"
        taller.foto_local_url = fake_url_local

    if foto_nit or foto_local:
        db.commit()
        db.refresh(taller)

    return {"message": "Documentos subidos exitosamente", "foto_nit_url": taller.foto_nit_url, "foto_local_url": taller.foto_local_url}

@router.post("/{id_taller}/horario")
def update_horario(id_taller: int, payload: dict, db: Session = Depends(get_db)):
    import models
    from datetime import time
    taller = db.query(models.Taller).filter(models.Taller.id_taller == id_taller).first()
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
        
    taller.es_24_7 = payload.get("es_24_7", False)
    
    ha = payload.get("horario_apertura")
    hc = payload.get("horario_cierre")
    
    try:
        if ha and ":" in ha:
            h, m = map(int, ha.split(":"))
            taller.horario_apertura = time(hour=h, minute=m)
        if hc and ":" in hc:
            h, m = map(int, hc.split(":"))
            taller.horario_cierre = time(hour=h, minute=m)
    except Exception as e:
        raise HTTPException(status_code=400, detail="Formato de hora inválido (Use HH:MM)")
            
    db.commit()
    return {"status": "success", "message": "Horario actualizado correctamente"}

@router.patch("/{id_taller}/aprobar")
def aprobar_taller(id_taller: int, db: Session = Depends(get_db)):
    """
    Endpoint para que el Superadmin apruebe un taller.
    Cambia el estado a 'Aprobado' y envía un correo de notificación.
    """
    import models
    from utils import send_approval_email
    
    taller = db.query(models.Taller).filter(models.Taller.id_taller == id_taller).first()
    
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
        
    if taller.estado_aprobacion == 'Aprobado':
        return {"message": "El taller ya se encuentra aprobado."}

    # Cambiar estado
    taller.estado_aprobacion = 'Aprobado'
    db.commit()
    db.refresh(taller)
    
    # Enviar correo de notificación
    correo_enviado = send_approval_email(destinatario=taller.correo, nombre_taller=taller.razon_social)
    
    mensaje = "Taller aprobado exitosamente."
    if not correo_enviado:
        mensaje += " (Aviso: Hubo un problema enviando el correo de notificación, pero el taller fue aprobado en base de datos)."

    return {
        "status": "success",
        "message": mensaje,
        "estado_actual": taller.estado_aprobacion
    }

@router.get("/{id_taller}/solicitudes")
def get_taller_solicitudes(id_taller: int, master_db: Session = Depends(get_db), tenant_db: Session = Depends(get_taller_db)):
    from services.matching_service import calcular_distancia
    from sqlalchemy import or_
    import models_shared
    import models_tenant
    
    taller = master_db.query(models_shared.Taller).filter(models_shared.Taller.id_taller == id_taller).first()
    
    # Buscamos incidentes en estado 'Pendiente', 'Notificado' o 'Aceptado' en el Tenant DB del taller
    incidentes = tenant_db.query(models_tenant.Incidente).filter(
        or_(
            models_tenant.Incidente.estado_solicitud == 'Pendiente',
            models_tenant.Incidente.estado_solicitud == 'Notificado',
            models_tenant.Incidente.estado_solicitud == 'Aceptado'
        )
    ).all()
    
    resultados = []
    for inc in incidentes:
        distancia = 1.5 # Default
        if taller and taller.ubicacion_base_latitud and taller.ubicacion_base_longitud and inc.ubicacion_latitud and inc.ubicacion_longitud:
            distancia = round(calcular_distancia(
                taller.ubicacion_base_latitud,
                taller.ubicacion_base_longitud,
                inc.ubicacion_latitud,
                inc.ubicacion_longitud
            ), 1)
            
        # Evidencias (Buscamos en la Maestra usando id_incidente)
        audio = master_db.query(models_shared.Evidencia).filter(
            models_shared.Evidencia.id_incidente == inc.id_incidente, 
            models_shared.Evidencia.tipo_recurso == 'Audio'
        ).first()
        foto = master_db.query(models_shared.Evidencia).filter(
            models_shared.Evidencia.id_incidente == inc.id_incidente, 
            models_shared.Evidencia.tipo_recurso == 'Foto'
        ).first()
        
        url_audio = audio.url_archivo if audio else None
        url_foto = foto.url_archivo if foto else None
 
        # Análisis IA (Buscamos en la Maestra)
        analisis = master_db.query(models_shared.AnalisisIA).filter(models_shared.AnalisisIA.id_incidente == inc.id_incidente).first()
        evaluacion_ia = analisis.resumen_estructurado if (analisis and analisis.resumen_estructurado) else "Calculando diagnóstico..."
 
        # Datos del Cliente/Vehículo (Buscamos en el Tenant del taller)
        t_cliente = tenant_db.query(models_tenant.Cliente).filter(models_tenant.Cliente.id_cliente == inc.id_cliente).first()
        t_vehiculo = tenant_db.query(models_tenant.Vehiculo).filter(models_tenant.Vehiculo.id_vehiculo == inc.id_vehiculo).first()
 
        # Buscar si ya enviamos cotización
        cot_enviada = master_db.query(models_shared.Cotizacion).filter(
            models_shared.Cotizacion.id_incidente == inc.id_incidente,
            models_shared.Cotizacion.id_taller == id_taller
        ).first()
        cotizacion_enviada_bool = True if cot_enviada else False

        # Buscar cotización aceptada si la hay
        cot_aceptada = master_db.query(models_shared.Cotizacion).filter(
            models_shared.Cotizacion.id_incidente == inc.id_incidente,
            models_shared.Cotizacion.id_taller == id_taller,
            models_shared.Cotizacion.estado == 'Aceptada'
        ).first()
        
        cot_info = None
        if cot_aceptada:
            cot_info = {
                "monto": float(cot_aceptada.monto_estimado),
                "tiempo_minutos": cot_aceptada.tiempo_estimado_minutos
            }

        resultados.append({
            "id_incidente": inc.id_incidente,
            "tipo_problema": inc.tipo_problema,
            "nivel_prioridad": inc.nivel_prioridad or "Media",
            "distancia_km": distancia,
            "cliente": f"{t_cliente.nombres} {t_cliente.apellidos}" if t_cliente else "Conductor",
            "vehiculo": f"{t_vehiculo.marca} {t_vehiculo.modelo} ({t_vehiculo.color})" if t_vehiculo else "Vehículo",
            "transcripcion_audio": inc.descripcion_manual or f"Falla reportada: {inc.tipo_problema}",
            "url_audio_evidencia": f"http://localhost:8001/{url_audio}" if url_audio else None,
            "url_foto_evidencia": f"http://localhost:8001/{url_foto}" if url_foto else None,
            "evaluacion_ia": evaluacion_ia,
            "latitud": inc.ubicacion_latitud,
            "longitud": inc.ubicacion_longitud,
            "estado_solicitud": inc.estado_solicitud,
            "cotizacion_aceptada": cot_info,
            "cotizacion_enviada": cotizacion_enviada_bool
        })
        
    return resultados



@router.post("/{id_taller}/tecnicos", response_model=schemas.TecnicoResponse)
def create_tecnico_endpoint(id_taller: int, tecnico: schemas.TecnicoCreate, db: Session = Depends(get_taller_db)):
    # Nota: No necesitamos buscar por correo en la Maestra, cada taller tiene sus propios técnicos aislados
    return crud.create_tecnico(db=db, tecnico=tecnico)

@router.get("/{id_taller}/tecnicos", response_model=list[schemas.TecnicoResponse])
def read_tecnicos(id_taller: int, db: Session = Depends(get_taller_db)):
    return crud.get_tecnicos_by_taller(db=db)

@router.get("/servicios/todos")
def get_all_servicios(db: Session = Depends(get_db)):
    import models_shared
    
    # Lista estática de servicios estándar que la plataforma soporta
    standard = [
        {"id": 1, "nombre_servicio": "Diagnóstico por Escáner y Reparación de Sistemas Eléctricos", "tarifa_base_estimada": 50.0},
        {"id": 2, "nombre_servicio": "Mantenimiento de Suspensión, Frenos y Neumáticos", "tarifa_base_estimada": 40.0},
        {"id": 3, "nombre_servicio": "Suministro e Inspección Rápida de Fluidos (Aceite/Combustible)", "tarifa_base_estimada": 30.0},
        {"id": 4, "nombre_servicio": "Reparación de Chapas y Codificación de Llaves Inteligentes", "tarifa_base_estimada": 80.0},
        {"id": 5, "nombre_servicio": "Servicio de Auxilio Vial y Traslado en Grúa", "tarifa_base_estimada": 150.0},
        {"id": 6, "nombre_servicio": "Mecánica Preventiva, Afinamiento y Reparación de Motor", "tarifa_base_estimada": 100.0},
        {"id": 7, "nombre_servicio": "Mantenimiento Integral del Sistema de Refrigeración", "tarifa_base_estimada": 60.0}
    ]
    
    # Devolver una combinación de los estándar y los que haya en la DB maestra
    db_servicios = db.query(models.Servicio).all()
    
    return standard + [
        {"id": s.id_servicio, "nombre_servicio": s.nombre_servicio, "tarifa_base_estimada": float(s.tarifa_base_estimada)}
        for s in db_servicios
    ]

@router.get("/{id_taller}/servicios")
def get_taller_servicios(id_taller: int, db: Session = Depends(get_taller_db)):
    import models_tenant as models
    ts = db.query(models.TallerServicio).all()
    return [t.id_servicio for t in ts]

@router.post("/{id_taller}/servicios")
def update_taller_servicios(id_taller: int, payload: dict, db: Session = Depends(get_taller_db)):
    import models_tenant as models
    servicios_ids = payload.get("servicios_ids", [])
    db.query(models.TallerServicio).delete()
    for sid in servicios_ids:
        t_serv = models.TallerServicio(
            id_servicio=sid,
            precio_especifico_taller=50.0,
            estado_disponible=True
        )
        db.add(t_serv)
    db.commit()
    return {"status": "success", "message": "Servicios del taller actualizados."}

@router.post("/tecnicos/login", response_model=schemas_auth.TokenResponse)
def login_tecnico(request: schemas_auth.LoginRequest, db: Session = Depends(get_db)):
    db_tecnico = crud.get_tecnico_by_email(db, email=request.correo)
    if not db_tecnico or not crud.verify_password(request.password, db_tecnico.password_hash):
        raise HTTPException(status_code=401, detail="Correo o contraseña incorrectos")
    
    return {
        "access_token": "fake-jwt-token-tecnico",
        "token_type": "bearer",
        "user_id": db_tecnico.id_tecnico,
        "user_name": f"{db_tecnico.nombres} {db_tecnico.apellidos}",
        "primer_login": db_tecnico.primer_login
    }

@router.post("/tecnicos/{id_tecnico}/cambiar-password")
def cambiar_password_tecnico(
    id_tecnico: int,
    data: dict,
    db: Session = Depends(get_db)
):
    tecnico = db.query(models.Tecnico).filter(models.Tecnico.id_tecnico == id_tecnico).first()
    if not tecnico:
        raise HTTPException(status_code=404, detail="Técnico no encontrado")
    
    if "new_password" not in data or not data["new_password"]:
        raise HTTPException(status_code=400, detail="La nueva contraseña es requerida")

    hashed_password = crud.get_password_hash(data["new_password"])
    
    # 1. Actualizar en la Maestra
    tecnico.password_hash = hashed_password
    tecnico.primer_login = False
    db.commit()

    # 2. Actualizar en el Tenant (Local)
    taller = tecnico.taller
    if taller and taller.db_name:
        from database import get_tenant_session
        tenant_db = get_tenant_session(taller.db_name)
        try:
            import models_tenant
            tecnico_tenant = tenant_db.query(models_tenant.Tecnico).filter(models_tenant.Tecnico.correo == tecnico.correo).first()
            if tecnico_tenant:
                tecnico_tenant.password_hash = hashed_password
                tecnico_tenant.primer_login = False
                tenant_db.commit()
        finally:
            tenant_db.close()
    
    return {"message": "Contraseña actualizada correctamente"}
    
@router.post("/tecnicos/{id_tecnico}/resetear-password")
def resetear_password_tecnico(
    id_tecnico: int,
    data: dict,
    db: Session = Depends(get_db)
):
    import models
    tecnico = db.query(models.Tecnico).filter(models.Tecnico.id_tecnico == id_tecnico).first()
    if not tecnico:
        raise HTTPException(status_code=404, detail="Técnico no encontrado")
    
    if "new_password" not in data or not data["new_password"]:
        raise HTTPException(status_code=400, detail="La nueva contraseña es requerida")

    tecnico.password_hash = crud.get_password_hash(data["new_password"])
    tecnico.primer_login = True
    db.commit()
    
    return {"message": "Contraseña reseteada correctamente"}

@router.post("/tecnicos/{id_tecnico}/fcm-token")
def update_tecnico_fcm_token(id_tecnico: int, request: schemas.UpdateFCMTokenRequest, db: Session = Depends(get_db)):
    import models
    db_tecnico = db.query(models.Tecnico).filter(models.Tecnico.id_tecnico == id_tecnico).first()
    if not db_tecnico:
        raise HTTPException(status_code=404, detail="Técnico no encontrado")
    db_tecnico.fcm_token = request.fcm_token
    db.commit()
    return {"message": "Token FCM de Técnico actualizado exitosamente"}

@router.get("/{id_taller}/trabajos")
def get_taller_trabajos(id_taller: int, db: Session = Depends(get_taller_db)):
    import models_tenant as models
    incidentes = db.query(models.Incidente).all()
    resultados = []
    for inc in incidentes:
        asis = inc.asistencia
        
        # Obtener datos del cliente del Tenant DB
        from models_tenant import Cliente, Vehiculo
        t_cliente = db.query(Cliente).filter(Cliente.id_cliente == inc.id_cliente).first()
        t_vehiculo = db.query(Vehiculo).filter(Vehiculo.id_vehiculo == inc.id_vehiculo).first()

        pago_monto = 0.0
        try:
            if asis and asis.pago:
                pago_monto = float(asis.pago.monto_total)
        except Exception:
            pass
            
        if not pago_monto:
            if inc.nivel_prioridad == "Alta":
                pago_monto = 80.0
            elif inc.nivel_prioridad == "Media":
                pago_monto = 50.0
            elif inc.nivel_prioridad == "Baja":
                pago_monto = 30.0
            else:
                pago_monto = 50.0

        resultados.append({
            "id": f"INC-{inc.id_incidente}",
            "id_incidente": inc.id_incidente,
            "estado": inc.estado_solicitud,
            "cliente": f"{t_cliente.nombres} {t_cliente.apellidos}" if t_cliente else "Conductor",
            "vehiculo": f"{t_vehiculo.marca} {t_vehiculo.modelo} ({t_vehiculo.color})" if t_vehiculo else "Vehículo",
            "problema": inc.tipo_problema,
            "prioridad": inc.nivel_prioridad or "Media",
            "tecnico": f"{asis.tecnico.nombres} {asis.tecnico.apellidos}" if (asis and asis.tecnico) else "Sin asignar",
            "monto": pago_monto,
            "latitud": inc.ubicacion_latitud,
            "longitud": inc.ubicacion_longitud
        })

    return resultados


@router.get("/tecnicos/{id_tecnico}/trabajos")
def get_tecnico_trabajos(id_tecnico: int, db: Session = Depends(get_db)):
    # 1. Obtener el técnico de la Maestra para saber a qué taller pertenece
    import models_shared, models_tenant
    from database import get_taller_db
    
    m_tecnico = db.query(models_shared.Tecnico).filter(models_shared.Tecnico.id_tecnico == id_tecnico).first()
    if not m_tecnico:
        raise HTTPException(status_code=404, detail="Técnico no encontrado en la base maestra")
    
    # 2. Conectarse a la DB del Taller (Tenant)
    tenant_db_gen = get_taller_db(id_taller=m_tecnico.id_taller)
    tenant_db = next(tenant_db_gen)
    
    try:
        # 3. Buscar al técnico en el Tenant por correo para obtener su ID local
        t_tecnico = tenant_db.query(models_tenant.Tecnico).filter(models_tenant.Tecnico.correo == m_tecnico.correo).first()
        if not t_tecnico:
            return [] # No está en este taller o no tiene trabajos
            
        # 4. Obtener las asistencias del Tenant usando el ID local
        asistencias = tenant_db.query(models_tenant.Asistencia).filter(models_tenant.Asistencia.id_tecnico == t_tecnico.id_tecnico).all()
        
        resultados = []
        for asis in asistencias:
            inc = asis.incidente
            if not inc:
                continue
                
            pago_monto = 0.0
            try:
                if asis.pago:
                    pago_monto = float(asis.pago.monto_total)
            except Exception:
                pass
                
            if not pago_monto:
                if inc.nivel_prioridad == "Alta": pago_monto = 80.0
                elif inc.nivel_prioridad == "Baja": pago_monto = 30.0
                else: pago_monto = 50.0

            # Datos del cliente y vehículo (del Tenant)
            t_cliente = tenant_db.query(models_tenant.Cliente).filter(models_tenant.Cliente.id_cliente == inc.id_cliente).first()
            t_vehiculo = tenant_db.query(models_tenant.Vehiculo).filter(models_tenant.Vehiculo.id_vehiculo == inc.id_vehiculo).first()

            resultados.append({
                "id": f"INC-{inc.id_incidente}",
                "id_incidente": inc.id_incidente,
                "estado": inc.estado_solicitud,
                "cliente": f"{t_cliente.nombres} {t_cliente.apellidos}" if t_cliente else "Conductor",
                "vehiculo": f"{t_vehiculo.marca} {t_vehiculo.modelo} ({t_vehiculo.color})" if t_vehiculo else "Vehículo",
                "problema": inc.tipo_problema,
                "servicio": inc.tipo_problema,
                "tipo": inc.tipo_problema,
                "fecha": inc.fecha_hora_reporte.strftime("%Y-%m-%d %H:%M") if inc.fecha_hora_reporte else "N/A",
                "monto": pago_monto,
                "prioridad": inc.nivel_prioridad or "Media",
                "latitud": inc.ubicacion_latitud,
                "longitud": inc.ubicacion_longitud
            })
        return resultados
    finally:
        tenant_db.close()

@router.post("/tecnicos/{id_tecnico}/ubicacion")
def update_tecnico_ubicacion(id_tecnico: int, request: dict, db: Session = Depends(get_db)):
    import models_shared
    tecnico = db.query(models_shared.Tecnico).filter(models_shared.Tecnico.id_tecnico == id_tecnico).first()
    if not tecnico:
        raise HTTPException(status_code=404, detail="Técnico no encontrado")
        
    if "latitud" not in request or "longitud" not in request:
        raise HTTPException(status_code=400, detail="Latitud y Longitud requeridas")
    
    lat = request["latitud"]
    lng = request["longitud"]
    
    # Actualizar en la tabla Tecnico
    if hasattr(tecnico, 'ubicacion_actual_latitud'):
        tecnico.ubicacion_actual_latitud = lat
        tecnico.ubicacion_actual_longitud = lng
    
    # Actualizar en todas las Asistencias activas de este técnico (para que el tracking del cliente lo vea)
    asistencias = db.query(models_shared.Asistencia).filter(
        models_shared.Asistencia.id_tecnico == id_tecnico,
        models_shared.Asistencia.estado_asistencia.notin_(['Completado', 'Cancelado'])
    ).all()
    for asis in asistencias:
        asis.ubicacion_actual_latitud = lat
        asis.ubicacion_actual_longitud = lng
    
    db.commit()
    return {"status": "success", "message": "Ubicación actualizada"}

# --- SERVICIOS Y ESPECIALIDADES (TENANT AWARE) ---

@router.get("/servicios-disponibles")
def get_servicios_disponibles(db: Session = Depends(get_db)):
    # Los servicios ahora pueden ser locales, pero si el frontend pide 'disponibles' 
    # y queremos darle una lista base, podemos usar una lista estática o el tenant db.
    # Dado que el usuario quiere autonomía total, los servicios se gestionan por taller.
    return [] # El taller debe crear los suyos o podemos devolver una lista base si se desea

@router.get("/{id_taller}/servicios-detallados")
def get_taller_servicios_detallados(id_taller: int, db: Session = Depends(get_taller_db)):
    import models_tenant
    ts_list = db.query(models_tenant.TallerServicio).all()
    resultados = []
    for ts in ts_list:
        nombre = ts.servicio.nombre_servicio if ts.servicio else f"Servicio {ts.id_servicio}"
        resultados.append({
            "id_servicio": ts.id_servicio,
            "nombre_servicio": nombre,
            "precio_especifico_taller": float(ts.precio_especifico_taller),
            "tiempo_estimado_minutos": ts.tiempo_estimado_minutos
        })
    return resultados

@router.post("/{id_taller}/servicios-detallados")
def vincular_taller_servicio_detallado(id_taller: int, payload: dict, db: Session = Depends(get_taller_db)):
    import models_tenant
    id_servicio = payload.get("id_servicio")
    precio = payload.get("precio", 50.0)
    tiempo = payload.get("tiempo", 30)

    # Asegurar que el servicio genérico exista en la tabla local del tenant
    existe_srv = db.query(models_tenant.Servicio).filter(models_tenant.Servicio.id_servicio == id_servicio).first()
    if not existe_srv:
        nombres_estandar = {
            1: "Diagnóstico por Escáner y Reparación de Sistemas Eléctricos",
            2: "Mantenimiento de Suspensión, Frenos y Neumáticos",
            3: "Suministro e Inspección Rápida de Fluidos (Aceite/Combustible)",
            4: "Reparación de Chapas y Codificación de Llaves Inteligentes",
            5: "Servicio de Auxilio Vial y Traslado en Grúa",
            6: "Mecánica Preventiva, Afinamiento y Reparación de Motor",
            7: "Mantenimiento Integral del Sistema de Refrigeración"
        }
        nombre = nombres_estandar.get(id_servicio, f"Servicio Estándar {id_servicio}")
        existe_srv = models_tenant.Servicio(
            id_servicio=id_servicio,
            nombre_servicio=nombre,
            tarifa_base_estimada=precio
        )
        db.add(existe_srv)
        db.commit()

    db.query(models_tenant.TallerServicio).filter(models_tenant.TallerServicio.id_servicio == id_servicio).delete()

    t_serv = models_tenant.TallerServicio(
        id_servicio=id_servicio,
        precio_especifico_taller=precio,
        tiempo_estimado_minutos=tiempo,
        estado_disponible=True
    )
    db.add(t_serv)
    db.commit()
    return {"status": "success", "message": "Servicio vinculado al taller."}

@router.get("/{id_taller}/especialidades")
def get_taller_especialidades(id_taller: int, db: Session = Depends(get_taller_db)):
    import models_tenant
    return db.query(models_tenant.Especialidad).all()

@router.get("/tecnicos/{id_tecnico}/especialidades/{id_taller}")
def get_tecnico_especialidades_global(id_tecnico: int, id_taller: int, db: Session = Depends(get_taller_db)):
    import models_tenant
    tecnico = db.query(models_tenant.Tecnico).filter(models_tenant.Tecnico.id_tecnico == id_tecnico).first()
    if not tecnico:
        raise HTTPException(status_code=404, detail="Técnico no encontrado")
    return tecnico.especialidades

@router.post("/tecnicos/{id_tecnico}/especialidades/{id_taller}")
def vincular_tecnico_especialidad_global(id_tecnico: int, payload: dict, id_taller: int, db: Session = Depends(get_taller_db)):
    import models_tenant
    id_especialidad = payload.get("id_especialidad")
    tecnico = db.query(models_tenant.Tecnico).filter(models_tenant.Tecnico.id_tecnico == id_tecnico).first()
    especialidad = db.query(models_tenant.Especialidad).filter(models_tenant.Especialidad.id_especialidad == id_especialidad).first()
    
    if not tecnico or not especialidad:
        raise HTTPException(status_code=404, detail="Técnico o Especialidad no encontrada")
    
    if especialidad not in tecnico.especialidades:
        tecnico.especialidades.append(especialidad)
        db.commit()
    return {"message": "Especialidad vinculada"}

@router.patch("/{id_taller}")
def update_taller_perfil(id_taller: int, request: dict, db: Session = Depends(get_db)):
    taller = db.query(models.Taller).filter(models.Taller.id_taller == id_taller).first()
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
        
    if "telefono_taller" in request:
        taller.telefono_taller = request["telefono_taller"]
    if "cuenta_bancaria" in request:
        taller.cuenta_bancaria = request["cuenta_bancaria"]
    if "horario_apertura" in request:
        taller.horario_apertura = request["horario_apertura"]
    if "horario_cierre" in request:
        taller.horario_cierre = request["horario_cierre"]
        
    db.commit()
    return {"status": "success", "message": "Perfil actualizado"}
