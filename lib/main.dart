import 'dart:io' show Platform;

import 'package:echo_map/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'blocs/navigation/navigation_bloc.dart';
import 'blocs/location/location_bloc.dart';
import 'screens/home/home_screen.dart';
import 'screens/vibration_test/vibration_test_screen.dart';
import 'screens/location_test/location_test_screen.dart';
import 'screens/map/map_screen.dart';
import 'services/vibration_service.dart';
import 'services/location_service.dart';
import 'services/geocoding_service.dart';
import 'services/recent_places_service.dart';
import 'services/settings_service.dart';
import 'utils/platform_config.dart';
import 'utils/theme_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load();

  // Configure platform-specific settings (API keys, etc.)
  await PlatformConfig.configure();

  // Give iOS more time to fully initialize Maps services
  if (Platform.isIOS) {
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services
  final vibrationService = VibrationService();
  await vibrationService.initialize();

  final locationService = LocationService();
  await locationService.initialize();

  final geocodingService = GeocodingService();
  await geocodingService.initialize();

  final recentPlacesService = RecentPlacesService();
  await recentPlacesService.initialize();

  // Initialize settings service
  final settingsService = SettingsService();
  await settingsService.initialize();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(EchoMapApp(settingsService: settingsService));
}

class EchoMapApp extends StatefulWidget {
  final SettingsService settingsService;

  const EchoMapApp({super.key, required this.settingsService});

  @override
  State<EchoMapApp> createState() => _EchoMapAppState();
}

class _EchoMapAppState extends State<EchoMapApp> {
  late SettingsData _currentSettings;

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settingsService.currentSettings;

    // Listen to settings changes
    widget.settingsService.settingsStream.listen((settings) {
      if (mounted) {
        setState(() {
          _currentSettings = settings;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LocationBloc>(
          create: (context) => LocationBloc(),
        ),
        BlocProvider<NavigationBloc>(
          create: (context) => NavigationBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'EchoMap',
        debugShowCheckedModeBanner: false,
        theme: _getTheme(ThemeMode.light),
        darkTheme: _getTheme(ThemeMode.dark),
        themeMode: _convertThemeMode(_currentSettings.themeMode),
        home: const HomeScreen(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/map': (context) => const MapScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/vibration_test': (context) => const VibrationTestScreen(),
          '/location_test': (context) => const LocationTestScreen(),
        },
      ),
    );
  }

  ThemeMode _convertThemeMode(AppThemeMode appThemeMode) {
    switch (appThemeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  ThemeData _getTheme(ThemeMode themeMode) {
    final isDark = themeMode == ThemeMode.dark;

    if (isDark) {
      return ThemeConfig.getDarkTheme(
        highContrast: _currentSettings.highContrastMode,
        largeFontSize: _currentSettings.largeFontSize,
      );
    } else {
      return ThemeConfig.getLightTheme(
        highContrast: _currentSettings.highContrastMode,
        largeFontSize: _currentSettings.largeFontSize,
      );
    }
  }
}
