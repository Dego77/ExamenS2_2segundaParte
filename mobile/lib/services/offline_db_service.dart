import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Servicio de base de datos local SQLite para almacenar
/// emergencias cuando no hay conexión a internet.
/// Funciona como un "buzón de salida": guarda temporalmente
/// y se vacía cuando se sincroniza con el backend (PostgreSQL).
class OfflineDbService {
  static Database? _database;

  static const String _dbName = 'emergencias_offline.db';
  static const String _tableName = 'emergencias_pendientes';
  static const int _dbVersion = 1;

  /// Obtener la instancia de la base de datos (singleton)
  static Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_uuid TEXT NOT NULL UNIQUE,
            id_cliente INTEGER NOT NULL,
            id_vehiculo INTEGER NOT NULL,
            ubicacion_latitud REAL NOT NULL,
            ubicacion_longitud REAL NOT NULL,
            descripcion_manual TEXT DEFAULT '',
            audio_path TEXT,
            foto_path TEXT,
            sync_status TEXT DEFAULT 'pendiente',
            error_message TEXT,
            retry_count INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Insertar una emergencia para enviar después
  static Future<int> insertarEmergencia({
    required String clientUuid,
    required int idCliente,
    required int idVehiculo,
    required double latitud,
    required double longitud,
    String? descripcion,
    String? audioPath,
    String? fotoPath,
  }) async {
    final db = await database;
    return await db.insert(_tableName, {
      'client_uuid': clientUuid,
      'id_cliente': idCliente,
      'id_vehiculo': idVehiculo,
      'ubicacion_latitud': latitud,
      'ubicacion_longitud': longitud,
      'descripcion_manual': descripcion ?? '',
      'audio_path': audioPath,
      'foto_path': fotoPath,
      'sync_status': 'pendiente',
      'retry_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Obtener emergencias pendientes de sincronización
  static Future<List<Map<String, dynamic>>> obtenerPendientes() async {
    final db = await database;
    return await db.query(
      _tableName,
      where: 'sync_status = ?',
      whereArgs: ['pendiente'],
    );
  }

  /// Obtener todas las emergencias (para mostrar en UI)
  static Future<List<Map<String, dynamic>>> obtenerTodas() async {
    final db = await database;
    return await db.query(_tableName, orderBy: 'created_at DESC');
  }

  /// Contar emergencias pendientes
  static Future<int> contarPendientes() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE sync_status = ?',
      ['pendiente'],
    );
    return result.first['count'] as int;
  }

  /// Marcar una emergencia como sincronizada
  static Future<void> marcarSincronizada(int id) async {
    final db = await database;
    await db.update(
      _tableName,
      {'sync_status': 'sincronizado'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marcar una emergencia con error
  static Future<void> marcarError(int id, String errorMessage) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE $_tableName SET sync_status = ?, error_message = ?, retry_count = retry_count + 1 WHERE id = ?',
      ['error', errorMessage, id],
    );
  }

  /// Resetear emergencias con error para reintentar (max 5 intentos)
  static Future<void> resetearParaReintento() async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE $_tableName SET sync_status = ? WHERE sync_status = ? AND retry_count < 5',
      ['pendiente', 'error'],
    );
  }

  /// Eliminar emergencias ya sincronizadas
  static Future<void> limpiarSincronizadas() async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'sync_status = ?',
      whereArgs: ['sincronizado'],
    );
  }
}
