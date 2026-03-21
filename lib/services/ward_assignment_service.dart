import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../utils/app_flags.dart';
import 'user_service.dart';

/// Resolves ward filters for role dashboards from `profiles.ward_zone` or `user_roles.ward_zone`.
///
/// Call [refresh] after login (see [LoginScreen]) so [assignedWards] is populated before dashboards read it.
class WardAssignmentService {
  WardAssignmentService._();

  /// Solapur zone centers (nearest-zone assignment for citizen complaints).
  static const Map<String, LatLng> zoneCenters = {
    'Zone 1': LatLng(17.6900, 75.8900),
    'Zone 2': LatLng(17.6800, 75.9100),
    'Zone 3': LatLng(17.7000, 75.9200),
    'Zone 4': LatLng(17.6600, 75.9300),
    'Zone 5': LatLng(17.6700, 75.8800),
    'Zone 6': LatLng(17.7100, 75.9000),
  };

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

  /// Nearest Zone 1–6 for valid Solapur-area coordinates; [Unknown Area] if far from all centers.
  static String assignZone(double lat, double lng) {
    String nearestZone = 'Zone 1';
    var minDistance = double.infinity;
    zoneCenters.forEach((zone, center) {
      final dist = _haversineMeters(
        lat,
        lng,
        center.latitude,
        center.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearestZone = zone;
      }
    });
    return minDistance < 20000 ? nearestZone : 'Unknown Area';
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final p1 = lat1 * pi / 180;
    final p2 = lat2 * pi / 180;
    final dp = (lat2 - lat1) * pi / 180;
    final dl = (lon2 - lon1) * pi / 180;
    final a = sin(dp / 2) * sin(dp / 2) +
        cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
