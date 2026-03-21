import 'package:flutter/foundation.dart';

/// Compile-time feature flags via `--dart-define`.
///
/// - `ALLOW_MOCK_DATA` — when `true`, enables local mock complaints, seeder, and demo UI samples.
///   Default: `false` (Supabase-only for production / judge builds).
/// - `ALLOW_DEMO_LOGIN` — when `true`, allows password `123` demo bypass in [demo_role_router].
///   Default: `false` (real Supabase Auth only).
///
/// [showAssetDemoUi] — debug-only: show embedded `assets/download` demo storyboards when mock is on.
class AppFlags {
  AppFlags._();

  static const String _allowMockDataRaw = String.fromEnvironment(
    'ALLOW_MOCK_DATA',
    defaultValue: 'false',
  );

  static const String _allowDemoLoginRaw = String.fromEnvironment(
    'ALLOW_DEMO_LOGIN',
    defaultValue: 'false',
  );

  static bool get allowMockData =>
      _allowMockDataRaw == 'true' || _allowMockDataRaw == '1';

  static bool get allowDemoLogin =>
      _allowDemoLoginRaw == 'true' || _allowDemoLoginRaw == '1';

  /// Embedded asset-image demos in dashboards (debug + mock only).
  static bool get showAssetDemoUi => kDebugMode && allowMockData;
}
