import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'schedule_service.dart';
import '../services/photo_db_service.dart';
import '../services/subject_db_service.dart';
import '../services/db_helper.dart';

class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String> takeAndClassifyPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) return 'No se tomó ninguna foto.';
      final folderName = await ScheduleService.classifyBySchedule();
      final savedFile = await _savePhotoToFolder(photo.path, folderName);
      if (savedFile == null) return 'Error guardando la foto';

      final idAsig = await _getAsignaturaId(folderName);
      final fecha = DateTime.now().toIso8601String();
      final newFoto = Foto(
        rutaArchivo: savedFile.path,
        idAsignatura: idAsig,
        fechaCreacion: fecha,
      );
      await PhotoDBService.insertFoto(newFoto);

      return 'Foto guardada en: $folderName';
    } catch (e) {
      return 'Error al tomar o guardar la foto: $e';
    }
  }

  static Future<File?> _savePhotoToFolder(String photoPath, String folderName) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final mainFolderPath = p.join(appDocDir.path, folderName);
      final dir = Directory(mainFolderPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      // Subcarpeta "Favoritas" si quieres tenerla físicamente
      final favDir = Directory(p.join(mainFolderPath, 'Favoritas'));
      if (!favDir.existsSync()) {
        favDir.createSync(recursive: true);
      }
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      return File(photoPath).copy(p.join(mainFolderPath, fileName));
    } catch (e) {
      return null;
    }
  }

  static Future<int?> _getAsignaturaId(String folderName) async {
    final asigs = await SubjectDBService.getAllAsignaturas();
    final match = asigs.firstWhere(
      (a) => a.nombre == folderName,
      orElse: () => Asignatura(nombre: 'Otros', horarioInicio: '00:00', horarioFin: '00:00'),
    );
    return (match.nombre == 'Otros') ? null : match.idAsignatura;
  }

  // Retorna TODOS los archivos de la carpeta principal (sin filtrar si esFavorito o no)
  static Future<List<FileSystemEntity>> getMainFolderPhotos(String subjectName) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final folderPath = p.join(appDocDir.path, subjectName);
    final folderDir = Directory(folderPath);
    if (!folderDir.existsSync()) return [];
    return folderDir.listSync().whereType<File>().toList();
  }

  // Mover físicamente la foto a la nueva carpeta [targetFolder]
  static Future<String?> movePhoto(String oldFilePath, String targetFolder) async {
    final file = File(oldFilePath);
    if (!await file.exists()) return null;
    final fileName = p.basename(oldFilePath);

    final appDocDir = await getApplicationDocumentsDirectory();
    final newFolderPath = p.join(appDocDir.path, targetFolder);
    final newFolderDir = Directory(newFolderPath);
    if (!newFolderDir.existsSync()) {
      newFolderDir.createSync(recursive: true);
      final favDir = Directory(p.join(newFolderPath, 'Favoritas'));
      if (!favDir.existsSync()) {
        favDir.createSync(recursive: true);
      }
    }

    final newFilePath = p.join(newFolderPath, fileName);
    if (oldFilePath == newFilePath) return oldFilePath;

    try {
      await file.rename(newFilePath);
      return newFilePath;
    } catch (e) {
      final newFile = await file.copy(newFilePath);
      await file.delete();
      return newFile.path;
    }
  }

  static Future<void> deletePhoto(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
    // (Opcional) Eliminar el registro en la BD si quieres
    // final foto = await PhotoDBService.getFotoByFilePath(filePath);
    // if (foto != null) {
    //   await PhotoDBService.deleteFoto(foto.idFoto!);
    // }
  }

  // Renombrar carpeta => actualizamos la BD y renombramos la carpeta
  static Future<void> renameFolder(String oldName, String newName) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final oldPath = p.join(appDocDir.path, oldName);
    final newPath = p.join(appDocDir.path, newName);
    await renameAssignmentPathsInDB(oldName, newName);

    final oldDir = Directory(oldPath);
    if (await oldDir.exists()) {
      final newDir = Directory(newPath);
      if (await newDir.exists()) {
        return;
      }
      await oldDir.rename(newPath);
    }
  }

  static Future<void> renameAssignmentPathsInDB(String oldName, String newName) async {
    final db = await DBHelper.database;
    final allRecords = await db.query('fotos');
    for (final m in allRecords) {
      final foto = Foto.fromMap(m);
      if (foto.rutaArchivo.contains("/$oldName/")) {
        final newPath = foto.rutaArchivo.replaceFirst("/$oldName/", "/$newName/");
        foto.rutaArchivo = newPath;
        await db.update('fotos', foto.toMap(),
            where: 'id_foto = ?', whereArgs: [foto.idFoto]);
      }
    }
  }

  /// Nuevo método para importar una foto local (imagePath) a la carpeta [subjectName].
  /// [idAsig] indica la asignatura en la BD (null si "Otros").
  static Future<void> importPhotoToSubject(
    String imagePath,
    String subjectName,
    int? idAsig,
  ) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final folderPath = p.join(appDocDir.path, subjectName);
      final folderDir = Directory(folderPath);
      if (!folderDir.existsSync()) {
        folderDir.createSync(recursive: true);
        // Subcarpeta Favoritas si quisieras
        final favDir = Directory(p.join(folderPath, 'Favoritas'));
        if (!favDir.existsSync()) {
          favDir.createSync(recursive: true);
        }
      }
      // Copiar la foto
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newFilePath = p.join(folderPath, fileName);
      final importedFile = await File(imagePath).copy(newFilePath);

      // Insertar en BD
      final fecha = DateTime.now().toIso8601String();
      final newFoto = Foto(
        rutaArchivo: importedFile.path,
        idAsignatura: idAsig,
        fechaCreacion: fecha,
      );
      await PhotoDBService.insertFoto(newFoto);
    } catch (e) {
      // Manejo de errores
      // Podrías mostrar un log o throw e
      // throw e;
    }
  }
}
