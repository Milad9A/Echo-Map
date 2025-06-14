import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoMap', semanticsLabel: 'EchoMap Navigation App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to EchoMap',
              style: TextStyle(fontSize: 24),
              semanticsLabel:
                  'Welcome to EchoMap, a navigation app for blind and low vision users',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/map');
              },
              child: const Text(
                'Open Map',
                semanticsLabel: 'Open navigation map screen',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Will implement navigation functionality
              },
              child: const Text(
                'Start Navigation',
                semanticsLabel: 'Start a new navigation route',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/vibration_test');
              },
              child: const Text(
                'Vibration Test',
                semanticsLabel: 'Open vibration pattern test screen',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/location_test');
              },
              child: const Text(
                'Location Test',
                semanticsLabel: 'Open location service test screen',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
