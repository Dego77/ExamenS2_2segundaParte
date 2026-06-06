import os
from google import genai
from typing import Dict, Any
import json
import re

# Cargar la API Key desde el entorno
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

class AIService:
    @staticmethod
    def analizar_incidente(audio_path: str, foto_path: str, descripcion_texto: str) -> Dict[str, Any]:
        """
        Envía los datos multimodales (Audio, Foto, Texto) a Gemini para 
        determinar la categoría del problema y nivel de urgencia.
        Genera dos mensajes distintos: uno empático para el conductor (diagnostico_ia) 
        y uno técnico para el taller (diagnostico_taller).
        """
        if not GEMINI_API_KEY:
            # Fallback simulado por si no hay API Key configurada todavía
            return {
                "categoria": "Mecánica General",
                "urgencia": "Media",
                "diagnostico_ia": "Simulado: No te preocupes, parece ser un problema con la batería. Recibirás cotizaciones pronto.",
                "diagnostico_taller": "Simulado: Problema en sistema de arranque o batería. Se requiere multímetro y cables.",
                "especialidad_requerida": "Electricista / Mecánico"
            }
        
        try:
            # Inicializar el nuevo SDK de Google GenAI
            client = genai.Client(api_key=GEMINI_API_KEY)
            
            contents = []
            
            # 1. Agregar descripción de texto
            prompt = (
                "Actúa como un experto mecánico automotriz. Analiza los siguientes datos de una emergencia vehicular "
                "(que pueden incluir texto, una imagen o foto adjunta del problema/tablero, y/o un audio descriptivo) "
                "y responde únicamente en formato JSON con la siguiente estructura exacta:\n"
                "{\n"
                '  "categoria": "Motor | Eléctrico | Frenos | Llantas | Suspensión | Otro",\n'
                '  "urgencia": "Alta | Media | Baja",\n'
                '  "diagnostico_ia": "Mensaje empático, claro y NADA técnico dirigido al conductor. Debe ser tranquilizador. Ej: \'No te preocupes, parece ser un problema menor de batería. Los talleres enviarán sus cotizaciones pronto.\'",\n'
                '  "diagnostico_taller": "Resumen técnico estructurado y directo para el Taller. Causas probables, fallas detectadas y lista de herramientas sugeridas que el mecánico debe llevar. Ej: \'Fallo en el alternador. Llevar multímetro y batería de repuesto.\'",\n'
                '  "especialidad_requerida": "Mecánico general, Electricista, etc."\n'
                "}\n\n"
                "Reglas para asignar 'urgencia':\n"
                "- Alta: Si compromete la seguridad inmediata o hay peligro físico (ej: fallan frenos, humo/fuego).\n"
                "- Media: El auto está varado pero el usuario no corre peligro (ej: batería muerta, llanta pinchada).\n"
                "- Baja: El auto funciona pero tiene ruidos o averías menores (ej: aire acondicionado).\n\n"
                "IMPORTANTE: Presta extrema atención a la imagen y/o audio adjunto (si existen). "
                "SÍNTESIS MULTIMODAL: UNIFICA todos los datos proporcionados (Foto, Audio y Texto) para dar un diagnóstico lógico.\n\n"
                f"Texto del usuario: {descripcion_texto if descripcion_texto else 'Sin texto descriptivo'}"
            )
            contents.append(prompt)
            
            # 2. Agregar Foto si existe
            if foto_path and os.path.exists(foto_path):
                img_file = client.files.upload(file=foto_path)
                contents.append(img_file)
                
            # 3. Agregar Audio si existe
            if audio_path and os.path.exists(audio_path):
                audio_file = client.files.upload(file=audio_path)
                contents.append(audio_file)

            # Generar respuesta
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=contents
            )
            
            text_response = response.text
            json_match = re.search(r'\{.*\}', text_response, re.DOTALL)
            if json_match:
                data = json.loads(json_match.group(0))
                # Validar que existan las llaves
                if "diagnostico_taller" not in data:
                    data["diagnostico_taller"] = data.get("diagnostico_ia", "Sin diagnóstico técnico disponible.")
                return data
            else:
                return {
                    "categoria": "Otro",
                    "urgencia": "Media",
                    "diagnostico_ia": "Hemos recibido tu reporte. En breve recibirás asistencia.",
                    "diagnostico_taller": text_response,
                    "especialidad_requerida": "Mecánico General"
                }

        except Exception as e:
            print(f"Error llamando a la API de Gemini: {e}")
            return {
                "categoria": "Otro",
                "urgencia": "Alta",
                "diagnostico_ia": "Tuvimos un problema procesando los datos con IA, pero tu reporte ha sido enviado a los talleres.",
                "diagnostico_taller": f"Error procesando la IA: {e}",
                "especialidad_requerida": "Mecánico General"
            }
