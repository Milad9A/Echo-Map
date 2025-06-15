import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_information.dart';

abstract class NavigationEvent extends Equatable {
  const NavigationEvent();

  @override
  List<Object> get props => [];
}

class StartNavigation extends NavigationEvent {
  final String destination;

  const StartNavigation(this.destination);

  @override
  List<Object> get props => [destination];
}

class StartNavigatingRoute extends NavigationEvent {
  final RouteInformation route;

  const StartNavigatingRoute(this.route);

  @override
  List<Object> get props => [route];
}

class StopNavigation extends NavigationEvent {}

class PauseNavigation extends NavigationEvent {}

class ResumeNavigation extends NavigationEvent {}

class UpdateLocation extends NavigationEvent {
  final LatLng position;

  const UpdateLocation(this.position);

  @override
  List<Object> get props => [position];
}

class ApproachingTurn extends NavigationEvent {
  final String turnDirection; // "left", "right", "uturn"
  final RouteStep step;

  const ApproachingTurn({required this.turnDirection, required this.step});

  @override
  List<Object> get props => [turnDirection, step];
}

class TurnCompleted extends NavigationEvent {
  final RouteStep completedStep;

  const TurnCompleted(this.completedStep);

  @override
  List<Object> get props => [completedStep];
}

class StartRerouting extends NavigationEvent {
  final LatLng currentPosition;
  final double deviationDistance;

  const StartRerouting({
    required this.currentPosition,
    required this.deviationDistance,
  });

  @override
  List<Object> get props => [currentPosition, deviationDistance];
}

class ReroutingComplete extends NavigationEvent {
  final RouteInformation newRoute;

  const ReroutingComplete(this.newRoute);

  @override
  List<Object> get props => [newRoute];
}

class ReroutingFailed extends NavigationEvent {
  final String reason;

  const ReroutingFailed(this.reason);

  @override
  List<Object> get props => [reason];
}

class OffRoute extends NavigationEvent {
  final LatLng position;
  final double deviationDistance;

  const OffRoute({required this.position, required this.deviationDistance});

  @override
  List<Object> get props => [position, deviationDistance];
}

class OnRoute extends NavigationEvent {
  final LatLng position;

  const OnRoute(this.position);

  @override
  List<Object> get props => [position];
}

class DestinationReached extends NavigationEvent {
  final LatLng position;

  const DestinationReached(this.position);

  @override
  List<Object> get props => [position];
}

class ApproachingCrossing extends NavigationEvent {
  final LatLng position;

  const ApproachingCrossing({required this.position});

  @override
  List<Object> get props => [position];
}

class ApproachingHazard extends NavigationEvent {
  final String hazardType;
  final LatLng position;

  const ApproachingHazard({required this.hazardType, required this.position});

  @override
  List<Object> get props => [hazardType, position];
}

class RouteDeviation extends NavigationEvent {
  final LatLng position;
  final double deviationDistance;

  const RouteDeviation({
    required this.position,
    required this.deviationDistance,
  });

  @override
  List<Object> get props => [position, deviationDistance];
}

class EmergencyStopRequested extends NavigationEvent {
  final String reason;
  final LatLng? position;

  const EmergencyStopRequested({required this.reason, this.position});

  @override
  List<Object> get props => position != null ? [reason, position!] : [reason];
}

class EmergencyRerouteRequested extends NavigationEvent {
  final String reason;
  final LatLng position;
  final List<LatLng> areaToAvoid;

  const EmergencyRerouteRequested({
    required this.reason,
    required this.position,
    this.areaToAvoid = const [],
  });

  @override
  List<Object> get props => [reason, position, areaToAvoid];
}

class EmergencyDetourRequested extends NavigationEvent {
  final String reason;
  final LatLng position;
  final LatLng hazardLocation;

  const EmergencyDetourRequested({
    required this.reason,
    required this.position,
    required this.hazardLocation,
  });

  @override
  List<Object> get props => [reason, position, hazardLocation];
}

class EmergencyEventReceived extends NavigationEvent {
  final String type;
  final String action;
  final String description;
  final LatLng? location;

  const EmergencyEventReceived({
    required this.type,
    required this.action,
    required this.description,
    this.location,
  });

  @override
  List<Object> get props => [
    type,
    action,
    description,
    if (location != null) location!,
  ];
}

class EmergencyResolved extends NavigationEvent {
  final String resolution;

  const EmergencyResolved(this.resolution);

  @override
  List<Object> get props => [resolution];
}
