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
    
    db.commit()
    db.refresh(cotizacion)
    
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
