import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { API_URL } from '../../config/api.config';

@Component({
  selector: 'app-admin-dashboard',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './admin-dashboard.html',
  styleUrl: './admin-dashboard.css'
})
export class AdminDashboard implements OnInit {
  adminName: string = 'Administrador';
  currentTab: string = 'dashboard';
  stats: any = {
    clientes: 0,
    talleres_total: 0,
    talleres_aprobados: 0,
    talleres_pendientes: 0,
    incidentes: 0,
    especialidades: 0,
    total_recaudado: 0.0,
    ganancia_plataforma: 0.0
  };
  talleres: any[] = [];
  clientes: any[] = [];
  incidentes: any[] = [];
  historialAcciones: any[] = [];

  constructor(private router: Router, private cdr: ChangeDetectorRef) { }

  ngOnInit() {
    const token = localStorage.getItem('admin_token');
    if (!token) {
      this.router.navigate(['/admin-login']);
      return;
    }
    this.adminName = localStorage.getItem('admin_name') || 'SuperAdmin';
    this.loadMetrics();
    this.loadBitacora();
  }

  changeTab(tab: string) {
    this.currentTab = tab;
    this.cdr.detectChanges();
  }

  async loadMetrics() {
    try {
      const response = await fetch(`${API_URL}/admin/metrics`);
      if (response.ok) {
        const data = await response.json();
        this.stats = data.stats;
        this.talleres = data.talleres;
        this.clientes = data.clientes;
        this.incidentes = data.incidentes;
        this.cdr.detectChanges();
      }
    } catch (e) {
      console.error('Error cargando métricas maestras:', e);
    }
  }

  procesandoId: number | null = null;

  async loadBitacora() {
    try {
      const response = await fetch(`${API_URL}/admin/bitacora`);
      if (response.ok) {
        this.historialAcciones = await response.json();
      }
    } catch (e) {
      console.error('Error cargando bitácora:', e);
    }
  }

  async aprobarTaller(id: number) {
    if (this.procesandoId) return;
    this.procesandoId = id;
    const adminId = localStorage.getItem('admin_id') || '';
    try {
      const response = await fetch(`${API_URL}/admin/talleres/${id}/aprobar?admin_id=${adminId}`, {
        method: 'POST'
      });
      if (response.ok) {
        alert('✅ ¡Taller aprobado exitosamente!');
        this.loadMetrics();
        this.loadBitacora();
      }
    } catch (e) {
      console.error('Error aprobando taller:', e);
      alert('❌ Error al aprobar taller.');
    } finally {
      this.procesandoId = null;
      this.cdr.detectChanges();
    }
  }

  async rechazarTaller(id: number) {
    if (this.procesandoId) return;
    this.procesandoId = id;
    const adminId = localStorage.getItem('admin_id') || '';
    try {
      const response = await fetch(`${API_URL}/admin/talleres/${id}/rechazar?admin_id=${adminId}`, {
        method: 'POST'
      });
      if (response.ok) {
        alert('✅ ¡Solicitud de taller rechazada!');
        this.loadMetrics();
        this.loadBitacora();
      }
    } catch (e) {
      console.error('Error rechazando taller:', e);
      alert('❌ Error al rechazar taller.');
    } finally {
      this.procesandoId = null;
      this.cdr.detectChanges();
    }
  }

  cerrarSesion() {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_name');
    localStorage.removeItem('admin_id');
    this.router.navigate(['/admin-login']);
  }
}
