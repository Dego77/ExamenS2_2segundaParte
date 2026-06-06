from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        # Almacena conexiones activas: {"taller_5": websocket, "cliente_10": websocket}
        self.active_connections: dict[str, WebSocket] = {}

    async def connect(self, user_key: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[user_key] = websocket
        print(f"✅ Nueva conexión WebSocket: {user_key}. Total: {len(self.active_connections)}", flush=True)

    def disconnect(self, user_key: str):
        if user_key in self.active_connections:
            del self.active_connections[user_key]
            print(f"❌ Conexión WebSocket cerrada: {user_key}", flush=True)

    async def send_personal_message(self, message: dict, user_key: str):
        if user_key in self.active_connections:
            try:
                await self.active_connections[user_key].send_json(message)
                print(f"📣 Mensaje enviado a {user_key}", flush=True)
                return True
            except Exception as e:
                print(f"⚠️ Error enviando a {user_key}: {e}", flush=True)
                self.disconnect(user_key)
        else:
            print(f"⚠️ {user_key} no está conectado. No se pudo enviar el mensaje.", flush=True)
        return False

    async def broadcast_to_incident(self, id_cliente: int, id_taller: int, message: dict):
        """Notifica tanto al cliente como al taller asociados a un incidente."""
        await self.send_personal_message(message, f"cliente_{id_cliente}")
        if id_taller:
            await self.send_personal_message(message, f"taller_{id_taller}")

manager = ConnectionManager()
