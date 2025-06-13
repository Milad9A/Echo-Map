import 'package:equatable/equatable.dart';

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

class StopNavigation extends NavigationEvent {}

class UpdateLocation extends NavigationEvent {
  final double latitude;
  final double longitude;

  const UpdateLocation({required this.latitude, required this.longitude});

  @override
  List<Object> get props => [latitude, longitude];
}

class ApproachingTurn extends NavigationEvent {
  final String turnDirection; // "left", "right", "uturn"

  const ApproachingTurn(this.turnDirection);

  @override
  List<Object> get props => [turnDirection];
}

class OffRoute extends NavigationEvent {}

class OnRoute extends NavigationEvent {}

class ReachedDestination extends NavigationEvent {}

class ApproachingCrossing extends NavigationEvent {}

class ApproachingHazard extends NavigationEvent {
  final String hazardType;

  const ApproachingHazard(this.hazardType);

  @override
  List<Object> get props => [hazardType];
}
