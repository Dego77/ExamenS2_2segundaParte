from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from sqlalchemy import func
from database import get_db
import models_shared as models
import crud

router = APIRouter(prefix="/api/admin", tags=["SuperAdmin"])

# El endpoint de setup fue ejecutado manualmente via script, se puede mantener para futuras refs o eliminar.
@router.post("/login")
def login_admin(payload: dict, db: Session = Depends(get_db)):
    correo = payload.get("correo")
    password = payload.get("password")
    
    admin = db.query(models.Admin).filter(models.Admin.correo == correo).first()
    if not admin or not crud.verify_password(password, admin.password_hash):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas para Administrador")
        
    return {
        "access_token": "fake-jwt-token-admin",
        "role": "admin",
        "user_id": admin.id_admin,
        "user_name": admin.nombre
    }

@router.get("/panel", response_class=HTMLResponse)
def get_superadmin_panel():
    html_content = """
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Panel Admin General - SegurIA</title>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
        <style>
            :root {
                --bg-main: #f3f4f6;
                --bg-sidebar: #ffffff;
                --bg-card: #ffffff;
                --primary: #4f46e5;
                --primary-hover: #4338ca;
                --text-main: #1f2937;
                --text-muted: #6b7280;
                --border-color: #e5e7eb;
                --shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            }

            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
                font-family: 'Inter', sans-serif;
            }

            body {
                background-color: var(--bg-main);
                color: var(--text-main);
                display: flex;
                height: 100vh;
                overflow: hidden;
            }

            /* SIDEBAR */
            aside {
                width: 260px;
                background-color: var(--bg-sidebar);
                border-right: 1px solid var(--border-color);
                display: flex;
                flex-direction: column;
                justify-content: space-between;
                padding: 24px;
            }

            .brand {
                font-size: 1.5rem;
                font-weight: bold;
                color: var(--primary);
                margin-bottom: 32px;
                display: flex;
                align-items: center;
                gap: 8px;
            }

            .nav-links {
                list-style: none;
                display: flex;
                flex-direction: column;
                gap: 8px;
            }

            .nav-item {
                display: flex;
                align-items: center;
                justify-content: space-between;
                padding: 12px 16px;
                border-radius: 8px;
                color: var(--text-muted);
                text-decoration: none;
                font-weight: 500;
                transition: all 0.2s;
                cursor: pointer;
            }

            .nav-item:hover, .nav-item.active {
                background-color: rgba(79, 70, 229, 0.08);
                color: var(--primary);
            }

            .nav-item.active {
                background-color: rgba(79, 70, 229, 0.1);
                font-weight: 600;
            }

            .nav-item-left {
                display: flex;
                align-items: center;
                gap: 12px;
            }

            .sidebar-footer {
                display: flex;
                flex-direction: column;
                gap: 12px;
                border-top: 1px solid var(--border-color);
                padding-top: 16px;
            }

            .footer-link {
                text-decoration: none;
                font-size: 0.9rem;
                font-weight: 500;
                padding: 8px 16px;
                border-radius: 6px;
                text-align: center;
            }

            .logout-btn {
                color: #ef4444;
                background-color: rgba(239, 68, 68, 0.05);
            }

            .home-btn {
                color: #2563eb;
                background-color: rgba(37, 99, 235, 0.05);
            }

            /* MAIN CONTENT */
            main {
                flex: 1;
                padding: 40px;
                overflow-y: auto;
            }

            .header {
                margin-bottom: 32px;
            }

            .header h1 {
                font-size: 1.875rem;
                font-weight: 700;
                color: #111827;
            }

            .header p {
                color: var(--text-muted);
                margin-top: 4px;
            }

            /* GRIDS */
            .grid-top {
                display: grid;
                grid-template-columns: repeat(3, 1fr);
                gap: 24px;
                margin-bottom: 24px;
            }

            .grid-small {
                display: grid;
                grid-template-columns: repeat(4, 1fr);
                gap: 24px;
                margin-bottom: 32px;
            }

            .grid-bottom {
                display: grid;
                grid-template-columns: repeat(2, 1fr);
                gap: 24px;
            }

            /* CARDS */
            .card {
                background-color: var(--bg-card);
                border-radius: 12px;
                padding: 24px;
                box-shadow: var(--shadow);
                border: 1px solid var(--border-color);
            }

            .card-gradient-blue {
                background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
                color: white;
            }

            .card-gradient-green {
                background: linear-gradient(135deg, #059669 0%, #047857 100%);
                color: white;
            }

            .card-title {
                font-size: 0.875rem;
                font-weight: 500;
                text-transform: uppercase;
                letter-spacing: 0.05em;
                margin-bottom: 12px;
                opacity: 0.9;
            }

            .card-value {
                font-size: 2rem;
                font-weight: 700;
                margin-bottom: 8px;
            }

            .card-subtitle {
                font-size: 0.75rem;
                opacity: 0.8;
            }

            /* SMALL CARDS */
            .card-small {
                border-left: 4px solid var(--primary);
                display: flex;
                justify-content: space-between;
                align-items: center;
            }

            .card-small-blue { border-left-color: #3b82f6; }
            .card-small-green { border-left-color: #10b981; }
            .card-small-orange { border-left-color: #f59e0b; }
            .card-small-purple { border-left-color: #8b5cf6; }

            .card-small-info h3 {
                font-size: 0.875rem;
                color: var(--text-muted);
                font-weight: 500;
            }

            .card-small-info .value {
                font-size: 1.5rem;
                font-weight: 700;
                color: #111827;
                margin-top: 4px;
            }

            .card-small-icon {
                font-size: 1.5rem;
                opacity: 0.2;
            }

            /* TABLES & LISTS */
            .section-title {
                font-size: 1.125rem;
                font-weight: 600;
                color: #111827;
                margin-bottom: 16px;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }

            .badge-count {
                background-color: rgba(16, 185, 129, 0.1);
                color: #10b981;
                padding: 4px 8px;
                border-radius: 9999px;
                font-size: 0.75rem;
                font-weight: 600;
            }

            .empty-state {
                text-align: center;
                padding: 40px 20px;
                color: var(--text-muted);
                font-size: 0.875rem;
            }

            /* UTILS */
            .text-purple { color: #6366f1; }
            .adjust-link {
                color: #6366f1;
                text-decoration: none;
                font-size: 0.75rem;
                font-weight: 600;
            }
            
            /* TABLAS */
            table {
                width: 100%;
                border-collapse: collapse;
            }
            th, td {
                padding: 12px;
                text-align: left;
                border-bottom: 1px solid var(--border-color);
                font-size: 0.875rem;
            }
            th {
                color: var(--text-muted);
                font-weight: 500;
            }
            .badge {
                padding: 4px 8px;
                border-radius: 6px;
                font-size: 0.75rem;
                font-weight: 600;
            }
            .badge-pending { background: #fef3c7; color: #d97706; }
            .badge-approved { background: #d1fae5; color: #059669; }
            .btn-action {
                padding: 6px 12px;
                border: none;
                border-radius: 6px;
                cursor: pointer;
                font-weight: 600;
                font-size: 0.75rem;
            }
            .btn-approve { background: #10b981; color: white; margin-right: 8px;}
            .btn-approve:hover { background: #059669; }
            .btn-reject { background: #ef4444; color: white;}
            .btn-reject:hover { background: #dc2626; }
        </style>
    </head>
    <body>
        <aside>
            <div>
                <div class="brand">
                    <span>🛡️</span> SegurIA
                </div>
                <nav>
                    <ul class="nav-links">
                        <li>
                            <a class="nav-item active">
                                <div class="nav-item-left"><span>📊</span> Dashboard</div>
                            </a>
                        </li>
                        <li>
                            <a class="nav-item">
                                <div class="nav-item-left"><span>👥</span> Usuarios</div>
                                <span>↓</span>
                            </a>
                        </li>
                        <li>
                            <a class="nav-item">
                                <div class="nav-item-left"><span>🛠️</span> Talleres</div>
                                <span>↓</span>
                            </a>
                        </li>
                        <li>
                            <a class="nav-item">
                                <div class="nav-item-left"><span>⚠️</span> Incidentes</div>
                                <span>↓</span>
                            </a>
                        </li>
                        <li>
                            <a class="nav-item">
                                <div class="nav-item-left"><span>💳</span> Finanzas</div>
                                <span>↓</span>
                            </a>
                        </li>
                        <li>
                            <a class="nav-item">
                                <div class="nav-item-left"><span>❓</span> Soporte Técnico</div>
                            </a>
                        </li>
                    </ul>
                </nav>
            </div>
            
            <div class="sidebar-footer">
                <a href="#" class="footer-link logout-btn">Cerrar sesión</a>
                <a href="/" class="footer-link home-btn">Ir al Inicio</a>
            </div>
        </aside>

        <main>
            <div class="header">
                <h1>Panel Admin General</h1>
                <p>Bienvenido, Super</p>
            </div>

            <!-- GRID TOP -->
            <div class="grid-top">
                <div class="card card-gradient-blue">
                    <div class="card-title">Total Recaudado (Pagos)</div>
                    <div class="card-value" id="total-recaudado">BOB 0.00</div>
                    <div class="card-subtitle">Métrica Total</div>
                </div>
                <div class="card card-gradient-green">
                    <div class="card-title">Ganancia Plataforma (10%)</div>
                    <div class="card-value" id="ganancia-plataforma">BOB 0.00</div>
                    <div class="card-subtitle">10% de cada servicio</div>
                </div>
                <div class="card">
                    <div class="card-title text-purple">Tasa de Comisión Actual</div>
                    <div class="card-value text-purple" id="tasa-comision">10%</div>
                    <a href="#" class="adjust-link">Ajustar Tasa</a>
                </div>
            </div>

            <!-- GRID SMALL -->
            <div class="grid-small">
                <div class="card card-small card-small-blue">
                    <div class="card-small-info">
                        <h3>Talleres</h3>
                        <div class="value" id="workshops-count">0</div>
                    </div>
                    <div class="card-small-icon">🔧</div>
                </div>
                <div class="card card-small card-small-green">
                    <div class="card-small-info">
                        <h3>Especialidades</h3>
                        <div class="value" id="specialties-count">0</div>
                    </div>
                    <div class="card-small-icon">⚙️</div>
                </div>
                <div class="card card-small card-small-orange">
                    <div class="card-small-info">
                        <h3>Usuarios</h3>
                        <div class="value" id="clients-count">0</div>
                    </div>
                    <div class="card-small-icon">👥</div>
                </div>
                <div class="card card-small card-small-purple">
                    <div class="card-small-info">
                        <h3>Incidentes</h3>
                        <div class="value" id="incidents-count">0</div>
                    </div>
                    <div class="card-small-icon">🚨</div>
                </div>
            </div>

            <!-- TABLA DE VALIDACIÓN DE TALLERES -->
            <div class="card" style="margin-bottom: 24px;">
                <div class="section-title">
                    <span>🛠️ Talleres Pendientes de Validación</span>
                </div>
                <table>
                    <thead>
                        <tr>
                            <th>Taller</th>
                            <th>NIT</th>
                            <th>Dirección</th>
                            <th>Estado</th>
                            <th>Acciones</th>
                        </tr>
                    </thead>
                    <tbody id="workshops-table">
                        <!-- Dinámico -->
                    </tbody>
                </table>
            </div>

            <!-- GRID BOTTOM -->
            <div class="grid-bottom">
                <div class="card">
                    <div class="section-title">
                        <span>Especialidades Registradas</span>
                        <span class="badge-count" id="specialties-total">0 Total</span>
                    </div>
                    <div id="specialties-list">
                        <!-- Dinámico o Empty -->
                        <div class="empty-state">No hay especialidades registradas.</div>
                    </div>
                </div>
                <div class="card">
                    <div class="section-title">
                        <span>Usuarios Recientes</span>
                    </div>
                    <div id="users-list">
                        <!-- Dinámico o Empty -->
                        <div class="empty-state">Cargando usuarios...</div>
                    </div>
                </div>
            </div>
        </main>

        <script>
            async function loadData() {
                try {
                    const res = await fetch('/api/admin/metrics');
                    const data = await res.json();
                    
                    document.getElementById('clients-count').innerText = data.stats.clientes;
                    document.getElementById('workshops-count').innerText = data.stats.talleres;
                    document.getElementById('incidents-count').innerText = data.stats.incidentes;
                    document.getElementById('specialties-count').innerText = data.stats.especialidades || 0;
                    document.getElementById('specialties-total').innerText = `${data.stats.especialidades || 0} Total`;
                    
                    document.getElementById('total-recaudado').innerText = `BOB ${data.stats.total_recaudado.toFixed(2)}`;
                    document.getElementById('ganancia-plataforma').innerText = `BOB ${data.stats.ganancia_plataforma.toFixed(2)}`;
                    document.getElementById('tasa-comision').innerText = `${data.stats.tasa_comision}%`;

                    // Talleres
                    const wt = document.getElementById('workshops-table');
                    wt.innerHTML = '';
                    let pendientes = data.talleres.filter(t => t.estado_aprobacion === 'Pendiente');
                    
                    if (pendientes.length === 0) {
                        wt.innerHTML = '<tr><td colspan="5" class="empty-state">No hay talleres pendientes de validación.</td></tr>';
                    } else {
                        pendientes.forEach(t => {
                            wt.innerHTML += `
                                <tr>
                                    <td>${t.razon_social}</td>
                                    <td>${t.nit}</td>
                                    <td>${t.direccion || 'No especificada'}</td>
                                    <td><span class="badge badge-pending">${t.estado_aprobacion}</span></td>
                                    <td>
                                        <button class="btn-action btn-approve" onclick="approveWorkshop(${t.id_taller})">Aprobar</button>
                                        <button class="btn-action btn-reject" onclick="rejectWorkshop(${t.id_taller})">Rechazar</button>
                                    </td>
                                </tr>
                            `;
                        });
                    }

                    // Usuarios Recientes
                    const ul = document.getElementById('users-list');
                    ul.innerHTML = '';
                    if (data.clientes.length === 0) {
                        ul.innerHTML = '<div class="empty-state">No hay usuarios registrados.</div>';
                    } else {
                        let html = '<table><thead><tr><th>Nombre</th><th>Correo</th></tr></thead><tbody>';
                        data.clientes.slice(0, 5).forEach(c => {
                            html += `<tr><td>${c.nombre_completo}</td><td>${c.correo}</td></tr>`;
                        });
                        html += '</tbody></table>';
                        ul.innerHTML = html;
                    }

                } catch (e) {
                    console.error(e);
                }
            }

            async function approveWorkshop(id) {
                await fetch(\`/api/admin/talleres/\${id}/aprobar\`, {method: 'POST'});
                loadData();
            }

            async function rejectWorkshop(id) {
                await fetch(\`/api/admin/talleres/\${id}/rechazar\`, {method: 'POST'});
                loadData();
            }

            loadData();
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content, status_code=200)

@router.get("/metrics")
def get_admin_metrics(db: Session = Depends(get_db)):
    # Capturamos métricas globales de la base maestra
    clientes_count = db.query(models.Cliente).count()
    talleres_total = db.query(models.Taller).count()
    talleres_aprobados = db.query(models.Taller).filter(models.Taller.estado_aprobacion == 'Aprobado').count()
    talleres_pendientes = db.query(models.Taller).filter(models.Taller.estado_aprobacion == 'Pendiente').count()
    incidentes_count = db.query(models.Incidente).count()
    
    especialidades_count = 0
    
    total_recaudado = db.query(func.sum(models.Pago.monto_total_cliente)).scalar() or 0.0
    ganancia_plataforma = db.query(func.sum(models.Pago.monto_comision_plataforma)).scalar() or 0.0
    
    talleres = db.query(models.Taller).all()
    clientes = db.query(models.Cliente).all()
    incidentes = db.query(models.Incidente).all()

    return {
        "stats": {
            "clientes": clientes_count,
            "talleres_total": talleres_total,
            "talleres_aprobados": talleres_aprobados,
            "talleres_pendientes": talleres_pendientes,
            "incidentes": incidentes_count,
            "especialidades": especialidades_count,
            "total_recaudado": float(total_recaudado),
            "ganancia_plataforma": float(ganancia_plataforma),
            "tasa_comision": 10.0
        },
        "talleres": [
            {
                "id_taller": t.id_taller,
                "razon_social": t.razon_social,
                "nit": t.nit,
                "direccion": t.direccion_fisica or "No especificada",
                "estado_aprobacion": t.estado_aprobacion
            } for t in talleres
        ],
        "clientes": [
            {
                "id_cliente": c.id_cliente,
                "nombre_completo": f"{c.nombres} {c.apellidos}",
                "correo": c.correo,
                "telefono": c.telefono
            } for c in clientes
        ],
        "incidentes": [
            {
                "id_incidente": i.id_incidente,
                "tipo_problema": i.tipo_problema,
                "estado": i.estado_solicitud,
                "prioridad": i.nivel_prioridad,
                "fecha": i.fecha_hora_reporte.strftime("%Y-%m-%d %H:%M") if i.fecha_hora_reporte else "N/A"
            } for i in incidentes
        ]
    }

@router.post("/talleres/{id_taller}/aprobar")
def aprobar_taller(id_taller: int, db: Session = Depends(get_db)):
    taller = db.query(models.Taller).filter(models.Taller.id_taller == id_taller).first()
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
    taller.estado_aprobacion = "Aprobado"
    # El envío de email está habilitado, las credenciales están en .env
    from utils import send_approval_email
    send_approval_email(destinatario=taller.correo, nombre_taller=taller.razon_social)
    
    # Registrar en Bitácora
    log = models.Bitacora(
        tipo_usuario="SuperAdmin",
        accion="Aprobar Taller",
        descripcion=f"El taller {taller.razon_social} (NIT: {taller.nit}) ha sido aprobado para operar en la plataforma."
    )
    db.add(log)
    
    db.commit()
    return {"message": "Taller aprobado exitosamente."}

@router.post("/talleres/{id_taller}/rechazar")
def rechazar_taller(id_taller: int, db: Session = Depends(get_db)):
    taller = db.query(models.Taller).filter(models.Taller.id_taller == id_taller).first()
    if not taller:
        raise HTTPException(status_code=404, detail="Taller no encontrado")
    taller.estado_aprobacion = "Rechazado"
    
    # Registrar en Bitácora
    log = models.Bitacora(
        tipo_usuario="SuperAdmin",
        accion="Rechazar Taller",
        descripcion=f"La solicitud del taller {taller.razon_social} (NIT: {taller.nit}) ha sido rechazada."
    )
    db.add(log)
    
    db.commit()
    return {"message": "Taller rechazado exitosamente."}

@router.get("/bitacora")
def obtener_bitacora(db: Session = Depends(get_db)):
    logs = db.query(models.Bitacora).order_by(models.Bitacora.fecha_hora.desc()).limit(50).all()
    return [
        {
            "id_log": l.id_log,
            "tipo_usuario": l.tipo_usuario,
            "accion": l.accion,
            "descripcion": l.descripcion,
            "fecha_hora": l.fecha_hora
        } for l in logs
    ]
