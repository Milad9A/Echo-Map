import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../blocs/location/location_event.dart';
import '../../blocs/location/location_state.dart';
import 'widgets/location_status_widget.dart';

class LocationTestScreen extends StatefulWidget {
  const LocationTestScreen({super.key});

  @override
  State<LocationTestScreen> createState() => _LocationTestScreenState();
}

class _LocationTestScreenState extends State<LocationTestScreen> {
  bool _backgroundMode = false;
  bool _historyTracking = true;

  @override
  void initState() {
    super.initState();
    // Initialize location services
    context.read<LocationBloc>().add(LocationInitialize());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Location Service Test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Location status display
            const LocationStatusWidget(showHistory: true),
            const SizedBox(height: 24),

            // Settings for tracking
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tracking Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: const Text('Background Mode'),
                      subtitle: const Text(
                        'Keep tracking when app is in background',
                      ),
                      value: _backgroundMode,
                      onChanged: (value) {
                        setState(() {
                          _backgroundMode = value;
                        });
                      },
                    ),

                    SwitchListTile(
                      title: const Text('Track History'),
                      subtitle: const Text(
                        'Store location history for path analysis',
                      ),
                      value: _historyTracking,
                      onChanged: (value) {
                        setState(() {
                          _historyTracking = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            context.read<LocationBloc>().add(
                              LocationStart(
                                trackHistory: _historyTracking,
                                inBackground: _backgroundMode,
                              ),
                            );
                          },
                          child: const Text('Start Tracking'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<LocationBloc>().add(LocationStop());
                          },
                          child: const Text('Stop Tracking'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Path info section
            BlocBuilder<LocationBloc, LocationState>(
              builder: (context, state) {
                if (state is LocationTracking &&
                    state.isTrackingHistory &&
                    state.pathHistory != null &&
                    state.pathHistory!.isNotEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Path Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Points: ${state.pathHistory!.length}'),

                          // Here you could calculate and display:
                          // - Total distance
                          // - Average speed
                          // - Duration
                          // - etc.
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              context.read<LocationBloc>().add(
                                LocationHistoryClear(),
                              );
                            },
                            child: const Text('Clear Path History'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
