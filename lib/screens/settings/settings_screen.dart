import 'package:flutter/material.dart';
import '../../services/vibration_service.dart';
import '../../utils/theme_config.dart';
import 'widgets/section_header.dart';
import 'widgets/settings_item.dart';
import 'widgets/vibration_intensity_setting.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final VibrationService _vibrationService = VibrationService();

  // Settings state
  bool _highContrastMode = false;
  bool _largeFontSize = false;
  bool _reduceMotion = false;
  int _vibrationIntensity = VibrationService.mediumIntensity;
  bool _speakInstructions = true;
  bool _enableVoiceCommands = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', semanticsLabel: 'Settings Screen'),
      ),
      body: Semantics(
        label: 'Settings options',
        hint: 'Adjust app preferences',
        child: ListView(
          padding: const EdgeInsets.all(ThemeConfig.standardPadding),
          children: [
            // Accessibility settings
            const SectionHeader(title: 'Accessibility'),

            SettingsItem(
              title: 'High Contrast Mode',
              subtitle: 'Use colors that are easier to distinguish',
              value: _highContrastMode,
              onChanged: (value) {
                setState(() {
                  _highContrastMode = value;
                });
              },
            ),

            SettingsItem(
              title: 'Large Font Size',
              subtitle: 'Increase text size throughout the app',
              value: _largeFontSize,
              onChanged: (value) {
                setState(() {
                  _largeFontSize = value;
                });
              },
            ),

            SettingsItem(
              title: 'Reduce Motion',
              subtitle: 'Minimize animations and movement',
              value: _reduceMotion,
              onChanged: (value) {
                setState(() {
                  _reduceMotion = value;
                });
              },
            ),

            const Divider(),

            // Vibration settings
            const SectionHeader(title: 'Vibration Feedback'),

            VibrationIntensitySetting(
              initialIntensity: _vibrationIntensity,
              onChanged: (value) {
                setState(() {
                  _vibrationIntensity = value.round();
                });
              },
              onTest: () {
                _vibrationService.playPattern(
                  'onRoute',
                  intensity: _vibrationIntensity,
                );
              },
            ),

            const SizedBox(height: ThemeConfig.standardPadding),

            // Test vibration patterns
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/vibration_test');
              },
              child: const Text('Test Vibration Patterns'),
            ),

            const Divider(),

            // Voice settings
            const SectionHeader(title: 'Voice & Audio'),

            SettingsItem(
              title: 'Speak Instructions',
              subtitle: 'Read navigation instructions aloud',
              value: _speakInstructions,
              onChanged: (value) {
                setState(() {
                  _speakInstructions = value;
                });
              },
            ),

            SettingsItem(
              title: 'Voice Commands',
              subtitle: 'Control the app with your voice',
              value: _enableVoiceCommands,
              onChanged: (value) {
                setState(() {
                  _enableVoiceCommands = value;
                });
              },
            ),

            const Divider(),

            // Other settings
            const SectionHeader(title: 'Gesture Controls'),

            const Padding(
              padding: EdgeInsets.all(ThemeConfig.standardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Double tap: Confirm actions',
                    style: TextStyle(fontSize: ThemeConfig.mediumText),
                  ),
                  SizedBox(height: ThemeConfig.smallPadding),
                  Text(
                    'Swipe down: Cancel or go back',
                    style: TextStyle(fontSize: ThemeConfig.mediumText),
                  ),
                  SizedBox(height: ThemeConfig.smallPadding),
                  Text(
                    'Shake device: Report current status',
                    style: TextStyle(fontSize: ThemeConfig.mediumText),
                  ),
                  SizedBox(height: ThemeConfig.smallPadding),
                  Text(
                    'Long press: Open context menu',
                    style: TextStyle(fontSize: ThemeConfig.mediumText),
                  ),
                ],
              ),
            ),

            const Divider(),

            // About section
            const SectionHeader(title: 'About'),

            ListTile(
              title: const Text('Version'),
              subtitle: const Text('1.0.0 (Beta)'),
              trailing: const Icon(Icons.info_outline),
              onTap: () {
                // Show app info
              },
            ),

            ListTile(
              title: const Text('Help & Feedback'),
              subtitle: const Text('Get assistance or report issues'),
              trailing: const Icon(Icons.help_outline),
              onTap: () {
                // Open help screen
              },
            ),
          ],
        ),
      ),
    );
  }
}
