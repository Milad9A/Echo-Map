import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_service.dart';
import '../../services/location_history_service.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationService _locationService = LocationService();
  final LocationHistoryService _historyService = LocationHistoryService();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<LocationStatus>? _statusSubscription;
  StreamSubscription<List<PositionRecord>>? _historySubscription;

  LocationBloc() : super(LocationInitial()) {
    on<LocationInitialize>(_onInitialize);
    on<LocationPermissionRequest>(_onPermissionRequest);
    on<LocationStart>(_onStart);
    on<LocationStop>(_onStop);
    on<LocationPositionUpdate>(_onPositionUpdate);
    on<LocationStatusUpdate>(_onStatusUpdate);
    on<LocationHistoryUpdate>(_onHistoryUpdate);
    on<LocationStreamError>(_onStreamError);
    on<LocationOpenSettings>(_onOpenSettings);
    on<LocationHistoryClear>(_onHistoryClear);
  }

  Future<void> _onInitialize(
    LocationInitialize event,
    Emitter<LocationState> emit,
  ) async {
    try {
      await _locationService.initialize();

      // Subscribe to location status updates
      _statusSubscription?.cancel();
      _statusSubscription = _locationService.statusStream.listen(
        (status) => add(LocationStatusUpdate(status)),
      );

      // Check current status and emit appropriate state
      final currentStatus = _locationService.status;
      add(LocationStatusUpdate(currentStatus));

      // Get current position if available
      if (currentStatus == LocationStatus.ready) {
        final position = await _locationService.getCurrentPosition();
        if (position != null) {
          emit(LocationReady(lastPosition: position));
        } else {
          emit(const LocationReady());
        }
      }
    } catch (e) {
      emit(LocationError('Failed to initialize location services: $e'));
    }
  }

  Future<void> _onPermissionRequest(
    LocationPermissionRequest event,
    Emitter<LocationState> emit,
  ) async {
    try {
      final permissionGranted = await _locationService.requestPermission();

      if (permissionGranted) {
        final position = await _locationService.getCurrentPosition();
        emit(LocationReady(lastPosition: position));
      }
      // The status subscription will handle other cases
    } catch (e) {
      emit(LocationError('Error requesting location permission: $e'));
    }
  }

  Future<void> _onStart(
    LocationStart event,
    Emitter<LocationState> emit,
  ) async {
    try {
      // Unsubscribe from previous position updates if any
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      await _historySubscription?.cancel();
      _historySubscription = null;

      // Start location updates
      final success = await _locationService.startLocationUpdates(
        inBackground: event.inBackground,
      );

      if (!success) {
        // If failed, the status subscription will handle the appropriate state
        return;
      }

      // Subscribe to position updates - use add instead of emit in the callback
      _positionSubscription = _locationService.locationStream.listen(
        (position) {
          if (!isClosed) {
            add(LocationPositionUpdate(position));
          }
        },
        onError: (error) {
          if (!isClosed) {
            add(LocationStreamError('Location stream error: $error'));
          }
        },
      );

      // Track history if requested
      if (event.trackHistory) {
        final historyStarted = await _historyService.startTracking();

        if (historyStarted) {
          _historySubscription = _historyService.historyStream.listen((
            history,
          ) {
            if (!isClosed) {
              add(LocationHistoryUpdate(history));
            }
          });
        }
      }

      // Set initial state only if we have a current position
      final currentPosition = _locationService.lastPosition;
      if (currentPosition != null) {
        emit(
          LocationTracking(
            currentPosition: currentPosition,
            isTrackingHistory: event.trackHistory && _historyService.isTracking,
            isInBackground: event.inBackground,
          ),
        );
      }
    } catch (e) {
      emit(LocationError('Failed to start location tracking: $e'));
    }
  }

  // Handle history updates from stream
  void _onHistoryUpdate(
    LocationHistoryUpdate event,
    Emitter<LocationState> emit,
  ) {
    if (state is LocationTracking) {
      final currentState = state as LocationTracking;
      emit(currentState.copyWith(pathHistory: event.history));
    }
  }

  // Handle stream errors
  void _onStreamError(LocationStreamError event, Emitter<LocationState> emit) {
    emit(LocationError(event.message));
  }

  Future<void> _onStop(LocationStop event, Emitter<LocationState> emit) async {
    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      await _historySubscription?.cancel();
      _historySubscription = null;

      _historyService.stopTracking();
      await _locationService.stopLocationUpdates();

      if (_locationService.lastPosition != null) {
        emit(LocationReady(lastPosition: _locationService.lastPosition));
      } else {
        emit(const LocationReady());
      }
    } catch (e) {
      emit(LocationError('Failed to stop location tracking: $e'));
    }
  }

  void _onPositionUpdate(
    LocationPositionUpdate event,
    Emitter<LocationState> emit,
  ) {
    if (state is LocationTracking) {
      final currentState = state as LocationTracking;
      emit(currentState.copyWith(currentPosition: event.position));
    } else {
      emit(
        LocationTracking(
          currentPosition: event.position,
          isTrackingHistory: _historyService.isTracking,
          isInBackground: _locationService.status == LocationStatus.active,
        ),
      );
    }
  }

  void _onStatusUpdate(
    LocationStatusUpdate event,
    Emitter<LocationState> emit,
  ) {
    switch (event.status) {
      case LocationStatus.initial:
        emit(LocationInitial());
        break;
      case LocationStatus.permissionDenied:
        emit(LocationPermissionDenied());
        break;
      case LocationStatus.permissionDeniedForever:
        emit(LocationPermissionPermanentlyDenied());
        break;
      case LocationStatus.serviceDisabled:
        emit(LocationServiceDisabled());
        break;
      case LocationStatus.ready:
        if (state is! LocationTracking) {
          emit(LocationReady(lastPosition: _locationService.lastPosition));
        }
        break;
      case LocationStatus.active:
        // This will be handled by position updates
        break;
      case LocationStatus.error:
        emit(const LocationError('An error occurred with location services'));
        break;
    }
  }

  Future<void> _onOpenSettings(
    LocationOpenSettings event,
    Emitter<LocationState> emit,
  ) async {
    try {
      if (event.appSettings) {
        await _locationService.openAppSettings();
      } else {
        await _locationService.openLocationSettings();
      }
    } catch (e) {
      emit(LocationError('Failed to open settings: $e'));
    }
  }

  void _onHistoryClear(
    LocationHistoryClear event,
    Emitter<LocationState> emit,
  ) {
    _historyService.clearHistory();
    if (state is LocationTracking) {
      final currentState = state as LocationTracking;
      emit(currentState.copyWith(pathHistory: []));
    }
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    _statusSubscription?.cancel();
    _historySubscription?.cancel();
    _historyService.dispose();
    _locationService.dispose();
    return super.close();
  }
}
