# Guía de Pruebas: Offline, Cotizaciones y Pagos

Sigue estos pasos en orden para verificar que todo el sistema funciona correctamente.

---

## 1. Prueba de Backend (Swagger API)
Accede a `http://localhost:8001/docs`:
- **Cotizaciones**: Prueba el endpoint `POST /api/cotizaciones/` enviando un JSON con `id_incidente`, `id_taller`, `monto_estimado`, etc.
- **Pagos**: Prueba `POST /api/pagos/crear-sesion` y luego `POST /api/pagos/{id}/confirmar`. Verifica que tras la confirmación, el estado del incidente sea "Pagado".

---

## 2. Prueba del Panel de Taller (Frontend Angular)
- Inicia sesión con un taller (ej: `taller_test@asiscar.com`).
- **Recibir Alerta**: Crea un incidente desde Swagger o la App Móvil.
- **Cotizar**: Verás la alerta en el Dashboard. Haz clic en el botón naranja **"Cotizar"**. Ingresa un monto (ej: 100) y envía.

---

## 3. Prueba de la App Móvil (Flujo Completo)
- **Reporte**: Reporta una falla (ej: "Batería muerta").
- **Recepción**: Verás que en la pantalla de "Buscando Taller" aparece una tarjeta con el nombre del taller y el monto que enviaste en el paso anterior.
- **Aceptar y Pagar**: Presiona "Aceptar". Te llevará a la nueva pantalla de Pago. Selecciona un método y confirma.
- **Seguimiento**: Tras el pago, deberías pasar automáticamente a la pantalla de Tracking.

---

## 4. Prueba del Modo Offline (Móvil)
- Pon el celular en **Modo Avión** o apaga el Wi-Fi.
- Intenta reportar un incidente. La app dirá "Emergencia guardada localmente".
- Vuelve al Home. Verás un badge naranja indicando **"1 Emergencia Pendiente"**.
- Activa el internet y presiona el botón de sincronizar (o espera unos segundos al auto-sync). Verifica que el incidente llegue al Backend/Dashboard.
