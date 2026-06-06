-- BASE DE DATOS: Plataforma Inteligente de Emergencias Vehiculares
-- MOTOR: PostgreSQL

-- 1. TABLAS PRINCIPALES

CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    ci_dni VARCHAR(20) UNIQUE NOT NULL, -- Obligatorio
    telefono VARCHAR(20) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    foto_perfil_url VARCHAR(255),
    estado_cuenta VARCHAR(20) DEFAULT 'Activo',
    calificacion_promedio DECIMAL(3,2) DEFAULT 5.00,
    fcm_token VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE admins (
    id_admin SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    rol VARCHAR(20) DEFAULT 'Admin',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE talleres (
    id_taller SERIAL PRIMARY KEY,
    razon_social VARCHAR(150) NOT NULL,
    nombre_representante VARCHAR(150) NOT NULL,
    id_admin_aprobador INT,
    nit VARCHAR(30) UNIQUE NOT NULL,
    ubicacion_base_latitud FLOAT NOT NULL,
    ubicacion_base_longitud FLOAT NOT NULL,
    direccion_fisica TEXT,
    telefono_taller VARCHAR(20),
    logo_url VARCHAR(255),
    es_24_7 BOOLEAN DEFAULT FALSE, -- Flag para el sistema de asignación
    horario_apertura TIME,
    horario_cierre TIME,
    horario_cierre_sabado TIME,
    foto_nit_url VARCHAR(255),
    foto_local_url VARCHAR(255),
    cuenta_bancaria VARCHAR(50),
    calificacion_promedio DECIMAL(3,2) DEFAULT 5.00,
    estado_aprobacion VARCHAR(20) DEFAULT 'Pendiente',
    correo VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_admin_aprobador) REFERENCES admins(id_admin)
);

CREATE TABLE servicios (
    id_servicio SERIAL PRIMARY KEY,
    nombre_servicio VARCHAR(100) NOT NULL,
    descripcion TEXT,
    tarifa_base_estimada DECIMAL(10,2) NOT NULL
);

CREATE TABLE especialidades (
    id_especialidad SERIAL PRIMARY KEY,
    nombre_especialidad VARCHAR(100) UNIQUE NOT NULL,
    descripcion TEXT
);

-- 2. TABLAS DE EQUIPO Y VEHÍCULOS

CREATE TABLE vehiculos (
    id_vehiculo SERIAL PRIMARY KEY,
    id_cliente INT NOT NULL,
    placa VARCHAR(15) UNIQUE NOT NULL,
    marca VARCHAR(50) NOT NULL,
    modelo VARCHAR(50) NOT NULL,
    año INT NOT NULL,
    color VARCHAR(30) NOT NULL,
    tipo_transmision VARCHAR(20) NOT NULL,
    tipo_combustible VARCHAR(20) NOT NULL,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE
);

CREATE TABLE tecnicos (
    id_tecnico SERIAL PRIMARY KEY,
    id_taller INT NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    ci_tecnico VARCHAR(20) UNIQUE NOT NULL,
    telefono_contacto VARCHAR(20) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    primer_login BOOLEAN DEFAULT TRUE,
    foto_perfil_url VARCHAR(255),
    en_turno BOOLEAN DEFAULT FALSE,
    ubicacion_actual_latitud FLOAT,
    ubicacion_actual_longitud FLOAT,
    estado_operativo VARCHAR(20) DEFAULT 'Disponible',
    fcm_token VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_taller) REFERENCES talleres(id_taller) ON DELETE CASCADE
);

CREATE TABLE tecnico_especialidades (
    id_tecnico INT NOT NULL,
    id_especialidad INT NOT NULL,
    PRIMARY KEY (id_tecnico, id_especialidad),
    FOREIGN KEY (id_tecnico) REFERENCES tecnicos(id_tecnico) ON DELETE CASCADE,
    FOREIGN KEY (id_especialidad) REFERENCES especialidades(id_especialidad) ON DELETE CASCADE
);

CREATE TABLE taller_servicios (
    id_taller_servicio SERIAL PRIMARY KEY,
    id_taller INT NOT NULL,
    id_servicio INT NOT NULL,
    precio_especifico_taller DECIMAL(10,2) NOT NULL,
    tiempo_estimado_minutos INT,
    estado_disponible BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (id_taller) REFERENCES talleres(id_taller) ON DELETE CASCADE,
    FOREIGN KEY (id_servicio) REFERENCES servicios(id_servicio) ON DELETE CASCADE
);

