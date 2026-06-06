from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import crud, schemas, schemas_auth
import models_shared as models
from database import get_master_db as get_db

router = APIRouter()

@router.post("/", response_model=schemas.ClienteResponse)
def create_cliente(cliente: schemas.ClienteCreate, db: Session = Depends(get_db)):
    db_cliente = crud.get_cliente_master_by_email(db, email=cliente.correo)
    if db_cliente:
        raise HTTPException(status_code=400, detail="El correo ya está registrado globalmente.")
    return crud.create_cliente_master(db=db, cliente=cliente)

@router.get("/", response_model=list[schemas.ClienteResponse])
def read_clientes(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    clientes = crud.get_clientes_master(db, skip=skip, limit=limit)
    return clientes

@router.get("/{cliente_id}", response_model=schemas.ClienteResponse)
def read_cliente(cliente_id: int, db: Session = Depends(get_db)):
    db_cliente = crud.get_cliente_master(db, cliente_id=cliente_id)
    if db_cliente is None:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    return db_cliente

# El login de clientes se movió a auth.py para centralizar la autenticación


@router.get("/{cliente_id}/vehiculos", response_model=list[schemas.VehiculoResponse])
def get_cliente_vehiculos(cliente_id: int, db: Session = Depends(get_db)):
    vehiculos = db.query(models.Vehiculo).filter(models.Vehiculo.id_cliente == cliente_id).all()
    return vehiculos

@router.post("/{cliente_id}/vehiculos", response_model=schemas.VehiculoResponse)
def create_cliente_vehiculo(cliente_id: int, vehiculo: schemas.VehiculoBase, db: Session = Depends(get_db)):
    existing = db.query(models.Vehiculo).filter(models.Vehiculo.placa == vehiculo.placa).first()
    if existing:
        raise HTTPException(status_code=400, detail="Ya existe un vehículo registrado con esta placa.")
        
    db_vehiculo = models.Vehiculo(
        id_cliente=cliente_id,
        placa=vehiculo.placa,
        marca=vehiculo.marca,
        modelo=vehiculo.modelo,
        año=vehiculo.año,
        color=vehiculo.color,
        tipo_transmision=vehiculo.tipo_transmision,
        tipo_combustible=vehiculo.tipo_combustible
    )
    db.add(db_vehiculo)
    db.commit()
    db.refresh(db_vehiculo)
    return db_vehiculo

@router.post("/{cliente_id}/fcm-token")
def update_cliente_fcm_token(cliente_id: int, request: schemas.UpdateFCMTokenRequest, db: Session = Depends(get_db)):
    db_cliente = db.query(models.Cliente).filter(models.Cliente.id_cliente == cliente_id).first()
    if not db_cliente:
        raise HTTPException(status_code=404, detail="Cliente no encontrado")
    db_cliente.fcm_token = request.fcm_token
    db.commit()
    return {"message": "Token FCM de Cliente actualizado exitosamente"}
