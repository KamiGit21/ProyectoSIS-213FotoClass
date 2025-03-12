// lib/screens/tab_photos_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/photo_db_service.dart';
import '../services/photo_service.dart';
import '../services/subject_db_service.dart';
import 'photo_preview_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class TabPhotosScreen extends StatefulWidget {
  final String subjectName;
  final bool isFavoriteTab; // true: pestaña de Favoritos, false: Principal
  const TabPhotosScreen({
    Key? key,
    required this.subjectName,
    required this.isFavoriteTab,
  }) : super(key: key);

  @override
  State<TabPhotosScreen> createState() => _TabPhotosScreenState();
}

class _TabPhotosScreenState extends State<TabPhotosScreen> {
  late Future<List<File>> _futurePhotos;
  // Mapa para cachear en vivo el estado "usado" de cada foto (opcional)
  final Map<String, bool> _usedStatusMap = {};

  // Variables para selección múltiple
  bool _multiSelectMode = false;
  final Set<String> _selectedPhotoPaths = {};

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  void _loadPhotos() {
    if (widget.isFavoriteTab) {
      _futurePhotos = _loadFavoritePhotos();
    } else {
      _futurePhotos = _loadMainPhotos();
    }
  }

  /// Para la pestaña Principal: consulta la BD para obtener todas las fotos de la asignatura
  Future<List<File>> _loadMainPhotos() async {
    int? idAsig;
    if (widget.subjectName != 'Otros') {
      final asigs = await SubjectDBService.getAllAsignaturas();
      final match = asigs.firstWhere(
        (a) => a.nombre == widget.subjectName,
        orElse: () => Asignatura(nombre: 'Otros', horarioInicio: '00:00', horarioFin: '00:00'),
      );
      idAsig = (match.nombre == 'Otros') ? null : match.idAsignatura;
    }
    final fotos = await PhotoDBService.getFotosByAsignaturaOrderedDesc(idAsig);
    return fotos.map((foto) => File(foto.rutaArchivo)).toList();
  }

  /// Para la pestaña Favoritas: obtiene solo las fotos marcadas como favoritas de la BD
  Future<List<File>> _loadFavoritePhotos() async {
    int? idAsig;
    if (widget.subjectName != 'Otros') {
      final asigs = await SubjectDBService.getAllAsignaturas();
      final match = asigs.firstWhere(
        (a) => a.nombre == widget.subjectName,
        orElse: () => Asignatura(nombre: 'Otros', horarioInicio: '00:00', horarioFin: '00:00'),
      );
      idAsig = (match.nombre == 'Otros') ? null : match.idAsignatura;
    }
    final favFotos = await PhotoDBService.getFavoriteFotosByAsignaturaOrderedDesc(idAsig);
    return favFotos.map((foto) => File(foto.rutaArchivo)).toList();
  }

