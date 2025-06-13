import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/navigation/navigation_bloc.dart';
import 'screens/home/home_screen.dart';
import 'screens/vibration_test/vibration_test_screen.dart';
import 'services/vibration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize vibration service
  final vibrationService = VibrationService();
  await vibrationService.initialize();

  runApp(const EchoMapApp());
}

class EchoMapApp extends StatelessWidget {
  const EchoMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<NavigationBloc>(create: (context) => NavigationBloc()),
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
        },
      ),
    );
  }
}
