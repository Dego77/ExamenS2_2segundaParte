import math
from sqlalchemy.orm import Session
import models_shared as models

def calcular_distancia(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calcula la distancia entre dos puntos geográficos en kilómetros usando la fórmula de Haversine.
    """
    R = 6371.0  # Radio de la Tierra en kilómetros
    
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi / 2.0) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * \
        math.sin(delta_lambda / 2.0) ** 2
        
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distancia = R * c
    return distancia

def buscar_talleres_cercanos(db: Session, lat_cliente: float, lon_cliente: float, radio_km: float = 10.0) -> list:
    """
    Filtra y devuelve todos los talleres aprobados ignorando geolocalización para pruebas directas del usuario.
    """
    talleres_aprobados = db.query(models.Taller).filter(models.Taller.estado_aprobacion == 'Aprobado').all()
    talleres_coincidentes = []
    
    for taller in talleres_aprobados:
        talleres_coincidentes.append({
            "id_taller": taller.id_taller,
            "razon_social": taller.razon_social,
            "distancia": 1.5, # Valor estático de test
            "telefono": taller.telefono_taller,
            "latitud": taller.ubicacion_base_latitud,
            "longitud": taller.ubicacion_base_longitud
        })
        
    return talleres_coincidentes
