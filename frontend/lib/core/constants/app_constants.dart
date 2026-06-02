// lib/core/constants/app_constants.dart
// Centralised app-wide constants

class AppConstants {
  AppConstants._();

  // ─── API ───────────────────────────────────
  // For Android emulator: 10.0.2.2 maps to host machine's localhost
  // For iOS simulator:    127.0.0.1
  // For physical device over Wi-Fi: your machine's LAN IP
  static const String baseUrl = 'https://ake-worker-app.onrender.com/api';

  // Set to TRUE for UI testing without a running backend
  // Mock mode removed — app always calls the real backend

  static const Duration connectTimeout = Duration(seconds: 60);

  // ─── UoM Options ───────────────────────────
  static const List<String> uomOptions = ['%', 'Gross', 'KG', 'Pcs', 'Bag', 'Box'];

  // ─── Mode Options ──────────────────────────
  static const List<String> modeOptions = [
    'cash',
    'online',
    'credit-slip',
    'gst-cash',
    'gst-bank',
    'gst-credit',
  ];

  // ─── Location Options ───────────────────────
  static const List<String> locationOptions = [
    'Home Godown',
    'Ake',
    'Radhe',
  ];
}
