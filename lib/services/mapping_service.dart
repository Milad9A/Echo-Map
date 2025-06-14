import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

enum MapStatus { uninitialized, initializing, ready, error }

class MappingService {
  // Singleton pattern
  static final MappingService _instance = MappingService._internal();
  factory MappingService() => _instance;
  MappingService._internal();

  // Services
  final LocationService _locationService = LocationService();

  // Controllers
  final StreamController<MapStatus> _statusController =
      StreamController<MapStatus>.broadcast();
  final StreamController<CameraPosition> _cameraController =
      StreamController<CameraPosition>.broadcast();
  final StreamController<Set<Marker>> _markersController =
      StreamController<Set<Marker>>.broadcast();
  final StreamController<Set<Polyline>> _polylinesController =
      StreamController<Set<Polyline>>.broadcast();

  // State
  MapStatus _status = MapStatus.uninitialized;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  CameraPosition? _currentCameraPosition;

  // Default map settings
  static const double defaultZoom = 15.0;
  static const MapType defaultMapType = MapType.normal;

  // Public getters
  Stream<MapStatus> get statusStream => _statusController.stream;
  Stream<CameraPosition> get cameraStream => _cameraController.stream;
  Stream<Set<Marker>> get markersStream => _markersController.stream;
  Stream<Set<Polyline>> get polylinesStream => _polylinesController.stream;

  MapStatus get status => _status;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  CameraPosition? get currentCameraPosition => _currentCameraPosition;

  // Initialize mapping service
  Future<bool> initialize() async {
    if (_status == MapStatus.initializing || _status == MapStatus.ready) {
      return _status == MapStatus.ready;
    }

    _updateStatus(MapStatus.initializing);

    try {
      // Initialize location service if not already initialized
      if (_locationService.status == LocationStatus.initial) {
        await _locationService.initialize();
      }

      // Successfully initialized
      _updateStatus(MapStatus.ready);
      return true;
    } catch (e) {
      debugPrint('Error initializing mapping service: $e');
      _updateStatus(MapStatus.error);
      return false;
    }
  }

  // Set map controller when map is created
  void setMapController(GoogleMapController controller) {
    _mapController = controller;

    // Apply night mode style if in dark mode
    // This would be implemented based on app's theme
  }

  // Center map on user's current location
  Future<bool> centerOnUserLocation() async {
    try {
      Position? position = _locationService.lastPosition;

      // If no last position, try to get current position
      position ??= await _locationService.getCurrentPosition();

      if (position != null) {
        return await animateCameraToPosition(
          LatLng(position.latitude, position.longitude),
        );
      }

      return false;
    } catch (e) {
      debugPrint('Error centering on user location: $e');
      return false;
    }
  }

  // Animate camera to a specific position
  Future<bool> animateCameraToPosition(
    LatLng position, {
    double zoom = defaultZoom,
  }) async {
    if (_mapController == null) return false;

    try {
      final cameraPosition = CameraPosition(target: position, zoom: zoom);

      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(cameraPosition),
      );

      _currentCameraPosition = cameraPosition;
      _cameraController.add(cameraPosition);

      return true;
    } catch (e) {
      debugPrint('Error animating camera: $e');
      return false;
    }
  }

  // Add a marker to the map
  Future<void> addMarker({
    required String id,
    required LatLng position,
    String title = '',
    String snippet = '',
    BitmapDescriptor? icon,
  }) async {
    final marker = Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(title: title, snippet: snippet),
      icon: icon ?? BitmapDescriptor.defaultMarker,
    );

    _markers.add(marker);
    _markersController.add(_markers);
  }

  // Clear all markers
  void clearMarkers() {
    _markers = {};
    _markersController.add(_markers);
  }

  // Add a polyline (route) to the map
  Future<void> addPolyline({
    required String id,
    required List<LatLng> points,
    int width = 5,
    Color color = const Color(0xFF0000FF),
  }) async {
    final polyline = Polyline(
      polylineId: PolylineId(id),
      points: points,
      width: width,
      color: color,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    );

    _polylines.add(polyline);
    _polylinesController.add(_polylines);
  }

  // Clear all polylines
  void clearPolylines() {
    _polylines = {};
    _polylinesController.add(_polylines);
  }

  // Update map status and notify listeners
  void _updateStatus(MapStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  // Dispose of resources
  void dispose() {
    _mapController?.dispose();
    _statusController.close();
    _cameraController.close();
    _markersController.close();
    _polylinesController.close();
  }
}
