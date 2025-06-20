import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Helper class to handle location timeout issues and provide robust location services
class LocationTimeoutHandler {
  static const Duration defaultTimeout = Duration(seconds: 8);
  static const int defaultMaxRetries = 3;
  static const int maxLastKnownPositionAgeMinutes = 5;

  /// Get current position with comprehensive timeout and retry handling
  static Future<Position?> getCurrentPositionSafely({
    Duration timeout = defaultTimeout,
    int maxRetries = defaultMaxRetries,
    bool enableHighAccuracy = true,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        debugPrint('Location attempt ${attempt + 1}/$maxRetries');

        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: (enableHighAccuracy && attempt == 0)
                ? LocationAccuracy.high
                : LocationAccuracy.medium,
            timeLimit: timeout,
          ),
        );

        debugPrint(
            'Location success: ${position.latitude}, ${position.longitude}');
        return position;
      } on TimeoutException catch (e) {
        debugPrint('Location timeout on attempt ${attempt + 1}: $e');

        // On last attempt, try last known position
        if (attempt == maxRetries - 1) {
          final lastKnown = await _getValidLastKnownPosition();
          if (lastKnown != null) {
            debugPrint('Using last known position as fallback');
            return lastKnown;
          }
          debugPrint('All location attempts failed');
          return null;
        }

        // Progressive delay between retries
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (e) {
        debugPrint('Location error on attempt ${attempt + 1}: $e');

        if (attempt == maxRetries - 1) {
          // Last attempt failed, try last known position
          final lastKnown = await _getValidLastKnownPosition();
          if (lastKnown != null) {
            debugPrint('Using last known position after error');
            return lastKnown;
          }
          return null;
        }

        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }

    return null;
  }

  /// Get a position stream with timeout handling
  static Stream<Position> getPositionStreamSafely({
    Duration timeout = defaultTimeout,
    int distanceFilter = 5,
  }) async* {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    await for (final position in Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).timeout(timeout, onTimeout: (sink) {
      debugPrint('Position stream timeout, trying recovery...');
      _handleStreamTimeout(sink);
    })) {
      yield position;
    }
  }

  /// Handle stream timeout by providing last known position
  static void _handleStreamTimeout(EventSink<Position> sink) {
    _getValidLastKnownPosition().then((position) {
      if (position != null) {
        debugPrint('Recovered with last known position');
        sink.add(position);
      } else {
        sink.addError(
          TimeoutException(
            'Position stream timeout and no valid last known position',
            defaultTimeout,
          ),
        );
      }
    });
  }

  /// Get last known position if it's recent enough
  static Future<Position?> _getValidLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();

      if (position == null) {
        debugPrint('No last known position available');
        return null;
      }

      final now = DateTime.now();
      final positionAge = now.difference(position.timestamp);

      if (positionAge.inMinutes > maxLastKnownPositionAgeMinutes) {
        debugPrint(
            'Last known position is too old: ${positionAge.inMinutes} minutes');
        return null;
      }

      debugPrint(
          'Valid last known position from ${positionAge.inSeconds} seconds ago');
      return position;
    } catch (e) {
      debugPrint('Error getting last known position: $e');
      return null;
    }
  }

  /// Check if location services are properly set up
  static Future<bool> isLocationSetupValid() async {
    try {
      // Check if location services are enabled
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('Location services are disabled');
        return false;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions not granted: $permission');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking location setup: $e');
      return false;
    }
  }

  /// Request location permissions with proper error handling
  static Future<bool> requestLocationPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions permanently denied');
        return false;
      }

      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions denied by user');
        return false;
      }

      debugPrint('Location permissions granted: $permission');
      return true;
    } catch (e) {
      debugPrint('Error requesting location permissions: $e');
      return false;
    }
  }
}
