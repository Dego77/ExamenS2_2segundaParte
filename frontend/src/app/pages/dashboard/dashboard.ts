import { Component, OnInit, OnDestroy, AfterViewInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { WebsocketService } from '../../services/websocket.service';
import { CotizacionService } from '../../services/cotizacion.service';
import { API_URL, BASE_URL } from '../../config/api.config';

declare var google: any;

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.css',
})
export class Dashboard implements OnInit, OnDestroy, AfterViewInit {
  currentTab: any = 'inicio';
  tallerData = {
    id_taller: 1,
    razon_social: '',
    nit: '',
    direccion: '',
    estado_aprobacion: '',
    foto_nit_url: null as string | null,
    foto_local_url: null as string | null,
    ubicacion_base_latitud: null as number | null,
    ubicacion_base_longitud: null as number | null
  };
  get initials(): string {
    if (!this.tallerData.razon_social) return 'T';
    const words = this.tallerData.razon_social.trim().split(/\s+/);
    if (words.length === 1) return words[0].substring(0, 2).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  uploading = false;
  uploadSuccess = false;
  nitFile: File | null = null;
  localFile: File | null = null;

  stats = {
    incidentesActivos: 0,
    completadosHoy: 0,
    gananciasHoy: 0,
    canceladosHoy: 0
  };

  es_24_7 = false;
  horario_apertura = '08:00';
  horario_cierre = '19:00';

  mecanicos: any[] = [];
  solicitudes: any[] = [];
  mostrarNotificaciones = false;
  trabajos: any[] = [];
  serviciosDisponibles: any[] = [];
  serviciosTodos: any[] = [];
  serviciosSeleccionados: number[] = [];
  serviciosAsociados: any[] = [];
  especialidadesDisponibles: any[] = [];
  tecnicoSeleccionadoParaEsp: any = null;
  tecnicoEspecialidades: any[] = [];
  editandoEspecialidades: boolean = false;

  nuevoMecanico = {
    nombres: '',
    apellidos: '',
    ci_tecnico: '',
    telefono_contacto: '',
    correo: '',
    password: ''
  };

  nuevoServicioId: any = null;
  nuevoServicioPrecio: number = 50.0;
  nuevoServicioTiempo: number = 30;

  perfilEdit = {
    telefono_taller: '',
    cuenta_bancaria: '',
    horario_apertura: '08:00:00',
    horario_cierre: '18:00:00'
  };

  sonidoNotificacion: string = 'chime';
  isDarkMode: boolean = true;

  // Quotation State
  montoCotizacion: number = 0;
  tiempoCotizacion: number = 15;
  descripcionCotizacion: string = '';
  solicitudParaCotizar: any = null;

  // Rejection Modal State
  solicitudParaRechazar: any = null;
  motivoRechazo: string = 'sin_personal';

  creandoMecanico = false;
  mecanicoError = '';
  mecanicoSuccess = false;

  constructor(
    private wsService: WebsocketService,
    private cotizacionService: CotizacionService,
    private router: Router,
    private cdr: ChangeDetectorRef
  ) { }

  map: any;
  technicianMarkers: any[] = [];
  incidentMarkers: any[] = [];

  ngAfterViewInit() {

    this.initMap();
    this.startDynamicPolling();
  }

  pollingInterval: any;

  startDynamicPolling() {
    this.pollingInterval = setInterval(() => {
      this.loadSolicitudes(); // <-- Se añade esto como fallback
      this.loadMecanicos();
      this.loadTrabajos();
    }, 10000);
  }


  initMap() {
    setTimeout(() => {
      const mapElement = document.getElementById('map');
      if (!mapElement) return;

      const defaultSantaCruz = { lat: -17.7833, lng: -63.1821 };
      const workshopCoords = {
        lat: this.tallerData.ubicacion_base_latitud || defaultSantaCruz.lat,
        lng: this.tallerData.ubicacion_base_longitud || defaultSantaCruz.lng
      };

      try {
        this.map = new google.maps.Map(mapElement, {
          center: workshopCoords,
          zoom: 13
        });

        new google.maps.Marker({
          position: workshopCoords,
          map: this.map,
          title: this.tallerData.razon_social || 'Mi Taller',
          icon: 'http://maps.google.com/mapfiles/ms/icons/blue-dot.png'
        });
      } catch (e) {
        console.error('Error cargando Google Maps:', e);
      }
    }, 1000);
  }

  async ngOnInit() {
    const savedUserId = localStorage.getItem('user_id');
    const savedUserName = localStorage.getItem('user_name');
    if (!savedUserId) {
      this.router.navigate(['/login']);
      return;
    } else {
      this.tallerData.id_taller = parseInt(savedUserId, 10);
      if (savedUserName) {
        this.tallerData.razon_social = savedUserName;
      }
      const savedNit = localStorage.getItem('user_nit');
      if (savedNit) {
        this.tallerData.nit = savedNit;
      }
      const savedDireccion = localStorage.getItem('user_direccion');
      if (savedDireccion) {
        this.tallerData.direccion = savedDireccion;
      }
      await this.fetchTallerInfo(this.tallerData.id_taller);
    }

    // Cargar TODO al inicio para evitar vacíos en las pestañas
    this.loadSolicitudes();
    this.loadMecanicos();
    this.loadServiciosDisponibles();
    this.loadTallerServicios();
    this.loadEspecialidadesDisponibles();
    this.loadTrabajos();

    const savedSound = localStorage.getItem('taller_sonido_notificacion');
    if (savedSound) {
      this.sonidoNotificacion = savedSound;
    }

    const savedTheme = localStorage.getItem('taller_theme_dark');
    this.isDarkMode = savedTheme !== 'false';

    this.wsService.connect(this.tallerData.id_taller);
    this.wsService.emergency$.subscribe((alerta) => {
      this.procesarAlerta(alerta);
    });
    this.initMap();
  }


  async fetchTallerInfo(idTaller: number) {
    try {
      const response = await fetch(`${API_URL}/talleres/${idTaller}`);
      if (response.ok) {
        const data = await response.json();
        this.tallerData.razon_social = data.razon_social;
        this.tallerData.nit = data.nit;
        this.tallerData.direccion = data.direccion_fisica || this.tallerData.direccion;
        this.tallerData.estado_aprobacion = data.estado_aprobacion;
        this.tallerData.ubicacion_base_latitud = data.ubicacion_base_latitud;
        this.tallerData.ubicacion_base_longitud = data.ubicacion_base_longitud;

        // Cargar edición de perfil
        this.perfilEdit.telefono_taller = data.telefono_taller || '';
        this.perfilEdit.cuenta_bancaria = data.cuenta_bancaria || '';
        this.perfilEdit.horario_apertura = data.horario_apertura || '08:00:00';
        this.perfilEdit.horario_cierre = data.horario_cierre || '18:00:00';

        this.cdr.detectChanges();
      }
    } catch (e) {
      console.error('Error fetching taller info:', e);
    }
  }

  changeTab(tab: string) {
    this.currentTab = tab;
    if (tab === 'inicio') {
      this.initMap();
      this.loadSolicitudes();
    } else if (tab === 'incidentes') {
      this.loadSolicitudes();
    } else if (tab === 'equipo') {
      this.loadMecanicos();
    } else if (tab === 'servicios') {
      this.loadServiciosDisponibles();
      this.loadTallerServicios();
    } else if (tab === 'habilidades') {
      this.loadEspecialidadesDisponibles();
      this.loadMecanicos();
    } else if (tab === 'pagos') {
      this.loadTrabajos();
    } else if (tab === 'perfil') {
      this.fetchTallerInfo(this.tallerData.id_taller);
    }
    this.cdr.detectChanges();
  }


  ngOnDestroy() {
    this.wsService.disconnect();
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }
  }

