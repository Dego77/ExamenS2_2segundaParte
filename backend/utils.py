import smtplib
from email.message import EmailMessage
import os

# Configuración de credenciales SMTP (Ejemplo usando Gmail)
# En producción, estas variables deben venir de un archivo .env
SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", 587))
SMTP_USER = os.getenv("SMTP_USER", "tu_correo@gmail.com") 
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "tu_contraseña_de_aplicacion")

def send_approval_email(destinatario: str, nombre_taller: str):
    """
    Envía un correo electrónico al taller notificando que su cuenta ha sido aprobada.
    """
    smtp_user = os.getenv("SMTP_USER", "tu_correo@gmail.com")
    smtp_password = os.getenv("SMTP_PASSWORD", "tu_contraseña_de_aplicacion")
    smtp_server = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", 587))

    msg = EmailMessage()
    msg['Subject'] = '¡Tu Taller ha sido Aprobado! - AsisCar'
    msg['From'] = smtp_user
    msg['To'] = destinatario

    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6;">
            <div style="max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
                <div style="background-color: #4f46e5; color: white; padding: 20px; text-align: center;">
                    <h2>¡Bienvenido a AsisCar!</h2>
                </div>
                <div style="padding: 30px;">
                    <p>Hola <strong>{nombre_taller}</strong>,</p>
                    <p>Nos complace informarte que hemos revisado tus documentos y tu cuenta ha sido <strong>aprobada exitosamente</strong>.</p>
                    <p>A partir de este momento, tu Dashboard Operativo ha sido desbloqueado. Ya puedes:</p>
                    <ul>
                        <li>Recibir alertas de emergencias en tiempo real.</li>
                        <li>Crear cuentas para tus mecánicos.</li>
                        <li>Empezar a generar ingresos.</li>
                    </ul>
                    <div style="text-align: center; margin-top: 30px;">
                        <a href="https://asisscar.netlify.app/login" style="background-color: #4f46e5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold;">Acceder a mi Dashboard</a>
                    </div>
                </div>
                <div style="background-color: #f5f5f5; padding: 15px; text-align: center; font-size: 12px; color: #666;">
                    Este es un mensaje automático, por favor no respondas a este correo.
                </div>
            </div>
        </body>
    </html>
    """
    msg.set_content("Tu taller ha sido aprobado. Inicia sesión para acceder al dashboard.")
    msg.add_alternative(html_content, subtype='html')

    try:
        if smtp_user and smtp_password and smtp_user != "tu_correo@gmail.com":
            with smtplib.SMTP(smtp_server, smtp_port) as server:
                server.starttls()
                server.login(smtp_user, smtp_password)
                server.send_message(msg)
                print(f"Correo de aprobación enviado exitosamente a {destinatario}")
        else:
            print(f"SIMULACIÓN: Correo de aprobación enviado exitosamente a {destinatario}")
        return True
    except Exception as e:
        print(f"Error enviando correo: {e}")
        return False

def send_reset_password_email(destinatario: str, token: str):
    """
    Envía un correo electrónico con el código de verificación para restablecer la contraseña.
    """
    smtp_user = os.getenv("SMTP_USER", "tu_correo@gmail.com")
    smtp_password = os.getenv("SMTP_PASSWORD", "tu_contraseña_de_aplicacion")
    smtp_server = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", 587))

    msg = EmailMessage()
    msg['Subject'] = 'Código de Recuperación de Contraseña - AsisCar'
    msg['From'] = smtp_user
    msg['To'] = destinatario

    html_content = f"""
    <html>
        <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6;">
            <div style="max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
                <div style="background-color: #4f46e5; color: white; padding: 20px; text-align: center;">
                    <h2>Recuperación de Contraseña</h2>
                </div>
                <div style="padding: 30px;">
                    <p>Hola,</p>
                    <p>Has solicitado restablecer tu contraseña en la plataforma AsisCar.</p>
                    <p>Utiliza el siguiente código de verificación para continuar con el proceso:</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <span style="background-color: #f3f4f6; color: #4f46e5; font-size: 32px; font-weight: bold; letter-spacing: 5px; padding: 10px 20px; border-radius: 8px; border: 1px dashed #4f46e5;">{token}</span>
                    </div>
                    <p>Este código es válido por 15 minutos. Si no solicitaste este cambio, puedes ignorar este correo de forma segura.</p>
                </div>
                <div style="background-color: #f5f5f5; padding: 15px; text-align: center; font-size: 12px; color: #666;">
                    Este es un mensaje automático, por favor no respondas a este correo.
                </div>
            </div>
        </body>
    </html>
    """
    msg.set_content(f"Tu código de recuperación es: {token}")
    msg.add_alternative(html_content, subtype='html')

    try:
        if smtp_user and smtp_password and smtp_user != "tu_correo@gmail.com":
            with smtplib.SMTP(smtp_server, smtp_port) as server:
                server.starttls()
                server.login(smtp_user, smtp_password)
                server.send_message(msg)
                print(f"Correo de recuperación enviado exitosamente a {destinatario}")
        else:
            print(f"SIMULACIÓN: Correo de recuperación enviado a {destinatario}. Token: {token}")
        return True
    except Exception as e:
        print(f"Error enviando correo de recuperación: {e}")
        return False
