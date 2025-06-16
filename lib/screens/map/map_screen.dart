import 'package:echo_map/blocs/navigation/navigation_bloc.dart';
import 'package:echo_map/blocs/navigation/navigation_event.dart';
import 'package:echo_map/blocs/navigation/navigation_state.dart';
import 'package:flutter/material.dart' hide RouteInformation;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../blocs/location/location_state.dart';
import '../../blocs/location/location_event.dart';
import '../../services/mapping_service.dart';
import '../../services/routing_service.dart';
import '../../models/route_information.dart';
import '../../models/waypoint.dart';
import '../../utils/map_config.dart';
import '../destination/destination_search_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/navigation_status_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final MappingService _mappingService = MappingService();
  final RoutingService _routingService = RoutingService();

  GoogleMapController? _mapController;
  RouteInformation? _currentRoute;
  bool _isLoading = false;
  bool _mapInitialized = false;
  String? _errorMessage;
  bool _centeringOnLocationRequested = false;
  Waypoint? _selectedDestination;

  bool _mapSelectionMode = false; // Add this to track selection mode

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Properly handle map controller disposal
    if (_mapController != null) {
      try {
        // Only dispose locally if it's not already managed by mapping service
        if (_mapController != _mappingService.mapController) {
          _mapController!.dispose();
        }
      } catch (e) {
        debugPrint('Error disposing local map controller: $e');
      }
      _mapController = null;
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes to better manage the map controller
    switch (state) {
      case AppLifecycleState.resumed:
        // If map was previously initialized but the app was in background,
        // we might need to reinitialize
        if (_mapInitialized && _mappingService.mapController == null) {
          debugPrint('App resumed: Map needs to be reinitialized');
          setState(() {
            _mapInitialized = false;
          });
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        break;
      default:
        break;
    }
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
            icon: Icon(_mapSelectionMode ? Icons.close : Icons.touch_app),
            onPressed: _toggleMapSelectionMode,
            tooltip:
                _mapSelectionMode ? 'Exit selection mode' : 'Select on map',
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
          // Map selection mode toggle
          if (!_mapSelectionMode)
            FloatingActionButton(
              heroTag: 'mapSelection',
              onPressed: _toggleMapSelectionMode,
              backgroundColor: Colors.blue,
              tooltip: 'Tap to select destination on map',
              child: const Icon(Icons.touch_app),
            ),
          const SizedBox(height: 16),
          // Destination selection button
          FloatingActionButton(
            heroTag: 'destination',
            onPressed: _openDestinationSearch,
            backgroundColor: _selectedDestination != null ? Colors.green : null,
            child: const Icon(Icons.search),
          ),
          const SizedBox(height: 16),
          // Test route button (for development)
          FloatingActionButton(
            heroTag: 'testRoute',
            onPressed: _selectedDestination != null
                ? _calculateRouteToDestination
                : _calculateTestRoute,
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
            // Google Map - Always enable onTap, but handle mode check inside
            GoogleMap(
              initialCameraPosition: MapConfig.defaultPosition,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              markers: _mappingService.markers,
              polylines: _mappingService.polylines,
              onMapCreated: _handleMapCreated,
              onTap: _handleMapTap,
            ),

            // Navigation Status Widget - positioned at top with full width and always visible
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: NavigationStatusWidget(
                isCompact: false, // Always use detailed view on map screen
                showControls: true,
                onTap: () {
                  // Optional: expand/collapse functionality or show navigation details
                },
              ),
            ),

            // Map selection mode overlay
            if (_mapSelectionMode)
              Positioned(
                top: 220, // Below navigation status with more space
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 48,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap on the map to select destination',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the X button to cancel',
                            style: TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // User's location information - moved to bottom and only show when not navigating
            BlocBuilder<NavigationBloc, NavigationState>(
              builder: (context, navigationState) {
                // Only show location info when not actively navigating
                if (navigationState is! NavigationIdle &&
                    navigationState is! NavigationError) {
                  return const SizedBox.shrink();
                }

                if (state is LocationTracking) {
                  return Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Location: ${state.currentPosition.latitude.toStringAsFixed(5)}, '
                          '${state.currentPosition.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
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

  // Improved map creation handler
  void _handleMapCreated(GoogleMapController controller) {
    // Set flag for local tracking
    setState(() {
      _mapController = controller;
    });

    // Use a phased approach to initialization to avoid race conditions
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Only set controller if it hasn't been set yet
        _mappingService.setMapController(controller);

        // Wait a bit to ensure the controller has time to initialize
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _mapInitialized = true;
            });

            // Add a delay before centering on user's location
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted && !_centeringOnLocationRequested) {
                _centeringOnLocationRequested = true;
                _centerOnUserLocation();
              }
            });
          }
        });
      }
    });
  }

  // Center the map on the user's current location - improved with error handling
  Future<void> _centerOnUserLocation() async {
    if (!mounted) return;

    // Guard against multiple concurrent centering attempts
    if (_centeringOnLocationRequested && !_mapInitialized) {
      debugPrint(
        'Centering already requested and map not ready yet. Waiting...',
      );
      return;
    }

    _centeringOnLocationRequested = true;

    try {
      final result = await _mappingService.centerOnUserLocation(maxRetries: 3);
      if (!result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to center on your location. Please try again.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error centering on user location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to center on your location')),
        );
      }
    } finally {
      _centeringOnLocationRequested = false;
    }
  }

  // Clear the current route
  void _clearRoute() {
    setState(() {
      _currentRoute = null;
      _selectedDestination = null;
      _mapSelectionMode = false;
    });
    _mappingService.clearMarkers();
    _mappingService.clearPolylines();
  }

  // Fit the map view to show the entire route - improved implementation
  void _fitRouteOnMap(List<LatLng> points) {
    if (points.isEmpty || !_mapInitialized) return;

    // Don't try to fit if the map isn't ready
    if (!_mappingService.isMapReady) {
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

    // Get local reference to controller
    final controller = _mapController;
    if (controller == null) return;

    // Use a more robust approach for fitting the route
    try {
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      // Add padding to bounds
      final padding = MediaQuery.of(context).size.width * 0.25;

      // Use a delayed operation to ensure the map is ready
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || controller.hashCode != _mapController?.hashCode) return;

        try {
          controller
              .animateCamera(CameraUpdate.newLatLngBounds(bounds, padding))
              .catchError((e) {
            debugPrint('Error animating camera: $e');

            // Try simpler center approach as fallback
            final center = LatLng(
              (minLat + maxLat) / 2,
              (minLng + maxLng) / 2,
            );
            controller.moveCamera(CameraUpdate.newLatLngZoom(center, 13));
          });
        } catch (e) {
          debugPrint('Exception fitting route: $e');
        }
      });
    } catch (e) {
      debugPrint('Error calculating bounds: $e');
    }
  }

  // Open destination search screen
  Future<void> _openDestinationSearch() async {
    // Get current position for initial location
    Position? position;
    final locationBlocState = context.read<LocationBloc>().state;

    if (locationBlocState is LocationTracking) {
      position = locationBlocState.currentPosition;
    } else {
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        debugPrint('Error getting current position: $e');
      }
    }

    // Navigate to destination search screen
    Waypoint? result;
    if (!mounted) return;
    result = await Navigator.push<Waypoint>(
      context,
      MaterialPageRoute(
        builder: (context) => DestinationSearchScreen(
          initialLocation: position != null
              ? LatLng(position.latitude, position.longitude)
              : null,
        ),
      ),
    );

    // If a destination was selected, update state
    if (result != null) {
      setState(() {
        _selectedDestination = result;
      });

      // Add a marker for the selected destination
      _mappingService.clearMarkers();
      _mappingService.addMarker(
        id: 'destination',
        position: result.position,
        title: result.name,
        snippet: result.description ?? '',
      );

      // Center map on the destination
      _mappingService.animateCameraToPosition(result.position, zoom: 15);

      // Show a snackbar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Destination set: ${result.name}'),
          action: SnackBarAction(
            label: 'Calculate Route',
            onPressed: _calculateRouteToDestination,
          ),
        ),
      );
    }
  }

  // Calculate route to the selected destination
  Future<void> _calculateRouteToDestination() async {
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get current position
      Position? position;
      final locationBlocState = context.read<LocationBloc>().state;

      if (locationBlocState is LocationTracking) {
        position = locationBlocState.currentPosition;
      } else {
        position = await Geolocator.getCurrentPosition();
      }

      // Create origin from current position
      final origin = LatLng(position.latitude, position.longitude);

      // Use the selected destination
      final destination = _selectedDestination!.position;

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
        _isLoading = false;
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
        title: _selectedDestination!.name,
        snippet: _selectedDestination!.description ?? '',
      );

      // Add polyline for the route
      _mappingService.clearPolylines();
      _mappingService.addPolyline(id: 'route', points: route.polylinePoints);

      // Give the map some time to process the updates before fitting the route
      await Future.delayed(const Duration(milliseconds: 500));

      // Show the entire route
      _fitRouteOnMap(route.polylinePoints);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  // Calculate a test route (for development purposes)
  Future<void> _calculateTestRoute() async {
    setState(() => _isLoading = true);

    try {
      // Get current position
      Position? position;
      final locationBlocState = context.read<LocationBloc>().state;

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

      if (!mounted) return;

      // Update state with new route
      setState(() {
        _currentRoute = route;
        _errorMessage = null;
        _isLoading = false;
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
      await Future.delayed(const Duration(milliseconds: 500));

      // Show the entire route
      _fitRouteOnMap(route.polylinePoints);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Start navigation with the current route
  void _startNavigation() {
    if (_currentRoute == null) return;

    // Start navigation through NavigationBloc instead of just showing SnackBar
    context.read<NavigationBloc>().add(StartNavigatingRoute(_currentRoute!));

    // Optionally show a brief confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigation started'),
        duration: Duration(
            seconds:
                2), // Shorter duration since status widget will show persistent info
      ),
    );
  }

  // Add method to toggle map selection mode
  void _toggleMapSelectionMode() {
    setState(() {
      _mapSelectionMode = !_mapSelectionMode;
      if (!_mapSelectionMode) {
        // Clear any pending selection when exiting mode
      }
    });

    if (_mapSelectionMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap anywhere on the map to select your destination'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Add method to handle map taps
  Future<void> _handleMapTap(LatLng position) async {
    // Only handle tap if we're in selection mode
    if (!_mapSelectionMode) return;

    setState(() {
      _mapSelectionMode = false; // Exit selection mode
    });

    // Clear existing destination
    _selectedDestination = null;

    // Add a marker at the tapped location
    _mappingService.clearMarkers();
    await _mappingService.addMarker(
      id: 'selected_destination',
      position: position,
      title: 'Selected Location',
      snippet:
          'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}',
    );

    // Create a waypoint for the selected location
    final selectedWaypoint = Waypoint(
      position: position,
      name: 'Selected Location',
      description:
          'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}',
      type: WaypointType.destination,
    );

    setState(() {
      _selectedDestination = selectedWaypoint;
    });

    // Show confirmation and option to calculate route
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Destination selected: ${selectedWaypoint.name}'),
        action: SnackBarAction(
          label: 'Calculate Route',
          onPressed: _calculateRouteToDestination,
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    // Center the map on the selected location
    _mappingService.animateCameraToPosition(position, zoom: 15);
  }
}
