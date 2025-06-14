import 'package:flutter/material.dart' hide RouteInformation;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../blocs/location/location_state.dart';
import '../../blocs/location/location_event.dart';
import '../../services/mapping_service.dart';
import '../../services/routing_service.dart';
import '../../models/route_information.dart';
import '../../utils/map_config.dart'; // Import the new config file
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MappingService _mappingService = MappingService();
  final RoutingService _routingService = RoutingService();

  GoogleMapController? _mapController;
  RouteInformation? _currentRoute;
  bool _isLoading = false;
  bool _mapInitialized = false;
  String? _errorMessage;
  bool _centeringOnLocationRequested = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    // Only dispose of the controller if mapping service doesn't have it
    if (_mapController != null &&
        _mapController != _mappingService.mapController) {
      try {
        _mapController!.dispose();
      } catch (e) {
        debugPrint('Error disposing map controller: $e');
      }
      _mapController = null;
    }

    super.dispose();
  }

  Future<void> _initializeServices() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    // Access the bloc synchronously before any await
    final locationBloc = context.read<LocationBloc>();

    try {
      // Initialize mapping service
      await _mappingService.initialize();

      // Initialize location if not already started
      if (locationBloc.state is! LocationTracking) {
        locationBloc.add(LocationInitialize());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to initialize map: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnUserLocation,
            tooltip: 'Center on my location',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearRoute,
            tooltip: 'Clear route',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Test route button (for development)
          FloatingActionButton(
            heroTag: 'testRoute',
            onPressed: _calculateTestRoute,
            child: const Icon(Icons.route),
          ),
          const SizedBox(height: 16),
          // Navigation start button
          if (_currentRoute != null)
            FloatingActionButton.extended(
              heroTag: 'startNavigation',
              onPressed: _startNavigation,
              icon: const Icon(Icons.navigation),
              label: const Text('Start Navigation'),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: $_errorMessage',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeServices,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, state) {
        return Stack(
          children: [
            // Google Map - Use MapConfig.defaultPosition instead of the hardcoded constant
            GoogleMap(
              initialCameraPosition: MapConfig.defaultPosition,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              markers: _mappingService.markers,
              polylines: _mappingService.polylines,
              onMapCreated: (GoogleMapController controller) {
                // Store controller locally
                setState(() {
                  _mapController = controller;
                });

                // Hand off controller to mapping service with a delay
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (mounted) {
                    // Only set the controller if it hasn't been set yet
                    if (_mappingService.mapController == null) {
                      _mappingService.setMapController(controller);
                    }

                    // Set flag that map is initialized
                    setState(() {
                      _mapInitialized = true;
                    });

                    // Add a delay before centering on user's location
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted && !_centeringOnLocationRequested) {
                        _centeringOnLocationRequested = true;
                        _centerOnUserLocation();
                      }
                    });
                  }
                });
              },
            ),

            // Route information panel (if route is available)
            if (_currentRoute != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Card(
                  margin: const EdgeInsets.all(16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Destination: ${_currentRoute!.destination.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Distance: ${_currentRoute!.distanceText}',
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Duration: ${_currentRoute!.durationText}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // User's location information
            if (state is LocationTracking)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Location: ${state.currentPosition.latitude.toStringAsFixed(5)}, '
                      '${state.currentPosition.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),

            // Loading indicator if map is not fully initialized
            if (!_mapInitialized)
              Container(
                color: const Color.fromRGBO(0, 0, 0, 0.1),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }

  // Center the map on the user's current location
  Future<void> _centerOnUserLocation() async {
    if (!mounted) return;

    // Read the bloc state before any await to avoid using context after an async gap
    final locationBlocState = context.read<LocationBloc>().state;

    if (!_mapInitialized) {
      debugPrint('Map not yet initialized, waiting...');
      // Wait for map to initialize with a timeout
      final initialized = await _mappingService.waitForMapInitialization(
        timeout: const Duration(seconds: 5),
      );
      if (!initialized) {
        debugPrint('Map initialization timed out, cannot center on location');
        return;
      }
    }

    try {
      // Add a small delay to ensure the map is fully ready
      await Future.delayed(const Duration(milliseconds: 300));

      // If location tracking is active, use current position
      if (locationBlocState is LocationTracking) {
        await _mappingService.animateCameraToPosition(
          LatLng(
            locationBlocState.currentPosition.latitude,
            locationBlocState.currentPosition.longitude,
          ),
        );
        return;
      }

      // Otherwise use location service directly
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      await _mappingService.animateCameraToPosition(
        LatLng(position.latitude, position.longitude),
      );
    } catch (e) {
      debugPrint('Error centering on user location: $e');
      // Don't update state or show error to avoid disrupting the user experience
    }
  }

  // Clear the current route
  void _clearRoute() {
    setState(() {
      _currentRoute = null;
    });
    _mappingService.clearMarkers();
    _mappingService.clearPolylines();
  }

  // Fit the map view to show the entire route
  void _fitRouteOnMap(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    // Safety check to avoid using a disposed controller
    if (!_mapInitialized) {
      debugPrint('Map not fully initialized, skipping route fitting');
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add a short delay to ensure the map is ready for animations
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _mapController == null) return;

      try {
        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        // Use a more reliable approach for animation
        _mapController!
            .animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0))
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                debugPrint(
                  'Camera animation timed out, trying alternative approach',
                );
                // Fallback to center on the route
                if (mounted && _mapController != null) {
                  final center = LatLng(
                    (minLat + maxLat) / 2,
                    (minLng + maxLng) / 2,
                  );
                  _mapController!.moveCamera(
                    CameraUpdate.newLatLngZoom(center, 13),
                  );
                }
              },
            )
            .catchError((e) {
              debugPrint('Error animating camera to show route: $e');
              // Try a simpler camera update as fallback
              if (mounted && _mapController != null) {
                try {
                  final center = LatLng(
                    (minLat + maxLat) / 2,
                    (minLng + maxLng) / 2,
                  );
                  _mapController!.moveCamera(
                    CameraUpdate.newLatLngZoom(center, 13),
                  );
                } catch (e2) {
                  debugPrint('Fallback camera update also failed: $e2');
                }
              }
            });
      } catch (e) {
        debugPrint('Exception when fitting route on map: $e');
      }
    });
  }

  // Calculate a test route (for development purposes)
  Future<void> _calculateTestRoute() async {
    setState(() => _isLoading = true);

    try {
      // Get current position
      Position? position;
      final locationBlocState = context
          .read<LocationBloc>()
          .state; // Read before any await

      if (locationBlocState is LocationTracking) {
        position = locationBlocState.currentPosition;
      } else {
        position = await Geolocator.getCurrentPosition();
      }

      // Create origin from current position
      final origin = LatLng(position.latitude, position.longitude);

      // Create a destination 1km to the north and east (for testing)
      final destination = LatLng(
        position.latitude + 0.01, // ~1km north
        position.longitude + 0.01, // ~1km east
      );

      // Calculate route
      final route = await _routingService.calculateRoute(
        origin,
        destination,
        mode: TravelMode.walking,
      );

      if (route == null) {
        throw Exception('Could not calculate route');
      }

      // Update state with new route
      setState(() {
        _currentRoute = route;
        _errorMessage = null;
      });

      // Add markers for origin and destination
      _mappingService.clearMarkers();
      _mappingService.addMarker(
        id: 'origin',
        position: origin,
        title: 'Starting Point',
      );
      _mappingService.addMarker(
        id: 'destination',
        position: destination,
        title: 'Destination',
      );

      // Add polyline for the route
      _mappingService.clearPolylines();
      _mappingService.addPolyline(id: 'route', points: route.polylinePoints);

      // Give the map some time to process the updates before fitting the route
      await Future.delayed(const Duration(milliseconds: 300));

      // Show the entire route
      _fitRouteOnMap(route.polylinePoints);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Start navigation with the current route
  void _startNavigation() {
    if (_currentRoute == null) return;

    // TODO: Navigate to navigation screen with route data
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Navigation starting...')));
  }
}
