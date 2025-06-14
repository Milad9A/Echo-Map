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
  final int? distanceToDestination;
  final int? estimatedTimeInSeconds;

  const NavigationActive({
    required this.destination,
    required this.currentLatitude,
    required this.currentLongitude,
    this.isOnRoute = true,
    this.nextManeuver,
    this.distanceToDestination,
    this.estimatedTimeInSeconds,
  });

  NavigationActive copyWith({
    String? destination,
    double? currentLatitude,
    double? currentLongitude,
    bool? isOnRoute,
    String? nextManeuver,
    int? distanceToDestination,
    int? estimatedTimeInSeconds,
  }) {
    return NavigationActive(
      destination: destination ?? this.destination,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      isOnRoute: isOnRoute ?? this.isOnRoute,
      nextManeuver: nextManeuver ?? this.nextManeuver,
      distanceToDestination:
          distanceToDestination ?? this.distanceToDestination,
      estimatedTimeInSeconds:
          estimatedTimeInSeconds ?? this.estimatedTimeInSeconds,
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
    currentLatitude,
    currentLongitude,
    isOnRoute,
    if (nextManeuver != null) nextManeuver!,
    if (distanceToDestination != null) distanceToDestination!,
    if (estimatedTimeInSeconds != null) estimatedTimeInSeconds!,
  ];
}

class NavigationCompleted extends NavigationState {}

class NavigationError extends NavigationState {
  final String message;

  const NavigationError(this.message);

  @override
  List<Object> get props => [message];
}
