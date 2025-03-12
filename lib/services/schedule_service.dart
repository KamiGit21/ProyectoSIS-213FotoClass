// lib/services/schedule_service.dart
import 'package:flutter/material.dart';
import 'subject_db_service.dart';

class ScheduleService {
  static Future<String> classifyBySchedule() async {
    final now = DateTime.now();
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
    final subjects = await SubjectDBService.getAllAsignaturas();
    for (var subject in subjects) {
      final startTime = _parseTime(subject.horarioInicio);
      final endTime = _parseTime(subject.horarioFin);
      if (_isWithinRange(currentTime, startTime, endTime)) {
        return subject.nombre;
      }
    }
    return 'Otros';
  }

  static TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static bool _isWithinRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final c = current.hour * 60 + current.minute;
    final s = start.hour * 60 + start.minute;
    final e = end.hour * 60 + end.minute;
    return c >= s && c <= e;
  }
}
