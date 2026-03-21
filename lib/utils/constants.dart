/// Application constants
///
/// Centralized constants for the application

class AppConstants {
  // App Info
  static const String appName = 'ROADNIRMAN';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String baseUrl = 'https://api.roadnirman.example.com';

  // Mapbox token — passed via --dart-define=MAPBOX_TOKEN=...
  static const String mapboxToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );

  /// Flask AI backend. Override per run:
  /// `--dart-define=FLASK_URL=http://<LAN-IP>:5000` (real device)
  /// Default matches Android emulator host loopback.
  static const String flaskUrl = String.fromEnvironment(
    'FLASK_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  // Validation Constants
  static const int minTitleLength = 5;
  static const int maxTitleLength = 100;
  static const int minDescriptionLength = 10;
  static const int maxDescriptionLength = 1000;
  static const int maxImagesPerComplaint = 5;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
}
