from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import models_shared, schemas
from database import get_master_db
from websocket_manager import manager
import asyncio

router = APIRouter(prefix="/api/cotizaciones", tags=["Cotizaciones"])

@router.post("/", response_model=schemas.CotizacionResponse)
async def enviar_cotizacion(cotizacion: schemas.CotizacionCreate, db: Session = Depends(get_master_db)):
    # Verificar si el incidente existe
    incidente = db.query(models_shared.Incidente).filter(models_shared.Incidente.id_incidente == cotizacion.id_incidente).first()
    if not incidente:
        raise HTTPException(status_code=404, detail="Incidente no encontrado")
    
    db_cotizacion = models_shared.Cotizacion(**cotizacion.model_dump())
    db.add(db_cotizacion)
    db.commit()
    db.refresh(db_cotizacion)
    
    # Notificar al cliente vía WebSocket
    taller = db.query(models_shared.Taller).filter(models_shared.Taller.id_taller == db_cotizacion.id_taller).first()
    payload = {
        "type": "NUEVA_COTIZACION",
        "id_cotizacion": db_cotizacion.id_cotizacion,
        "id_incidente": db_cotizacion.id_incidente,
        "id_taller": db_cotizacion.id_taller,
        "monto": float(db_cotizacion.monto_estimado),
        "tiempo_minutos": db_cotizacion.tiempo_estimado_minutos,
        "taller_nombre": taller.razon_social if taller else "Taller Externo",
        "descripcion": db_cotizacion.descripcion_propuesta
    }
    asyncio.create_task(manager.send_personal_message(payload, f"cliente_{incidente.id_cliente}"))
    
    return db_cotizacion

@router.get("/incidente/{id_incidente}", response_model=list[schemas.CotizacionResponse])
def get_cotizaciones_incidente(id_incidente: int, db: Session = Depends(get_master_db)):
    return db.query(models_shared.Cotizacion).filter(models_shared.Cotizacion.id_incidente == id_incidente).all()

