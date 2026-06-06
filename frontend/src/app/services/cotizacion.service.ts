import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { API_URL } from '../config/api.config';
import { Observable } from 'rxjs';

@Injectable({
    providedIn: 'root'
})
export class CotizacionService {
    private baseUrl = `${API_URL}/cotizaciones`;

    constructor(private http: HttpClient) { }

    enviarCotizacion(cotizacion: any): Observable<any> {
        return this.http.post(`${this.baseUrl}/`, cotizacion);
    }

    getCotizacionesIncidente(idIncidente: number): Observable<any[]> {
        return this.http.get<any[]>(`${this.baseUrl}/incidente/${idIncidente}`);
    }

    aceptarCotizacion(idCotizacion: number): Observable<any> {
        return this.http.patch(`${this.baseUrl}/${idCotizacion}/aceptar`, {});
    }

    rechazarCotizacion(idCotizacion: number): Observable<any> {
        return this.http.patch(`${this.baseUrl}/${idCotizacion}/rechazar`, {});
    }
}
