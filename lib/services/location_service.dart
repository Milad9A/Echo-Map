import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'location_timeout_handler.dart';

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
  LocationAccuracy _currentAccuracy =
      LocationAccuracy.best; // Changed from high to best
  bool _inBackground = false;
  int _distanceFilter = 1; // Changed from 5 to 1 meter for more precision

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

  // Initialize location services with comprehensive error handling
  Future<bool> initializeLocationServices() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return false;
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return false;
      }

      // Try to get an initial position with timeout
      try {
        final position = await getCurrentPositionWithRetry();
        if (position != null) {
          debugPrint('Location services initialized successfully');
          return true;
        }
      } catch (e) {
        debugPrint('Could not get initial position: $e');
        // Still return true if permissions are OK, position might be available later
        return true;
      }

      return true;
    } catch (e) {
      debugPrint('Error initializing location services: $e');
      return false;
    }
  }

  // Get current position with retry logic
  Future<Position?> getCurrentPositionWithRetry({
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy:
                attempt == 0 ? LocationAccuracy.high : LocationAccuracy.medium,
            timeLimit: timeout,
          ),
        );

        debugPrint(
            'Got position on attempt ${attempt + 1}: ${position.latitude}, ${position.longitude}');
        return position;
      } on TimeoutException catch (e) {
        debugPrint('Location timeout on attempt ${attempt + 1}: $e');
        if (attempt == maxRetries - 1) {
          // Last attempt, try to get last known position
          final lastKnown = await getLastKnownPosition();
          if (lastKnown != null) {
            debugPrint('Using last known position as fallback');
            return lastKnown;
          }
          throw LocationTimeoutException(
              'Failed to get position after $maxRetries attempts');
        }
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (e) {
        debugPrint('Location error on attempt ${attempt + 1}: $e');
        if (attempt == maxRetries - 1) {
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    return null;
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
          accuracy:
              LocationAccuracy.best, // Always use best for single requests
          timeLimit: const Duration(seconds: 10), // Reduced timeout
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
              intervalDuration: const Duration(
                  milliseconds: 500), // Update every 500ms in background
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
              timeLimit:
                  const Duration(seconds: 10), // Reduced from 30 to 10 seconds
            );

      // For iOS, use more frequent updates
      if (!_inBackground) {
        final iosSettings = AppleSettings(
          accuracy: _currentAccuracy,
          activityType: ActivityType.other,
          distanceFilter: _distanceFilter,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );

        _positionStreamSubscription = Geolocator.getPositionStream(
          locationSettings: iosSettings,
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
      } else {
        // Use Android/general settings for background
        _positionStreamSubscription = Geolocator.getPositionStream(
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
      }

      return true;
    } catch (e) {
      debugPrint('Failed to start location updates: $e');
      _updateStatus(LocationStatus.error);
      return false;
    }
  }

  // Improved position stream with timeout handling
  Stream<Position> getPositionStream({
    Duration timeout = const Duration(seconds: 8),
    int distanceFilter = 5,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).timeout(
      timeout,
      onTimeout: (sink) {
        debugPrint('Position stream timeout, attempting recovery...');
        _handleLocationTimeout(sink);
      },
    ).handleError((error) {
      debugPrint('Position stream error: $error');
      // Add error to stream or handle appropriately
    });
  }

  // Handle location timeout by trying to get last known position
  void _handleLocationTimeout(EventSink<Position> sink) {
    getLastKnownPosition().then((position) {
      if (position != null) {
        debugPrint('Using last known position after timeout');
        sink.add(position);
      } else {
        sink.addError(LocationTimeoutException(
            'Position stream timeout and no last known position available'));
      }
    });
  }

  // Get last known position with better error handling
  Future<Position?> getLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: false,
      );

      if (position != null) {
        // Check if the position is too old (older than 5 minutes)
        final now = DateTime.now();
        final positionTime = position.timestamp;
        final timeDifference = now.difference(positionTime);

        if (timeDifference.inMinutes > 5) {
          debugPrint(
              'Last known position is too old: ${timeDifference.inMinutes} minutes');
          return null;
        }

        debugPrint(
            'Using last known position from ${timeDifference.inSeconds} seconds ago');
        return position;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting last known position: $e');
      return null;
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

  /// Initialize location services with timeout handling
  Future<bool> initializeWithTimeoutHandling() async {
    try {
      // Use the timeout handler for robust initialization
      final isSetupValid = await LocationTimeoutHandler.isLocationSetupValid();
      if (!isSetupValid) {
        debugPrint('Location setup invalid, requesting permissions...');
        final permissionsOk =
            await LocationTimeoutHandler.requestLocationPermissions();
        if (!permissionsOk) {
          debugPrint('Could not get location permissions');
          return false;
        }
      }

      // Try to get an initial position to verify everything works
      final initialPosition =
          await LocationTimeoutHandler.getCurrentPositionSafely(
        timeout: const Duration(seconds: 10),
        maxRetries: 2,
      );

      if (initialPosition != null) {
        debugPrint('Location service initialized successfully');
        return true;
      } else {
        debugPrint(
            'Location service initialized but could not get initial position');
        // Still return true as location might work later
        return true;
      }
    } catch (e) {
      debugPrint(
          'Error initializing location service with timeout handling: $e');
      return false;
    }
  }
}

// Custom exceptions for location handling
class LocationTimeoutException implements Exception {
  final String message;
  LocationTimeoutException(this.message);
  @override
  String toString() => 'LocationTimeoutException: $message';
}

class LocationPermissionException implements Exception {
  final String message;
  LocationPermissionException(this.message);
  @override
  String toString() => 'LocationPermissionException: $message';
}

class LocationServiceDisabledException implements Exception {
  final String message;
  LocationServiceDisabledException(this.message);
  @override
  String toString() => 'LocationServiceDisabledException: $message';
}