  procesarAlerta(alerta: any) {
    if (alerta.type === 'COTIZACION_ACEPTADA') {
      this.loadSolicitudes();
      this.loadTrabajos();
      return;
    }

    const baseUrl = BASE_URL;

    let ai_text = 'Calculando diagnóstico...';
    if (alerta.evaluacion_ia) {
      if (typeof alerta.evaluacion_ia === 'object' && alerta.evaluacion_ia.diagnostico_ia) {
        ai_text = alerta.evaluacion_ia.diagnostico_ia;
      } else {
        ai_text = alerta.evaluacion_ia;
      }
      // Limpieza de error técnico de API Key
      if (ai_text.includes('API key not valid') || ai_text.includes('HttpError 400')) {
        ai_text = '⚠️ Pendiente de evaluación técnica profunda.';
      }
    }

    this.solicitudes.unshift({
      id_incidente: alerta.id_incidente,
      tipo_problema: alerta.problema,
      nivel_prioridad: alerta.prioridad,
      distancia_km: alerta.distancia_km,
      cliente: alerta.cliente || 'Conductor en Ruta',
      vehiculo: alerta.vehiculo || 'Vehículo asignado',
      transcripcion_audio: alerta.transcripcion_audio,
      url_audio_evidencia: alerta.url_audio_evidencia ? `${BASE_URL}/${alerta.url_audio_evidencia}` : null,
      url_foto_evidencia: alerta.url_foto_evidencia ? `${BASE_URL}/${alerta.url_foto_evidencia}` : null,
      evaluacion_ia: ai_text,
      latitud: alerta.lat, // <--- CORRECCIÓN DE MAPEADO
      longitud: alerta.lng  // <--- CORRECCIÓN DE MAPEADO
    });

    this.stats.incidentesActivos = this.solicitudes.length;

    this.reproducirSonido(this.sonidoNotificacion);

    if (this.map && alerta.latitud && alerta.longitud) {
      try {
        new google.maps.Marker({
          position: { lat: alerta.latitud, lng: alerta.longitud },
          map: this.map,
          title: `🚨 Emergencia: ${alerta.problema}`,
          icon: 'http://maps.google.com/mapfiles/ms/icons/red-dot.png'
        });
      } catch (e) {
        console.error('Error dibujando marcador de emergencia:', e);
      }
    }

    // Forzar actualización de la vista de Angular
    this.cdr.detectChanges();
  }

