// lib/services/permission_service.dart
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> requestPermissions() async {
    await [
      Permission.camera,
      Permission.storage,
    ].request();
  }
}
