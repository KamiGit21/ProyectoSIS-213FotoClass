// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/initial_setup_screen.dart';

void main() {
  runApp(const FotoClassApp());
}

class FotoClassApp extends StatefulWidget {
  const FotoClassApp({Key? key}) : super(key: key);

  @override
  State<FotoClassApp> createState() => _FotoClassAppState();
}

class _FotoClassAppState extends State<FotoClassApp> {
  bool _isConfigured = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  Future<void> _checkConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isConfigured = prefs.getBool('isConfigured') ?? false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return MaterialApp(
      title: 'FotoClass',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _isConfigured
          ? const HomeScreen()
          : const InitialSetupScreen(),
    );
  }
}
