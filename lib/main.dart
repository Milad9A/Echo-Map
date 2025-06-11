import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/navigation/navigation_bloc.dart';
import 'screens/home_screen.dart';
import 'screens/vibration_test_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
          primarySwatch: Colors.blue,
          useMaterial3: true,
          // High contrast theme settings for accessibility
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
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
