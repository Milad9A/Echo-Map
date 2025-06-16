import 'package:flutter/material.dart';
import '../../services/vibration_service.dart';
import '../../services/settings_service.dart';
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
  final SettingsService _settingsService = SettingsService();

  SettingsData _currentSettings = const SettingsData();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    try {
      await _settingsService.initialize();

      // Load current settings
      setState(() {
        _currentSettings = _settingsService.currentSettings;
        _isLoading = false;
      });

      // Listen to settings changes
      _settingsService.settingsStream.listen((settings) {
        if (mounted) {
          setState(() {
            _currentSettings = settings;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', semanticsLabel: 'Settings Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _showResetDialog,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Semantics(
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
                    value: _currentSettings.highContrastMode,
                    onChanged: (value) {
                      _settingsService.setHighContrastMode(value);
                    },
                  ),

                  SettingsItem(
                    title: 'Large Font Size',
                    subtitle: 'Increase text size throughout the app',
                    value: _currentSettings.largeFontSize,
                    onChanged: (value) {
                      _settingsService.setLargeFontSize(value);
                    },
                  ),

                  SettingsItem(
                    title: 'Reduce Motion',
                    subtitle: 'Minimize animations and movement',
                    value: _currentSettings.reduceMotion,
                    onChanged: (value) {
                      _settingsService.setReduceMotion(value);
                    },
                  ),

                  const Divider(),

                  // Vibration settings
                  const SectionHeader(title: 'Vibration Feedback'),

                  VibrationIntensitySetting(
                    initialIntensity: _currentSettings.vibrationIntensity,
                    onChanged: (value) {
                      _settingsService.setVibrationIntensity(value.round());
                    },
                    onTest: () {
                      _vibrationService.playPattern(
                        'onRoute',
                        intensity: _currentSettings.vibrationIntensity,
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
                    value: _currentSettings.speakInstructions,
                    onChanged: (value) {
                      _settingsService.setSpeakInstructions(value);
                    },
                  ),

                  SettingsItem(
                    title: 'Voice Commands',
                    subtitle: 'Control the app with your voice',
                    value: _currentSettings.enableVoiceCommands,
                    onChanged: (value) {
                      _settingsService.setEnableVoiceCommands(value);
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
                      _showAboutDialog();
                    },
                  ),

                  ListTile(
                    title: const Text('Help & Feedback'),
                    subtitle: const Text('Get assistance or report issues'),
                    trailing: const Icon(Icons.help_outline),
                    onTap: () {
                      _showHelpDialog();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _settingsService.resetToDefaults();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings reset to defaults')),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: 'EchoMap',
        applicationVersion: '1.0.0 (Beta)',
        applicationIcon: const Icon(Icons.navigation, size: 64),
        children: const [
          Text(
            'EchoMap is a navigation app designed for blind and low-vision users, '
            'providing navigation guidance through vibration patterns.',
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Getting Started:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Allow location permissions when prompted'),
              Text('2. Test vibration patterns to familiarize yourself'),
              Text('3. Use the map screen to set a destination'),
              Text('4. Follow vibration guidance during navigation'),
              SizedBox(height: 16),
              Text(
                'Need Help?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Contact support at: support@echomap.app'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
