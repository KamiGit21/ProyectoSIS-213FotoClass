// lib/screens/photo_preview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../services/photo_db_service.dart';
import '../services/photo_service.dart';
import '../services/subject_db_service.dart';

class PhotoPreviewScreen extends StatefulWidget {
  final String filePath;
  final String subjectName;
  final Function(String filePath, bool isUsed)? onUsedChange;
  final Function(String filePath, bool isFavorite)? onFavoriteChange; // Nuevo callback

  const PhotoPreviewScreen({
    Key? key,
    required this.filePath,
    required this.subjectName,
    this.onUsedChange,
    this.onFavoriteChange, // Nuevo callback
  }) : super(key: key);

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  bool _isFavorite = false;
  bool _isUsed = false;
  String _currentFilePath = '';

  @override
  void initState() {
    super.initState();
    _currentFilePath = widget.filePath; // ruta inicial
    _loadPhotoStatus();
  }

  Future<void> _loadPhotoStatus() async {
    final foto = await PhotoDBService.getFotoByFilePath(_currentFilePath);
    if (foto != null) {
      setState(() {
        _isFavorite = foto.esFavorita;
        _isUsed = foto.estaUsada;
      });
    }
  }

  /// Marcar/desmarcar favorito: solo actualiza la BD (no mueve el archivo)
  Future<void> _toggleFavorite() async {
    final foto = await PhotoDBService.getFotoByFilePath(_currentFilePath);
    if (foto != null) {
      final newValue = !_isFavorite;
      foto.esFavorita = newValue;
      await PhotoDBService.updateFoto(foto);
      setState(() {
        _isFavorite = newValue;
      });
      // Notificar al listado para que se refresque
      widget.onFavoriteChange?.call(_currentFilePath, _isFavorite);
    }
  }

  /// Marcar/desmarcar usada: actualiza la BD y la UI (opacidad)
  Future<void> _toggleUsed() async {
    final foto = await PhotoDBService.getFotoByFilePath(_currentFilePath);
    if (foto != null) {
      final newValue = !_isUsed;
      foto.estaUsada = newValue;
      await PhotoDBService.updateFoto(foto);
      setState(() {
        _isUsed = newValue;
      });
      widget.onUsedChange?.call(_currentFilePath, newValue);
    }
  }

  Future<void> _deletePhoto() async {
  // 1) Eliminar la foto de la BD (por idFoto)
  final foto = await PhotoDBService.getFotoByFilePath(_currentFilePath);
  if (foto != null && foto.idFoto != null) {
    await PhotoDBService.deleteFoto(foto.idFoto!);
  }

  // 2) Eliminar el archivo físico
  await PhotoService.deletePhoto(_currentFilePath);

  // 3) Retornar pop(true) para notificar que hay cambio
  Navigator.of(context).pop(true);
}


  Future<void> _movePhoto() async {
    final subjects = (await SubjectDBService.getAllAsignaturas()).map((s) => s.nombre).toList();
    if (!subjects.contains('Otros')) subjects.insert(0, 'Otros');

    String? chosenSubject;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mover foto a...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: subjects.map((subjectName) {
            return ListTile(
              title: Text(subjectName),
              onTap: () {
                chosenSubject = subjectName;
                Navigator.of(ctx).pop();
              },
            );
          }).toList(),
        ),
      ),
    );

    if (chosenSubject != null && chosenSubject != widget.subjectName) {
      final newPath = await PhotoService.movePhoto(_currentFilePath, chosenSubject!);
      if (newPath != null) {
        final oldFoto = await PhotoDBService.getFotoByFilePath(_currentFilePath);
        if (oldFoto != null) {
          final allAsigs = await SubjectDBService.getAllAsignaturas();
          final newAsig = allAsigs.firstWhere(
            (a) => a.nombre == chosenSubject,
            orElse: () => Asignatura(nombre: 'Otros', horarioInicio: '00:00', horarioFin: '00:00'),
          );
          oldFoto.rutaArchivo = newPath;
          oldFoto.idAsignatura = (newAsig.nombre == 'Otros') ? null : newAsig.idAsignatura;
          await PhotoDBService.updateFoto(oldFoto);
          setState(() {
            _currentFilePath = newPath;
          });
        }
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _sharePhoto() async {
    try {
      await Share.shareXFiles(
        [XFile(_currentFilePath)],
        text: 'Mira esta foto de mis apuntes',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir la foto: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(_currentFilePath);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previsualización'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePhoto,
          ),
          IconButton(
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: Icon(_isUsed ? Icons.check_box : Icons.check_box_outline_blank),
            onPressed: _toggleUsed,
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_move),
            onPressed: _movePhoto,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deletePhoto,
          ),
        ],
      ),
      body: Center(
        child: Opacity(
          opacity: _isUsed ? 0.5 : 1.0,
          child: Image.file(file, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