  // Abre la previsualización; en modo normal abre la foto, y en modo de selección alterna la selección
  void _openPhotoPreview(String filePath) async {
    if (_multiSelectMode) {
      setState(() {
        if (_selectedPhotoPaths.contains(filePath)) {
          _selectedPhotoPaths.remove(filePath);
          if (_selectedPhotoPaths.isEmpty) _multiSelectMode = false;
        } else {
          _selectedPhotoPaths.add(filePath);
        }
      });
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoPreviewScreen(
            filePath: filePath,
            subjectName: widget.subjectName,
            onUsedChange: (fp, used) {
              setState(() {
                _usedStatusMap[fp] = used;
              });
            },
            onFavoriteChange: (fp, fav) {
              setState(() {
                // Al cambiar favorito, recargamos la lista para reflejar el cambio
                _loadPhotos();
              });
            },
          ),
        ),
      );
      if (result == true) {
        setState(() {
          _usedStatusMap.clear();
          _loadPhotos();
        });
      }
    }
  }

  // Activa el modo de selección múltiple
  void _activateMultiSelect(String filePath) {
    setState(() {
      _multiSelectMode = true;
      _selectedPhotoPaths.add(filePath);
    });
  }

  // Acciones en modo de selección múltiple
  Future<void> _multiSelectActionFavorite() async {
    // Para cada foto seleccionada, actualiza la BD para marcar como favorito (sin mover físicamente)
    for (final path in _selectedPhotoPaths) {
      final foto = await PhotoDBService.getFotoByFilePath(path);
      if (foto != null && !foto.esFavorita) {
        foto.esFavorita = true;
        await PhotoDBService.updateFoto(foto);
      }
    }
    setState(() {
      _multiSelectMode = false;
      _selectedPhotoPaths.clear();
      _loadPhotos();
    });
  }

  Future<void> _multiSelectActionDelete() async {
    for (final path in _selectedPhotoPaths) {
      await PhotoService.deletePhoto(path);
    }
    setState(() {
      _multiSelectMode = false;
      _selectedPhotoPaths.clear();
      _loadPhotos();
    });
  }

  Future<void> _multiSelectActionMove() async {
    // Muestra diálogo para seleccionar carpeta destino
    final subjects = (await SubjectDBService.getAllAsignaturas()).map((s) => s.nombre).toList();
    if (!subjects.contains('Otros')) subjects.insert(0, 'Otros');
    String? chosenSubject;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mover fotos a...'),
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
    if (chosenSubject != null) {
      for (final path in _selectedPhotoPaths) {
        final newPath = await PhotoService.movePhoto(path, chosenSubject!);
        if (newPath != null) {
          final foto = await PhotoDBService.getFotoByFilePath(path);
          if (foto != null) {
            // Actualizar la asignatura de la foto
            final allAsigs = await SubjectDBService.getAllAsignaturas();
            final newAsig = allAsigs.firstWhere(
              (a) => a.nombre == chosenSubject,
              orElse: () => Asignatura(nombre: 'Otros', horarioInicio: '00:00', horarioFin: '00:00'),
            );
            foto.rutaArchivo = newPath;
            foto.idAsignatura = (newAsig.nombre == 'Otros') ? null : newAsig.idAsignatura;
            await PhotoDBService.updateFoto(foto);
          }
        }
      }
      setState(() {
        _multiSelectMode = false;
        _selectedPhotoPaths.clear();
        _loadPhotos();
      });
    }
  }

  Future<void> _multiSelectActionShare() async {
    // Recopila todas las rutas de las fotos seleccionadas
    final files = _selectedPhotoPaths.map((path) => XFile(path)).toList();
    try {
      await Share.shareXFiles(files, text: 'Mira estas fotos de mis apuntes');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    }
    // Después de compartir, no forzamos salida del modo selección (puedes decidirlo)
  }

  // Barra de acciones para el modo de selección múltiple
  PreferredSizeWidget _buildMultiSelectAppBar() {
    return AppBar(
      title: Text('${_selectedPhotoPaths.length} seleccionadas'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          setState(() {
            _multiSelectMode = false;
            _selectedPhotoPaths.clear();
          });
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.star),
          onPressed: _multiSelectActionFavorite,
          tooltip: 'Marcar como favoritos',
        ),
        IconButton(
          icon: const Icon(Icons.drive_file_move),
          onPressed: _multiSelectActionMove,
          tooltip: 'Mover a otra carpeta',
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _multiSelectActionShare,
          tooltip: 'Compartir',
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: _multiSelectActionDelete,
          tooltip: 'Eliminar',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _multiSelectMode
          ? _buildMultiSelectAppBar()
          : null, // Si no está en modo selección, se usa la AppBar definida en SubjectDetailScreen.
      body: FutureBuilder<List<File>>(
        future: _futurePhotos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar fotos: ${snapshot.error}'));
          }
          final files = snapshot.data ?? [];
          if (files.isEmpty) {
            return const Center(child: Text('No hay fotos en esta carpeta.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return FutureBuilder<Foto?>(
                future: PhotoDBService.getFotoByFilePath(file.path),
                builder: (context, snapFoto) {
                  bool used = false;
                  if (snapFoto.hasData && snapFoto.data != null) {
                    used = snapFoto.data!.estaUsada;
                  }
                  // Si tenemos override en el mapa, lo usamos
                  if (_usedStatusMap.containsKey(file.path)) {
                    used = _usedStatusMap[file.path]!;
                  }
                  final isSelected = _selectedPhotoPaths.contains(file.path);
                  return GestureDetector(
                    onLongPress: () {
                      if (!_multiSelectMode) {
                        _activateMultiSelect(file.path);
                      }
                    },
                    onTap: () => _openPhotoPreview(file.path),
                    child: Stack(
                      children: [
                        Opacity(
                          opacity: used ? 0.5 : 1.0,
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                const Icon(Icons.broken_image),
                          ),
                        ),
                        if (_multiSelectMode)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected ? Colors.blue : Colors.white,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
