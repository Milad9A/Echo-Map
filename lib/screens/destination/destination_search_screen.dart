import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/waypoint.dart';
import '../../services/location_service.dart';

class DestinationSearchScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const DestinationSearchScreen({super.key, this.initialLocation});

  @override
  State<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();

  // In a real app, these would come from a places API
  final List<_PlaceResult> _recentPlaces = [
    _PlaceResult(
      name: 'Coffee Shop',
      address: '123 Main St',
      latLng: const LatLng(53.0793, 8.8117),
    ),
    _PlaceResult(
      name: 'City Library',
      address: '456 Elm St',
      latLng: const LatLng(53.0753, 8.8067),
    ),
    _PlaceResult(
      name: 'Central Park',
      address: '789 Park Ave',
      latLng: const LatLng(53.0723, 8.8217),
    ),
  ];

  List<_PlaceResult> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Simulate search API call
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      // Mock search results - in a real app, this would query Places API
      final results = _recentPlaces
          .where(
            (place) =>
                place.name.toLowerCase().contains(query.toLowerCase()) ||
                place.address.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  void _selectDestination(_PlaceResult place) {
    final waypoint = Waypoint(
      position: place.latLng,
      name: place.name,
      description: place.address,
      type: WaypointType.destination,
    );

    Navigator.pop(context, waypoint);
  }

  Future<void> _selectCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;

    if (position != null) {
      final currentWaypoint = Waypoint(
        position: LatLng(position.latitude, position.longitude),
        name: 'Current Location',
        type: WaypointType.destination,
      );

      Navigator.pop(context, currentWaypoint);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get current location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Destination'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _selectCurrentLocation,
            tooltip: 'Use current location',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a destination',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              autofocus: true,
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_isSearching)
            const Center(child: CircularProgressIndicator())
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final place = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.place),
                    title: Text(place.name),
                    subtitle: Text(place.address),
                    onTap: () => _selectDestination(place),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Recent Places',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _recentPlaces.length,
                      itemBuilder: (context, index) {
                        final place = _recentPlaces[index];
                        return ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(place.name),
                          subtitle: Text(place.address),
                          onTap: () => _selectDestination(place),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceResult {
  final String name;
  final String address;
  final LatLng latLng;

  _PlaceResult({
    required this.name,
    required this.address,
    required this.latLng,
  });
}
