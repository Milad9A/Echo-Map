import 'package:flutter/material.dart';

class DeviceInfoCard extends StatelessWidget {
  final bool supportsVibration;
  final bool supportsAmplitude;

  const DeviceInfoCard({
    super.key,
    required this.supportsVibration,
    required this.supportsAmplitude,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vibration Support: ${supportsVibration ? 'Yes' : 'No'}'),
            Text('Amplitude Control: ${supportsAmplitude ? 'Yes' : 'No'}'),
          ],
        ),
      ),
    );
  }
}
