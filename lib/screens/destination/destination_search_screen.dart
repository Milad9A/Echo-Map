import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/waypoint.dart';
import '../../models/geocoding_result.dart';
import '../../models/recent_place.dart';
import '../../services/location_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/recent_places_service.dart';

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
  final GeocodingService _geocodingService = GeocodingService();
  final RecentPlacesService _recentPlacesService = RecentPlacesService();

  // Search state
  List<GeocodingResult> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;

  // Recent places state
  List<RecentPlace> _recentPlaces = [];
  List<RecentPlace> _favoritePlaces = [];
  bool _isLoadingPlaces = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeServices();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoadingPlaces = true);

    try {
      await _geocodingService.initialize();
      await _recentPlacesService.initialize();

      // Load recent and favorite places
      setState(() {
        _recentPlaces = _recentPlacesService.recentPlaces;
        _favoritePlaces = _recentPlacesService.favoritePlaces;
        _isLoadingPlaces = false;
      });

      // Listen to changes in recent places
      _recentPlacesService.recentPlacesStream.listen((places) {
        if (mounted) {
          setState(() {
            _recentPlaces = places;
          });
        }
      });

      _recentPlacesService.favoritePlacesStream.listen((places) {
        if (mounted) {
          setState(() {
            _favoritePlaces = places;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize services: $e';
        _isLoadingPlaces = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    // Debounce search requests
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 3) {
      return; // Wait for at least 3 characters
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      // Use location bias if available
      final results = await _geocodingService.searchPlaces(
        query,
        bias: widget.initialLocation,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _selectGeocodingResult(GeocodingResult result) async {
    final waypoint = Waypoint(
      position: result.coordinates,
      name: result.displayName,
      description: result.formattedAddress,
      type: WaypointType.destination,
      metadata: {
        'placeId': result.placeId,
        'confidence': result.confidence,
        'isSpecificAddress': result.isSpecificAddress,
      },
    );

    // Add to recent places before returning
    await _recentPlacesService.addRecentPlaceFromGeocoding(result);

    if (mounted) {
      Navigator.pop(context, waypoint);
    }
  }

  void _selectRecentPlace(RecentPlace place) async {
    final waypoint = Waypoint(
      position: place.position,
      name: place.name,
      description: place.description,
      type: WaypointType.destination,
      metadata: {
        'placeId': place.placeId,
        'category': place.category.toString(),
        'isFavorite': place.isFavorite,
      },
    );

    // Update usage count
    await _recentPlacesService.addRecentPlace(waypoint);

    if (mounted) {
      Navigator.pop(context, waypoint);
    }
  }

  Future<void> _selectCurrentLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;

    if (position != null) {
      // Try to get a readable address for current location
      try {
        final results = await _geocodingService.reverseGeocode(
          LatLng(position.latitude, position.longitude),
        );

        String name = 'Current Location';
        String description = 'Your current position';

        if (results.isNotEmpty) {
          name = results.first.displayName;
          description = results.first.formattedAddress;
        }

        final currentWaypoint = Waypoint(
          position: LatLng(position.latitude, position.longitude),
          name: name,
          description: description,
          type: WaypointType.destination,
        );

        if (mounted) {
          Navigator.pop(context, currentWaypoint);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to get current location')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
      }
    }
  }

  // Toggle favorite status of a recent place
  Future<void> _toggleFavorite(RecentPlace place) async {
    if (place.isFavorite) {
      await _recentPlacesService.removeFavoritePlace(place.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${place.name} from favorites')),
        );
      }
    } else {
      await _recentPlacesService.addFavoritePlace(place);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${place.name} to favorites')),
        );
      }
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
          if (_recentPlaces.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'clear_recent') {
                  _showClearRecentDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_recent',
                  child: Text('Clear Recent Places'),
                ),
              ],
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
              onSubmitted: _performSearch,
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search error: $_errorMessage',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Loading indicator
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )

          // Search results
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: Icon(
                      result.isPointOfInterest
                          ? Icons.place
                          : result.isSpecificAddress
                              ? Icons.home
                              : Icons.location_on,
                    ),
                    title: Text(result.displayName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result.shortDescription),
                        if (result.confidence != null)
                          Text(
                            'Confidence: ${(result.confidence! * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _selectGeocodingResult(result),
                    trailing: result.isSpecificAddress
                        ? const Icon(Icons.my_location, size: 16)
                        : null,
                  );
                },
              ),
            )

          // Recent and favorite places (when no search)
          else
            Expanded(
              child: _isLoadingPlaces
                  ? const Center(child: CircularProgressIndicator())
                  : DefaultTabController(
                      length: _favoritePlaces.isEmpty ? 1 : 2,
                      child: Column(
                        children: [
                          if (_favoritePlaces.isNotEmpty)
                            const TabBar(
                              tabs: [
                                Tab(text: 'Recent'),
                                Tab(text: 'Favorites'),
                              ],
                            ),
                          Expanded(
                            child: _favoritePlaces.isEmpty
                                ? _buildRecentPlacesView()
                                : TabBarView(
                                    children: [
                                      _buildRecentPlacesView(),
                                      _buildFavoritePlacesView(),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentPlacesView() {
    if (_recentPlaces.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No recent places',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Places you navigate to will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
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
                leading: Text(
                  place.categoryIcon,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(place.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.shortDescription),
                    Text(
                      '${place.lastUsedText} • Used ${place.usageCount} time${place.usageCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        place.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: place.isFavorite ? Colors.red : null,
                      ),
                      onPressed: () => _toggleFavorite(place),
                    ),
                  ],
                ),
                onTap: () => _selectRecentPlace(place),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritePlacesView() {
    if (_favoritePlaces.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No favorite places',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the heart icon on recent places to add them here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Favorite Places',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _favoritePlaces.length,
            itemBuilder: (context, index) {
              final place = _favoritePlaces[index];
              return ListTile(
                leading: Text(
                  place.categoryIcon,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(place.name),
                subtitle: Text(place.shortDescription),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => _toggleFavorite(place),
                ),
                onTap: () => _selectRecentPlace(place),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showClearRecentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Recent Places'),
        content: const Text(
          'Are you sure you want to clear all recent places? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              navigator.pop();
              await _recentPlacesService.clearRecentPlaces();
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Recent places cleared')),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
