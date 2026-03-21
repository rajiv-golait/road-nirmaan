import '../utils/app_flags.dart';
import 'user_service.dart';

/// Resolves ward filters for role dashboards from `profiles.ward_zone` or `user_roles.ward_zone`.
///
/// Call [refresh] after login (see [LoginScreen]) so [assignedWards] is populated before dashboards read it.
class WardAssignmentService {
  WardAssignmentService._();

  /// Matches [supabase/seed.sql] ward column values when DB has no per-user zone.
  static const List<String> _cityZoneFallback = <String>[
    'North',
    'South',
    'East',
    'West',
    'Central',
    'Cantonment',
  ];

  /// Legacy demo ward labels used only when [AppFlags.allowMockData] is true.
  static const List<String> _legacyDemoWards = <String>[
    'Ward 12',
    'Ward 13',
    'Ward 14',
    'Ward 15',
  ];

  static List<String>? _cached;

  /// Wards/zones used to filter `ComplaintStore` lists. Safe to read anytime; uses fallback until [refresh] runs.
  static List<String> get assignedWards => _cached ?? _defaultFallback();

  static List<String> _defaultFallback() {
    if (AppFlags.allowMockData) {
      return List<String>.from(_legacyDemoWards);
    }
    return List<String>.from(_cityZoneFallback);
  }

  static Future<void> refresh() async {
    _cached = await _load();
  }

  static Future<List<String>> _load() async {
    final user = UserService.instance.currentUser;
    if (user == null) {
      return _defaultFallback();
    }
    String? wz;
    try {
      final profile = await UserService.instance.getCurrentProfile();
      wz = profile?['ward_zone']?.toString().trim();
      if (wz == null || wz.isEmpty) {
        final row = await UserService.instance.getOfficialRoleByEmail(
          user.email ?? '',
        );
        wz = row?['ward_zone']?.toString().trim();
      }
    } catch (_) {}
    if (wz != null && wz.isNotEmpty) {
      return <String>[wz];
    }
    return _defaultFallback();
  }
}
