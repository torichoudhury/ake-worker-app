// lib/core/constants/app_constants.dart
// Centralised app-wide constants

class AppConstants {
  AppConstants._();

  // ─── API ───────────────────────────────────
  // For Android emulator: 10.0.2.2 maps to host machine's localhost
  // For iOS simulator:    127.0.0.1
  // For physical device:  your machine's LAN IP, e.g. 192.168.1.10
  // Note: Using 127.0.0.1 because ADB reverse proxy is active for the physical device
  static const String baseUrl = 'http://127.0.0.1:3000/api';

  // Set to TRUE for UI testing without a running backend
  // Mock mode removed — app always calls the real backend

  static const Duration connectTimeout = Duration(seconds: 10);

  // ─── UoM Options ───────────────────────────
  static const List<String> uomOptions = ['5', 'Gross', 'KH', 'Pcs', 'Box'];

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
