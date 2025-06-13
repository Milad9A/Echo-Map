import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_service.dart';
import '../../services/location_history_service.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object?> get props => [];
}

class LocationInitialize extends LocationEvent {}

class LocationPermissionRequest extends LocationEvent {}

class LocationStart extends LocationEvent {
  final bool trackHistory;
  final bool inBackground;

  const LocationStart({this.trackHistory = true, this.inBackground = false});

  @override
  List<Object?> get props => [trackHistory, inBackground];
}

class LocationStop extends LocationEvent {}

class LocationPositionUpdate extends LocationEvent {
  final Position position;

  const LocationPositionUpdate(this.position);

  @override
  List<Object?> get props => [position];
}

class LocationStatusUpdate extends LocationEvent {
  final LocationStatus status;

  const LocationStatusUpdate(this.status);

  @override
  List<Object?> get props => [status];
}

class LocationHistoryUpdate extends LocationEvent {
  final List<PositionRecord> history;

  const LocationHistoryUpdate(this.history);

  @override
  List<Object?> get props => [history];
}

class LocationStreamError extends LocationEvent {
  final String message;

  const LocationStreamError(this.message);

  @override
  List<Object?> get props => [message];
}

class LocationOpenSettings extends LocationEvent {
  final bool appSettings;

  const LocationOpenSettings({this.appSettings = false});

  @override
  List<Object?> get props => [appSettings];
}

class LocationHistoryClear extends LocationEvent {}
