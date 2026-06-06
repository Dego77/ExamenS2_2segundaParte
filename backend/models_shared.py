from sqlalchemy import Column, Integer, String, TIMESTAMP, func, Boolean, DECIMAL, Text, Float, ForeignKey, Time
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

Base = declarative_base()

class Admin(Base):
    __tablename__ = "admins"
    id_admin = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    correo = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    rol = Column(String(20), default='Admin')
    created_at = Column(TIMESTAMP, server_default=func.now())

class Taller(Base):
    __tablename__ = "talleres"
    id_taller = Column(Integer, primary_key=True, index=True)
    razon_social = Column(String(150), nullable=False)
    nombre_representante = Column(String(150), nullable=False)
    nit = Column(String(30), unique=True, nullable=False)
    correo = Column(String(100), unique=True, nullable=False, index=True)
    ubicacion_base_latitud = Column(Float, nullable=False)
    ubicacion_base_longitud = Column(Float, nullable=False)
    direccion_fisica = Column(String(255), nullable=True)
    telefono_taller = Column(String(20), nullable=True)
    logo_url = Column(String(255), nullable=True)
    es_24_7 = Column(Boolean, default=False)
    horario_apertura = Column(Time, nullable=True)
    horario_cierre = Column(Time, nullable=True)
    horario_cierre_sabado = Column(Time, nullable=True)
    foto_nit_url = Column(String(255), nullable=True)
    foto_local_url = Column(String(255), nullable=True)
    cuenta_bancaria = Column(String(100), nullable=True)
    password_hash = Column(String(255), nullable=False)
    db_name = Column(String(100), nullable=True) 
    estado_aprobacion = Column(String(20), default='Pendiente')
    created_at = Column(TIMESTAMP, server_default=func.now())

class Cliente(Base):
    __tablename__ = "clientes"
    id_cliente = Column(Integer, primary_key=True, index=True)
    nombres = Column(String(100), nullable=False)
    apellidos = Column(String(100), nullable=False)
    ci_dni = Column(String(20), unique=True, nullable=False)
    telefono = Column(String(20), nullable=False)
    correo = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    fcm_token = Column(String(255), nullable=True) # Token para notificaciones push
    created_at = Column(TIMESTAMP, server_default=func.now())
    vehiculos = relationship("Vehiculo", back_populates="cliente")

class Vehiculo(Base):
    __tablename__ = "vehiculos"
    id_vehiculo = Column(Integer, primary_key=True, index=True)
    id_cliente = Column(Integer, ForeignKey('clientes.id_cliente', ondelete='CASCADE'), nullable=False)
    placa = Column(String(15), unique=True, nullable=False)
    marca = Column(String(50), nullable=False)
    modelo = Column(String(50), nullable=False)
    año = Column(Integer, nullable=False)
    color = Column(String(30), nullable=False)
    tipo_transmision = Column(String(20), nullable=False)
    tipo_combustible = Column(String(20), nullable=False)
    cliente = relationship("Cliente", back_populates="vehiculos")

class Incidente(Base):
    __tablename__ = "incidentes"
    id_incidente = Column(Integer, primary_key=True, index=True)
    id_cliente = Column(Integer, ForeignKey('clientes.id_cliente'), nullable=False)
    id_vehiculo = Column(Integer, ForeignKey('vehiculos.id_vehiculo'), nullable=False)
    fecha_hora_reporte = Column(TIMESTAMP, server_default=func.now())
    ubicacion_latitud = Column(Float, nullable=False)
    ubicacion_longitud = Column(Float, nullable=False)
    tipo_problema = Column(String(50), nullable=False)
    descripcion_manual = Column(Text, nullable=True)
    nivel_prioridad = Column(String(15), nullable=True)
    estado_solicitud = Column(String(20), default='Pendiente')
    client_uuid = Column(String(36), unique=True, nullable=True)  # Para dedup offline

class Evidencia(Base):
    __tablename__ = "evidencias"
    id_evidencia = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente', ondelete='CASCADE'), nullable=False)
    tipo_recurso = Column(String(20), nullable=False)
    url_archivo = Column(String(255), nullable=False)
    fecha_subida = Column(TIMESTAMP, server_default=func.now())

class AnalisisIA(Base):
    __tablename__ = "analisis_ia"
    id_analisis = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente', ondelete='CASCADE'), nullable=False, unique=True)
    clasificacion_sugerida = Column(String(50), nullable=True)
    resumen_estructurado = Column(Text, nullable=True)

