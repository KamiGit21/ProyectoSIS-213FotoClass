import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foto_class/screens/subject_detail_screen.dart';
import '../services/photo_service.dart';
import '../services/permission_service.dart';
import '../services/subject_db_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _message = "Presiona el botón para tomar una foto";
  bool _isDarkMode = false;
  
  @override
  void initState() {
    super.initState();
    PermissionService.requestPermissions();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = value;
    });
    await prefs.setBool('isDarkMode', value);
  }
  
  Future<void> _takePhoto() async {
    final result = await PhotoService.takeAndClassifyPhoto();
    setState(() {
      _message = result;
    });
  }

  void _openSubjectDetail(String subjectName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectDetailScreen(subjectName: subjectName),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }
  
  void _showAddSubjectDialog() {
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 9, minute: 0);
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSB) {
            return AlertDialog(
              title: const Text('Agregar Asignatura'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Asignatura',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text("Inicio: "),
                        TextButton(
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
                          child: Text(startTime.format(ctx)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text("Fin: "),
                        TextButton(
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
                          child: Text(endTime.format(ctx)),
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
                    final subjectName = nameController.text.trim();
                    if (subjectName.isNotEmpty) {
                      final startStr = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
                      final endStr = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";
                      await SubjectDBService.insertAsignatura(
                        Asignatura(nombre: subjectName, horarioInicio: startStr, horarioFin: endStr)
                      );
                      setState(() {});
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      }
    );
  }
  
  void _deleteSubject(String name) async {
    if (name == 'Otros') return; // No permitir eliminar "Otros"

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false), // Cancelar
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true), // Confirmar
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      final subjects = await SubjectDBService.getAllAsignaturas();
      final subject = subjects.firstWhere(
        (s) => s.nombre == name, 
        orElse: () => Asignatura(nombre: '', horarioInicio: '', horarioFin: '')
      );
      if (subject.nombre.isNotEmpty) {
        await SubjectDBService.deleteAsignatura(subject.idAsignatura!);
        setState(() {}); // Recargar la lista de asignaturas
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FotoClass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddSubjectDialog,
          ),
          Switch(
            value: _isDarkMode,
            onChanged: _toggleTheme,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            alignment: Alignment.center,
            child: Text(
              _message,
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<Asignatura>>(
              future: SubjectDBService.getAllAsignaturas(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final subjects = snapshot.data ?? [];
                return ListView(
                  children: [
                    // "Otros" fijo
                    ListTile(
                      title: const Text("Otros (por defecto)"),
                      trailing: const Icon(Icons.lock),
                      onTap: () => _openSubjectDetail("Otros"),
                    ),
                    ...subjects.map((subject) {
                      return ListTile(
                        title: Text(subject.nombre),
                        subtitle: Text("Horario: ${subject.horarioInicio} - ${subject.horarioFin}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteSubject(subject.nombre),
                        ),
                        onTap: () => _openSubjectDetail(subject.nombre),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePhoto,
        tooltip: 'Tomar Foto',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
