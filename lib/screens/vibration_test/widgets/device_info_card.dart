import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class DeviceInfoCard extends StatelessWidget {
  final bool supportsVibration;
  final bool supportsAmplitude;
  final bool vibrationWorking;
  final String errorMessage;
  final bool isIOS;

  // Determine the actual platform name
  String get platformName {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isFuchsia) return 'Fuchsia';
    return 'Unknown';
  }

  const DeviceInfoCard({
    super.key,
    required this.supportsVibration,
    required this.supportsAmplitude,
    this.vibrationWorking = false,
    this.errorMessage = '',
    this.isIOS = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isKnownMobilePlatform = Platform.isIOS || Platform.isAndroid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform: $platformName',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (!isKnownMobilePlatform)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  'Warning: Vibration may not be supported on this platform',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Vibration Support: ${supportsVibration ? 'Yes' : 'No'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: supportsVibration ? Colors.green : Colors.red,
              ),
            ),
            Text(
              'Amplitude Control: ${supportsAmplitude ? 'Yes' : 'No'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: supportsAmplitude
                    ? Colors.green
                    : (isIOS ? Colors.orange : Colors.red),
              ),
            ),
            Text(
              'Vibration Working: ${vibrationWorking ? 'Yes' : 'No'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: vibrationWorking ? Colors.green : Colors.red,
              ),
            ),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Error: $errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
