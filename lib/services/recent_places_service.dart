import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_place.dart';
import '../models/waypoint.dart';
import '../models/geocoding_result.dart';

class RecentPlacesService {
  static final RecentPlacesService _instance = RecentPlacesService._internal();
  factory RecentPlacesService() => _instance;
  RecentPlacesService._internal();

  static const String _recentPlacesKey = 'recent_places';
  static const String _favoriteColorsKey = 'favorite_places';
  static const int _maxRecentPlaces = 20;
  static const int _maxFavoritePlaces = 50;

  SharedPreferences? _prefs;
  final List<RecentPlace> _recentPlaces = [];
  final List<RecentPlace> _favoritePlaces = [];

  final StreamController<List<RecentPlace>> _recentPlacesController =
      StreamController<List<RecentPlace>>.broadcast();
  final StreamController<List<RecentPlace>> _favoritePlacesController =
      StreamController<List<RecentPlace>>.broadcast();

  // Public streams
  Stream<List<RecentPlace>> get recentPlacesStream =>
      _recentPlacesController.stream;
  Stream<List<RecentPlace>> get favoritePlacesStream =>
      _favoritePlacesController.stream;

  // Getters
  List<RecentPlace> get recentPlaces => List.unmodifiable(_recentPlaces);
  List<RecentPlace> get favoritePlaces => List.unmodifiable(_favoritePlaces);

  // Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadRecentPlaces();
      await _loadFavoritePlaces();
      debugPrint(
          'RecentPlacesService initialized with ${_recentPlaces.length} recent places');
    } catch (e) {
      debugPrint('Error initializing RecentPlacesService: $e');
    }
  }

  // Load recent places from storage
  Future<void> _loadRecentPlaces() async {
    try {
      final String? recentPlacesJson = _prefs?.getString(_recentPlacesKey);
      if (recentPlacesJson != null) {
        final List<dynamic> recentPlacesList = json.decode(recentPlacesJson);
        _recentPlaces.clear();

        for (final placeData in recentPlacesList) {
          try {
            final recentPlace =
                RecentPlace.fromJson(placeData as Map<String, dynamic>);
            _recentPlaces.add(recentPlace);
          } catch (e) {
            debugPrint('Error parsing recent place: $e');
          }
        }

        // Sort by last used (most recent first)
        _recentPlaces.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
        _recentPlacesController.add(_recentPlaces);
      }
    } catch (e) {
      debugPrint('Error loading recent places: $e');
    }
  }

  // Load favorite places from storage
  Future<void> _loadFavoritePlaces() async {
    try {
      final String? favoritePlacesJson = _prefs?.getString(_favoriteColorsKey);
      if (favoritePlacesJson != null) {
        final List<dynamic> favoritePlacesList =
            json.decode(favoritePlacesJson);
        _favoritePlaces.clear();

        for (final placeData in favoritePlacesList) {
          try {
            final favoritePlace =
                RecentPlace.fromJson(placeData as Map<String, dynamic>);
            _favoritePlaces.add(favoritePlace);
          } catch (e) {
            debugPrint('Error parsing favorite place: $e');
          }
        }

        // Sort by name
        _favoritePlaces.sort((a, b) => a.name.compareTo(b.name));
        _favoritePlacesController.add(_favoritePlaces);
      }
    } catch (e) {
      debugPrint('Error loading favorite places: $e');
    }
  }

  // Save recent places to storage
  Future<void> _saveRecentPlaces() async {
    try {
      final recentPlacesJson =
          json.encode(_recentPlaces.map((place) => place.toJson()).toList());
      await _prefs?.setString(_recentPlacesKey, recentPlacesJson);
    } catch (e) {
      debugPrint('Error saving recent places: $e');
    }
  }

  // Save favorite places to storage
  Future<void> _saveFavoritePlaces() async {
    try {
      final favoritePlacesJson =
          json.encode(_favoritePlaces.map((place) => place.toJson()).toList());
      await _prefs?.setString(_favoriteColorsKey, favoritePlacesJson);
    } catch (e) {
      debugPrint('Error saving favorite places: $e');
    }
  }

  // Add a place to recent places
  Future<void> addRecentPlace(Waypoint waypoint) async {
    try {
      // Check if this place already exists in recent places
      final existingIndex = _recentPlaces.indexWhere((place) =>
          place.position.latitude == waypoint.position.latitude &&
          place.position.longitude == waypoint.position.longitude);

      if (existingIndex >= 0) {
        // Update existing place
        final existingPlace = _recentPlaces[existingIndex];
        _recentPlaces[existingIndex] = existingPlace.copyWith(
          lastUsed: DateTime.now(),
          usageCount: existingPlace.usageCount + 1,
        );
      } else {
        // Add new place
        final recentPlace = RecentPlace(
          id: waypoint.id,
          name: waypoint.name,
          description: waypoint.description,
          position: waypoint.position,
          lastUsed: DateTime.now(),
          usageCount: 1,
          placeId: waypoint.metadata?['placeId'] as String?,
          category: _categorizePlace(waypoint),
        );
        _recentPlaces.insert(0, recentPlace);
      }

      // Remove excess places
      while (_recentPlaces.length > _maxRecentPlaces) {
        _recentPlaces.removeLast();
      }

      // Sort by last used
      _recentPlaces.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));

      await _saveRecentPlaces();
      _recentPlacesController.add(_recentPlaces);

      debugPrint('Added recent place: ${waypoint.name}');
    } catch (e) {
      debugPrint('Error adding recent place: $e');
    }
  }

  // Add a place from geocoding result
  Future<void> addRecentPlaceFromGeocoding(GeocodingResult result) async {
    final waypoint = Waypoint(
      position: result.coordinates,
      name: result.displayName,
      description: result.formattedAddress,
      type: WaypointType.destination,
      metadata: {
        'placeId': result.placeId,
        'confidence': result.confidence,
        'isSpecificAddress': result.isSpecificAddress,
        'addressComponents': result.addressComponents,
      },
    );

    await addRecentPlace(waypoint);
  }

  // Add a place to favorites
  Future<void> addFavoritePlace(RecentPlace place, {String? customName}) async {
    try {
      // Check if already in favorites
      final existingIndex =
          _favoritePlaces.indexWhere((fav) => fav.id == place.id);

      if (existingIndex >= 0) {
        debugPrint('Place already in favorites: ${place.name}');
        return;
      }

      // Check favorites limit
      if (_favoritePlaces.length >= _maxFavoritePlaces) {
        debugPrint('Maximum favorite places reached');
        return;
      }

      final favoritePlace = place.copyWith(
        name: customName ?? place.name,
        lastUsed: DateTime.now(),
        isFavorite: true,
      );

      _favoritePlaces.add(favoritePlace);
      _favoritePlaces.sort((a, b) => a.name.compareTo(b.name));

      await _saveFavoritePlaces();
      _favoritePlacesController.add(_favoritePlaces);

      debugPrint('Added favorite place: ${favoritePlace.name}');
    } catch (e) {
      debugPrint('Error adding favorite place: $e');
    }
  }

  // Remove a place from favorites
  Future<void> removeFavoritePlace(String placeId) async {
    try {
      final existingIndex =
          _favoritePlaces.indexWhere((place) => place.id == placeId);

      if (existingIndex >= 0) {
        _favoritePlaces.removeAt(existingIndex);
        await _saveFavoritePlaces();
        _favoritePlacesController.add(_favoritePlaces);
        debugPrint('Removed favorite place with id: $placeId');
      }
    } catch (e) {
      debugPrint('Error removing favorite place: $e');
    }
  }

  // Clear recent places
  Future<void> clearRecentPlaces() async {
    try {
      _recentPlaces.clear();
      await _saveRecentPlaces();
      _recentPlacesController.add(_recentPlaces);
      debugPrint('Cleared recent places');
    } catch (e) {
      debugPrint('Error clearing recent places: $e');
    }
  }

  // Get places by category
  List<RecentPlace> getPlacesByCategory(PlaceCategory category) {
    return _recentPlaces.where((place) => place.category == category).toList();
  }

  // Search recent places
  List<RecentPlace> searchRecentPlaces(String query) {
    if (query.trim().isEmpty) return _recentPlaces;

    final lowerQuery = query.toLowerCase();
    return _recentPlaces.where((place) {
      return place.name.toLowerCase().contains(lowerQuery) ||
          (place.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // Get most frequently used places
  List<RecentPlace> getMostUsedPlaces({int limit = 10}) {
    final sortedPlaces = List<RecentPlace>.from(_recentPlaces);
    sortedPlaces.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return sortedPlaces.take(limit).toList();
  }

  // Check if a place is favorited
  bool isFavorite(String placeId) {
    return _favoritePlaces.any((place) => place.id == placeId);
  }

  // Categorize place based on waypoint data
  PlaceCategory _categorizePlace(Waypoint waypoint) {
    final metadata = waypoint.metadata;
    if (metadata == null) return PlaceCategory.other;

    final addressComponents =
        metadata['addressComponents'] as Map<String, String>?;
    if (addressComponents == null) return PlaceCategory.other;

    // Check for establishment types
    if (addressComponents.containsKey('establishment')) {
      final establishment = addressComponents['establishment']!.toLowerCase();
      if (establishment.contains('restaurant') ||
          establishment.contains('cafe')) {
        return PlaceCategory.restaurant;
      } else if (establishment.contains('shop') ||
          establishment.contains('store')) {
        return PlaceCategory.shopping;
      } else if (establishment.contains('hospital') ||
          establishment.contains('clinic')) {
        return PlaceCategory.health;
      }
    }

    // Check for specific address
    if (metadata['isSpecificAddress'] == true) {
      return PlaceCategory.address;
    }

    // Check for transit
    if (addressComponents.containsKey('transit_station')) {
      return PlaceCategory.transit;
    }

    return PlaceCategory.other;
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    final categories = <PlaceCategory, int>{};
    for (final place in _recentPlaces) {
      categories[place.category] = (categories[place.category] ?? 0) + 1;
    }

    return {
      'totalRecentPlaces': _recentPlaces.length,
      'totalFavoritePlaces': _favoritePlaces.length,
      'categoriesBreakdown': categories,
      'oldestRecentPlace':
          _recentPlaces.isNotEmpty ? _recentPlaces.last.lastUsed : null,
      'newestRecentPlace':
          _recentPlaces.isNotEmpty ? _recentPlaces.first.lastUsed : null,
    };
  }

  // Dispose resources
  void dispose() {
    _recentPlacesController.close();
    _favoritePlacesController.close();
  }
}
