from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form
from sqlalchemy.orm import Session
import crud, schemas
import models_shared, models_tenant
from database import get_db, get_master_db
from services.ai_service import AIService
from services.matching_service import buscar_talleres_cercanos
import os
import uuid

router = APIRouter()

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@router.post("/", response_model=schemas.IncidenteResponse)
def create_incidente(incidente: schemas.IncidenteCreate, db: Session = Depends(get_master_db)):
    return crud.create_incidente_master(db=db, incidente=incidente)

@router.get("/{id_incidente}", response_model=schemas.IncidenteResponse)
def read_incidente(id_incidente: int, db: Session = Depends(get_master_db)):
    db_incidente = db.query(models_shared.Incidente).filter(models_shared.Incidente.id_incidente == id_incidente).first()
    if not db_incidente:
        raise HTTPException(status_code=404, detail="Incidente no encontrado")
    return db_incidente

@router.get("/{id_incidente}/tracking")
def get_incidente_tracking(id_incidente: int, db: Session = Depends(get_master_db)):
    incidente = db.query(models_shared.Incidente).filter(models_shared.Incidente.id_incidente == id_incidente).first()
    if not incidente:
        raise HTTPException(status_code=404, detail="Incidente no encontrado")
        
    asistencia = db.query(models_shared.Asistencia).filter(models_shared.Asistencia.id_incidente == id_incidente).first()
    
    # Obtener coordenadas del técnico desde la tabla Tecnico (donde la app envía la ubicación)
    lat_tecnico = None
    lng_tecnico = None
    if asistencia:
        # Primero intentar desde la Asistencia
        lat_tecnico = asistencia.ubicacion_actual_latitud
        lng_tecnico = asistencia.ubicacion_actual_longitud
        # Si no tiene, buscar en el Tecnico directamente
        if (lat_tecnico is None or lng_tecnico is None) and asistencia.tecnico:
            tecnico = asistencia.tecnico
            if hasattr(tecnico, 'ubicacion_actual_latitud'):
                lat_tecnico = tecnico.ubicacion_actual_latitud
                lng_tecnico = tecnico.ubicacion_actual_longitud
    
    return {
        "estado": incidente.estado_solicitud,
        "tipo_problema": incidente.tipo_problema,
        "nivel_prioridad": incidente.nivel_prioridad,
        "lat_cliente": incidente.ubicacion_latitud,
        "lng_cliente": incidente.ubicacion_longitud,
        "taller_nombre": asistencia.taller.razon_social if (asistencia and asistencia.taller) else "Buscando taller...",
        "lat_tecnico": lat_tecnico,
        "lng_tecnico": lng_tecnico,
        "monto_pago": 50.0
    }

