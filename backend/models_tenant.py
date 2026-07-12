from sqlalchemy import Column, Integer, String, Float, Time, Boolean, DECIMAL, Text, ForeignKey, TIMESTAMP, func
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Tecnico(Base):
    __tablename__ = "tecnicos"
    id_tecnico = Column(Integer, primary_key=True, index=True)
    nombres = Column(String(100), nullable=False)
    apellidos = Column(String(100), nullable=False)
    ci_tecnico = Column(String(20), unique=True, nullable=False)
    telefono_contacto = Column(String(20), nullable=False)
    correo = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    estado_operativo = Column(String(20), default='Disponible')
    created_at = Column(TIMESTAMP, server_default=func.now())

    especialidades = relationship("Especialidad", secondary="tecnico_especialidades")

class Especialidad(Base):
    __tablename__ = "especialidades"
    id_especialidad = Column(Integer, primary_key=True, index=True)
    nombre_especialidad = Column(String(100), nullable=False)
    descripcion = Column(Text, nullable=True)

class Servicio(Base):
    __tablename__ = "servicios"
    id_servicio = Column(Integer, primary_key=True, index=True)
    nombre_servicio = Column(String(100), nullable=False)
    descripcion = Column(Text, nullable=True)
    tarifa_base_estimada = Column(DECIMAL(10, 2), nullable=False)

class TallerServicio(Base):
    __tablename__ = "taller_servicios"
    id_taller_servicio = Column(Integer, primary_key=True, index=True)
    id_servicio = Column(Integer, ForeignKey('servicios.id_servicio'), nullable=False)
    precio_especifico_taller = Column(DECIMAL(10, 2), nullable=False)
    tiempo_estimado_minutos = Column(Integer, nullable=True)
    estado_disponible = Column(Boolean, default=True)
    servicio = relationship("Servicio")

class Incidente(Base):
    __tablename__ = "incidentes"
    id_incidente = Column(Integer, primary_key=True, index=True)
    id_cliente = Column(Integer, nullable=False) # Ref al Master
    id_vehiculo = Column(Integer, nullable=False) # Ref al Master
    fecha_hora_reporte = Column(TIMESTAMP, server_default=func.now())
    ubicacion_latitud = Column(Float, nullable=False)
    ubicacion_longitud = Column(Float, nullable=False)
    tipo_problema = Column(String(50), nullable=False)
    descripcion_manual = Column(Text, nullable=True)
    nivel_prioridad = Column(String(15), nullable=True)
    estado_solicitud = Column(String(20), default='Pendiente')

    evidencias = relationship("Evidencia", back_populates="incidente")
    asistencia = relationship("Asistencia", back_populates="incidente", uselist=False)
    analisis_ia = relationship("AnalisisIA", uselist=False)

class Evidencia(Base):
    __tablename__ = "evidencias"
    id_evidencia = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente'), nullable=False)
    tipo_recurso = Column(String(20), nullable=False)
    url_archivo = Column(String(255), nullable=False)
    incidente = relationship("Incidente", back_populates="evidencias")

class Asistencia(Base):
    __tablename__ = "asistencias"
    id_asistencia = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente'), nullable=False, unique=True)
    id_tecnico = Column(Integer, ForeignKey('tecnicos.id_tecnico'), nullable=False)
    estado_asistencia = Column(String(20), default='Asignado')
    fecha_hora_asignacion = Column(TIMESTAMP, server_default=func.now())
    fecha_hora_finalizacion = Column(TIMESTAMP, nullable=True)
    
    incidente = relationship("Incidente", back_populates="asistencia")
    tecnico = relationship("Tecnico")
    pago = relationship("Pago", back_populates="asistencia", uselist=False)

class Pago(Base):
    __tablename__ = "pagos"
    id_pago = Column(Integer, primary_key=True, index=True)
    id_asistencia = Column(Integer, ForeignKey('asistencias.id_asistencia'), nullable=False, unique=True)
    monto_total = Column(DECIMAL(10, 2), nullable=False)
    metodo_pago = Column(String(30), nullable=False)
    estado_transaccion = Column(String(20), default='Pendiente')
    
    asistencia = relationship("Asistencia", back_populates="pago")

class Notificacion(Base):
    __tablename__ = "notificaciones"
    id_notificacion = Column(Integer, primary_key=True, index=True)
    id_usuario_destino = Column(Integer, nullable=False)
    tipo_usuario_destino = Column(String(20), nullable=False)
    titulo = Column(String(100), nullable=False)
    mensaje = Column(Text, nullable=False)
    leido = Column(Boolean, default=False)
    fecha_envio = Column(TIMESTAMP, server_default=func.now())

class Bitacora(Base):
    __tablename__ = "bitacora"
    id_log = Column(Integer, primary_key=True, index=True)
    id_usuario = Column(Integer, nullable=True)
    accion = Column(String(100), nullable=False)
    fecha_hora = Column(TIMESTAMP, server_default=func.now())

class AnalisisIA(Base):
    __tablename__ = "analisis_ia"
    id_analisis = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente'), nullable=False)
    # Sin back_populates aquí para simplificar
    diagnostico_ia = Column(Text, nullable=False)
    probabilidad_acierto = Column(Float, nullable=False)
    requiere_grua = Column(Boolean, default=False)
    sugerencias_primeros_auxilios = Column(Text, nullable=True)

class TecnicoEspecialidad(Base):
    __tablename__ = "tecnico_especialidades"
    id_tecnico = Column(Integer, ForeignKey('tecnicos.id_tecnico'), primary_key=True)
    id_especialidad = Column(Integer, ForeignKey('especialidades.id_especialidad'), primary_key=True)

class Valoracion(Base):
    __tablename__ = "valoraciones"
    id_valoracion = Column(Integer, primary_key=True, index=True)
    id_asistencia = Column(Integer, ForeignKey('asistencias.id_asistencia'), nullable=False)
    puntuacion = Column(Integer, nullable=False)
    comentario = Column(Text, nullable=True)
    fecha_valoracion = Column(TIMESTAMP, server_default=func.now())

class Cliente(Base):
    __tablename__ = "clientes"
    id_cliente = Column(Integer, primary_key=True, index=True)
    nombres = Column(String(100), nullable=False)
    apellidos = Column(String(100), nullable=False)
    ci_dni = Column(String(20), unique=True, nullable=False)
    telefono = Column(String(20), nullable=False)
    correo = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
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

class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"
    id_token = Column(Integer, primary_key=True, index=True)
    correo = Column(String(100), nullable=False)
    token = Column(String(6), nullable=False)
    expiracion = Column(TIMESTAMP, nullable=False)
    utilizado = Column(Boolean, default=False)
