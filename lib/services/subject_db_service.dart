// lib/services/subject_db_service.dart
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class Asignatura {
  int? idAsignatura;
  String nombre;
  String horarioInicio;
  String horarioFin;

  Asignatura({
    this.idAsignatura,
    required this.nombre,
    required this.horarioInicio,
    required this.horarioFin,
  });

  factory Asignatura.fromMap(Map<String, dynamic> map) {
    return Asignatura(
      idAsignatura: map['id_asignatura'] as int?,
      nombre: map['nombre_asignatura'] as String,
      horarioInicio: map['horario_inicio'] as String,
      horarioFin: map['horario_fin'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_asignatura': idAsignatura,
      'nombre_asignatura': nombre,
      'horario_inicio': horarioInicio,
      'horario_fin': horarioFin,
    };
  }
}

class SubjectDBService {
  static Future<int> insertAsignatura(Asignatura asig) async {
    final db = await DBHelper.database;
    return await db.insert(
      'asignaturas',
      asig.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Asignatura>> getAllAsignaturas() async {
    final db = await DBHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('asignaturas');
    return maps.map((m) => Asignatura.fromMap(m)).toList();
  }

  static Future<int> updateAsignatura(Asignatura asig) async {
    final db = await DBHelper.database;
    return await db.update(
      'asignaturas',
      asig.toMap(),
      where: 'id_asignatura = ?',
      whereArgs: [asig.idAsignatura],
    );
  }

  static Future<int> deleteAsignatura(int id) async {
    final db = await DBHelper.database;
    return await db.delete(
      'asignaturas',
      where: 'id_asignatura = ?',
      whereArgs: [id],
    );
  }

  static Future<Asignatura?> getAsignaturaById(int id) async {
    final db = await DBHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'asignaturas',
      where: 'id_asignatura = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) return Asignatura.fromMap(maps.first);
    return null;
  }
}
