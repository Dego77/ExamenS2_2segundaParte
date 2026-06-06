import firebase_admin
from firebase_admin import credentials, messaging
import os

SERVICE_ACCOUNT_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "serviceAccountKey.json")

try:
    if not firebase_admin._apps:
        if os.path.exists(SERVICE_ACCOUNT_PATH):
            cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK inicializado correctamente.")
        else:
            print("⚠️ ADVERTENCIA: No se encontró 'serviceAccountKey.json'. Modo Simulación activo.")
except Exception as e:
    print(f"❌ Error inicializando Firebase: {e}")

def send_push_notification(fcm_token: str, titulo: str, mensaje: str, data: dict = None):
    """
    Envía una notificación push a un dispositivo específico mediante su FCM Token.
    """
    if not fcm_token:
        print("⚠️ No se proporcionó FCM Token. Ignorando notificación.")
        return False

    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        print(f"PUSH SIMULADO a [{fcm_token}]: {titulo} - {mensaje}")
        return True

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=titulo,
                body=mensaje,
            ),
            data=data or {},
            token=fcm_token,
        )
        response = messaging.send(message)
        print(f"✅ Notificación Push enviada con éxito. ID: {response}")
        return True
    except Exception as e:
        print(f"❌ Error enviando Push: {e}")
        return False