@router.patch("/{id_cotizacion}/aceptar", response_model=schemas.CotizacionResponse)
async def aceptar_cotizacion(id_cotizacion: int, db: Session = Depends(get_master_db)):
    cotizacion = db.query(models_shared.Cotizacion).filter(models_shared.Cotizacion.id_cotizacion == id_cotizacion).first()
    if not cotizacion:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")
    
    cotizacion.estado = 'Aceptada'
    
    # Rechazar el resto de cotizaciones para ese incidente
    db.query(models_shared.Cotizacion).filter(
        models_shared.Cotizacion.id_incidente == cotizacion.id_incidente,
        models_shared.Cotizacion.id_cotizacion != id_cotizacion
    ).update({"estado": "Rechazada"})
    
    # Obtener el incidente
    incidente_master = db.query(models_shared.Incidente).filter(models_shared.Incidente.id_incidente == cotizacion.id_incidente).first()
    if incidente_master:
        incidente_master.estado_solicitud = 'Asignado'
        
    db.commit()
    db.refresh(cotizacion)
    
    # --- Sincronización Multitenant al Tenant DB del Taller ---
    import crud
    import models_tenant
    from database import get_taller_db
    
    id_taller = cotizacion.id_taller
    id_incidente_master = cotizacion.id_incidente
    
    master_cliente = db.query(models_shared.Cliente).filter(models_shared.Cliente.id_cliente == incidente_master.id_cliente).first()
    master_vehiculo = db.query(models_shared.Vehiculo).filter(models_shared.Vehiculo.id_vehiculo == incidente_master.id_vehiculo).first()
    
    tenant_db_gen = get_taller_db(id_taller)
    tenant_db = next(tenant_db_gen)
    
    try:
        tenant_cliente = crud.sync_cliente_to_tenant(tenant_db, master_cliente)
        tenant_vehiculo = crud.sync_vehiculo_to_tenant(tenant_db, master_vehiculo, tenant_cliente.id_cliente)
        
        # Buscar o crear incidente local en tenant
        db_incidente_tenant = tenant_db.query(models_tenant.Incidente).filter(models_tenant.Incidente.id_incidente == id_incidente_master).first()
        if db_incidente_tenant:
            db_incidente_tenant.id_cliente = tenant_cliente.id_cliente
            db_incidente_tenant.id_vehiculo = tenant_vehiculo.id_vehiculo
            db_incidente_tenant.estado_solicitud = 'Aceptado'
        else:
            db_incidente_tenant = models_tenant.Incidente(
                id_incidente=id_incidente_master,
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
        
        # Buscar técnico local disponible
        tecnico_tenant = tenant_db.query(models_tenant.Tecnico).filter(models_tenant.Tecnico.estado_operativo == 'Disponible').first()
        if not tecnico_tenant:
            tecnico_tenant = tenant_db.query(models_tenant.Tecnico).first()
            
        if not tecnico_tenant:
            raise HTTPException(status_code=400, detail="El taller no tiene técnicos registrados o disponibles.")
            
        tecnico_master = db.query(models_shared.Tecnico).filter(models_shared.Tecnico.correo == tecnico_tenant.correo).first()
        
        # Crear/actualizar asistencia en la maestra
        asistencia_global = db.query(models_shared.Asistencia).filter(models_shared.Asistencia.id_incidente == id_incidente_master).first()
        if not asistencia_global:
            asistencia_global = models_shared.Asistencia(
                id_incidente=id_incidente_master,
                id_taller=id_taller,
                id_tecnico=tecnico_master.id_tecnico if tecnico_master else None,
                estado_asistencia='Aceptado'
            )
            db.add(asistencia_global)
        else:
            asistencia_global.id_taller = id_taller
            asistencia_global.id_tecnico = tecnico_master.id_tecnico if tecnico_master else None
            asistencia_global.estado_asistencia = 'Aceptado'
            
        db.commit()
        
        # Crear/actualizar asistencia en el tenant
        asistencia_tenant = tenant_db.query(models_tenant.Asistencia).filter(models_tenant.Asistencia.id_incidente == id_incidente_master).first()
        if asistencia_tenant:
            asistencia_tenant.id_tecnico = tecnico_tenant.id_tecnico
            asistencia_tenant.estado_asistencia = "Aceptado"
        else:
            asistencia_tenant = models_tenant.Asistencia(
                id_incidente=id_incidente_master,
                id_tecnico=tecnico_tenant.id_tecnico,
                estado_asistencia="Aceptado"
            )
            tenant_db.add(asistencia_tenant)
            
        tenant_db.commit()
    except Exception as e:
        tenant_db.rollback()
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error al sincronizar aceptación con tenant: {str(e)}")
    finally:
        tenant_db.close()
        
    # --- Descarte preventivo en otros Tenants ---
    try:
        cotizaciones_otros = db.query(models_shared.Cotizacion).filter(
            models_shared.Cotizacion.id_incidente == id_incidente_master,
            models_shared.Cotizacion.id_taller != id_taller
        ).all()
        for cot_o in cotizaciones_otros:
            t_other = db.query(models_shared.Taller).filter(models_shared.Taller.id_taller == cot_o.id_taller).first()
            if t_other and t_other.db_name:
                from database import get_tenant_session
                session_other = get_tenant_session(t_other.db_name)
                try:
                    inc_other = session_other.query(models_tenant.Incidente).filter(models_tenant.Incidente.id_incidente == id_incidente_master).first()
                    if inc_other:
                        inc_other.estado_solicitud = 'Cancelado'
                        session_other.commit()
                except Exception:
                    session_other.rollback()
                finally:
                    session_other.close()
    except Exception as e:
        print(f"⚠️ Error limpiando otros tenants: {e}")
        
    # Notificar al taller vía WebSocket
    payload = {
        "type": "COTIZACION_ACEPTADA",
        "id_cotizacion": id_cotizacion,
        "id_incidente": cotizacion.id_incidente
    }
    asyncio.create_task(manager.send_personal_message(payload, f"taller_{cotizacion.id_taller}"))
    
    return cotizacion

@router.patch("/{id_cotizacion}/rechazar", response_model=schemas.CotizacionResponse)
async def rechazar_cotizacion(id_cotizacion: int, db: Session = Depends(get_master_db)):
    cotizacion = db.query(models_shared.Cotizacion).filter(models_shared.Cotizacion.id_cotizacion == id_cotizacion).first()
    if not cotizacion:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")
    
    cotizacion.estado = 'Rechazada'
    db.commit()
    db.refresh(cotizacion)
    
    return cotizacion
