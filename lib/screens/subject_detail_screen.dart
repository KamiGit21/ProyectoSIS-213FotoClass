// lib/screens/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/subject_db_service.dart';
import '../services/photo_service.dart';
import 'tab_photos_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final String subjectName;
  const SubjectDetailScreen({Key? key, required this.subjectName})
      : super(key: key);

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late String _subjectName;
  Asignatura? _asignatura;
  bool _isLoadingAsignatura = true;
  TabController? _tabController;

  // Contador para forzar la reconstrucción de TabPhotosScreen
  int _reloadCounter = 0;

  @override
  void initState() {
    super.initState();
    _subjectName = widget.subjectName;
    _loadAsignatura();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _loadAsignatura() async {
    final subjects = await SubjectDBService.getAllAsignaturas();
    final match = subjects.firstWhere(
      (s) => s.nombre == _subjectName,
      orElse: () =>
          Asignatura(nombre: 'Otros', horarioInicio: '00:00', horarioFin: '00:00'),
    );
    setState(() {
      _asignatura = (match.nombre == 'Otros') ? null : match;
      _isLoadingAsignatura = false;
    });
  }

  // Editar asignatura con TimePickers
  void _editSubject() {
    if (_asignatura == null) return;
    final asig = _asignatura!;
    final nameController = TextEditingController(text: asig.nombre);
    String oldName = asig.nombre;
    TimeOfDay startTime = _parseTime(asig.horarioInicio);
    TimeOfDay endTime = _parseTime(asig.horarioFin);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSB) {
          return AlertDialog(
            title: const Text('Editar Asignatura'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Nombre Asignatura'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Hora inicio: '),
                      TextButton(
                        child: Text(_formatTimeOfDay(startTime)),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: startTime,
                          );
                          if (picked != null) {
                            setStateSB(() {
                              startTime = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Hora fin: '),
                      TextButton(
                        child: Text(_formatTimeOfDay(endTime)),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: endTime,
                          );
                          if (picked != null) {
                            setStateSB(() {
                              endTime = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isEmpty) return;

                  asig.nombre = newName;
                  asig.horarioInicio = _timeOfDayToString(startTime);
                  asig.horarioFin = _timeOfDayToString(endTime);
                  await SubjectDBService.updateAsignatura(asig);

                  if (oldName != newName) {
                    await PhotoService.renameFolder(oldName, newName);
                    setState(() {
                      _subjectName = newName;
                    });
                  }
                  await _loadAsignatura();
                  setState(() {});
                  Navigator.of(ctx).pop(); // Cierra diálogo
                  Navigator.of(context).pop(true); // Notifica a HomeScreen
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _timeOfDayToString(TimeOfDay time) {
    return _formatTimeOfDay(time);
  }

  // NUEVO: Importar fotos desde la galería y asignarlas a la asignatura actual
  Future<void> _importPhotoFromGallery() async {
    // Se puede seleccionar más de una imagen
    final picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();
    if (pickedFiles == null || pickedFiles.isEmpty) return;

    int? idAsig = _asignatura?.idAsignatura;
    for (final xfile in pickedFiles) {
      await PhotoService.importPhotoToSubject(xfile.path, _subjectName, idAsig);
    }
    // Forzamos la actualización inmediata de la UI incrementando _reloadCounter
    setState(() {
      _reloadCounter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOtros = (_subjectName == 'Otros');
    return Scaffold(
      appBar: AppBar(
        title: Text('Carpeta: $_subjectName'),
        actions: [
          if (!isOtros && _asignatura != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editSubject,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Principal'),
            Tab(text: 'Favoritas'),
          ],
        ),
      ),
      // Usamos una key basada en _reloadCounter para forzar la reconstrucción de las pestañas al importar fotos
      body: _isLoadingAsignatura
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                TabPhotosScreen(
                  key: ValueKey('main-${widget.subjectName}-$_reloadCounter'),
                  subjectName: _subjectName,
                  isFavoriteTab: false,
                ),
                TabPhotosScreen(
                  key: ValueKey('fav-${widget.subjectName}-$_reloadCounter'),
                  subjectName: _subjectName,
                  isFavoriteTab: true,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _importPhotoFromGallery,
        tooltip: 'Importar fotos desde la galería',
      ),
    );
  }
}
