from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import models_shared, schemas
from database import get_master_db
from websocket_manager import manager
import asyncio
from decimal import Decimal

router = APIRouter(prefix="/api/pagos", tags=["Pagos"])

@router.post("/crear-sesion", response_model=schemas.PagoResponse)
async def crear_sesion_pago(pago: schemas.PagoCreate, db: Session = Depends(get_master_db)):
    # Verificar si el incidente existe
    incidente = db.query(models_shared.Incidente).filter(models_shared.Incidente.id_incidente == pago.id_incidente).first()
    if not incidente:
        raise HTTPException(status_code=404, detail="Incidente no encontrado")
        
    # Calcular comisión (ej: 10%)
    comision = Decimal(str(pago.monto_total)) * Decimal('0.10')
    
    db_pago = models_shared.PagoGlobal(
        id_incidente=pago.id_incidente,
        id_taller=pago.id_taller,
        monto_total=pago.monto_total,
        metodo_pago=pago.metodo_pago,
        comision_plataforma=comision,
        estado_transaccion='Pendiente'
    )
    
    db.add(db_pago)
    db.commit()
    db.refresh(db_pago)
    
    return db_pago

@router.post("/{id_pago}/confirmar", response_model=schemas.PagoResponse)
async def confirmar_pago(id_pago: int, db: Session = Depends(get_master_db)):
    db_pago = db.query(models_shared.PagoGlobal).filter(models_shared.PagoGlobal.id_pago == id_pago).first()
    if not db_pago:
        raise HTTPException(status_code=404, detail="Pago no encontrado")
        
    db_pago.estado_transaccion = 'Completado'
    
    # Actualizar estado del incidente
    incidente = db.query(models_shared.Incidente).filter(models_shared.Incidente.id_incidente == db_pago.id_incidente).first()
    if incidente:
        incidente.estado_solicitud = 'Pagado'
        
    db.commit()
    db_pago = db.query(models_shared.PagoGlobal).filter(models_shared.PagoGlobal.id_pago == id_pago).first()
    
    # Notificar al taller y al cliente
    payload = {
        "type": "PAGO_CONFIRMADO",
        "id_pago": id_pago,
        "id_incidente": db_pago.id_incidente,
        "monto": float(db_pago.monto_total)
    }
    
    asyncio.create_task(manager.send_personal_message(payload, f"taller_{db_pago.id_taller}"))
    asyncio.create_task(manager.send_personal_message(payload, f"cliente_{incidente.id_cliente}"))
    
    return db_pago

@router.get("/cliente/{id_cliente}", response_model=list[schemas.PagoResponse])
def get_historial_pagos_cliente(id_cliente: int, db: Session = Depends(get_master_db)):
    return db.query(models_shared.PagoGlobal).join(models_shared.Incidente).filter(models_shared.Incidente.id_cliente == id_cliente).all()
