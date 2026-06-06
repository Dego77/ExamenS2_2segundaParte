import os
import google.generativeai as genai
from typing import Dict, Any

# Cargar la API Key desde el entorno
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Configurar el SDK de Google Generative AI
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

class AIService:
    @staticmethod
    def analizar_incidente(audio_path: str, foto_path: str, descripcion_texto: str) -> Dict[str, Any]:
        """
        Envía los datos multimodales (Audio, Foto, Texto) a Gemini 1.5 Flash para 
        determinar la categoría del problema y nivel de urgencia.
        """
        if not GEMINI_API_KEY:
            # Fallback simulado por si no hay API Key configurada todavía
            return {
                "categoria": "Mecánica General",
                "urgencia": "Media",
                "diagnostico_ia": "Simulado: Parece un problema con el sistema de arranque o batería. Se requiere revisión física.",
                "especialidad_requerida": "Electricista / Mecánico"
            }
        
        try:
            # Configurado para usar Gemini Flash Latest (Nombre oficial)
            model = genai.GenerativeModel("gemini-flash-latest")
            
            contents = []
            
            # 1. Agregar descripción de texto
            prompt = (
                "Actúa como un experto mecánico automotriz. Analiza los siguientes datos de una emergencia vehicular "
                "(que pueden incluir texto, una imagen o foto adjunta del problema/tablero, y/o un audio descriptivo) "
                "y responde únicamente en formato JSON con la siguiente estructura:\n"
                "{\n"
                '  "categoria": "Motor | Eléctrico | Frenos | Llantas | Suspensión | Otro",\n'
                '  "urgencia": "Alta | Media | Baja",\n'
                '  "diagnostico_ia": "Diagnóstico inicial de la falla basándote en TODOS los datos proporcionados (texto, imagen, audio) + consejos/herramientas recomendadas.",\n'
                '  "especialidad_requerida": "Mecánico general, Electricista, etc."\n'
                "}\n\n"
                "Reglas para asignar 'urgencia':\n"
                "- Alta: Si compromete la seguridad inmediata o hay peligro físico (ej: fallan frenos, humo/fuego).\n"
                "- Media: El auto está varado pero el usuario no corre peligro (ej: batería muerta, llanta pinchada).\n"
                "- Baja: El auto funciona pero tiene ruidos o averías menores (ej: aire acondicionado).\n\n"
                "IMPORTANTE: Presta extrema atención a la imagen y/o audio adjunto (si existen). "
                "Si la imagen muestra un tablero de instrumentos, identifica qué luces o indicadores están encendidos "
                "(por ejemplo: falta de combustible, check engine, presión de aceite, etc.) y úsalo para el diagnóstico.\n"
                "SÍNTESIS MULTIMODAL (Unificación de criterios):\n"
                "Tienes que UNIFICAR todos los datos proporcionados (Foto, Audio y Texto) para dar un diagnóstico lógico.\n"
                "1. Si el texto o audio describe un síntoma (ej: 'mi auto no se mueve') y la foto muestra la causa (ej: 'llanta reventada' o 'tablero sin gasolina'), "
                "crea un diagnóstico que conecte ambas cosas (ej: 'El cliente reporta que el auto no se mueve debido a que, según la imagen, tiene una llanta reventada').\n"
                "2. Solo si existe una contradicción directa grave, dale mayor prioridad a tu propio análisis de la FOTO y el AUDIO, mencionando la discrepancia.\n\n"
                f"Texto del usuario: {descripcion_texto if descripcion_texto else 'Sin texto descriptivo'}"
            )
            contents.append(prompt)
            
            # 2. Agregar Foto si existe
            if foto_path and os.path.exists(foto_path):
                import PIL.Image
                img = PIL.Image.open(foto_path)
                contents.append(img)
                
            # 3. Agregar Audio si existe
            if audio_path and os.path.exists(audio_path):
                audio_file = genai.upload_file(path=audio_path)
                contents.append(audio_file)

            # Generar respuesta
            response = model.generate_content(contents)
            
            import json
            import re
            
            text_response = response.text
            json_match = re.search(r'\{.*\}', text_response, re.DOTALL)
            if json_match:
                data = json.loads(json_match.group(0))
                return data
            else:
                return {
                    "categoria": "Otro",
                    "urgencia": "Media",
                    "diagnostico_ia": text_response,
                    "especialidad_requerida": "Mecánico General"
                }

        except Exception as e:
            print(f"Error llamando a la API de Gemini: {e}")
            return {
                "categoria": "Otro",
                "urgencia": "Alta",
                "diagnostico_ia": f"Error procesando la IA: {e}",
                "especialidad_requerida": "Mecánico General"
            }
