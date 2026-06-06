from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
import models_shared as models, schemas, crud, utils, schemas_auth
from datetime import datetime, timedelta
import random

router = APIRouter()

@router.post("/forgot-password")
def forgot_password(request: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    cliente = db.query(models.Cliente).filter(models.Cliente.correo == request.correo).first()
    taller = db.query(models.Taller).filter(models.Taller.correo == request.correo).first()
    
    if not cliente and not taller:
        raise HTTPException(status_code=404, detail="Correo electrónico no registrado")

    token = f"{random.randint(100000, 999999)}"
    expiracion = datetime.now() + timedelta(minutes=15)

    db_token = models.PasswordResetToken(
        correo=request.correo,
        token=token,
        expiracion=expiracion
    )
    db.add(db_token)
    db.commit()

    utils.send_reset_password_email(request.correo, token)

    return {"message": "Código de verificación enviado al correo electrónico"}

@router.post("/verify-token")
def verify_token(request: schemas.VerifyTokenRequest, db: Session = Depends(get_db)):
    db_token = db.query(models.PasswordResetToken).filter(
        models.PasswordResetToken.correo == request.correo,
        models.PasswordResetToken.token == request.token,
        models.PasswordResetToken.utilizado == False,
        models.PasswordResetToken.expiracion > datetime.now()
    ).first()

    if not db_token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Código inválido o expirado")

    return {"message": "Código verificado con éxito", "valid": True}

@router.post("/reset-password")
def reset_password(request: schemas.ResetPasswordRequest, db: Session = Depends(get_db)):
    db_token = db.query(models.PasswordResetToken).filter(
        models.PasswordResetToken.correo == request.correo,
        models.PasswordResetToken.token == request.token,
        models.PasswordResetToken.utilizado == False,
        models.PasswordResetToken.expiracion > datetime.now()
    ).first()

    if not db_token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Código inválido o expirado")

    hashed_password = crud.get_password_hash(request.nueva_password)
    
    cliente = db.query(models.Cliente).filter(models.Cliente.correo == request.correo).first()
    taller = db.query(models.Taller).filter(models.Taller.correo == request.correo).first()

    if cliente:
        cliente.password_hash = hashed_password
    elif taller:
        taller.password_hash = hashed_password
    else:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    db_token.utilizado = True
    db.commit()

    return {"message": "Contraseña actualizada exitosamente"}

@router.post("/login", response_model=schemas_auth.TokenResponse)
def login_conductor(request: schemas_auth.LoginRequest, db: Session = Depends(get_db)):
    db_cliente = crud.get_cliente_master_by_email(db, email=request.correo)
    if not db_cliente or not crud.verify_password(request.password, db_cliente.password_hash):
        raise HTTPException(status_code=401, detail="Correo o contraseña incorrectos")
    
    return {
        "access_token": "fake-jwt-token-for-now", 
        "token_type": "bearer",
        "user_id": db_cliente.id_cliente,
        "user_name": f"{db_cliente.nombres} {db_cliente.apellidos}"
    }
