import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

enum LocationStatus {
  initial,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  ready,
  active,
  error,
}

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  final StreamController<Position> _locationController =
      StreamController<Position>.broadcast();
  final StreamController<LocationStatus> _statusController =
      StreamController<LocationStatus>.broadcast();

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  Position? _lastPosition;
  LocationStatus _currentStatus = LocationStatus.initial;
  LocationAccuracy _currentAccuracy = LocationAccuracy.high;
  bool _inBackground = false;
  int _distanceFilter = 5; // in meters

  // Public access to streams
  Stream<Position> get locationStream => _locationController.stream;
  Stream<LocationStatus> get statusStream => _statusController.stream;

  // Getters for current state
  Position? get lastPosition => _lastPosition;
  LocationStatus get status => _currentStatus;
  bool get isTracking => _positionStreamSubscription != null;

  // Initialize the location service
  Future<bool> initialize() async {
    try {
      // Listen for service status changes
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen(
        (ServiceStatus status) {
          if (status == ServiceStatus.disabled) {
            _updateStatus(LocationStatus.serviceDisabled);
            stopLocationUpdates(); // Stop updates if service is disabled
          } else if (status == ServiceStatus.enabled &&
              _currentStatus == LocationStatus.serviceDisabled) {
            // Automatically restart if we were previously stopped due to service being disabled
            _checkPermissionAndStartUpdates();
          }
        },
        onError: (error) {
          debugPrint('Error in service status stream: $error');
        },
      );

      // Initial permission check
      return await _checkPermissionStatus();
    } catch (e) {
      debugPrint('Error initializing location service: $e');
      _updateStatus(LocationStatus.error);
      return false;
    }
  }

  // Update tracking accuracy
  void setAccuracy(LocationAccuracy accuracy) {
    _currentAccuracy = accuracy;
    // If currently tracking, restart with new accuracy
    if (isTracking) {
      stopLocationUpdates();
      startLocationUpdates();
    }
  }

  // Update distance filter
  void setDistanceFilter(int meters) {
    _distanceFilter = meters;
    // If currently tracking, restart with new distance filter
    if (isTracking) {
      stopLocationUpdates();
      startLocationUpdates();
    }
  }

  // Check if background mode is possible
  Future<bool> isBackgroundModeAvailable() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Error checking background mode: $e');
      return false;
    }
  }

  // Request location permissions
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _updateStatus(LocationStatus.serviceDisabled);
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _updateStatus(LocationStatus.permissionDenied);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _updateStatus(LocationStatus.permissionDeniedForever);
      return false;
    }

    // Permissions are granted
    _updateStatus(LocationStatus.ready);
    return true;
  }

  // Get current position with error handling
  Future<Position?> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _currentAccuracy,
          timeLimit: const Duration(seconds: 15),
        ),
      );
      _lastPosition = position;
      return position;
    } on TimeoutException {
      debugPrint('Timeout getting current position');
      return null;
    } on LocationServiceDisabledException {
      _updateStatus(LocationStatus.serviceDisabled);
      return null;
    } on PlatformException catch (e) {
      debugPrint('Platform exception getting position: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  // Start location updates with enhanced error handling
  Future<bool> startLocationUpdates({bool inBackground = false}) async {
    _inBackground = inBackground;
    return await _checkPermissionAndStartUpdates();
  }

  // Internal method to check permissions and start updates
  Future<bool> _checkPermissionAndStartUpdates() async {
    final hasPermission = await requestPermission();

    if (!hasPermission) {
      return false;
    }

    try {
      // Stop existing subscription if any
      await stopLocationUpdates();

      // Configure location settings based on whether we're in background or not
      final locationSettings = _inBackground
          ? AndroidSettings(
              accuracy: _currentAccuracy,
              distanceFilter: _distanceFilter,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationText:
                    "EchoMap is using your location in the background",
                notificationTitle: "EchoMap Active",
                enableWakeLock: true,
              ),
            )
          : LocationSettings(
              accuracy: _currentAccuracy,
              distanceFilter: _distanceFilter,
              timeLimit: const Duration(seconds: 30),
            );

      // Start the position stream
      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              _lastPosition = position;
              _locationController.add(position);
              _updateStatus(LocationStatus.active);
            },
            onError: (error) {
              // Handle specific errors
              if (error is LocationServiceDisabledException) {
                _updateStatus(LocationStatus.serviceDisabled);
              } else if (error is PermissionDeniedException) {
                _updateStatus(LocationStatus.permissionDenied);
              } else {
                debugPrint('Location stream error: $error');
                _updateStatus(LocationStatus.error);
              }
            },
            onDone: () {
              // Stream completed - might happen if service is stopped
              if (_currentStatus == LocationStatus.active) {
                _updateStatus(LocationStatus.ready);
              }
            },
            cancelOnError: false, // Don't cancel on error, let us handle it
          );

      return true;
    } catch (e) {
      debugPrint('Failed to start location updates: $e');
      _updateStatus(LocationStatus.error);
      return false;
    }
  }

  // Private helper to check current permission status
  Future<bool> _checkPermissionStatus() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateStatus(LocationStatus.serviceDisabled);
        return false;
      }

      // Check current permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        _updateStatus(LocationStatus.permissionDenied);
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        _updateStatus(LocationStatus.permissionDeniedForever);
        return false;
      }

      // Permission is either whileInUse or always
      _updateStatus(LocationStatus.ready);
      return true;
    } catch (e) {
      debugPrint('Error checking permission status: $e');
      _updateStatus(LocationStatus.error);
      return false;
    }
  }

  // Stop location updates
  Future<void> stopLocationUpdates() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    if (_currentStatus == LocationStatus.active) {
      _updateStatus(LocationStatus.ready);
    }
  }

  // Update the status and notify listeners
  void _updateStatus(LocationStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  // Open location settings on the device
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Failed to open location settings: $e');
      return false;
    }
  }

  // Open app settings (useful when permission is permanently denied)
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Failed to open app settings: $e');
      return false;
    }
  }

  // Properly dispose resources
  void dispose() {
    stopLocationUpdates();
    _serviceStatusSubscription?.cancel();
    _locationController.close();
    _statusController.close();
  }
}
