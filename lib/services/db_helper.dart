// lib/services/db_helper.dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Database? _database;
  static const _dbName = 'fotoclass.db';
  static const _dbVersion = 1;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE asignaturas (
        id_asignatura INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_asignatura TEXT NOT NULL,
        horario_inicio TEXT NOT NULL,
        horario_fin TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE fotos (
        id_foto INTEGER PRIMARY KEY AUTOINCREMENT,
        ruta_archivo TEXT NOT NULL,
        id_asignatura INTEGER,
        fecha_creacion TEXT NOT NULL,
        es_favorita INTEGER NOT NULL DEFAULT 0,
        esta_usada INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (id_asignatura) REFERENCES asignaturas (id_asignatura)
      )
    ''');
  }
}
