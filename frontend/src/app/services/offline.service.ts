import { Injectable, OnDestroy } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, fromEvent, merge, Subject, takeUntil } from 'rxjs';
import { map } from 'rxjs/operators';
import { API_URL } from '../config/api.config';

/**
 * Servicio PWA Offline para la aplicación web de talleres.
 *
 * Funcionalidades:
 * - Detecta estado de conexión (online/offline)
 * - Guarda incidentes en IndexedDB cuando no hay conexión
 * - Sincroniza automáticamente al recuperar conexión
 * - Evita duplicados usando client_uuid
 * - Expone estado de sincronización para los componentes
 */

// Interfaz para emergencias guardadas offline
export interface EmergenciaOffline {
    id?: number;                // Auto-increment en IndexedDB
    client_uuid: string;        // UUID único para dedup
    id_cliente: number;
    id_vehiculo: number;
    ubicacion_latitud: number;
    ubicacion_longitud: number;
    tipo_problema: string;
    descripcion_manual: string;
    nivel_prioridad: string;
    sync_status: 'pendiente' | 'sincronizado' | 'error';
    error_message?: string;
    retry_count: number;
    created_at: string;         // ISO string
}

const DB_NAME = 'asistencia_vehicular_offline';
const DB_VERSION = 1;
const STORE_NAME = 'emergencias_pendientes';

@Injectable({
    providedIn: 'root'
})
export class OfflineService implements OnDestroy {

    // Estado de conexión
    private _isOnline = new BehaviorSubject<boolean>(navigator.onLine);
    public isOnline$ = this._isOnline.asObservable();

    // Contador de pendientes
    private _pendingCount = new BehaviorSubject<number>(0);
    public pendingCount$ = this._pendingCount.asObservable();

    // Eventos de sincronización
    private _syncEvent = new Subject<{ uuid: string; success: boolean; message: string }>();
    public syncEvent$ = this._syncEvent.asObservable();

    private db: IDBDatabase | null = null;
    private destroy$ = new Subject<void>();
    private isSyncing = false;

    constructor(private http: HttpClient) {
        this.initDB();
        this.setupConnectivityListeners();
    }

    ngOnDestroy(): void {
        this.destroy$.next();
        this.destroy$.complete();
        if (this.db) {
            this.db.close();
        }
    }

    // ──────────────────────────────────────────────
    // Conectividad
    // ──────────────────────────────────────────────

    private setupConnectivityListeners(): void {
        const online$ = fromEvent(window, 'online').pipe(map(() => true));
        const offline$ = fromEvent(window, 'offline').pipe(map(() => false));

        merge(online$, offline$)
            .pipe(takeUntil(this.destroy$))
            .subscribe((isOnline) => {
                this._isOnline.next(isOnline);
                console.log(`🌐 Estado de red: ${isOnline ? 'ONLINE' : 'OFFLINE'}`);

                if (isOnline) {
                    // Al reconectar, sincronizar pendientes automáticamente
                    this.sincronizarPendientes();
                }
            });
    }

    get isOnline(): boolean {
        return this._isOnline.value;
    }

    // ──────────────────────────────────────────────
    // IndexedDB
    // ──────────────────────────────────────────────

