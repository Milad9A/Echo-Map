import 'dart:async';
import 'dart:math';

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
  Timer? _searchDebounceTimer;

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
    _searchDebounceTimer?.cancel();
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

    // Cancel previous search timer
    _searchDebounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    // Set loading state immediately for responsiveness
    if (!_isSearching) {
      setState(() {
        _isSearching = true;
        _errorMessage = null;
      });
    }

    // Debounce search requests
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    try {
      // Use location bias if available for better local results
      final results = await _geocodingService.searchPlaces(
        query,
        bias: widget.initialLocation,
      );

      // Add distance information to results if we have user location
      final resultsWithDistance = <GeocodingResult>[];
      if (widget.initialLocation != null) {
        for (final result in results) {
          final distance =
              _calculateDistance(widget.initialLocation!, result.coordinates);
          resultsWithDistance.add(result.copyWithDistance(distance));
        }
      } else {
        resultsWithDistance.addAll(results);
      }

      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _searchResults = resultsWithDistance;
          _isSearching = false;
          _errorMessage = resultsWithDistance.isEmpty
              ? 'No results found for "$query" nearby'
              : null;
        });
      }
    } catch (e) {
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _errorMessage = _getErrorMessage(e.toString());
        });
      }
    }
  }

  // Calculate distance between two points
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final double lat1Rad = point1.latitude * (3.141592653589793 / 180);
    final double lat2Rad = point2.latitude * (3.141592653589793 / 180);
    final double deltaLatRad =
        (point2.latitude - point1.latitude) * (3.141592653589793 / 180);
    final double deltaLngRad =
        (point2.longitude - point1.longitude) * (3.141592653589793 / 180);

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  String _getErrorMessage(String error) {
    if (error.contains('timeout')) {
      return 'Search timed out. Please check your connection and try again.';
    } else if (error.contains('connection')) {
      return 'Connection error. Please check your internet connection.';
    } else if (error.contains('quota') || error.contains('limit')) {
      return 'Search limit reached. Please try again later.';
    } else if (error.contains('API key')) {
      return 'Search service configuration error.';
    } else {
      return 'Search failed. Please try again.';
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
                hintText: widget.initialLocation != null
                    ? 'Search nearby (e.g., "McDonald\'s", "Hauptbahnhof")'
                    : 'Search for a destination (e.g., "McDonald\'s Berlin")',
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
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
                helperText: widget.initialLocation != null
                    ? 'Results are sorted by distance from your location'
                    : 'Try searching for addresses, landmarks, or business names',
                helperMaxLines: 2,
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
                color: _searchResults.isEmpty
                    ? Colors.orange.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        _searchResults.isEmpty ? Icons.info : Icons.error,
                        color: _searchResults.isEmpty
                            ? Colors.orange.shade700
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: _searchResults.isEmpty
                                ? Colors.orange.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                      if (_searchResults.isEmpty &&
                          !_errorMessage!.contains('No results'))
                        TextButton(
                          onPressed: () =>
                              _performSearch(_searchController.text.trim()),
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Search results
          if (_searchResults.isNotEmpty)
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
                      color: result.isSpecificAddress ? Colors.blue : null,
                    ),
                    title: Text(
                      result.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result.shortDescription),
                        if (result.distanceFromUser != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            result.distanceText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (result.confidence != null)
                          Text(
                            'Confidence: ${(result.confidence! * 100).round()}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _selectGeocodingResult(result),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (result.distanceFromUser != null &&
                            result.distanceFromUser! < 500)
                          Icon(Icons.near_me,
                              size: 16, color: Colors.green[700]),
                        if (result.isSpecificAddress)
                          const Icon(Icons.my_location,
                              size: 16, color: Colors.blue),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  );
                },
              ),
            )

          // Recent and favorite places (when no search or search is empty)
          else if (_searchController.text.trim().isEmpty)
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
            )

          // Empty state when searching but no results
          else if (!_isSearching &&
              _searchResults.isEmpty &&
              _errorMessage == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Start typing to search for places',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
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
