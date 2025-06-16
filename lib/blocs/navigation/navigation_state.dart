import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_information.dart';

abstract class NavigationState extends Equatable {
  const NavigationState();

  @override
  List<Object> get props => [];
}

/// Idle state - no active navigation
class NavigationIdle extends NavigationState {}

/// Active navigation state - following a route
class NavigationActive extends NavigationState {
  final String destination;
  final LatLng currentPosition;
  final RouteInformation route;
  final bool isOnRoute;
  final RouteStep? nextStep;
  final int? distanceToNextStep;
  final int? distanceToDestination;
  final int? estimatedTimeInSeconds;
  final DateTime lastUpdated;

  NavigationActive({
    required this.destination,
    required this.currentPosition,
    required this.route,
    this.isOnRoute = true,
    this.nextStep,
    this.distanceToNextStep,
    this.distanceToDestination,
    this.estimatedTimeInSeconds,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  NavigationActive copyWith({
    String? destination,
    LatLng? currentPosition,
    RouteInformation? route,
    bool? isOnRoute,
    RouteStep? nextStep,
    int? distanceToNextStep,
    int? distanceToDestination,
    int? estimatedTimeInSeconds,
    DateTime? lastUpdated,
  }) {
    return NavigationActive(
      destination: destination ?? this.destination,
      currentPosition: currentPosition ?? this.currentPosition,
      route: route ?? this.route,
      isOnRoute: isOnRoute ?? this.isOnRoute,
      nextStep: nextStep ?? this.nextStep,
      distanceToNextStep: distanceToNextStep ?? this.distanceToNextStep,
      distanceToDestination:
          distanceToDestination ?? this.distanceToDestination,
      estimatedTimeInSeconds:
          estimatedTimeInSeconds ?? this.estimatedTimeInSeconds,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  String get distanceText {
    if (distanceToDestination == null) return 'Unknown';

    if (distanceToDestination! < 1000) {
      return '$distanceToDestination m';
    } else {
      final km = distanceToDestination! / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  String get timeText {
    if (estimatedTimeInSeconds == null) return 'Unknown';

    final minutes = (estimatedTimeInSeconds! / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes / 60;
      final remainingMinutes = minutes % 60;
      return '${hours.floor()} hr ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    }
  }

  @override
  List<Object> get props => [
        destination,
        currentPosition,
        route,
        isOnRoute,
        lastUpdated,
        if (nextStep != null) nextStep!,
        if (distanceToNextStep != null) distanceToNextStep!,
        if (distanceToDestination != null) distanceToDestination!,
        if (estimatedTimeInSeconds != null) estimatedTimeInSeconds!,
      ];
}

/// Rerouting state - calculating a new route
class NavigationRerouting extends NavigationState {
  final LatLng currentPosition;
  final String destination;
  final double deviationDistance;
  final DateTime startedAt;

  NavigationRerouting({
    required this.currentPosition,
    required this.destination,
    required this.deviationDistance,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  @override
  List<Object> get props => [
        currentPosition,
        destination,
        deviationDistance,
        startedAt,
      ];
}

/// Arrived state - destination reached
class NavigationArrived extends NavigationState {
  final String destination;
  final LatLng finalPosition;
  final DateTime arrivedAt;
  final int? totalDistance;
  final int? totalDuration;

  NavigationArrived({
    required this.destination,
    required this.finalPosition,
    this.totalDistance,
    this.totalDuration,
    DateTime? arrivedAt,
  }) : arrivedAt = arrivedAt ?? DateTime.now();

  @override
  List<Object> get props => [
        destination,
        finalPosition,
        arrivedAt,
        if (totalDistance != null) totalDistance!,
        if (totalDuration != null) totalDuration!,
      ];
}

/// Navigation error state
class NavigationError extends NavigationState {
  final String message;
  final DateTime occurredAt;
  final bool isFatal;

  NavigationError({
    required this.message,
    this.isFatal = false,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();

  @override
  List<Object> get props => [message, occurredAt, isFatal];
}

/// Emergency navigation state
class NavigationEmergency extends NavigationState {
  final String emergencyType;
  final String description;
  final LatLng? currentPosition;
  final DateTime occurredAt;
  final bool isResolvable;
  final String? actionRequired;

  NavigationEmergency({
    required this.emergencyType,
    required this.description,
    this.currentPosition,
    this.isResolvable = true,
    this.actionRequired,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();

  @override
  List<Object> get props => [
        emergencyType,
        description,
        occurredAt,
        isResolvable,
        if (currentPosition != null) currentPosition!,
        if (actionRequired != null) actionRequired!,
      ];
}

/// Paused navigation state - navigation is temporarily stopped but can be resumed
class NavigationPaused extends NavigationState {
  final String destination;
  final LatLng currentPosition;
  final RouteInformation route;
  final RouteStep? nextStep;
  final int? distanceToDestination;
  final int? estimatedTimeInSeconds;
  final DateTime pausedAt;

  NavigationPaused({
    required this.destination,
    required this.currentPosition,
    required this.route,
    this.nextStep,
    this.distanceToDestination,
    this.estimatedTimeInSeconds,
    DateTime? pausedAt,
  }) : pausedAt = pausedAt ?? DateTime.now();

  String get distanceText {
    if (distanceToDestination == null) return 'Unknown';

    if (distanceToDestination! < 1000) {
      return '$distanceToDestination m';
    } else {
      final km = distanceToDestination! / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  String get timeText {
    if (estimatedTimeInSeconds == null) return 'Unknown';

    final minutes = (estimatedTimeInSeconds! / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes / 60;
      final remainingMinutes = minutes % 60;
      return '${hours.floor()} hr ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    }
  }

  @override
  List<Object> get props => [
        destination,
        currentPosition,
        route,
        pausedAt,
        if (nextStep != null) nextStep!,
        if (distanceToDestination != null) distanceToDestination!,
        if (estimatedTimeInSeconds != null) estimatedTimeInSeconds!,
      ];
}
