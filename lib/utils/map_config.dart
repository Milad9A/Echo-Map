import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Configuration class for map-related default values
class MapConfig {
  /// Default camera position used when map is first loaded
  static const CameraPosition defaultPosition = CameraPosition(
    target: LatLng(53.0793, 8.8017), // Bremen, Germany as default
    zoom: 14.0,
  );

  /// Default zoom level for map
  static const double defaultZoom = 14.0;

  /// Default zoom level when following user
  static const double followUserZoom = 16.0;

  /// Default map type
  static const MapType defaultMapType = MapType.normal;

  /// Default route line width
  static const int routeLineWidth = 5;

  /// Default route line color
  static const int routeLineColor = 0xFF0000FF; // Blue
}
