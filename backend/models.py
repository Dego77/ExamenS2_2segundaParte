from sqlalchemy import Column, Integer, String, Float, Time, Boolean, DECIMAL, Text, ForeignKey, TIMESTAMP, func
from sqlalchemy.orm import relationship
from database import Base

class Cliente(Base):
    __tablename__ = "clientes"

    id_cliente = Column(Integer, primary_key=True, index=True)
    nombres = Column(String(100), nullable=False)
    apellidos = Column(String(100), nullable=False)
    ci_dni = Column(String(20), unique=True, nullable=False) # Obligatorio por seguridad
    telefono = Column(String(20), nullable=False)
    correo = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    foto_perfil_url = Column(String(255), nullable=True)
    fcm_token = Column(String(255), nullable=True)
    estado_cuenta = Column(String(20), default='Activo')
    calificacion_promedio = Column(DECIMAL(3, 2), default=5.00)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    vehiculos = relationship("Vehiculo", back_populates="cliente", cascade="all, delete-orphan")
    incidentes = relationship("Incidente", back_populates="cliente")


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
    id_admin_aprobador = Column(Integer, ForeignKey('admins.id_admin'), nullable=True)
    nit = Column(String(30), unique=True, nullable=False)
    ubicacion_base_latitud = Column(Float, nullable=False)
    ubicacion_base_longitud = Column(Float, nullable=False)
    direccion_fisica = Column(Text, nullable=True)
    telefono_taller = Column(String(20), nullable=True)
    logo_url = Column(String(255), nullable=True)
    es_24_7 = Column(Boolean, default=False) # Para asignación automática del sistema
    horario_apertura = Column(Time, nullable=True)
    horario_cierre = Column(Time, nullable=True)
    horario_cierre_sabado = Column(Time, nullable=True)
    foto_nit_url = Column(String(255), nullable=True)
    foto_local_url = Column(String(255), nullable=True)
    cuenta_bancaria = Column(String(50), nullable=True)
    calificacion_promedio = Column(DECIMAL(3, 2), default=5.00)
    estado_aprobacion = Column(String(20), default='Pendiente')
    correo = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    tecnicos = relationship("Tecnico", back_populates="taller", cascade="all, delete-orphan")
    taller_servicios = relationship("TallerServicio", back_populates="taller", cascade="all, delete-orphan")
    asistencias = relationship("Asistencia", back_populates="taller")


class Especialidad(Base):
    __tablename__ = "especialidades"

    id_especialidad = Column(Integer, primary_key=True, index=True)
    nombre_especialidad = Column(String(100), nullable=False, unique=True)
    descripcion = Column(Text, nullable=True)


class TecnicoEspecialidad(Base):
    __tablename__ = "tecnico_especialidades"

    id_tecnico = Column(Integer, ForeignKey('tecnicos.id_tecnico', ondelete='CASCADE'), primary_key=True)
    id_especialidad = Column(Integer, ForeignKey('especialidades.id_especialidad', ondelete='CASCADE'), primary_key=True)


class Tecnico(Base):
    __tablename__ = "tecnicos"

    id_tecnico = Column(Integer, primary_key=True, index=True)
    id_taller = Column(Integer, ForeignKey('talleres.id_taller', ondelete='CASCADE'), nullable=False)
    nombres = Column(String(100), nullable=False)
    apellidos = Column(String(100), nullable=False)
    ci_tecnico = Column(String(20), unique=True, nullable=False) # Obligatorio
    telefono_contacto = Column(String(20), nullable=False)
    correo = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    primer_login = Column(Boolean, default=True)
    foto_perfil_url = Column(String(255), nullable=True)
    fcm_token = Column(String(255), nullable=True)
    en_turno = Column(Boolean, default=False)
    ubicacion_actual_latitud = Column(Float, nullable=True)
    ubicacion_actual_longitud = Column(Float, nullable=True)
    estado_operativo = Column(String(20), default='Disponible')
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    taller = relationship("Taller", back_populates="tecnicos")
    asistencias = relationship("Asistencia", back_populates="tecnico")
    especialidades = relationship("Especialidad", secondary="tecnico_especialidades")


class Servicio(Base):
    __tablename__ = "servicios"

    id_servicio = Column(Integer, primary_key=True, index=True)
    nombre_servicio = Column(String(100), nullable=False)
    descripcion = Column(Text, nullable=True)
    tarifa_base_estimada = Column(DECIMAL(10, 2), nullable=False)

    taller_servicios = relationship("TallerServicio", back_populates="servicio")


