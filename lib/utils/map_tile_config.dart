import 'package:flutter_map/flutter_map.dart';

import 'constants.dart';

/// Mapbox raster tiles when [AppConstants.mapboxToken] is set at compile time;
/// otherwise OpenStreetMap (no API key).
///
/// Pass Mapbox token: `flutter run --dart-define=MAPBOX_TOKEN=pk...`
class MapTileConfig {
  MapTileConfig._();

  static const String _osmTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Package name sent as User-Agent fragment (OSM tile policy).
  static const String _userAgentPackageName = 'dev.smc.roadnirman';

  static TileLayer buildTileLayer() {
    final token = AppConstants.mapboxToken;
    if (token.isNotEmpty) {
      return TileLayer(
        urlTemplate:
            'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$token',
        additionalOptions: <String, String>{'access_token': token},
      );
    }
    return TileLayer(
      urlTemplate: _osmTemplate,
      userAgentPackageName: _userAgentPackageName,
    );
  }
}
