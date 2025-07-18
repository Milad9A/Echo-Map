import 'package:echo_map/services/text_to_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/vibration_service.dart';
import '../../services/settings_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme_config.dart' hide AppThemeMode;
import 'widgets/section_header.dart';
import 'widgets/settings_item.dart';
import 'widgets/vibration_intensity_setting.dart';
import 'widgets/theme_selector.dart';

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

    // Track screen view
    AnalyticsService.logNavigation('settings_screen');
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
                  // Appearance section
                  const SectionHeader(title: 'Appearance'),

                  // Theme selector
                  ThemeSelector(
                    currentTheme:
                        _appThemeModeToThemeMode(_currentSettings.themeMode),
                    onThemeChanged: (theme) {
                      _settingsService
                          .setThemeMode(_themeModeToAppThemeMode(theme));
                    },
                  ),

                  const Divider(),

                  // Accessibility settings
                  const SectionHeader(title: 'Accessibility'),

                  SettingsItem(
                    title: 'High Contrast Mode',
                    subtitle: 'Enhance color contrast for better visibility',
                    value: _currentSettings.highContrastMode,
                    onChanged: (value) {
                      _settingsService.setHighContrastMode(value);
                    },
                  ),

                  SettingsItem(
                    title: 'Large Text Size',
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

                  const SizedBox(height: ThemeConfig.smallPadding),

                  // Test location services
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/location_test');
                    },
                    child: const Text('Test Location Services'),
                  ),

                  const Divider(),

                  // Voice settings
                  const SectionHeader(title: 'Voice & Audio'),

                  SettingsItem(
                    title: 'Speak Navigation Steps',
                    subtitle: 'Read directions aloud during navigation',
                    value: _currentSettings.ttsEnabled,
                    onChanged: (value) {
                      _settingsService.setTtsEnabled(value);
                    },
                  ),

                  // Speech rate dropdown
                  ListTile(
                    title: const Text('Speech Rate'),
                    subtitle: const Text('How fast the voice speaks'),
                    trailing: DropdownButton<String>(
                      value: _currentSettings.ttsRate,
                      onChanged: _currentSettings.ttsEnabled
                          ? (String? newValue) async {
                              if (newValue != null) {
                                _settingsService.setTtsRate(newValue);
                              }
                            }
                          : null,
                      items: ['slow', 'normal', 'fast']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child:
                              Text(value[0].toUpperCase() + value.substring(1)),
                        );
                      }).toList(),
                    ),
                  ),

                  // Speech volume slider
                  ListTile(
                    title: const Text('Speech Volume'),
                    subtitle: Slider(
                      value: _currentSettings.ttsVolume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label:
                          (_currentSettings.ttsVolume * 100).round().toString(),
                      onChanged: _currentSettings.ttsEnabled
                          ? (double value) {
                              _settingsService.setTtsVolume(value);
                            }
                          : null,
                    ),
                    trailing: Icon(
                      _currentSettings.ttsVolume > 0.5
                          ? Icons.volume_up
                          : _currentSettings.ttsVolume > 0.0
                              ? Icons.volume_down
                              : Icons.volume_off,
                    ),
                  ),

                  // Test voice button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton(
                      onPressed: _currentSettings.ttsEnabled
                          ? () {
                              final tts = TextToSpeechService();
                              tts.initialize().then((_) {
                                tts.setVolume(_currentSettings.ttsVolume);
                                tts.setPitch(_currentSettings.ttsPitch);

                                SpeechRate rate;
                                switch (_currentSettings.ttsRate) {
                                  case 'slow':
                                    rate = SpeechRate.slow;
                                    break;
                                  case 'fast':
                                    rate = SpeechRate.fast;
                                    break;
                                  default:
                                    rate = SpeechRate.normal;
                                }
                                tts.setSpeechRate(rate);

                                tts.speak(
                                    "This is how navigation instructions will sound");
                              });
                            }
                          : null,
                      child: const Text('Test Voice Output'),
                    ),
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

                  ListTile(
                    title: const Text('Open Source'),
                    subtitle: const Text('View source code on GitHub'),
                    trailing: const Icon(Icons.code),
                    onTap: () {
                      _openGitHub();
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
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              await _settingsService.resetToDefaults();
              if (mounted) {
                scaffoldMessenger.showSnackBar(
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
          SizedBox(height: 16),
          Text(
            'This app is open source and available on GitHub. '
            'Contributions and feedback are welcome!',
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

  Future<void> _openGitHub() async {
    final Uri url = Uri.parse('https://github.com/Milad9A/Echo-Map');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open GitHub repository'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening GitHub: $e'),
          ),
        );
      }
    }
  }

  ThemeMode _appThemeModeToThemeMode(AppThemeMode appThemeMode) {
    switch (appThemeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  AppThemeMode _themeModeToAppThemeMode(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return AppThemeMode.light;
      case ThemeMode.dark:
        return AppThemeMode.dark;
      case ThemeMode.system:
        return AppThemeMode.system;
    }
  }
}