    private initDB(): Promise<void> {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(DB_NAME, DB_VERSION);

            request.onerror = () => {
                console.error('❌ Error al abrir IndexedDB:', request.error);
                reject(request.error);
            };

            request.onupgradeneeded = (event: IDBVersionChangeEvent) => {
                const db = (event.target as IDBOpenDBRequest).result;

                if (!db.objectStoreNames.contains(STORE_NAME)) {
                    const store = db.createObjectStore(STORE_NAME, {
                        keyPath: 'id',
                        autoIncrement: true,
                    });
                    store.createIndex('client_uuid', 'client_uuid', { unique: true });
                    store.createIndex('sync_status', 'sync_status', { unique: false });
                    console.log('✅ IndexedDB: Object store creado');
                }
            };

            request.onsuccess = () => {
                this.db = request.result;
                console.log('✅ IndexedDB inicializada');
                this.actualizarContadorPendientes();
                resolve();
            };
        });
    }

    private getStore(mode: IDBTransactionMode): IDBObjectStore {
        if (!this.db) {
            throw new Error('IndexedDB no inicializada');
        }
        const transaction = this.db.transaction([STORE_NAME], mode);
        return transaction.objectStore(STORE_NAME);
    }

    // ──────────────────────────────────────────────
    // Operaciones CRUD
    // ──────────────────────────────────────────────

    /**
     * Guarda una emergencia en IndexedDB para enviar después.
     * Genera un client_uuid para evitar duplicados.
     */
    async guardarEmergenciaOffline(data: {
        id_cliente: number;
        id_vehiculo: number;
        ubicacion_latitud: number;
        ubicacion_longitud: number;
        tipo_problema: string;
        descripcion_manual?: string;
        nivel_prioridad?: string;
    }): Promise<string> {
        const uuid = this.generateUUID();

        const emergencia: EmergenciaOffline = {
            client_uuid: uuid,
            id_cliente: data.id_cliente,
            id_vehiculo: data.id_vehiculo,
            ubicacion_latitud: data.ubicacion_latitud,
            ubicacion_longitud: data.ubicacion_longitud,
            tipo_problema: data.tipo_problema,
            descripcion_manual: data.descripcion_manual || '',
            nivel_prioridad: data.nivel_prioridad || 'Media',
            sync_status: 'pendiente',
            retry_count: 0,
            created_at: new Date().toISOString(),
        };

        return new Promise((resolve, reject) => {
            try {
                const store = this.getStore('readwrite');
                const request = store.add(emergencia);

                request.onsuccess = () => {
                    console.log(`💾 Emergencia guardada offline con UUID: ${uuid}`);
                    this.actualizarContadorPendientes();
                    resolve(uuid);
                };

                request.onerror = () => {
                    console.error('❌ Error al guardar en IndexedDB:', request.error);
                    reject(request.error);
                };
            } catch (error) {
                reject(error);
            }
        });
    }

    /**
     * Obtiene todas las emergencias pendientes de sincronización.
     */
    async obtenerPendientes(): Promise<EmergenciaOffline[]> {
        return new Promise((resolve, reject) => {
            try {
                const store = this.getStore('readonly');
                const index = store.index('sync_status');
                const request = index.getAll('pendiente');

                request.onsuccess = () => resolve(request.result);
                request.onerror = () => reject(request.error);
            } catch (error) {
                reject(error);
            }
        });
    }

    /**
     * Obtiene todas las emergencias (para mostrar historial offline).
     */
    async obtenerTodas(): Promise<EmergenciaOffline[]> {
        return new Promise((resolve, reject) => {
            try {
                const store = this.getStore('readonly');
                const request = store.getAll();

                request.onsuccess = () => resolve(request.result);
                request.onerror = () => reject(request.error);
            } catch (error) {
                reject(error);
            }
        });
    }

    /**
     * Actualiza el estado de sincronización de una emergencia.
     */
    private async actualizarEstado(
        id: number,
        status: 'sincronizado' | 'error',
        errorMessage?: string
    ): Promise<void> {
        return new Promise((resolve, reject) => {
            try {
                const store = this.getStore('readwrite');
                const getRequest = store.get(id);

                getRequest.onsuccess = () => {
                    const emergencia = getRequest.result as EmergenciaOffline;
                    if (emergencia) {
                        emergencia.sync_status = status;
                        if (errorMessage) {
                            emergencia.error_message = errorMessage;
                        }
                        if (status === 'error') {
                            emergencia.retry_count += 1;
                        }
                        const putRequest = store.put(emergencia);
                        putRequest.onsuccess = () => {
                            this.actualizarContadorPendientes();
                            resolve();
                        };
                        putRequest.onerror = () => reject(putRequest.error);
                    } else {
                        resolve();
                    }
                };

                getRequest.onerror = () => reject(getRequest.error);
            } catch (error) {
                reject(error);
            }
        });
    }

    /**
     * Elimina las emergencias ya sincronizadas.
     */
    async limpiarSincronizadas(): Promise<void> {
        return new Promise((resolve, reject) => {
            try {
                const store = this.getStore('readwrite');
                const index = store.index('sync_status');
                const request = index.openCursor('sincronizado');

                request.onsuccess = (event) => {
                    const cursor = (event.target as IDBRequest<IDBCursorWithValue>).result;
                    if (cursor) {
                        cursor.delete();
                        cursor.continue();
                    } else {
                        this.actualizarContadorPendientes();
                        resolve();
                    }
                };

                request.onerror = () => reject(request.error);
            } catch (error) {
                reject(error);
            }
        });
    }

    // ──────────────────────────────────────────────
    // Sincronización
    // ──────────────────────────────────────────────

    /**
     * Sincroniza todas las emergencias pendientes con el backend.
     * Se llama automáticamente al reconectar, o manualmente.
     */
    async sincronizarPendientes(): Promise<void> {
        if (this.isSyncing) {
            console.log('⏳ Sincronización ya en curso...');
            return;
        }

        if (!this.isOnline) {
            console.log('📡 Sin conexión, sincronización aplazada');
            return;
        }

        this.isSyncing = true;
        console.log('🔄 Iniciando sincronización de emergencias pendientes...');

        try {
            const pendientes = await this.obtenerPendientes();

            if (pendientes.length === 0) {
                console.log('✅ No hay emergencias pendientes');
                this.isSyncing = false;
                return;
            }

            console.log(`📤 Sincronizando ${pendientes.length} emergencia(s)...`);

            for (const emergencia of pendientes) {
                // Máximo 5 reintentos
                if (emergencia.retry_count >= 5) {
                    console.warn(`⚠️ Emergencia ${emergencia.client_uuid} excedió máximo de reintentos`);
                    continue;
                }

                try {
                    await this.enviarAlBackend(emergencia);

                    await this.actualizarEstado(emergencia.id!, 'sincronizado');

                    this._syncEvent.next({
                        uuid: emergencia.client_uuid,
                        success: true,
                        message: 'Emergencia sincronizada exitosamente',
                    });

                    console.log(`✅ Emergencia ${emergencia.client_uuid} sincronizada`);
                } catch (error: any) {
                    const errorMsg = error?.message || 'Error desconocido';

                    // Si el backend devuelve 409 (duplicado), marcar como sincronizado
                    if (error?.status === 409) {
                        await this.actualizarEstado(emergencia.id!, 'sincronizado');
                        console.log(`♻️ Emergencia ${emergencia.client_uuid} ya existía en el servidor`);
                        this._syncEvent.next({
                            uuid: emergencia.client_uuid,
                            success: true,
                            message: 'Emergencia ya registrada en el servidor',
                        });
                    } else {
                        await this.actualizarEstado(emergencia.id!, 'error', errorMsg);
                        console.error(`❌ Error sincronizando ${emergencia.client_uuid}:`, errorMsg);
                        this._syncEvent.next({
                            uuid: emergencia.client_uuid,
                            success: false,
                            message: errorMsg,
                        });
                    }
                }
            }
        } catch (error) {
            console.error('❌ Error general en sincronización:', error);
        } finally {
            this.isSyncing = false;
        }
    }

    /**
     * Envía una emergencia al backend via HTTP.
     */
    private enviarAlBackend(emergencia: EmergenciaOffline): Promise<any> {
        const formData = new FormData();
        formData.append('id_cliente', emergencia.id_cliente.toString());
        formData.append('id_vehiculo', emergencia.id_vehiculo.toString());
        formData.append('ubicacion_latitud', emergencia.ubicacion_latitud.toString());
        formData.append('ubicacion_longitud', emergencia.ubicacion_longitud.toString());
        formData.append('descripcion_manual', emergencia.descripcion_manual);
        formData.append('client_uuid', emergencia.client_uuid);

        return new Promise((resolve, reject) => {
            this.http.post(`${API_URL}/incidentes/reportar`, formData).subscribe({
                next: (response) => resolve(response),
                error: (error) => reject(error),
            });
        });
    }

    // ──────────────────────────────────────────────
    // Utilidades
    // ──────────────────────────────────────────────

    private async actualizarContadorPendientes(): Promise<void> {
        try {
            const pendientes = await this.obtenerPendientes();
            this._pendingCount.next(pendientes.length);
        } catch {
            // Si IndexedDB no está lista aún, ignorar
        }
    }

    private generateUUID(): string {
        // Generar UUID v4 compatible con navegadores sin crypto.randomUUID
        if (typeof crypto !== 'undefined' && crypto.randomUUID) {
            return crypto.randomUUID();
        }
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
            const r = (Math.random() * 16) | 0;
            const v = c === 'x' ? r : (r & 0x3) | 0x8;
            return v.toString(16);
        });
    }
}