-- 3. TRANSACCIONAL

CREATE TABLE incidentes (
    id_incidente SERIAL PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_vehiculo INT NOT NULL,
    fecha_hora_reporte TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ubicacion_latitud FLOAT NOT NULL,
    ubicacion_longitud FLOAT NOT NULL,
    tipo_problema VARCHAR(50) NOT NULL,
    descripcion_manual TEXT,
    nivel_prioridad VARCHAR(15),
    estado_solicitud VARCHAR(20) DEFAULT 'Pendiente',
    distancia_km_calculada DECIMAL(5,2),
    motivo_cancelacion TEXT,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_vehiculo) REFERENCES vehiculos(id_vehiculo)
);

CREATE TABLE evidencias (
    id_evidencia SERIAL PRIMARY KEY,
    id_incidente INT NOT NULL,
    tipo_recurso VARCHAR(20) NOT NULL,
    url_archivo VARCHAR(255) NOT NULL,
    fecha_subida TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_incidente) REFERENCES incidentes(id_incidente) ON DELETE CASCADE
);

CREATE TABLE analisis_ia (
    id_analisis SERIAL PRIMARY KEY,
    id_incidente INT UNIQUE NOT NULL,
    transcripcion_audio TEXT,
    clasificacion_sugerida VARCHAR(50),
    resumen_estructurado TEXT,
    nivel_confianza_porcentaje INT,
    requiere_revision_manual BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (id_incidente) REFERENCES incidentes(id_incidente) ON DELETE CASCADE
);

CREATE TABLE asistencias (
    id_asistencia SERIAL PRIMARY KEY,
    id_incidente INT UNIQUE NOT NULL,
    id_taller INT NOT NULL,
    id_tecnico INT NOT NULL,
    fecha_hora_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_hora_llegada_tecnico TIMESTAMP,
    fecha_hora_finalizacion TIMESTAMP,
    observaciones_tecnico TEXT,
    FOREIGN KEY (id_incidente) REFERENCES incidentes(id_incidente),
    FOREIGN KEY (id_taller) REFERENCES talleres(id_taller),
    FOREIGN KEY (id_tecnico) REFERENCES tecnicos(id_tecnico)
);

CREATE TABLE pagos (
    id_pago SERIAL PRIMARY KEY,
    id_asistencia INT UNIQUE NOT NULL,
    monto_subtotal DECIMAL(10,2) NOT NULL,
    monto_comision_plataforma DECIMAL(10,2) NOT NULL, -- El 10%
    monto_total_cliente DECIMAL(10,2) NOT NULL,
    metodo_pago VARCHAR(30) NOT NULL,
    estado_transaccion VARCHAR(20) DEFAULT 'Pendiente',
    fecha_pago TIMESTAMP,
    FOREIGN KEY (id_asistencia) REFERENCES asistencias(id_asistencia)
);

CREATE TABLE valoraciones (
    id_valoracion SERIAL PRIMARY KEY,
    id_asistencia INT UNIQUE NOT NULL,
    puntuacion INT NOT NULL CHECK (puntuacion >= 1 AND puntuacion <= 5),
    comentario TEXT,
    fecha_valoracion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_asistencia) REFERENCES asistencias(id_asistencia)
);

CREATE TABLE notificaciones (
    id_notificacion SERIAL PRIMARY KEY,
    id_usuario_destino INT NOT NULL,
    tipo_usuario_destino VARCHAR(20) NOT NULL,
    titulo VARCHAR(100) NOT NULL,
    mensaje TEXT NOT NULL,
    leido BOOLEAN DEFAULT FALSE,
    fecha_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bitacora (
    id_log SERIAL PRIMARY KEY,
    id_usuario INT,
    tipo_usuario VARCHAR(20),
    accion VARCHAR(100) NOT NULL,
    descripcion TEXT,
    ip_address VARCHAR(45),
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE password_reset_tokens (
    id_token SERIAL PRIMARY KEY,
    correo VARCHAR(100) NOT NULL,
    token VARCHAR(6) NOT NULL,
    expiracion TIMESTAMP NOT NULL,
    utilizado BOOLEAN DEFAULT FALSE
);