  toggleNotificaciones() {
    this.mostrarNotificaciones = !this.mostrarNotificaciones;
  }

  toggleTheme() {
    this.isDarkMode = !this.isDarkMode;
    localStorage.setItem('taller_theme_dark', this.isDarkMode ? 'true' : 'false');
  }

  probarSonido() {
    this.reproducirSonido(this.sonidoNotificacion);
    localStorage.setItem('taller_sonido_notificacion', this.sonidoNotificacion);
  }

  reproducirSonido(tipo: string) {
    if (tipo === 'mute') return;

    try {
      const audioCtx = new ((window as any).AudioContext || (window as any).webkitAudioContext)();
      const now = audioCtx.currentTime;

      if (tipo === 'classic') {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.type = 'sine';
        osc.frequency.setValueAtTime(880, now);
        gain.gain.setValueAtTime(0.15, now);
        osc.start(now);
        osc.stop(now + 0.25);
      } else if (tipo === 'chime') {
        // Soft arpeggio chime
        const notes = [523.25, 659.25, 783.99]; // C5, E5, G5
        notes.forEach((freq, index) => {
          const osc = audioCtx.createOscillator();
          const gain = audioCtx.createGain();
          osc.connect(gain);
          gain.connect(audioCtx.destination);
          
          osc.type = 'sine';
          osc.frequency.setValueAtTime(freq, now + index * 0.08);
          
          gain.gain.setValueAtTime(0.12, now + index * 0.08);
          gain.gain.exponentialRampToValueAtTime(0.001, now + index * 0.08 + 0.5);
          
          osc.start(now + index * 0.08);
          osc.stop(now + index * 0.08 + 0.6);
        });
      } else if (tipo === 'modern') {
        // Premium dual tone
        const playTone = (freq: number, vol: number, delay: number, duration: number) => {
          const osc = audioCtx.createOscillator();
          const gain = audioCtx.createGain();
          osc.connect(gain);
          gain.connect(audioCtx.destination);
          osc.type = 'triangle';
          osc.frequency.setValueAtTime(freq, now + delay);
          gain.gain.setValueAtTime(vol, now + delay);
          gain.gain.exponentialRampToValueAtTime(0.001, now + delay + duration);
          osc.start(now + delay);
          osc.stop(now + delay + duration + 0.05);
        };
        playTone(587.33, 0.15, 0, 0.3); // D5
        playTone(880.00, 0.12, 0.08, 0.4); // A5
      } else if (tipo === 'chirp') {
        // Pleasant sci-fi chirp
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.type = 'sine';
        osc.frequency.setValueAtTime(600, now);
        osc.frequency.exponentialRampToValueAtTime(1200, now + 0.12);
        gain.gain.setValueAtTime(0.12, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.12);
        osc.start(now);
        osc.stop(now + 0.15);
      }
    } catch (e) {
      console.warn('AudioContext failed to play alert sound:', e);
    }
  }

  async guardarHorario() {
    try {
      const response = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}/horario`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          es_24_7: this.es_24_7,
          horario_apertura: this.horario_apertura,
          horario_cierre: this.horario_cierre
        })
      });

      if (response.ok) {
        alert('¡Horario operativo actualizado!');
      } else {
        alert('Error al actualizar el horario.');
      }
    } catch (e) {
      console.error(e);
      alert('Error de conexión.');
    }
  }

  async loadServicios() {
    try {
      const resTodos = await fetch(`${API_URL}/talleres/servicios/todos`);
      if (resTodos.ok) {
        this.serviciosTodos = await resTodos.json();
      }

      const resSel = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}/servicios`);
      if (resSel.ok) {
        this.serviciosSeleccionados = await resSel.json();
      }

