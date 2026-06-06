from pydantic import BaseModel, EmailStr, ConfigDict, Field
from typing import Optional, List
from datetime import datetime, time

# --- Cliente Schemas ---
class ClienteBase(BaseModel):
    nombres: str
    apellidos: str
    ci_dni: str
    telefono: str
    correo: EmailStr
    foto_perfil_url: Optional[str] = None

class ClienteCreate(ClienteBase):
    password: str

class ClienteResponse(ClienteBase):
    id_cliente: int
    estado_cuenta: str = "Activo"
    calificacion_promedio: float = 0.0

    model_config = ConfigDict(from_attributes=True)

# --- Taller Schemas ---
class TallerBase(BaseModel):
    razon_social: str
    nombre_representante: str
    nit: str = Field(..., pattern=r"^[0-9]+$")
    correo: EmailStr
    ubicacion_base_latitud: float
    ubicacion_base_longitud: float
    direccion_fisica: Optional[str] = None
    telefono_taller: Optional[str] = None
    logo_url: Optional[str] = None
    es_24_7: bool = False
    horario_apertura: Optional[time] = None
    horario_cierre: Optional[time] = None
    horario_cierre_sabado: Optional[time] = None
    foto_nit_url: Optional[str] = None
    foto_local_url: Optional[str] = None
    cuenta_bancaria: Optional[str] = None

class TallerCreate(TallerBase):
    password: str

class TallerResponse(TallerBase):
    id_taller: int
    id_admin_aprobador: Optional[int] = None
    estado_aprobacion: str = "Pendiente"
    calificacion_promedio: float = 0.0

    model_config = ConfigDict(from_attributes=True)

# --- Especialidad Schemas ---
class EspecialidadBase(BaseModel):
    nombre_especialidad: str
    descripcion: Optional[str] = None

class EspecialidadResponse(EspecialidadBase):
    id_especialidad: int
    model_config = ConfigDict(from_attributes=True)

# --- Tecnico Schemas ---
class TecnicoBase(BaseModel):
    nombres: str
    apellidos: str
    ci_tecnico: str
    telefono_contacto: str
    correo: EmailStr
    foto_perfil_url: Optional[str] = None

class TecnicoCreate(TecnicoBase):
    id_taller: int
    password: str

class TecnicoResponse(TecnicoBase):
    id_tecnico: int
    id_taller: Optional[int] = None
    en_turno: bool = False
    primer_login: bool = True
    estado_operativo: str = "Disponible"
    ubicacion_actual_latitud: Optional[float] = None
    ubicacion_actual_longitud: Optional[float] = None
    especialidades: List[EspecialidadResponse] = []

    model_config = ConfigDict(from_attributes=True)


# schemas/responses intermedios
class VehiculoBase(BaseModel):
    placa: str
    marca: str
    modelo: str
    año: int
    color: str
    tipo_transmision: str
    tipo_combustible: str

class VehiculoCreate(VehiculoBase):
    pass

class VehiculoResponse(VehiculoBase):
    id_vehiculo: int
    id_cliente: int

# --- Vehiculo Schemas ---
class VehiculoBase(BaseModel):
    placa: str
    marca: str
    modelo: str
    año: int
    color: str
    tipo_transmision: str
    tipo_combustible: str

class VehiculoCreate(VehiculoBase):
    id_cliente: int

class VehiculoResponse(VehiculoBase):
    id_vehiculo: int
    id_cliente: int
    model_config = ConfigDict(from_attributes=True)

# --- Incidente Schemas ---
class IncidenteBase(BaseModel):
    ubicacion_latitud: float
    ubicacion_longitud: float
    tipo_problema: str
    descripcion_manual: Optional[str] = None
    nivel_prioridad: Optional[str] = None

class IncidenteCreate(IncidenteBase):
    id_cliente: int
    id_vehiculo: int

class IncidenteResponse(IncidenteBase):
    id_incidente: int
    id_cliente: int
    id_vehiculo: int
    estado_solicitud: str
    fecha_hora_reporte: datetime
    distancia_km_calculada: Optional[float]
    model_config = ConfigDict(from_attributes=True)

# --- Pago Schemas ---
class PagoBase(BaseModel):
    monto_subtotal: float
    metodo_pago: str

class PagoResponse(PagoBase):
    id_pago: int
    monto_comision_plataforma: float
    monto_total_cliente: float
    estado_transaccion: str
    fecha_pago: Optional[datetime]
    model_config = ConfigDict(from_attributes=True)


# --- Auth Schemas ---
class ForgotPasswordRequest(BaseModel):
    correo: EmailStr

class VerifyTokenRequest(BaseModel):
    correo: EmailStr
    token: str

class ResetPasswordRequest(BaseModel):
    correo: EmailStr
    token: str
    nueva_password: str

class UpdateFCMTokenRequest(BaseModel):
    fcm_token: str

# --- Valoracion Schemas ---
class ValoracionCreate(BaseModel):
    puntuacion: int
    comentario: Optional[str] = None

class ValoracionResponse(BaseModel):
    id_valoracion: int
    id_asistencia: int
    puntuacion: int
    comentario: Optional[str] = None
    fecha_valoracion: datetime
    model_config = ConfigDict(from_attributes=True)

# --- Cotizacion Schemas ---
class CotizacionBase(BaseModel):
    id_incidente: int
    id_taller: int
    monto_estimado: float
    tiempo_estimado_minutos: int
    descripcion_propuesta: Optional[str] = None

class CotizacionCreate(CotizacionBase):
    pass

class CotizacionResponse(CotizacionBase):
    id_cotizacion: int
    estado: str
    created_at: datetime

    class Config:
        from_attributes = True

class PagoCreate(BaseModel):
    id_incidente: int
    id_taller: int
    monto_total: float
    metodo_pago: str

class PagoResponse(PagoCreate):
    id_pago: int
    estado_transaccion: str
    fecha_pago: datetime

    class Config:
        from_attributes = True