class TallerServicio(Base):
    __tablename__ = "taller_servicios"

    id_taller_servicio = Column(Integer, primary_key=True, index=True)
    id_taller = Column(Integer, ForeignKey('talleres.id_taller', ondelete='CASCADE'), nullable=False)
    id_servicio = Column(Integer, ForeignKey('servicios.id_servicio', ondelete='CASCADE'), nullable=False)
    precio_especifico_taller = Column(DECIMAL(10, 2), nullable=False)
    tiempo_estimado_minutos = Column(Integer, nullable=True)
    estado_disponible = Column(Boolean, default=True)

    taller = relationship("Taller", back_populates="taller_servicios")
    servicio = relationship("Servicio", back_populates="taller_servicios")


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
    incidentes = relationship("Incidente", back_populates="vehiculo")


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
    distancia_km_calculada = Column(DECIMAL(5, 2), nullable=True)
    motivo_cancelacion = Column(Text, nullable=True)

    cliente = relationship("Cliente", back_populates="incidentes")
    vehiculo = relationship("Vehiculo", back_populates="incidentes")
    evidencias = relationship("Evidencia", back_populates="incidente", cascade="all, delete-orphan")
    analisis_ia = relationship("AnalisisIA", back_populates="incidente", uselist=False, cascade="all, delete-orphan")
    asistencia = relationship("Asistencia", back_populates="incidente", uselist=False)


class Evidencia(Base):
    __tablename__ = "evidencias"

    id_evidencia = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente', ondelete='CASCADE'), nullable=False)
    tipo_recurso = Column(String(20), nullable=False)
    url_archivo = Column(String(255), nullable=False)
    fecha_subida = Column(TIMESTAMP, server_default=func.now())

    incidente = relationship("Incidente", back_populates="evidencias")


class AnalisisIA(Base):
    __tablename__ = "analisis_ia"

    id_analisis = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente', ondelete='CASCADE'), nullable=False, unique=True)
    transcripcion_audio = Column(Text, nullable=True)
    clasificacion_sugerida = Column(String(50), nullable=True)
    resumen_estructurado = Column(Text, nullable=True)
    nivel_confianza_porcentaje = Column(Integer, nullable=True)
    requiere_revision_manual = Column(Boolean, default=False)

    incidente = relationship("Incidente", back_populates="analisis_ia")


class Asistencia(Base):
    __tablename__ = "asistencias"

    id_asistencia = Column(Integer, primary_key=True, index=True)
    id_incidente = Column(Integer, ForeignKey('incidentes.id_incidente'), nullable=False, unique=True)
    id_taller = Column(Integer, ForeignKey('talleres.id_taller'), nullable=False)
    id_tecnico = Column(Integer, ForeignKey('tecnicos.id_tecnico'), nullable=False)
    fecha_hora_asignacion = Column(TIMESTAMP, server_default=func.now())
    fecha_hora_llegada_tecnico = Column(TIMESTAMP, nullable=True)
    fecha_hora_finalizacion = Column(TIMESTAMP, nullable=True)
    observaciones_tecnico = Column(Text, nullable=True)

    incidente = relationship("Incidente", back_populates="asistencia")
    taller = relationship("Taller", back_populates="asistencias")
    tecnico = relationship("Tecnico", back_populates="asistencias")
    pago = relationship("Pago", back_populates="asistencia", uselist=False)
    valoracion = relationship("Valoracion", back_populates="asistencia", uselist=False)


class Pago(Base):
    __tablename__ = "pagos"

    id_pago = Column(Integer, primary_key=True, index=True)
    id_asistencia = Column(Integer, ForeignKey('asistencias.id_asistencia'), nullable=False, unique=True)
    monto_subtotal = Column(DECIMAL(10, 2), nullable=False)
    monto_comision_plataforma = Column(DECIMAL(10, 2), nullable=False)
    monto_total_cliente = Column(DECIMAL(10, 2), nullable=False)
    metodo_pago = Column(String(30), nullable=False)
    estado_transaccion = Column(String(20), default='Pendiente')
    fecha_pago = Column(TIMESTAMP, nullable=True)

    asistencia = relationship("Asistencia", back_populates="pago")


class Valoracion(Base):
    __tablename__ = "valoraciones"

    id_valoracion = Column(Integer, primary_key=True, index=True)
    id_asistencia = Column(Integer, ForeignKey('asistencias.id_asistencia'), nullable=False, unique=True)
    puntuacion = Column(Integer, nullable=False)
    comentario = Column(Text, nullable=True)
    fecha_valoracion = Column(TIMESTAMP, server_default=func.now())

    asistencia = relationship("Asistencia", back_populates="valoracion")


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
    tipo_usuario = Column(String(20), nullable=True)
    accion = Column(String(100), nullable=False)
    descripcion = Column(Text, nullable=True)
    ip_address = Column(String(45), nullable=True)
    fecha_hora = Column(TIMESTAMP, server_default=func.now())


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id_token = Column(Integer, primary_key=True, index=True)
    correo = Column(String(100), nullable=False)
    token = Column(String(6), nullable=False)
    expiracion = Column(TIMESTAMP, nullable=False)
    utilizado = Column(Boolean, default=False)



