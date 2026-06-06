import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import models_shared
import models_tenant
from websocket_manager import manager
from database import master_engine

# Inicializar Base de Datos Maestra
models_shared.Base.metadata.create_all(bind=master_engine)

os.makedirs("uploads", exist_ok=True)

app = FastAPI(
    title="API - Plataforma Inteligente de Emergencias Vehiculares",
    description="Backend para la gestión de incidentes vehiculares, talleres y técnicos",
    version="1.0.0"
)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# Configuración de CORS
origins = [
    "http://localhost:4200",
    "http://127.0.0.1:4200",
    "http://192.168.1.5:4200",
    "http://192.168.1.6:4200",
    "http://192.168.1.10:4200",
    "http://192.168.1.5:8001",
    "http://192.168.1.6:8001",
    "http://192.168.1.10:8001"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"]
)

from fastapi import WebSocket, WebSocketDisconnect

# El manager ahora se importa de websocket_manager.py al inicio

@app.websocket("/ws/talleres/{id_taller}")
async def websocket_taller(websocket: WebSocket, id_taller: int):
    user_key = f"taller_{id_taller}"
    await manager.connect(user_key, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(user_key)

@app.websocket("/ws/clientes/{id_cliente}")
async def websocket_cliente(websocket: WebSocket, id_cliente: int):
    user_key = f"cliente_{id_cliente}"
    await manager.connect(user_key, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(user_key)

@app.get("/")
def read_root():
    return {
        "status": "up",
        "message": "Bienvenido a la API de Plataforma Inteligente de Emergencias Vehiculares"
    }

from routers import clientes, talleres, incidentes, pagos, admin, auth, tracking, cotizaciones

app.include_router(clientes.router, prefix="/api/clientes", tags=["Clientes"])
app.include_router(talleres.router, prefix="/api/talleres", tags=["Talleres"])
app.include_router(incidentes.router, prefix="/api/incidentes", tags=["Incidentes"])
app.include_router(pagos.router, prefix="/api/pagos", tags=["Pagos"])
app.include_router(admin.router)
app.include_router(auth.router, prefix="/api/auth", tags=["Autenticación"])
app.include_router(tracking.router, tags=["Tracking"])
app.include_router(cotizaciones.router)
