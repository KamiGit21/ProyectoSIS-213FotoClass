// lib/screens/initial_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:foto_class/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/subject_db_service.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({Key? key}) : super(key: key);

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final List<_TempSubject> _tempSubjects = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONFIGURACIÓN INICIAL'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Bienvenido a FotoClass, por favor ingresa tu nombre:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _tempSubjects.length,
                itemBuilder: (context, index) {
                  final item = _tempSubjects[index];
                  return Card(
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        "Inicio: ${item.startTime.format(context)} - Fin: ${item.endTime.format(context)}",
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _tempSubjects.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('AGREGAR ASIGNATURA'),
                  onPressed: _showAddTempSubjectDialog,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('GUARDAR'),
                  onPressed: _onSaveConfiguration,
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTempSubjectDialog() {
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 9, minute: 0);
    final TextEditingController subjectNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSB) {
            return AlertDialog(
              title: const Text('AGREGAR ASIGNATURA'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subjectNameController,
                      decoration: const InputDecoration(
                        labelText: 'NOMBRE DE LA ASIGNATURA',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text("HORA DE INICIO: "),
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
                        const Text("HORA DE FIN: "),
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
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = subjectNameController.text.trim();
                    if (name.isNotEmpty) {
                      setState(() {
                        _tempSubjects.add(
                          _TempSubject(
                            name: name,
                            startTime: startTime,
                            endTime: endTime,
                          ),
                        );
                      });
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('AGREGAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onSaveConfiguration() async {
    final userName = _nameController.text.trim();
    // Podrías guardar userName en SharedPreferences o en otra tabla
    // Aquí mismo guardaremos solo en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', userName);

    // Insertar las asignaturas en la BD
    for (var temp in _tempSubjects) {
      final startStr = "${temp.startTime.hour.toString().padLeft(2,'0')}:${temp.startTime.minute.toString().padLeft(2,'0')}";
      final endStr = "${temp.endTime.hour.toString().padLeft(2,'0')}:${temp.endTime.minute.toString().padLeft(2,'0')}";
      await SubjectDBService.insertAsignatura(
        Asignatura(nombre: temp.name, horarioInicio: startStr, horarioFin: endStr),
      );
    }

    // Marcamos la configuración como completada
    await prefs.setBool('isConfigured', true);

    // Navegar a HomeScreen
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }
}

class _TempSubject {
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  _TempSubject({
    required this.name,
    required this.startTime,
    required this.endTime,
  });
}
