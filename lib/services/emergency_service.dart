import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_information.dart';
import '../services/vibration_service.dart';
import '../services/routing_service.dart';
import '../services/location_service.dart';

enum EmergencyType {
  userInitiated, // User manually triggered emergency
  hazardAhead, // Hazard detected on path
  unsafeCrossing, // Dangerous crossing detected
  navigationError, // Critical error in navigation
  timeConstraint, // Time-based emergency (e.g., late at night)
  batteryLow, // Device battery critically low
  connectivity, // Lost connectivity in unsafe area
  other, // Other emergencies
}

enum EmergencyAction {
  stop, // Stop navigation immediately
  reroute, // Find alternative route
  detour, // Find route avoiding specific area
  pause, // Pause navigation
  alertUser, // Just alert the user but continue
  slowDown, // Suggest slowing down
}

class EmergencyEvent {
  final EmergencyType type;
  final EmergencyAction action;
  final String description;
  final DateTime timestamp;
  final LatLng? location;
  final Map<String, dynamic>? metadata;

  EmergencyEvent({
    required this.type,
    required this.action,
    required this.description,
    DateTime? timestamp,
    this.location,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  int get priorityLevel {
    switch (type) {
      case EmergencyType.userInitiated:
        return 10; // Highest priority
      case EmergencyType.hazardAhead:
        return 9;
      case EmergencyType.unsafeCrossing:
        return 8;
      case EmergencyType.navigationError:
        return 7;
      case EmergencyType.batteryLow:
        return 6;
      case EmergencyType.timeConstraint:
        return 5;
      case EmergencyType.connectivity:
        return 4;
      case EmergencyType.other:
        return 3;
    }
  }

  bool get requiresImmediateAction =>
      action == EmergencyAction.stop || priorityLevel >= 8;
}

class EmergencyService {
  // Singleton pattern
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  // Services
  final VibrationService _vibrationService = VibrationService();
  final RoutingService _routingService = RoutingService();
  final LocationService _locationService = LocationService();

  // Stream controllers
  final _emergencyController = StreamController<EmergencyEvent>.broadcast();
  final _emergencyResolvedController =
      StreamController<EmergencyEvent>.broadcast();
  final _rerouteController = StreamController<RouteInformation>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  // Public streams
  Stream<EmergencyEvent> get emergencyStream => _emergencyController.stream;
  Stream<EmergencyEvent> get emergencyResolvedStream =>
      _emergencyResolvedController.stream;
  Stream<RouteInformation> get rerouteStream => _rerouteController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // State
  bool _isActive = false;
  EmergencyEvent? _currentEmergency;
  final Set<String> _avoidAreas = {}; // Areas to avoid in rerouting
  DateTime? _lastEmergencyTime;

  // Configuration
  static const int _minTimeBetweenEmergencies = 10; // seconds

  // Getters
  bool get isActive => _isActive;
  EmergencyEvent? get currentEmergency => _currentEmergency;

  // Initialize emergency service
  Future<void> initialize() async {
    _isActive = true;
    _log('Emergency service initialized');
  }

  // Trigger an emergency
  Future<bool> triggerEmergency({
    required EmergencyType type,
    required EmergencyAction action,
    required String description,
    LatLng? location,
    Map<String, dynamic>? metadata,
  }) async {
    // Check if we've had a very recent emergency
    if (_lastEmergencyTime != null) {
      final timeSinceLastEmergency =
          DateTime.now().difference(_lastEmergencyTime!).inSeconds;
      if (timeSinceLastEmergency < _minTimeBetweenEmergencies) {
        _log('Emergency ignored - too soon after previous emergency');
        return false;
      }
    }

    // Create emergency event
    final event = EmergencyEvent(
      type: type,
      action: action,
      description: description,
      location: location ?? await _getCurrentPosition(),
      metadata: metadata,
    );

    // Update state
    _currentEmergency = event;
    _lastEmergencyTime = event.timestamp;

    // Notify listeners
    _emergencyController.add(event);
    _log('Emergency triggered: ${event.description}');

    // Provide immediate feedback
    await _provideEmergencyFeedback(event);

    return true;
  }

  // User manually initiates emergency stop
  Future<bool> initiateEmergencyStop({
    String reason = "User emergency stop",
    Map<String, dynamic>? metadata,
  }) async {
    return triggerEmergency(
      type: EmergencyType.userInitiated,
      action: EmergencyAction.stop,
      description: reason,
      metadata: metadata,
    );
  }

  // Request an emergency reroute
  Future<RouteInformation?> requestEmergencyReroute({
    required LatLng origin,
    required LatLng destination,
    String reason = "Emergency reroute",
    List<LatLng> areaToAvoid = const [],
    TravelMode mode = TravelMode.walking,
  }) async {
    try {
      // Log the request
      _log('Emergency reroute requested: $reason');

      // Provide rerouting feedback
      _vibrationService.emergencyReroutingFeedback();

      // Add areas to avoid
      if (areaToAvoid.isNotEmpty) {
        for (final point in areaToAvoid) {
          _avoidAreas.add('${point.latitude},${point.longitude}');
        }
      }

      // Calculate new route avoiding danger areas
      // In a real implementation, you would pass the avoid areas to the routing service
      final newRoute = await _routingService.calculateRoute(
        origin,
        destination,
        mode: mode,
      );

      if (newRoute == null) {
        _log('Failed to calculate emergency reroute');
        return null;
      }

      // Notify listeners
      _rerouteController.add(newRoute);
      _log('Emergency reroute calculated');

      // Provide feedback for successful reroute
      _vibrationService.newRouteFeedback();

      return newRoute;
    } catch (e) {
      _log('Error calculating emergency reroute: $e');
      return null;
    }
  }

  // Resolve the current emergency
  void resolveEmergency({String? resolution}) {
    if (_currentEmergency != null) {
      _log('Emergency resolved: ${resolution ?? "No details provided"}');
      _emergencyResolvedController.add(_currentEmergency!);
      _currentEmergency = null;
    }
  }

  // Add an area to avoid in future routes
  void addAreaToAvoid(LatLng center, {double radiusMeters = 100}) {
    final areaKey = '${center.latitude},${center.longitude}';
    _avoidAreas.add(areaKey);
    _log('Added area to avoid: $areaKey with radius ${radiusMeters}m');
  }

  // Clear all areas to avoid
  void clearAreasToAvoid() {
    _avoidAreas.clear();
    _log('Cleared all areas to avoid');
  }

  // Provide appropriate haptic feedback based on emergency
  Future<void> _provideEmergencyFeedback(EmergencyEvent event) async {
    switch (event.action) {
      case EmergencyAction.stop:
        await _vibrationService.emergencyStopFeedback();
        break;
      case EmergencyAction.reroute:
        await _vibrationService.emergencyReroutingFeedback();
        break;
      case EmergencyAction.detour:
        await _vibrationService.emergencyReroutingFeedback();
        break;
      case EmergencyAction.pause:
        await _vibrationService.pauseNavigationFeedback();
        break;
      case EmergencyAction.alertUser:
        await _vibrationService.hazardWarningFeedback(
          intensity: VibrationService.highIntensity,
        );
        break;
      case EmergencyAction.slowDown:
        await _vibrationService.slowDownFeedback();
        break;
    }
  }

  // Get current position
  Future<LatLng?> _getCurrentPosition() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      return LatLng(position.latitude, position.longitude);
    }
    return null;
  }

  // Log messages
  void _log(String message) {
    debugPrint('🚨 [Emergency] $message');
    _statusController.add(message);
  }

  // Clean up resources
  void dispose() {
    _isActive = false;
    _emergencyController.close();
    _emergencyResolvedController.close();
    _rerouteController.close();
    _statusController.close();
  }
}