@router.post("/reportar")
async def reportar_incidente(
    id_cliente: int = Form(...),
    id_vehiculo: int = Form(...),
    ubicacion_latitud: float = Form(...),
    ubicacion_longitud: float = Form(...),
    descripcion_manual: str = Form(""),
    client_uuid: str = Form(None),
    audio: UploadFile = File(None),
    foto: UploadFile = File(None),
    db: Session = Depends(get_master_db)
):
    # --- Dedup: si ya existe un incidente con este client_uuid, retornar el existente ---
    if client_uuid:
        existente = db.query(models_shared.Incidente).filter(
            models_shared.Incidente.client_uuid == client_uuid
        ).first()
        if existente:
            print(f"♻️ Incidente duplicado detectado (client_uuid={client_uuid}), retornando existente", flush=True)
            talleres_cercanos = buscar_talleres_cercanos(db, existente.ubicacion_latitud, existente.ubicacion_longitud)
            return {
                "status": "success",
                "id_incidente": existente.id_incidente,
                "evaluacion_ia": {},
                "talleres_notificados": talleres_cercanos,
                "duplicado": True
            }

    print(f"📥 Nuevo reporte de incidente: Cliente {id_cliente}, Lat: {ubicacion_latitud}, Lon: {ubicacion_longitud}", flush=True)
    audio_path = None
    foto_path = None
    
    if audio:
        ext = os.path.splitext(audio.filename)[1]
        audio_name = f"audio_{uuid.uuid4()}{ext}"
        audio_path = os.path.join(UPLOAD_DIR, audio_name)
        with open(audio_path, "wb") as buffer:
            buffer.write(await audio.read())
            
    if foto:
        ext = os.path.splitext(foto.filename)[1]
        foto_name = f"foto_{uuid.uuid4()}{ext}"
        foto_path = os.path.join(UPLOAD_DIR, foto_name)
        with open(foto_path, "wb") as buffer:
            buffer.write(await foto.read())

    incidente_data = schemas.IncidenteCreate(
        id_cliente=id_cliente,
        id_vehiculo=id_vehiculo,
        ubicacion_latitud=ubicacion_latitud,
        ubicacion_longitud=ubicacion_longitud,
        descripcion_manual=descripcion_manual,
        tipo_problema="Buscando..."
    )
    db_incidente = crud.create_incidente_master(db=db, incidente=incidente_data)
    
    # Asignar client_uuid para dedup offline
    if client_uuid:
        db_incidente.client_uuid = client_uuid
        db.commit()
        db.refresh(db_incidente)
    
    ai_result = AIService.analizar_incidente(audio_path, foto_path, descripcion_manual)
    
    db_incidente.tipo_problema = ai_result.get("categoria", "Otro")
    db_incidente.nivel_prioridad = ai_result.get("urgencia", "Media")
    db.commit()
    db.refresh(db_incidente)
    
    if audio_path:
        db_audio = models_shared.Evidencia(
            id_incidente=db_incidente.id_incidente,
            tipo_recurso="Audio",
            url_archivo=f"uploads/{os.path.basename(audio_path)}"
        )
        db.add(db_audio)
        
    if foto_path:
        db_foto = models_shared.Evidencia(
            id_incidente=db_incidente.id_incidente,
            tipo_recurso="Foto",
            url_archivo=f"uploads/{os.path.basename(foto_path)}"
        )
        db.add(db_foto)
    
    db_analisis = models_shared.AnalisisIA(
        id_incidente=db_incidente.id_incidente,
        clasificacion_sugerida=ai_result.get("categoria", "Otro"),
        resumen_estructurado=ai_result.get("diagnostico_taller", "Sin diagnóstico técnico disponible.")
    )
    db.add(db_analisis)
    db.commit()

    talleres_cercanos = buscar_talleres_cercanos(db, ubicacion_latitud, ubicacion_longitud)
    print(f"🔍 Talleres encontrados: {[t['id_taller'] for t in talleres_cercanos]}", flush=True)
    
    # Obtener info del cliente para el dashboard
    cliente = db.query(models_shared.Cliente).filter(models_shared.Cliente.id_cliente == db_incidente.id_cliente).first()
    nombre_cliente = cliente.nombres if cliente else "Conductor en Ruta"
    
    # Notificaciones WebSocket
    talleres_online = []
    try:
        from websocket_manager import manager
        print(f"📢 Conexiones actuales en el manager: {list(manager.active_connections.keys())}", flush=True)
        
        for taller in talleres_cercanos:
            user_key = f"taller_{taller.get('id_taller')}"
            if user_key in manager.active_connections:
                talleres_online.append(taller)
                payload = {
                    "type": "NUEVA_EMERGENCIA",
                    "id_incidente": db_incidente.id_incidente,
                    "problema": db_incidente.tipo_problema,
                    "prioridad": db_incidente.nivel_prioridad,
                    "distancia_km": taller.get("distancia", 1.0),
                    "latitud": ubicacion_latitud,
                    "longitud": ubicacion_longitud,
                    "cliente": nombre_cliente,
                    "vehiculo": "Vehículo en ruta", 
                    "transcripcion_audio": ai_result.get("transcripcion_audio", ""),
                    "evaluacion_ia": ai_result.get("diagnostico_taller", "Sin diagnóstico técnico disponible."),
                    "url_audio_evidencia": f"uploads/{os.path.basename(audio_path)}" if audio_path else None,
                    "url_foto_evidencia": f"uploads/{os.path.basename(foto_path)}" if foto_path else None
                }
                import asyncio
                print(f"📡 Enviando notificación a {user_key}...", flush=True)
                asyncio.create_task(manager.send_personal_message(payload, user_key))
    except Exception as e:
        print(f"❌ Error WS en reportar_incidente: {e}", flush=True)

    return {
        "status": "success",
        "id_incidente": db_incidente.id_incidente,
        "evaluacion_ia": ai_result,
        "talleres_notificados": talleres_online
    }

