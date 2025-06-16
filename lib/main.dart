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

  runApp(const EchoMapApp());
}

class EchoMapApp extends StatelessWidget {
  const EchoMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<NavigationBloc>(create: (context) => NavigationBloc()),
        BlocProvider<LocationBloc>(create: (context) => LocationBloc()),
      ],
      child: MaterialApp(
        title: 'EchoMap',
        theme: ThemeConfig.getLightTheme(),
        darkTheme: ThemeConfig.getDarkTheme(),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/map': (context) => const MapScreen(),
          '/vibration_test': (context) => const VibrationTestScreen(),
          '/location_test': (context) => const LocationTestScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
