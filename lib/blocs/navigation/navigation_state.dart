import 'package:equatable/equatable.dart';

abstract class NavigationState extends Equatable {
  const NavigationState();

  @override
  List<Object> get props => [];
}

class NavigationInitial extends NavigationState {}

class NavigationActive extends NavigationState {
  final String destination;
  final double currentLatitude;
  final double currentLongitude;
  final bool isOnRoute;
  final String? nextManeuver;

  const NavigationActive({
    required this.destination,
    required this.currentLatitude,
    required this.currentLongitude,
    this.isOnRoute = true,
    this.nextManeuver,
  });

  NavigationActive copyWith({
    String? destination,
    double? currentLatitude,
    double? currentLongitude,
    bool? isOnRoute,
    String? nextManeuver,
  }) {
    return NavigationActive(
      destination: destination ?? this.destination,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      isOnRoute: isOnRoute ?? this.isOnRoute,
      nextManeuver: nextManeuver ?? this.nextManeuver,
    );
  }

  @override
  List<Object> get props => [
    destination,
    currentLatitude,
    currentLongitude,
    isOnRoute,
    if (nextManeuver != null) nextManeuver!,
  ];
}

class NavigationCompleted extends NavigationState {}

class NavigationError extends NavigationState {
  final String message;

  const NavigationError(this.message);

  @override
  List<Object> get props => [message];
}