@router.post("/{id_incidente}/notificar-taller")
async def notificar_taller_especifico(id_incidente: int, payload: dict, db: Session = Depends(get_master_db)):
    id_taller = payload.get("id_taller")
    taller = db.query(models_shared.Taller).filter(models_shared.Taller.id_taller == id_taller).first()
    incidente = db.query(models_shared.Incidente).filter(models_shared.Incidente.id_incidente == id_incidente).first()
    
    if not taller or not incidente:
        raise HTTPException(status_code=404, detail="Taller o incidente no encontrado")

    # Obtener el análisis de IA para incluirlo
    analisis = db.query(models_shared.AnalisisIA).filter(models_shared.AnalisisIA.id_incidente == id_incidente).first()
    cliente = db.query(models_shared.Cliente).filter(models_shared.Cliente.id_cliente == incidente.id_cliente).first()
    
    # Notificar vía WebSocket al taller específico
    # --- MEJORA: Sincronización Inmediata con el Tenant ---
    # Para evitar que el incidente desaparezca del dashboard por polling, 
    # lo insertamos preventivamente en la DB del taller con estado 'Notificado'.
    try:
        from database import get_taller_db
        tenant_db_gen = get_taller_db(id_taller)
        tenant_db = next(tenant_db_gen)

        # Buscar si ya existe para no duplicar
        import models_tenant
        existe_tenant = tenant_db.query(models_tenant.Incidente).filter(models_tenant.Incidente.id_incidente == id_incidente).first()
        
        if not existe_tenant:
            # Sync básico para que aparezca en la lista
            db_incidente_tenant = models_tenant.Incidente(
                id_incidente=incidente.id_incidente,
                id_cliente=incidente.id_cliente, # Nota: Asumimos que el ID coincide o se sync luego
                id_vehiculo=incidente.id_vehiculo,
                ubicacion_latitud=incidente.ubicacion_latitud,
                ubicacion_longitud=incidente.ubicacion_longitud,
                tipo_problema=incidente.tipo_problema,
                descripcion_manual=incidente.descripcion_manual,
                nivel_prioridad=incidente.nivel_prioridad,
                estado_solicitud='Notificado' # <--- ESTO ES CLAVE
            )
            tenant_db.add(db_incidente_tenant)
            tenant_db.commit()
    except Exception as e:
        print(f"⚠️ Error en sync preventivo al taller: {e}")
    # -----------------------------------------------------

    from websocket_manager import manager
    notification = {
        "type": "NUEVA_EMERGENCIA",
        "id_incidente": id_incidente,
        "cliente": f"{cliente.nombres} {cliente.apellidos}" if cliente else "Conductor",
        "problema": incidente.tipo_problema,
        "lat": incidente.ubicacion_latitud,
        "lng": incidente.ubicacion_longitud,
        "distancia_km": 0,
        "prioridad": incidente.nivel_prioridad,
        "transcripcion_audio": "Ver detalles en dashboard",
        "evaluacion_ia": analisis.resumen_estructurado if (analisis and not "API key not valid" in (analisis.resumen_estructurado or "")) else "Pendiente de análisis profundo"
    }
    
    await manager.send_personal_message(notification, f"taller_{id_taller}")
    
    return {"status": "notified", "taller": taller.razon_social}