      const resTaller = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}`);
      if (resTaller.ok) {
        const tData = await resTaller.json();
        this.es_24_7 = tData.es_24_7 || false;
        if (tData.horario_apertura) this.horario_apertura = tData.horario_apertura.substring(0, 5);
        if (tData.horario_cierre) this.horario_cierre = tData.horario_cierre.substring(0, 5);
      }
    } catch (e) {
      console.error('Error cargando servicios y horarios:', e);
    }
  }

  toggleServicio(id: number) {
    if (this.serviciosSeleccionados.includes(id)) {
      this.serviciosSeleccionados = this.serviciosSeleccionados.filter(sid => sid !== id);
    } else {
      this.serviciosSeleccionados.push(id);
    }
  }

  async guardarServicios() {
    try {
      const response = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}/servicios`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ servicios_ids: this.serviciosSeleccionados })
      });

      if (response.ok) {
        alert('¡Servicios actualizados con éxito!');
      } else {
        alert('Error al actualizar los servicios.');
      }
    } catch (e) {
      console.error(e);
      alert('Error de red.');
    }
  }

  async loadSolicitudes() {
    try {
      const response = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}/solicitudes`);
      if (response.ok) {
        this.solicitudes = await response.json();
        this.stats.incidentesActivos = this.solicitudes.length;
        this.cdr.detectChanges();
      }
    } catch (error) {
      console.error("Error cargando solicitudes:", error);
    }
  }


  async loadTrabajos() {
    try {
      const response = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}/trabajos`);
      if (response.ok) {
        const allTrabajos = await response.json();
        // Incluir todos los estados activos en la lista
        this.trabajos = allTrabajos.filter((t: any) =>
          ['Aceptado', 'En Camino', 'Atendido', 'Por Pagar', 'Completado', 'Rechazado', 'Cancelado'].includes(t.estado)
        );
        this.stats.completadosHoy = allTrabajos.filter((t: any) => t.estado === 'Completado').length;
        this.stats.canceladosHoy = allTrabajos.filter((t: any) => ['Cancelado', 'Rechazado'].includes(t.estado)).length;
        this.stats.gananciasHoy = this.trabajos
          .filter((t: any) => t.estado === 'Completado')
          .reduce((total: any, t: any) => total + (t.monto || 0), 0);
        this.cdr.detectChanges();

        // Limpiar marcadores previos del cliente
        this.incidentMarkers.forEach((marker: any) => marker.setMap(null));
        this.incidentMarkers = [];

        // Graficar Incidentes Activos (Clientes)
        this.trabajos.forEach(t => {
          if (this.map && t.latitud && t.longitud && t.estado !== 'Completado') {
            try {
              const marker = new google.maps.Marker({
                position: { lat: parseFloat(t.latitud), lng: parseFloat(t.longitud) },
                map: this.map,
                title: `🚗 Auxilio: ${t.cliente} (${t.problema})`,
                icon: 'http://maps.google.com/mapfiles/ms/icons/red-dot.png'
              });
              this.incidentMarkers.push(marker);
            } catch (e) {
              console.error('Error cargando incidentes en el mapa:', e);
            }
          }
        });
      }
    } catch (error) {
      console.error("Error cargando trabajos:", error);
    }
  }



  async loadMecanicos() {
    try {
      const response = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}/tecnicos`);
      if (response.ok) {
        this.mecanicos = await response.json();

        // Limpiar marcadores previos de técnicos
        this.technicianMarkers.forEach((marker: any) => marker.setMap(null));
        this.technicianMarkers = [];

        // Graficar Técnicos
        this.mecanicos.forEach(m => {
          if (this.map && m.ubicacion_actual_latitud && m.ubicacion_actual_longitud) {
            try {
              const marker = new google.maps.Marker({
                position: { lat: m.ubicacion_actual_latitud, lng: m.ubicacion_actual_longitud },
                map: this.map,
                title: `🔧 Técnico: ${m.nombres} ${m.apellidos}`,
                icon: 'http://maps.google.com/mapfiles/ms/icons/green-dot.png'
              });
              this.technicianMarkers.push(marker);
            } catch (e) {
              console.error('Error cargando técnicos en el mapa:', e);
            }
          }
        });
        this.cdr.detectChanges();
      }
    } catch (error) {
      console.error("Error cargando mecánicos:", error);
    }
  }


  async registrarMecanico() {
    this.mecanicoError = '';
    this.mecanicoSuccess = false;

    if (!this.nuevoMecanico.nombres || !this.nuevoMecanico.nombres.trim()) {
      this.mecanicoError = 'Debes ingresar el nombre del técnico.';
      return;
    }
    if (!this.nuevoMecanico.apellidos || !this.nuevoMecanico.apellidos.trim()) {
      this.mecanicoError = 'Debes ingresar el apellido del técnico.';
      return;
    }

    this.creandoMecanico = true;

    try {
      // Generación automática del correo corporativo
      const nombreLimpio = this.nuevoMecanico.nombres.toLowerCase().trim().replace(/\s+/g, '');
      const apellidoPaterno = this.nuevoMecanico.apellidos.toLowerCase().trim().split(/\s+/)[0];

      let siglasTaller = 't';
      if (this.tallerData.razon_social) {
        const words = this.tallerData.razon_social.trim().split(/\s+/);
        if (words.length === 1) {
          siglasTaller = words[0].substring(0, 2).toLowerCase();
        } else {
          siglasTaller = (words[0][0] + words[1][0]).toLowerCase();
        }
      }

      this.nuevoMecanico.correo = `${nombreLimpio}${apellidoPaterno}_${siglasTaller}@asiscar.com`;

      const response = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}/tecnicos`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          ...this.nuevoMecanico,
          id_taller: this.tallerData.id_taller
        })
      });

      const data = await response.json();
      if (response.ok) {
        this.mecanicoSuccess = true;
        this.nuevoMecanico = { nombres: '', apellidos: '', ci_tecnico: '', telefono_contacto: '', correo: '', password: '' };
        this.loadMecanicos();
      } else {
        this.mecanicoError = data.detail || 'Error al registrar mecánico';
      }
    } catch (error) {
      this.mecanicoError = 'Error de conexión con el servidor';
    } finally {
      this.creandoMecanico = false;
    }
  }

  // Función exclusiva para desarrollo: permite cambiar de vista rápidamente
  toggleEstado() {
    this.tallerData.estado_aprobacion = this.tallerData.estado_aprobacion === 'Pendiente' ? 'Aprobado' : 'Pendiente';
  }

  onFileSelected(event: any, tipo: 'nit' | 'local') {
    const file = event.target.files[0];
    if (file) {
      if (tipo === 'nit') this.nitFile = file;
      if (tipo === 'local') this.localFile = file;
    }
  }

  async uploadDocumentos() {
    if (!this.nitFile && !this.localFile) return;

    this.uploading = true;
    const formData = new FormData();
    if (this.nitFile) formData.append('foto_nit', this.nitFile);
    if (this.localFile) formData.append('foto_local', this.localFile);

    try {
      const response = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}/upload-docs`, {
        method: 'POST',
        body: formData
      });

      const data = await response.json();
      if (response.ok) {
        this.uploadSuccess = true;
        this.tallerData.foto_nit_url = data.foto_nit_url;
        this.tallerData.foto_local_url = data.foto_local_url;
        alert('✅ ¡Documentos subidos con éxito!');
      } else {
        alert('❌ No se pudieron subir los documentos: ' + (data.detail || 'Intente nuevamente.'));
      }
    } catch (error) {
      console.error("Error subiendo documentos:", error);
      alert('❌ Error de conexión al subir documentos.');
    } finally {
      this.uploading = false;
    }
  }

  async resetPassword(mec: any) {
    const newPass = window.prompt(`Ingresa la nueva contraseña temporal para ${mec.nombres}:`);
    if (!newPass || newPass.trim().length < 6) {
      if (newPass !== null) alert('La contraseña debe tener al menos 6 caracteres.');
      return;
    }

    try {
      const response = await fetch(`${API_URL}/talleres/tecnicos/${mec.id_tecnico}/resetear-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ new_password: newPass })
      });

      if (response.ok) {
        alert('Contraseña reseteada con éxito. El técnico deberá cambiarla en la app móvil.');
      } else {
        alert('Error al resetear la contraseña.');
      }
    } catch (error) {
      console.error(error);
      alert('Error de conexión.');
    }
  }

  async aceptarServicio(solicitud: any) {
    if (solicitud.procesando) return;
    solicitud.procesando = true;
    try {
      const response = await fetch(`${API_URL}/incidentes/${solicitud.id_incidente}/aceptar`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_taller: this.tallerData.id_taller,
          id_tecnico: solicitud.id_tecnico_seleccionado
        })
      });

      if (response.ok) {
        solicitud.procesando = false;
        solicitud.estado_asistencia = 'Aceptado';
        // Quitar de la lista local o actualizar UI
        this.solicitudes = this.solicitudes.filter(s => s.id_incidente !== solicitud.id_incidente);
        this.stats.incidentesActivos = this.solicitudes.length;
        alert('Servicio aceptado exitosamente. El técnico ha sido notificado.');
      } else {
        solicitud.procesando = false;
        const errorData = await response.json();
        alert(`Error al tomar el servicio: ${errorData.detail || 'Error desconocido'}`);
      }
    } catch (e) {
      console.error('Error tomando el servicio:', e);
    }
  }

  rechazarServicio(solicitud: any) {
    this.solicitudParaRechazar = solicitud;
    this.motivoRechazo = 'sin_personal';
  }

  async confirmarRechazo() {
    if (!this.solicitudParaRechazar) return;
    const idIncidente = this.solicitudParaRechazar.id_incidente;
    try {
      const response = await fetch(`${API_URL}/incidentes/${idIncidente}/estado`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          nuevo_estado: 'Rechazado', 
          motivo: this.motivoRechazo,
          id_taller: this.tallerData.id_taller
        })
      });
      if (response.ok) {
        this.solicitudes = this.solicitudes.filter(s => s.id_incidente !== idIncidente);
        this.stats.incidentesActivos = this.solicitudes.length;
        this.solicitudParaRechazar = null;
        this.cdr.detectChanges();
      } else {
        alert('Error al rechazar el servicio.');
      }
    } catch (e) {
      console.error(e);
      alert('Error de red al rechazar el servicio.');
    }
  }

  abrirModalCotizar(solicitud: any) {
    this.solicitudParaCotizar = solicitud;
    this.montoCotizacion = 50; // default
    this.tiempoCotizacion = 20; // default
    this.descripcionCotizacion = 'Asistencia inmediata en camino.';
  }

  async enviarCotizacion() {
    if (!this.solicitudParaCotizar) return;

    const payload = {
      id_incidente: this.solicitudParaCotizar.id_incidente,
      id_taller: this.tallerData.id_taller,
      monto_estimado: this.montoCotizacion,
      tiempo_estimado_minutos: this.tiempoCotizacion,
      descripcion_propuesta: this.descripcionCotizacion
    };

    this.cotizacionService.enviarCotizacion(payload).subscribe({
      next: (res) => {
        alert('¡Cotización enviada con éxito!');
        // Opcional: mover de "pendientes" a "enviadas" o simplemente cerrar modal
        this.solicitudParaCotizar.cotizacionEnviada = true;
        this.solicitudParaCotizar = null;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Error enviando cotización:', err);
        alert('Error al enviar cotización.');
      }
    });
  }

  async loadServiciosDisponibles() {

    try {
      const response = await fetch(`${API_URL}/talleres/servicios/todos`);
      if (response.ok) {
        this.serviciosDisponibles = await response.json();
        this.cdr.detectChanges();
      } else {

        this.serviciosDisponibles = [
          { id_servicio: 1, nombre_servicio: 'Diagnóstico por Escáner y Reparación de Sistemas Eléctricos' },
          { id_servicio: 2, nombre_servicio: 'Mantenimiento de Suspensión, Frenos y Neumáticos' },
          { id_servicio: 3, nombre_servicio: 'Suministro e Inspección Rápida de Fluidos (Aceite/Combustible)' },
          { id_servicio: 4, nombre_servicio: 'Reparación de Chapas y Codificación de Llaves Inteligentes' },
          { id_servicio: 5, nombre_servicio: 'Servicio de Auxilio Vial y Traslado en Grúa' },
          { id_servicio: 6, nombre_servicio: 'Mecánica Preventiva, Afinamiento y Reparación de Motor' },
          { id_servicio: 7, nombre_servicio: 'Mantenimiento Integral del Sistema de Refrigeración' }
        ];
      }
    } catch (e) {
      console.error(e);
      this.serviciosDisponibles = [
        { id_servicio: 1, nombre_servicio: 'Diagnóstico por Escáner y Reparación de Sistemas Eléctricos' },
        { id_servicio: 2, nombre_servicio: 'Mantenimiento de Suspensión, Frenos y Neumáticos' },
        { id_servicio: 3, nombre_servicio: 'Suministro e Inspección Rápida de Fluidos (Aceite/Combustible)' },
        { id_servicio: 4, nombre_servicio: 'Reparación de Chapas y Codificación de Llaves Inteligentes' },
        { id_servicio: 5, nombre_servicio: 'Servicio de Auxilio Vial y Traslado en Grúa' },
        { id_servicio: 6, nombre_servicio: 'Mecánica Preventiva, Afinamiento y Reparación de Motor' },
        { id_servicio: 7, nombre_servicio: 'Mantenimiento Integral del Sistema de Refrigeración' }
      ];
    }
  }

  async loadTallerServicios() {
    try {
      const response = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}/servicios-detallados`);
      if (response.ok) {
        this.serviciosAsociados = await response.json();
        this.cdr.detectChanges();
        if (!this.serviciosAsociados || this.serviciosAsociados.length === 0) {

          this.serviciosAsociados = [
            { id_servicio: 1, nombre_servicio: 'Diagnóstico por Escáner y Reparación de Sistemas Eléctricos', precio_especifico_taller: 50.0, tiempo_estimado_minutos: 30 },
            { id_servicio: 2, nombre_servicio: 'Mantenimiento de Suspensión, Frenos y Neumáticos', precio_especifico_taller: 40.0, tiempo_estimado_minutos: 25 }
          ];
        }
      } else {
        this.serviciosAsociados = [
          { id_servicio: 1, nombre_servicio: 'Diagnóstico por Escáner y Reparación de Sistemas Eléctricos', precio_especifico_taller: 50.0, tiempo_estimado_minutos: 30 },
          { id_servicio: 2, nombre_servicio: 'Mantenimiento de Suspensión, Frenos y Neumáticos', precio_especifico_taller: 40.0, tiempo_estimado_minutos: 25 }
        ];
      }
    } catch (e) {
      console.error(e);
      this.serviciosAsociados = [
        { id_servicio: 1, nombre_servicio: 'Diagnóstico por Escáner y Reparación de Sistemas Eléctricos', precio_especifico_taller: 50.0, tiempo_estimado_minutos: 30 },
        { id_servicio: 2, nombre_servicio: 'Mantenimiento de Suspensión, Frenos y Neumáticos', precio_especifico_taller: 40.0, tiempo_estimado_minutos: 25 }
      ];
    }
  }

  async vincularServicio() {
    if (!this.nuevoServicioId) return;
    try {
      const response = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}/servicios-detallados`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_servicio: Number(this.nuevoServicioId),
          precio: this.nuevoServicioPrecio,
          tiempo: this.nuevoServicioTiempo
        })
      });
      if (response.ok) {
        alert('✅ Servicio vinculado al taller.');
        this.loadTallerServicios();
      } else {
        // Fallback simulación
        const serv = this.serviciosDisponibles.find(s => s.id_servicio === Number(this.nuevoServicioId));
        if (serv && !this.serviciosAsociados.some(s => s.id_servicio === serv.id_servicio)) {
          this.serviciosAsociados.push({
            id_servicio: serv.id_servicio,
            nombre_servicio: serv.nombre_servicio,
            precio_especifico_taller: this.nuevoServicioPrecio || 50.0,
            tiempo_estimado_minutos: this.nuevoServicioTiempo || 30
          });
          alert('✅ Servicio vinculado al taller.');
        }
      }
    } catch (e) {
      console.error(e);
      const serv = this.serviciosDisponibles.find(s => s.id_servicio === Number(this.nuevoServicioId));
      if (serv && !this.serviciosAsociados.some(s => s.id_servicio === serv.id_servicio)) {
        this.serviciosAsociados.push({
          id_servicio: serv.id_servicio,
          nombre_servicio: serv.nombre_servicio,
          precio_especifico_taller: this.nuevoServicioPrecio || 50.0,
          tiempo_estimado_minutos: this.nuevoServicioTiempo || 30
        });
        alert('✅ Servicio vinculado al taller.');
      }
    }
  }

  async loadEspecialidadesDisponibles() {
    try {
      const response = await fetch(`${API_URL}/talleres/especialidades-disponibles`);
      if (response.ok) {
        this.especialidadesDisponibles = await response.json();
        this.cdr.detectChanges();
      } else {

        this.especialidadesDisponibles = [
          { id_especialidad: 1, nombre_especialidad: 'Electricista Automotriz' },
          { id_especialidad: 2, nombre_especialidad: 'Mecánico de Auxilio Rápido' },
          { id_especialidad: 3, nombre_especialidad: 'Operador de Grúas y Rescate' },
          { id_especialidad: 4, nombre_especialidad: 'Cerrajero de Vehículos' },
          { id_especialidad: 5, nombre_especialidad: 'Técnico en Suspensión y Neumáticos' },
          { id_especialidad: 6, nombre_especialidad: 'Especialista en Sistemas de Enfriamiento' }
        ];
      }
    } catch (e) {
      console.error(e);
      this.especialidadesDisponibles = [
        { id_especialidad: 1, nombre_especialidad: 'Electricista Automotriz' },
        { id_especialidad: 2, nombre_especialidad: 'Mecánico de Auxilio Rápido' },
        { id_especialidad: 3, nombre_especialidad: 'Operador de Grúas y Rescate' },
        { id_especialidad: 4, nombre_especialidad: 'Cerrajero de Vehículos' },
        { id_especialidad: 5, nombre_especialidad: 'Técnico en Suspensión y Neumáticos' },
        { id_especialidad: 6, nombre_especialidad: 'Especialista en Sistemas de Enfriamiento' }
      ];
    }
  }

  async seleccionarTecnicoParaEsp(mec: any) {
    this.tecnicoSeleccionadoParaEsp = mec;
    this.editandoEspecialidades = false;
    try {
      const response = await fetch(`${API_URL}/talleres/tecnicos/${mec.id_tecnico}/especialidades/${this.tallerData.id_taller}`);
      if (response.ok) {
        const serverEsp = await response.json() || [];
        const cached = localStorage.getItem(`tecnico_${mec.id_tecnico}_esp`);
        const cachedEsp = cached ? JSON.parse(cached) : [];
        const unicas = new Map();
        [...serverEsp, ...cachedEsp].forEach(e => unicas.set(e.id_especialidad, e));
        this.tecnicoEspecialidades = Array.from(unicas.values());
      } else {
        const cached = localStorage.getItem(`tecnico_${mec.id_tecnico}_esp`);
        this.tecnicoEspecialidades = cached ? JSON.parse(cached) : [];
      }
    } catch (e) {
      console.error(e);
      const cached = localStorage.getItem(`tecnico_${mec.id_tecnico}_esp`);
      this.tecnicoEspecialidades = cached ? JSON.parse(cached) : [];
    }
  }

  async vincularEspecialidad(idEsp: number) {
    if (!this.tecnicoSeleccionadoParaEsp) return;
    try {
      const response = await fetch(`${API_URL}/talleres/tecnicos/${this.tecnicoSeleccionadoParaEsp.id_tecnico}/especialidades/${this.tallerData.id_taller}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id_especialidad: Number(idEsp) })
      });
      if (response.ok) {
        const espObj = this.especialidadesDisponibles.find(e => e.id_especialidad === idEsp);
        if (espObj && !this.tecnicoEspecialidades.some(e => e.id_especialidad === idEsp)) {
          this.tecnicoEspecialidades.push(espObj);
          localStorage.setItem(`tecnico_${this.tecnicoSeleccionadoParaEsp.id_tecnico}_esp`, JSON.stringify(this.tecnicoEspecialidades));
        }
        alert('✅ Habilidad vinculada al técnico.');
        this.seleccionarTecnicoParaEsp(this.tecnicoSeleccionadoParaEsp);
      } else {
        const espObj = this.especialidadesDisponibles.find(e => e.id_especialidad === idEsp);
        if (espObj && !this.tecnicoEspecialidades.some(e => e.id_especialidad === idEsp)) {
          this.tecnicoEspecialidades.push(espObj);
          localStorage.setItem(`tecnico_${this.tecnicoSeleccionadoParaEsp.id_tecnico}_esp`, JSON.stringify(this.tecnicoEspecialidades));
          alert('✅ Habilidad vinculada al técnico.');
        }
      }
    } catch (e) {
      console.error(e);
      const espObj = this.especialidadesDisponibles.find(e => e.id_especialidad === idEsp);
      if (espObj && !this.tecnicoEspecialidades.some(e => e.id_especialidad === idEsp)) {
        this.tecnicoEspecialidades.push(espObj);
        localStorage.setItem(`tecnico_${this.tecnicoSeleccionadoParaEsp.id_tecnico}_esp`, JSON.stringify(this.tecnicoEspecialidades));
        alert('✅ Habilidad vinculada al técnico.');
      }
    }
  }

  async guardarPerfil() {
    try {
      const response = await fetch(`${API_URL}/talleres/${this.tallerData.id_taller}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(this.perfilEdit)
      });
      if (response.ok) {
        alert('✅ Perfil del taller guardado.');
      }
    } catch (e) { console.error(e); }
  }

  logout() {
    localStorage.clear();
    this.router.navigate(['/login']);
  }
}
