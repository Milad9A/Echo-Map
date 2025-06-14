import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/navigation_utilities.dart';
import '../utils/map_config.dart'; // Import the config
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
  final StreamController<double> _routeDeviationController =
      StreamController<double>.broadcast();

  // State
  MapStatus _status = MapStatus.uninitialized;
  GoogleMapController? mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  CameraPosition? _currentCameraPosition;
  List<LatLng> _activeRoutePoints = [];
  bool _isMonitoringDeviation = false;
  StreamSubscription<Position>? _deviationMonitorSubscription;
  double _deviationThresholdMeters = 20.0; // Default deviation threshold
  bool _mapReady = false;

  // Add a lock for controller operations
  bool _controllerLocked = false;
  bool _controllerDisposed = false;

  // Add a completer to track when the map is fully initialized
  final Completer<bool> _mapInitCompleter = Completer<bool>();

  // Replace default map settings with references to MapConfig
  static const double defaultZoom = MapConfig.defaultZoom;
  static const MapType defaultMapType = MapConfig.defaultMapType;

  // Public getters
  Stream<MapStatus> get statusStream => _statusController.stream;
  Stream<CameraPosition> get cameraStream => _cameraController.stream;
  Stream<Set<Marker>> get markersStream => _markersController.stream;
  Stream<Set<Polyline>> get polylinesStream => _polylinesController.stream;
  Stream<double> get routeDeviationStream => _routeDeviationController.stream;

  MapStatus get status => _status;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  CameraPosition? get currentCameraPosition => _currentCameraPosition;
  List<LatLng> get activeRoutePoints => _activeRoutePoints;
  bool get isMonitoringDeviation => _isMonitoringDeviation;
  bool get isMapReady =>
      _mapReady &&
      mapController != null &&
      !_controllerLocked &&
      !_controllerDisposed;

  // New method to wait for map initialization
  Future<bool> waitForMapInitialization({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (isMapReady) return true;

    try {
      return await _mapInitCompleter.future.timeout(timeout);
    } catch (e) {
      debugPrint('Map initialization timed out or failed: $e');
      return false;
    }
  }

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
    // Prevent setting a new controller if one already exists and is not disposed
    if (mapController != null && !_controllerDisposed) {
      debugPrint('Map controller already exists. Ignoring new controller.');
      return;
    }

    // Reset state flags
    _controllerLocked = true;
    _controllerDisposed = false;
    _mapReady = false;

    // Clear previous controller reference
    mapController = null;

    // Add a small delay before assigning the new controller to ensure clean state
    Future.delayed(const Duration(milliseconds: 100), () {
      mapController = controller;

      // Add a delay to ensure the controller is fully initialized
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mapController == controller) {
          // Verify it's still the same controller
          _mapReady = true;
          _controllerLocked = false;
          debugPrint(
            'Google Maps controller initialized successfully and ready for use',
          );

          // Complete the initialization completer
          if (!_mapInitCompleter.isCompleted) {
            _mapInitCompleter.complete(true);
          }
        }
      });
    });
  }

  // Center map on user's current location
  Future<bool> centerOnUserLocation() async {
    try {
      // Ensure map is ready before attempting to center
      if (!isMapReady) {
        debugPrint('Map not ready yet, waiting for initialization...');
        final isInitialized = await waitForMapInitialization();
        if (!isInitialized) {
          debugPrint('Map initialization timeout, cannot center on location');
          return false;
        }
      }

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

  // Animate camera to a specific position with enhanced error handling
  Future<bool> animateCameraToPosition(
    LatLng position, {
    double zoom = MapConfig.defaultZoom, // Use the config value here
  }) async {
    // Ensure map is initialized before attempting animation
    if (!isMapReady) {
      debugPrint('Map not ready yet, waiting for initialization...');
      final isInitialized = await waitForMapInitialization();
      if (!isInitialized) {
        debugPrint('Map initialization timeout, cannot animate camera');
        return false;
      }
    }

    // Safety check for controller state
    if (_controllerDisposed || mapController == null) {
      debugPrint('Map controller is disposed or null. Cannot animate camera.');
      return false;
    }

    // Prevent concurrent animations
    if (_controllerLocked) {
      debugPrint('Map controller is locked. Skipping animation.');
      return false;
    }

    _controllerLocked = true;

    try {
      final cameraPosition = CameraPosition(target: position, zoom: zoom);

      // Store the controller reference to avoid race conditions
      final controller = mapController;
      if (controller == null) {
        throw Exception('Controller became null unexpectedly');
      }

      // Wait a short time before animating to avoid potential initialization issues
      await Future.delayed(const Duration(milliseconds: 200));

      // Check again if controller is valid
      if (_controllerDisposed ||
          mapController == null ||
          mapController != controller) {
        throw Exception(
          'Controller changed or disposed during animation preparation',
        );
      }

      // Use a timeout for the animation to avoid hanging
      await controller
          .animateCamera(CameraUpdate.newCameraPosition(cameraPosition))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint(
                'Camera animation timed out, trying moveCamera instead',
              );
              try {
                controller.moveCamera(
                  CameraUpdate.newCameraPosition(cameraPosition),
                );
              } catch (e) {
                debugPrint('moveCamera fallback also failed: $e');
              }
              return;
            },
          );

      _currentCameraPosition = cameraPosition;
      _cameraController.add(cameraPosition);

      return true;
    } catch (e) {
      debugPrint('Error animating camera: $e');

      // Try a fallback approach with moveCamera
      try {
        if (mapController != null && !_controllerDisposed) {
          final cameraPosition = CameraPosition(target: position, zoom: zoom);
          mapController!.moveCamera(
            CameraUpdate.newCameraPosition(cameraPosition),
          );
          _currentCameraPosition = cameraPosition;
          _cameraController.add(cameraPosition);
          return true;
        }
      } catch (fallbackError) {
        debugPrint('Fallback camera movement also failed: $fallbackError');
      }

      return false;
    } finally {
      // Always unlock the controller, even if an error occurs
      _controllerLocked = false;
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
    int width = MapConfig.routeLineWidth,
    Color? color,
  }) async {
    color ??= Color(MapConfig.routeLineColor);
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

    // Store the route points for deviation detection
    if (id == 'route') {
      _activeRoutePoints = List.from(points);
    }
  }

  // Clear all polylines
  void clearPolylines() {
    _polylines = {};
    _polylinesController.add(_polylines);
    _activeRoutePoints = [];

    // Stop monitoring if we're clearing the route
    stopDeviationMonitoring();
  }

  // Start monitoring for route deviation
  Future<bool> startDeviationMonitoring({double? thresholdMeters}) async {
    if (_isMonitoringDeviation) {
      // Already monitoring
      return true;
    }

    if (_activeRoutePoints.isEmpty) {
      debugPrint('Cannot monitor deviation: No active route');
      return false;
    }

    if (thresholdMeters != null) {
      _deviationThresholdMeters = thresholdMeters;
    }

    try {
      // Make sure location service is active
      if (!_locationService.isTracking) {
        final success = await _locationService.startLocationUpdates();
        if (!success) {
          debugPrint(
            'Failed to start location updates for deviation monitoring',
          );
          return false;
        }
      }

      // Subscribe to location updates to check for deviation
      _deviationMonitorSubscription = _locationService.locationStream.listen(
        _checkForRouteDeviation,
        onError: (error) {
          debugPrint('Error in deviation monitoring: $error');
        },
      );

      _isMonitoringDeviation = true;
      return true;
    } catch (e) {
      debugPrint('Error starting deviation monitoring: $e');
      return false;
    }
  }

  // Stop monitoring for route deviation
  void stopDeviationMonitoring() {
    _deviationMonitorSubscription?.cancel();
    _deviationMonitorSubscription = null;
    _isMonitoringDeviation = false;
  }

  // Check if the current position deviates from the route
  void _checkForRouteDeviation(Position position) {
    if (_activeRoutePoints.isEmpty) return;

    final currentPosition = LatLng(position.latitude, position.longitude);

    final double deviation = NavigationUtilities.calculateRouteDeviation(
      currentPosition,
      _activeRoutePoints,
      _deviationThresholdMeters,
    );

    // Notify listeners about the deviation distance
    _routeDeviationController.add(deviation);
  }

  // Get the closest point on the current route to a given position
  LatLng? getClosestPointOnRoute(LatLng position) {
    if (_activeRoutePoints.isEmpty) return null;

    return NavigationUtilities.findClosestPointOnRoute(
      position,
      _activeRoutePoints,
    );
  }

  // Find the index of the closest route segment to the current position
  int findClosestRouteSegmentIndex(LatLng position) {
    if (_activeRoutePoints.length < 2) return -1;

    double minDistance = double.infinity;
    int closestSegmentIndex = -1;

    for (int i = 0; i < _activeRoutePoints.length - 1; i++) {
      final LatLng segmentStart = _activeRoutePoints[i];
      final LatLng segmentEnd = _activeRoutePoints[i + 1];

      // Project the position onto the segment
      final LatLng projectedPoint = NavigationUtilities.projectPointOnSegment(
        position,
        segmentStart,
        segmentEnd,
      );

      // Calculate distance to the projected point
      final double distance = NavigationUtilities.calculateDistance(
        position,
        projectedPoint,
      );

      // Update closest segment if this one is closer
      if (distance < minDistance) {
        minDistance = distance;
        closestSegmentIndex = i;
      }
    }

    return closestSegmentIndex;
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
    stopDeviationMonitoring();

    // Mark controller as disposed first to prevent new operations
    _controllerDisposed = true;

    // Make sure we're not trying to dispose the controller while it's locked
    if (mapController != null && !_controllerLocked) {
      try {
        mapController!.dispose();
      } catch (e) {
        debugPrint('Error disposing map controller: $e');
      }
      mapController = null;
    } else if (_controllerLocked) {
      // Schedule controller disposal after lock is released
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mapController != null) {
          try {
            mapController!.dispose();
          } catch (e) {
            debugPrint('Error in delayed disposal of map controller: $e');
          }
          mapController = null;
        }
      });
    }

    // Close stream controllers
    _statusController.close();
    _cameraController.close();
    _markersController.close();
    _polylinesController.close();
    _routeDeviationController.close();
  }
}