class Pago(Base):
    __tablename__ = "pagos"
    id_pago = Column(Integer, primary_key=True, index=True)
    id_asistencia_global = Column(Integer, nullable=True) # Ref opcional a la asistencia vinculada
    monto_subtotal = Column(DECIMAL(10, 2), nullable=False)
    monto_comision_plataforma = Column(DECIMAL(10, 2), nullable=False)
    monto_total_cliente = Column(DECIMAL(10, 2), nullable=False)
    metodo_pago = Column(String(30), nullable=False)
    estado_transaccion = Column(String(20), default='Pendiente')
    fecha_pago = Column(TIMESTAMP, server_default=func.now())

class Bitacora(Base):
    __tablename__ = "bitacora"
    id_log = Column(Integer, primary_key=True, index=True)
    id_usuario = Column(Integer, nullable=True)
    tipo_usuario = Column(String(20), nullable=True)
    accion = Column(String(100), nullable=False)
    descripcion = Column(Text, nullable=True)
    fecha_hora = Column(TIMESTAMP, server_default=func.now())

class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"
    id_token = Column(Integer, primary_key=True, index=True)
    correo = Column(String(100), nullable=False)
    token = Column(String(6), nullable=False)
    expiracion = Column(TIMESTAMP, nullable=False)
    utilizado = Column(Boolean, default=False)

class Tecnico(Base):
    __tablename__ = "tecnicos"
    id_tecnico = Column(Integer, primary_key=True, index=True)
    id_taller = Column(Integer, ForeignKey('talleres.id_taller', ondelete='CASCADE'), nullable=False)
    nombres = Column(String(100), nullable=False)
    apellidos = Column(String(100), nullable=False)
    ci_tecnico = Column(String(20), unique=True, nullable=False)
    telefono_contacto = Column(String(20), nullable=False)
    correo = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    primer_login = Column(Boolean, default=True)
    en_turno = Column(Boolean, default=False)
    estado_operativo = Column(String(20), default='Disponible')
    created_at = Column(TIMESTAMP, server_default=func.now())

    taller = relationship("Taller", back_populates="tecnicos")

# Añadir relación inversa en Taller si no existe
Taller.tecnicos = relationship("Tecnico", back_populates="taller", cascade="all, delete-orphan")

class Asistencia(Base):
    __tablename__ = "asistencias_global"
    id_asistencia = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente'), nullable=False, unique=True)
    id_taller = Column(Integer, ForeignKey('talleres.id_taller'), nullable=False)
    id_tecnico = Column(Integer, ForeignKey('tecnicos.id_tecnico'), nullable=True)
    fecha_hora_asignacion = Column(TIMESTAMP, server_default=func.now())
    ubicacion_actual_latitud = Column(Float, nullable=True)
    ubicacion_actual_longitud = Column(Float, nullable=True)
    estado_asistencia = Column(String(20), default='Pendiente')
    
    incidente = relationship("Incidente")
    taller = relationship("Taller")
    tecnico = relationship("Tecnico")

class Servicio(Base):
    __tablename__ = "servicios"
    id_servicio = Column(Integer, primary_key=True, index=True)
    nombre_servicio = Column(String(100), nullable=False)
    descripcion = Column(Text, nullable=True)
    tarifa_base_estimada = Column(DECIMAL(10, 2), nullable=False)

class Cotizacion(Base):
    __tablename__ = "cotizaciones"
    id_cotizacion = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente'), nullable=False)
    id_taller = Column(Integer, ForeignKey('talleres.id_taller'), nullable=False)
    monto_estimado = Column(DECIMAL(10, 2), nullable=False)
    tiempo_estimado_minutos = Column(Integer, nullable=False)
    descripcion_propuesta = Column(Text, nullable=True)
    estado = Column(String(20), default='Enviada')
    created_at = Column(TIMESTAMP, server_default=func.now())

    incidente = relationship("Incidente")
    taller = relationship("Taller")

class PagoGlobal(Base):
    __tablename__ = "pagos_global"
    id_pago = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente'), nullable=False)
    id_taller = Column(Integer, ForeignKey('talleres.id_taller'), nullable=False)
    monto_total = Column(DECIMAL(10, 2), nullable=False)
    metodo_pago = Column(String(30), nullable=False)
    estado_transaccion = Column(String(20), default='Pendiente') # Pendiente, Completado, Fallido
    comision_plataforma = Column(DECIMAL(10, 2), nullable=False)
    fecha_pago = Column(TIMESTAMP, server_default=func.now())

    incidente = relationship("Incidente")
    taller = relationship("Taller")

