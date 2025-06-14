import 'package:flutter/material.dart' hide RouteInformation;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../blocs/location/location_state.dart';
import '../../blocs/location/location_event.dart';
import '../../services/mapping_service.dart';
import '../../services/routing_service.dart';
import '../../models/route_information.dart';
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
  String? _errorMessage;

  // Default map settings
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(48.2082, 16.3738), // Vienna, Austria as default
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);

    try {
      // Initialize mapping service
      await _mappingService.initialize();

      // Initialize location if not already started
      final locationBloc = context.read<LocationBloc>();
      if (locationBloc.state is! LocationTracking) {
        locationBloc.add(LocationInitialize());
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to initialize map: $e');
    } finally {
      setState(() => _isLoading = false);
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
            // Google Map
            GoogleMap(
              initialCameraPosition: _defaultPosition,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              markers: _mappingService.markers,
              polylines: _mappingService.polylines,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _mappingService.setMapController(controller);

                // Center on user's location when map is created
                _centerOnUserLocation();
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
          ],
        );
      },
    );
  }

  // Center the map on the user's current location
  Future<void> _centerOnUserLocation() async {
    final state = context.read<LocationBloc>().state;

    // If location tracking is active, use current position
    if (state is LocationTracking) {
      await _mappingService.animateCameraToPosition(
        LatLng(state.currentPosition.latitude, state.currentPosition.longitude),
      );
      return;
    }

    // Otherwise use location service directly
    await _mappingService.centerOnUserLocation();
  }

  // Clear the current route
  void _clearRoute() {
    setState(() {
      _currentRoute = null;
    });
    _mappingService.clearMarkers();
    _mappingService.clearPolylines();
  }

  // Calculate a test route (for development purposes)
  Future<void> _calculateTestRoute() async {
    setState(() => _isLoading = true);

    try {
      // Get current position
      Position? position;
      final state = context.read<LocationBloc>().state;

      if (state is LocationTracking) {
        position = state.currentPosition;
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

      // Show the entire route
      _fitRouteOnMap(route.polylinePoints);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fit the map view to show the entire route
  void _fitRouteOnMap(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

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

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0, // padding
      ),
    );
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