@router.post("/{id_incidente}/aceptar")
def aceptar_incidente(id_incidente: int, payload: dict, master_db: Session = Depends(get_master_db)):
    id_incidente_master = id_incidente # Tomado de la URL
    id_taller = payload.get("id_taller")
    id_tecnico = payload.get("id_tecnico")
    
    incidente_master = master_db.query(models_shared.Incidente).filter(models_shared.Incidente.id_incidente == id_incidente_master).first()
    if not incidente_master:
        raise HTTPException(status_code=404, detail="Incidente no encontrado")
    
    master_cliente = master_db.query(models_shared.Cliente).filter(models_shared.Cliente.id_cliente == incidente_master.id_cliente).first()
    master_vehiculo = master_db.query(models_shared.Vehiculo).filter(models_shared.Vehiculo.id_vehiculo == incidente_master.id_vehiculo).first()

    from database import get_taller_db
    tenant_db_gen = get_taller_db(id_taller)
    tenant_db = next(tenant_db_gen)

    try:
        tenant_cliente = crud.sync_cliente_to_tenant(tenant_db, master_cliente)
        tenant_vehiculo = crud.sync_vehiculo_to_tenant(tenant_db, master_vehiculo, tenant_cliente.id_cliente)
        
        # Buscar si el incidente ya fue pre-sincronizado al ser notificado
        db_incidente_tenant = tenant_db.query(models_tenant.Incidente).filter(models_tenant.Incidente.id_incidente == incidente_master.id_incidente).first()
        
        if db_incidente_tenant:
            # Actualizar datos si ya existe (fue pre-sync al ser notificado)
            db_incidente_tenant.id_cliente = tenant_cliente.id_cliente
            db_incidente_tenant.id_vehiculo = tenant_vehiculo.id_vehiculo
            db_incidente_tenant.estado_solicitud = 'Aceptado'
        else:
            # Crear si no existía (ej. asignado manualmente desde admin)
            db_incidente_tenant = models_tenant.Incidente(
                id_incidente=incidente_master.id_incidente,
                id_cliente=tenant_cliente.id_cliente,
                id_vehiculo=tenant_vehiculo.id_vehiculo,
                ubicacion_latitud=incidente_master.ubicacion_latitud,
                ubicacion_longitud=incidente_master.ubicacion_longitud,
                tipo_problema=incidente_master.tipo_problema,
                descripcion_manual=incidente_master.descripcion_manual,
                nivel_prioridad=incidente_master.nivel_prioridad,
                estado_solicitud='Aceptado'
            )
            tenant_db.add(db_incidente_tenant)
        
        if not id_tecnico:
            tecnico_tenant = tenant_db.query(models_tenant.Tecnico).filter(models_tenant.Tecnico.estado_operativo == 'Disponible').first()
        else:
            try:
                # Asegurar que sea entero para la consulta
                tid = int(id_tecnico)
                tecnico_tenant = tenant_db.query(models_tenant.Tecnico).filter(models_tenant.Tecnico.id_tecnico == tid).first()
            except:
                tecnico_tenant = None
            
        if not tecnico_tenant:
            # Fallback al primer técnico disponible si el seleccionado falló
            tecnico_tenant = tenant_db.query(models_tenant.Tecnico).first()
            
        if not tecnico_tenant:
            # Si aún no hay técnicos, esto fallará por el nullable=False en la DB del tenant.
            # Debemos informar al usuario que necesita al menos un técnico.
            raise HTTPException(status_code=400, detail="El taller no tiene técnicos registrados o disponibles.")
            
        # --- MEJORA: Mapeo de Técnico a la Maestra ---
        # El registro de Asistencia Global requiere el ID del técnico en la Maestra.
        tecnico_master = None
        if tecnico_tenant:
            tecnico_master = master_db.query(models_shared.Tecnico).filter(models_shared.Tecnico.correo == tecnico_tenant.correo).first()

        # Mover el incidente a la base de datos del taller (Tenant)
        # Primero buscamos si ya existe el registro en la maestra o lo creamos
        asistencia_global = master_db.query(models_shared.Asistencia).filter(models_shared.Asistencia.id_incidente == id_incidente_master).first()
        if not asistencia_global:
            asistencia_global = models_shared.Asistencia(
                id_incidente=id_incidente_master,
                id_taller=id_taller,
                id_tecnico=tecnico_master.id_tecnico if tecnico_master else None,
                estado_asistencia='Aceptado'
            )
            master_db.add(asistencia_global)
        else:
            asistencia_global.id_taller = id_taller
            asistencia_global.id_tecnico = tecnico_master.id_tecnico if tecnico_master else None
            asistencia_global.estado_asistencia = 'Aceptado'
        
        master_db.commit()

        # Ahora en el tenant
        asistencia_tenant = tenant_db.query(models_tenant.Asistencia).filter(models_tenant.Asistencia.id_incidente == id_incidente_master).first()
        if asistencia_tenant:
            asistencia_tenant.id_tecnico = tecnico_tenant.id_tecnico if tecnico_tenant else None
            asistencia_tenant.estado_asistencia = "Aceptado"
        else:
            asistencia_tenant = models_tenant.Asistencia(
                id_incidente=id_incidente_master,
                id_tecnico=tecnico_tenant.id_tecnico if tecnico_tenant else None,
                estado_asistencia="Aceptado"
            )
            tenant_db.add(asistencia_tenant)
        
        incidente_master.estado_solicitud = 'Asignado'
        tenant_db.commit()
        master_db.commit()

        # Notificar al Cliente en tiempo real vía WebSocket
        try:
            from websocket_manager import manager
            payload_ws = {
                "type": "TALLER_ASIGNADO",
                "id_incidente": incidente_master.id_incidente,
                "estado": "Asignado",
                "taller": {
                    "id_taller": id_taller,
                    "razon_social": master_db.query(models_shared.Taller).filter(models_shared.Taller.id_taller == id_taller).first().razon_social
                },
                "tecnico": {
                    "id_tecnico": tecnico_master.id_tecnico if tecnico_master else None,
                    "nombre": f"{tecnico_tenant.nombres} {tecnico_tenant.apellidos}" if tecnico_tenant else "Por asignar"
                }
            }
            import asyncio
            asyncio.create_task(manager.send_personal_message(payload_ws, f"cliente_{incidente_master.id_cliente}"))
        except Exception as ws_err:
            print(f"Error enviando WS al cliente: {ws_err}")

        return {"status": "success", "message": "Incidente aceptado"}
    except Exception as e:
        tenant_db.rollback()
        master_db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        tenant_db.close()

