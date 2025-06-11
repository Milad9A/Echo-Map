import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  final StreamController<Position> _locationController =
      StreamController<Position>.broadcast();
  StreamSubscription<Position>? _positionStreamSubscription;

  Stream<Position> get locationStream => _locationController.stream;

  // Request location permissions
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      return false;
    }

    // Permissions are granted
    return true;
  }

  // Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  // Start location updates
  Future<void> startLocationUpdates() async {
    final hasPermission = await requestPermission();

    if (!hasPermission) {
      _locationController.addError('Location permission not granted');
      return;
    }

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // Update every 5 meters
          ),
        ).listen(
          (Position position) {
            _locationController.add(position);
          },
          onError: (error) {
            _locationController.addError('Failed to get location: $error');
          },
        );
  }

  // Stop location updates
  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  // Dispose resources
  void dispose() {
    stopLocationUpdates();
    _locationController.close();
  }
}
