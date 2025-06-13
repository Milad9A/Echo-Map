import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class LocationHistoryService {
  // Singleton pattern
  static final LocationHistoryService _instance =
      LocationHistoryService._internal();
  factory LocationHistoryService() => _instance;
  LocationHistoryService._internal();

  // Location service reference
  final LocationService _locationService = LocationService();

  // Configuration
  int _maxHistoryLength = 100;
  Duration _minTimeBetweenPoints = const Duration(seconds: 5);
  double _minDistanceBetweenPoints = 5.0; // meters

  // Location history storage
  final Queue<PositionRecord> _locationHistory = Queue<PositionRecord>();
  StreamSubscription<Position>? _locationSubscription;

  // Controllers
  final StreamController<List<PositionRecord>> _historyController =
      StreamController<List<PositionRecord>>.broadcast();

  // Public streams
  Stream<List<PositionRecord>> get historyStream => _historyController.stream;

  // Getters
  List<PositionRecord> get locationHistory =>
      List.unmodifiable(_locationHistory);
  bool get isTracking => _locationSubscription != null;
  int get historyLength => _locationHistory.length;

  // Initialize and start tracking
  Future<bool> startTracking() async {
    if (isTracking) {
      return true; // Already tracking
    }

    try {
      // Listen to location updates
      _locationSubscription = _locationService.locationStream.listen(
        _processNewPosition,
        onError: (error) {
          debugPrint('Error in location history tracking: $error');
        },
      );

      // If location service isn't already active, start it
      if (!_locationService.isTracking) {
        return await _locationService.startLocationUpdates();
      }
      return true;
    } catch (e) {
      debugPrint('Failed to start location history tracking: $e');
      return false;
    }
  }

  // Stop tracking
  void stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  // Clear history
  void clearHistory() {
    _locationHistory.clear();
    _notifyHistoryListeners();
  }

  // Process new position
  void _processNewPosition(Position position) {
    // Create position record with timestamp
    final record = PositionRecord(
      position: position,
      timestamp: DateTime.now(),
    );

    // Check if we should add this point
    if (_shouldAddPoint(record)) {
      _addToHistory(record);
    }
  }

  // Decide if point should be added based on time and distance criteria
  bool _shouldAddPoint(PositionRecord record) {
    // Always add the first point
    if (_locationHistory.isEmpty) {
      return true;
    }

    final lastPoint = _locationHistory.last;

    // Check time between points
    final timeDifference = record.timestamp.difference(lastPoint.timestamp);
    if (timeDifference < _minTimeBetweenPoints) {
      return false;
    }

    // Check distance between points
    final distance = Geolocator.distanceBetween(
      lastPoint.position.latitude,
      lastPoint.position.longitude,
      record.position.latitude,
      record.position.longitude,
    );

    return distance >= _minDistanceBetweenPoints;
  }

  // Add to history and maintain max length
  void _addToHistory(PositionRecord record) {
    _locationHistory.add(record);

    // Trim history if needed
    while (_locationHistory.length > _maxHistoryLength) {
      _locationHistory.removeFirst();
    }

    // Notify listeners
    _notifyHistoryListeners();
  }

  // Configure history tracking settings
  void configure({
    int? maxHistoryLength,
    Duration? minTimeBetweenPoints,
    double? minDistanceBetweenPoints,
  }) {
    if (maxHistoryLength != null && maxHistoryLength > 0) {
      _maxHistoryLength = maxHistoryLength;
      // Trim history if needed after changing max length
      while (_locationHistory.length > _maxHistoryLength) {
        _locationHistory.removeFirst();
      }
    }

    if (minTimeBetweenPoints != null) {
      _minTimeBetweenPoints = minTimeBetweenPoints;
    }

    if (minDistanceBetweenPoints != null && minDistanceBetweenPoints > 0) {
      _minDistanceBetweenPoints = minDistanceBetweenPoints;
    }
  }

  // Calculate total distance of the path
  double calculateTotalDistance() {
    if (_locationHistory.length < 2) return 0.0;

    double totalDistance = 0.0;
    PositionRecord? previousRecord;

    for (final record in _locationHistory) {
      if (previousRecord != null) {
        totalDistance += Geolocator.distanceBetween(
          previousRecord.position.latitude,
          previousRecord.position.longitude,
          record.position.latitude,
          record.position.longitude,
        );
      }
      previousRecord = record;
    }

    return totalDistance;
  }

  // Calculate average speed (m/s)
  double calculateAverageSpeed() {
    if (_locationHistory.length < 2) return 0.0;

    final totalDistance = calculateTotalDistance();
    final firstTimestamp = _locationHistory.first.timestamp;
    final lastTimestamp = _locationHistory.last.timestamp;
    final durationSeconds = lastTimestamp.difference(firstTimestamp).inSeconds;

    if (durationSeconds <= 0) return 0.0;
    return totalDistance / durationSeconds;
  }

  // Notify history listeners
  void _notifyHistoryListeners() {
    if (!_historyController.isClosed) {
      _historyController.add(List.unmodifiable(_locationHistory));
    }
  }

  // Clean up
  void dispose() {
    stopTracking();
    _historyController.close();
  }
}

// Class to store position with timestamp
class PositionRecord {
  final Position position;
  final DateTime timestamp;

  PositionRecord({required this.position, required this.timestamp});

  @override
  String toString() =>
      'PositionRecord(lat: ${position.latitude}, '
      'lng: ${position.longitude}, time: $timestamp)';
}
