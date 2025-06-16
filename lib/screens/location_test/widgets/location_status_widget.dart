import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/location/location_bloc.dart';
import '../../../blocs/location/location_state.dart';
import '../../../blocs/location/location_event.dart';

class LocationStatusWidget extends StatelessWidget {
  final bool showControls;
  final bool showHistory;

  const LocationStatusWidget({
    super.key,
    this.showControls = true,
    this.showHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Location Status: ${_getStatusText(state)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (state is LocationTracking) ...[
                  Text(
                    'Latitude: ${state.currentPosition.latitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Longitude: ${state.currentPosition.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Accuracy: ±${state.currentPosition.accuracy.toStringAsFixed(1)}m',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (state.currentPosition.speed >= 0)
                    Text(
                      'Speed: ${(state.currentPosition.speed * 3.6).toStringAsFixed(1)} km/h',
                      style: const TextStyle(fontSize: 14),
                    ),
                  if (showHistory &&
                      state.isTrackingHistory &&
                      state.pathHistory != null)
                    Text(
                      'History Points: ${state.pathHistory!.length}',
                      style: const TextStyle(fontSize: 14),
                    ),
                ] else if (state is LocationReady &&
                    state.lastPosition != null) ...[
                  Text(
                    'Last Position: ${state.lastPosition!.latitude.toStringAsFixed(6)}, '
                    '${state.lastPosition!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
                if (showControls) ...[
                  const SizedBox(height: 16),
                  _buildControls(context, state),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _getStatusText(LocationState state) {
    if (state is LocationInitial) return 'Initializing';
    if (state is LocationPermissionDenied) return 'Permission Denied';
    if (state is LocationPermissionPermanentlyDenied) {
      return 'Permission Permanently Denied';
    }
    if (state is LocationServiceDisabled) return 'Location Service Disabled';
    if (state is LocationReady) return 'Ready';
    if (state is LocationTracking) return 'Tracking';
    if (state is LocationError) return 'Error: ${state.message}';
    return 'Unknown';
  }

  Widget _buildControls(BuildContext context, LocationState state) {
    final bloc = BlocProvider.of<LocationBloc>(context);

    if (state is LocationPermissionDenied) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => bloc.add(LocationPermissionRequest()),
          child: const Text('Grant Permission'),
        ),
      );
    }

    if (state is LocationPermissionPermanentlyDenied) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () =>
              bloc.add(const LocationOpenSettings(appSettings: true)),
          child: const Text('Open App Settings'),
        ),
      );
    }

    if (state is LocationServiceDisabled) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => bloc.add(const LocationOpenSettings()),
          child: const Text('Enable Location Services'),
        ),
      );
    }

    if (state is LocationReady) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  bloc.add(const LocationStart(trackHistory: true)),
              child: const Text('Start Tracking'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => bloc.add(LocationPermissionRequest()),
              child: const Text('Check Permission'),
            ),
          ),
        ],
      );
    }

    if (state is LocationTracking) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => bloc.add(LocationStop()),
              child: const Text('Stop Tracking'),
            ),
          ),
          if (showHistory && state.isTrackingHistory) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => bloc.add(LocationHistoryClear()),
                child: const Text('Clear History'),
              ),
            ),
          ],
        ],
      );
    }

    // Default case for other states
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => bloc.add(LocationInitialize()),
        child: const Text('Initialize Location'),
      ),
    );
  }
}
