// lib/services/photo_db_service.dart
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class Foto {
  int? idFoto;
  String rutaArchivo;
  int? idAsignatura;
  String fechaCreacion;
  bool esFavorita;
  bool estaUsada;

  Foto({
    this.idFoto,
    required this.rutaArchivo,
    this.idAsignatura,
    required this.fechaCreacion,
    this.esFavorita = false,
    this.estaUsada = false,
  });

  factory Foto.fromMap(Map<String, dynamic> map) {
    return Foto(
      idFoto: map['id_foto'] as int?,
      rutaArchivo: map['ruta_archivo'],
      idAsignatura: map['id_asignatura'] as int?,
      fechaCreacion: map['fecha_creacion'],
      esFavorita: (map['es_favorita'] ?? 0) == 1,
      estaUsada: (map['esta_usada'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_foto': idFoto,
      'ruta_archivo': rutaArchivo,
      'id_asignatura': idAsignatura,
      'fecha_creacion': fechaCreacion,
      'es_favorita': esFavorita ? 1 : 0,
      'esta_usada': estaUsada ? 1 : 0,
    };
  }
}

class PhotoDBService {
  // Insertar una nueva foto
  static Future<int> insertFoto(Foto foto) async {
    final db = await DBHelper.database;
    return db.insert('fotos', foto.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Actualizar una foto
  static Future<int> updateFoto(Foto foto) async {
    final db = await DBHelper.database;
    return db.update(
      'fotos',
      foto.toMap(),
      where: 'id_foto = ?',
      whereArgs: [foto.idFoto],
    );
  }

  // Borrar una foto por su ID
  static Future<int> deleteFoto(int idFoto) async {
    final db = await DBHelper.database;
    return db.delete('fotos', where: 'id_foto = ?', whereArgs: [idFoto]);
  }

  // Obtener una foto por la rutaArchivo
  static Future<Foto?> getFotoByFilePath(String filePath) async {
    final db = await DBHelper.database;
    final maps = await db.query(
      'fotos',
      where: 'ruta_archivo = ?',
      whereArgs: [filePath],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Foto.fromMap(maps.first);
    }
    return null;
  }

  // ================== NUEVAS FUNCIONES ORDENADAS DESC =================== //

  // Todas las fotos de una asignatura, ordenadas desc por fechaCreacion
  // Si idAsig == null => “Otros”
  static Future<List<Foto>> getFotosByAsignaturaOrderedDesc(int? idAsig) async {
    final db = await DBHelper.database;
    List<Map<String, dynamic>> maps;
    if (idAsig == null) {
      maps = await db.query(
        'fotos',
        where: 'id_asignatura IS NULL',
        orderBy: 'fecha_creacion DESC',
      );
    } else {
      maps = await db.query(
        'fotos',
        where: 'id_asignatura = ?',
        whereArgs: [idAsig],
        orderBy: 'fecha_creacion DESC',
      );
    }
    return maps.map((m) => Foto.fromMap(m)).toList();
  }

  // Solo las fotos favoritas de una asignatura, ordenadas desc
  static Future<List<Foto>> getFavoriteFotosByAsignaturaOrderedDesc(int? idAsig) async {
    final db = await DBHelper.database;
    List<Map<String, dynamic>> maps;
    if (idAsig == null) {
      maps = await db.query(
        'fotos',
        where: 'es_favorita = 1 AND id_asignatura IS NULL',
        orderBy: 'fecha_creacion DESC',
      );
    } else {
      maps = await db.query(
        'fotos',
        where: 'es_favorita = 1 AND id_asignatura = ?',
        whereArgs: [idAsig],
        orderBy: 'fecha_creacion DESC',
      );
    }
    return maps.map((m) => Foto.fromMap(m)).toList();
  }
}
