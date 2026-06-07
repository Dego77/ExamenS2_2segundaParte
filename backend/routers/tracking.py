from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict, Set
import json

router = APIRouter()

# Salas de tracking: { id_incidente: set(websockets) }
tracking_rooms: Dict[int, Set[WebSocket]] = {}

@router.websocket("/ws/tracking/{id_incidente}")
async def websocket_tracking(websocket: WebSocket, id_incidente: int):
    await websocket.accept()
    
    if id_incidente not in tracking_rooms:
        tracking_rooms[id_incidente] = set()
    
    tracking_rooms[id_incidente].add(websocket)
    print(f"📍 Alguien se unió al tracking del incidente {id_incidente}. Total en sala: {len(tracking_rooms[id_incidente])}", flush=True)

    try:
        while True:
            # Recibir coordenadas del técnico
            data = await websocket.receive_json()
            
            # El mensaje esperado es: {"lat": -17.3, "lng": -66.1}
            lat = data.get("lat")
            lng = data.get("lng")
            
            # Actualizar en la base de datos maestra para que el GET /tracking lo vea
            from database import MasterSessionLocal
            import models_shared
            with MasterSessionLocal() as db:
                asistencia = db.query(models_shared.Asistencia).filter(models_shared.Asistencia.id_incidente == id_incidente).first()
                if asistencia:
                    asistencia.ubicacion_actual_latitud = lat
                    asistencia.ubicacion_actual_longitud = lng
                    db.commit()

            message = {
                "type": "LOCATION_UPDATE",
                "id_incidente": id_incidente,
                "lat": lat,
                "lng": lng
            }
            
            # Broadcast a la sala
            to_remove = set()
            for client in tracking_rooms[id_incidente]:
                if client != websocket: # No enviar al mismo que lo mandó
                    try:
                        await client.send_json(message)
                    except:
                        to_remove.add(client)
            
            for client in to_remove:
                tracking_rooms[id_incidente].remove(client)
                
    except WebSocketDisconnect:
        tracking_rooms[id_incidente].remove(websocket)
        if not tracking_rooms[id_incidente]:
            del tracking_rooms[id_incidente]
        print(f"📍 Alguien salió del tracking del incidente {id_incidente}", flush=True)
    except Exception as e:
        print(f"📍 Error en tracking incidente {id_incidente}: {e}", flush=True)
        if websocket in tracking_rooms[id_incidente]:
            tracking_rooms[id_incidente].remove(websocket)
