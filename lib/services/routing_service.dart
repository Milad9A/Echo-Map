import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RouteInformation;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../models/waypoint.dart';
import '../models/route_information.dart';
import '../utils/env.dart'; // Import env utility instead of secrets

enum TravelMode { walking, cycling, driving, transit }

class RoutingService {
  // Singleton pattern
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  // HTTP client
  final Dio _dio = Dio();
  final PolylinePoints _polylinePoints = PolylinePoints();

  // Initialize the service
  Future<void> initialize() async {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  // Calculate route between two points
  Future<RouteInformation?> calculateRoute(
    LatLng origin,
    LatLng destination, {
    List<LatLng> waypoints = const [],
    TravelMode mode = TravelMode.walking,
  }) async {
    try {
      final apiKey = Env.googleMapsApiKey;
      if (apiKey.isEmpty) {
        debugPrint('Google Maps API key not found');
        return null;
      }

      // Build API URL
      final url =
          _buildDirectionsUrl(origin, destination, mode, waypoints, apiKey);

      debugPrint('Requesting directions from: $url');

      // Make API request
      final response = await _dio.get(url);

      if (response.statusCode != 200) {
        debugPrint('Directions API returned status: ${response.statusCode}');
        return null;
      }

      final data = response.data;

      if (data['status'] != 'OK') {
        debugPrint(
            'Directions API error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
        return null;
      }

      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        debugPrint('No routes found in response');
        return null;
      }

      // Parse the route
      return _parseRoute(data['routes'][0], origin, destination);
    } catch (e) {
      debugPrint('Error calculating route: $e');
      return null;
    }
  }

  // Build Google Directions API URL
  String _buildDirectionsUrl(
    LatLng origin,
    LatLng destination,
    TravelMode mode,
    List<LatLng> waypoints,
    String apiKey,
  ) {
    final buffer = StringBuffer();
    buffer.write('https://maps.googleapis.com/maps/api/directions/json?');

    // Origin and destination
    buffer.write('origin=${origin.latitude},${origin.longitude}');
    buffer
        .write('&destination=${destination.latitude},${destination.longitude}');

    // Travel mode
    buffer.write('&mode=${_getTravelModeString(mode)}');

    // Waypoints
    if (waypoints.isNotEmpty) {
      final waypointStr =
          waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|');
      buffer.write('&waypoints=$waypointStr');
    }

    // Additional parameters
    buffer.write('&units=metric');
    buffer.write('&language=en');
    buffer.write('&alternatives=false');
    buffer.write('&key=$apiKey');

    return buffer.toString();
  }

  // Convert TravelMode enum to API string
  String _getTravelModeString(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return 'walking';
      case TravelMode.cycling:
        return 'bicycling';
      case TravelMode.driving:
        return 'driving';
      case TravelMode.transit:
        return 'transit';
    }
  }

  // Parse Google Directions API response into RouteInformation
  RouteInformation? _parseRoute(
    Map<String, dynamic> route,
    LatLng origin,
    LatLng destination,
  ) {
    try {
      final legs = route['legs'] as List;
      if (legs.isEmpty) return null;

      final firstLeg = legs[0];

      // Extract basic route info
      final distance = firstLeg['distance']['value'] as int; // meters
      final duration = firstLeg['duration']['value'] as int; // seconds

      // Decode polyline
      final polylineString = route['overview_polyline']['points'] as String;
      final polylineCoordinates =
          _polylinePoints.decodePolyline(polylineString);

      final polylinePoints = polylineCoordinates
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      // Parse steps
      final steps = _parseSteps(firstLeg['steps'] as List);

      // Create waypoints
      final waypoints = [
        Waypoint(
          position: origin,
          name: 'Starting Point',
          type: WaypointType.origin,
        ),
        Waypoint(
          position: destination,
          name: 'Destination',
          type: WaypointType.destination,
        ),
      ];

      return RouteInformation(
        polylinePoints: polylinePoints,
        distanceMeters: distance,
        durationSeconds: duration,
        steps: steps,
        waypoints: waypoints,
      );
    } catch (e) {
      debugPrint('Error parsing route: $e');
      return null;
    }
  }

  // Parse route steps from Google Directions API
  List<RouteStep> _parseSteps(List<dynamic> stepsData) {
    final steps = <RouteStep>[];

    for (final stepData in stepsData) {
      try {
        final startLocation = stepData['start_location'];
        final endLocation = stepData['end_location'];

        final step = RouteStep(
          instruction:
              _cleanHtmlInstruction(stepData['html_instructions'] as String),
          maneuver: stepData['maneuver'] as String? ?? 'straight',
          distanceMeters: stepData['distance']['value'] as int,
          durationSeconds: stepData['duration']['value'] as int,
          startLocation: LatLng(
            startLocation['lat'] as double,
            startLocation['lng'] as double,
          ),
          endLocation: LatLng(
            endLocation['lat'] as double,
            endLocation['lng'] as double,
          ),
        );

        steps.add(step);
      } catch (e) {
        debugPrint('Error parsing step: $e');
        // Continue with other steps
      }
    }

    return steps;
  }

  // Clean HTML tags from instruction text
  String _cleanHtmlInstruction(String htmlInstruction) {
    // Remove HTML tags
    String cleaned = htmlInstruction.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode HTML entities
    cleaned = cleaned
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    return cleaned.trim();
  }

  // Dispose resources
  void dispose() {
    _dio.close();
  }
}
