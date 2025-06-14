import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/navigation_utilities.dart';
import '../utils/map_config.dart';
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

  // Enhanced controller state tracking
  final _controllerCompleter = Completer<GoogleMapController>();
  bool _controllerLocked = false;
  bool _controllerDisposed = false;
  bool _controllerInitialized = false;

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

  // Improved check for map readiness
  bool get isMapReady =>
      _mapReady &&
      mapController != null &&
      _controllerInitialized &&
      !_controllerLocked &&
      !_controllerDisposed;

  // New method to get a future for the controller
  Future<GoogleMapController> get controller => _controllerCompleter.future;

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

  // Set map controller when map is created - improved implementation
  void setMapController(GoogleMapController controller) {
    // Safety checks for controller state
    if (_controllerDisposed) {
      debugPrint('Cannot set controller: Previous controller was disposed');
      return;
    }

    if (mapController != null && !_controllerCompleter.isCompleted) {
      debugPrint(
        'Controller already exists but completer not completed, completing now',
      );
      _controllerCompleter.complete(mapController);
    }

    // Reset controller state
    _controllerLocked = true;
    _controllerInitialized = false;
    _mapReady = false;

    // Assign the new controller
    mapController = controller;

    // Complete the completer if not already completed
    if (!_controllerCompleter.isCompleted) {
      _controllerCompleter.complete(controller);
    }

    // Add a delay to ensure the controller is fully initialized
    // This helps prevent race conditions
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mapController == controller) {
        _controllerInitialized = true;
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
  }

  // Center map on user's current location - improved with retry logic
  Future<bool> centerOnUserLocation({int maxRetries = 3}) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        // Ensure map is ready before attempting to center
        if (!isMapReady) {
          debugPrint('Map not ready yet, waiting for initialization...');
          final isInitialized = await waitForMapInitialization();
          if (!isInitialized) {
            debugPrint('Map initialization timeout, retrying...');
            retryCount++;
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
        }

        Position? position = _locationService.lastPosition;

        // If no last position, try to get current position
        position ??= await _locationService.getCurrentPosition();

        if (position != null) {
          return await animateCameraToPosition(
            LatLng(position.latitude, position.longitude),
            zoom: MapConfig.followUserZoom,
          );
        }

        retryCount++;
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        debugPrint(
          'Error centering on user location (attempt $retryCount): $e',
        );
        retryCount++;
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    return false;
  }

  // Animate camera to a specific position with enhanced error handling and retry logic
  Future<bool> animateCameraToPosition(
    LatLng position, {
    double zoom = MapConfig.defaultZoom,
    int maxRetries = 2,
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
    int retryCount = 0;

    try {
      final cameraPosition = CameraPosition(target: position, zoom: zoom);

      // Store the controller reference to avoid race conditions
      final controller = mapController;
      if (controller == null) {
        throw Exception('Controller became null unexpectedly');
      }

      // Add small delay to avoid potential issues right after initialization
      await Future.delayed(const Duration(milliseconds: 300));

      // Check again if controller is valid
      if (_controllerDisposed ||
          mapController == null ||
          mapController != controller) {
        throw Exception(
          'Controller changed or disposed during animation preparation',
        );
      }

      bool success = false;
      Exception? lastException;

      // Try animation with retries
      while (retryCount <= maxRetries && !success) {
        try {
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
                    success = true;
                  } catch (e) {
                    debugPrint('moveCamera fallback also failed: $e');
                    success = false;
                  }
                },
              );

          success = true;
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          debugPrint('Animation attempt $retryCount failed: $e');
          retryCount++;

          // Small delay before retry
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (success) {
        _currentCameraPosition = cameraPosition;
        _cameraController.add(cameraPosition);
        return true;
      } else if (lastException != null) {
        throw lastException;
      }

      return false;
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

  // Dispose of resources with improved safety
  void dispose() {
    stopDeviationMonitoring();

    // Mark controller as disposed first to prevent new operations
    _controllerDisposed = true;
    _mapReady = false;
    _controllerInitialized = false;

    // Cancel any pending futures
    if (!_mapInitCompleter.isCompleted) {
      _mapInitCompleter.completeError('Service disposed');
    }

    // Handle controller disposal with extra care
    final localController = mapController;
    if (localController != null && !_controllerLocked) {
      try {
        // Wrap in a future to avoid blocking
        Future.microtask(() {
          try {
            localController.dispose();
          } catch (e) {
            debugPrint('Error in delayed disposal of map controller: $e');
          }
        });
      } catch (e) {
        debugPrint('Error queuing controller disposal: $e');
      }
    }

    mapController = null;

    // Close stream controllers
    _statusController.close();
    _cameraController.close();
    _markersController.close();
    _polylinesController.close();
    _routeDeviationController.close();
  }

  // Create a new controller completer (for reinitialization)
  void resetControllerCompleter() {
    if (!_controllerCompleter.isCompleted) {
      // Complete with error to avoid hanging futures
      _controllerCompleter.completeError('Controller reset');
    }

    // No need to create a new completer - this would lose existing listeners
    // Instead, we'll handle this in setMapController
  }
}
