import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_history_service.dart';

abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}

class LocationPermissionDenied extends LocationState {}

class LocationPermissionPermanentlyDenied extends LocationState {}

class LocationServiceDisabled extends LocationState {}

class LocationReady extends LocationState {
  final Position? lastPosition;

  const LocationReady({this.lastPosition});

  @override
  List<Object?> get props => [lastPosition];
}

class LocationTracking extends LocationState {
  final Position currentPosition;
  final List<PositionRecord>? pathHistory;
  final bool isTrackingHistory;
  final bool isInBackground;

  const LocationTracking({
    required this.currentPosition,
    this.pathHistory,
    this.isTrackingHistory = false,
    this.isInBackground = false,
  });

  @override
  List<Object?> get props => [
    currentPosition,
    pathHistory,
    isTrackingHistory,
    isInBackground,
  ];

  LocationTracking copyWith({
    Position? currentPosition,
    List<PositionRecord>? pathHistory,
    bool? isTrackingHistory,
    bool? isInBackground,
  }) {
    return LocationTracking(
      currentPosition: currentPosition ?? this.currentPosition,
      pathHistory: pathHistory ?? this.pathHistory,
      isTrackingHistory: isTrackingHistory ?? this.isTrackingHistory,
      isInBackground: isInBackground ?? this.isInBackground,
    );
  }
}

class LocationError extends LocationState {
  final String message;

  const LocationError(this.message);

  @override
  List<Object?> get props => [message];
}