@router.get("/", response_model=list[schemas.IncidenteResponse])
def read_incidentes(skip: int = 0, limit: int = 100, db: Session = Depends(get_master_db)):
    return crud.get_incidentes_master(db, skip=skip, limit=limit)

@router.put("/{id_incidente}/estado")
def actualizar_estado_incidente(id_incidente: int, payload: dict, db: Session = Depends(get_master_db)):
    incidente = db.query(models_shared.Incidente).filter(models_shared.Incidente.id_incidente == id_incidente).first()
    if not incidente:
        raise HTTPException(status_code=404, detail="Incidente no encontrado")
    
    nuevo_estado = payload.get("nuevo_estado") or payload.get("estado", incidente.estado_solicitud)
    incidente.estado_solicitud = nuevo_estado
    
    # --- Sync con el Tenant ---
    asistencia = db.query(models_shared.Asistencia).filter(models_shared.Asistencia.id_incidente == id_incidente).first()
    if asistencia:
        asistencia.estado_asistencia = nuevo_estado
        try:
            from database import get_taller_db
            import models_tenant
            tenant_db_gen = get_taller_db(asistencia.id_taller)
            tenant_db = next(tenant_db_gen)
            
            # Actualizar Incidente en Tenant
            t_inc = tenant_db.query(models_tenant.Incidente).filter(models_tenant.Incidente.id_incidente == id_incidente).first()
            if t_inc:
                t_inc.estado_solicitud = nuevo_estado
            
            # Actualizar Asistencia en Tenant
            t_asis = tenant_db.query(models_tenant.Asistencia).filter(models_tenant.Asistencia.id_incidente == id_incidente).first()
            if t_asis:
                t_asis.estado_asistencia = nuevo_estado
            
            tenant_db.commit()
            tenant_db.close()
        except Exception as e:
            print(f"⚠️ Error al sincronizar estado con tenant: {e}")
    # --------------------------
    
    db.commit()

    # Notificar a las partes involucradas (Cliente y Taller)
    try:
        from websocket_manager import manager
        payload_ws = {
            "type": "ESTADO_CAMBIADO",
            "id_incidente": id_incidente,
            "nuevo_estado": incidente.estado_solicitud
        }
        import asyncio
        asyncio.create_task(manager.send_personal_message(payload_ws, f"cliente_{incidente.id_cliente}"))
        if asistencia:
            asyncio.create_task(manager.send_personal_message(payload_ws, f"taller_{asistencia.id_taller}"))
    except Exception as ws_err:
        print(f"Error enviando WS de estado: {ws_err}")

    return {"status": "success", "nuevo_estado": nuevo_estado}
