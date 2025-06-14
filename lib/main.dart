import 'dart:io' show Platform;

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
import 'utils/platform_config.dart';

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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          // High contrast theme settings for accessibility
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          visualDensity: VisualDensity.comfortable,
        ),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        routes: {
          '/': (context) => const HomeScreen(),
          '/vibration_test': (context) => const VibrationTestScreen(),
          '/location_test': (context) => const LocationTestScreen(),
          '/map': (context) => const MapScreen(),
        },
      ),
    );
  }
}
