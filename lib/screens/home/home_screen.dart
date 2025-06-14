import 'package:flutter/material.dart';
import '../../services/gesture_handler_service.dart';
import '../../services/voice_command_service.dart';
import '../../utils/theme_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VoiceCommandService _voiceCommandService = VoiceCommandService();
  final GestureHandlerService _gestureHandler = GestureHandlerService();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _gestureHandler.initialize();
    _setupVoiceCommandListener();
  }

  void _setupVoiceCommandListener() {
    _voiceCommandService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isListening = status == VoiceCommandStatus.listening;
        });
      }
    });

    _voiceCommandService.commandStream.listen((result) {
      _handleVoiceCommand(result);
    });

    _gestureHandler.gestureStream.listen((gesture) {
      _handleGesture(gesture);
    });
  }

  void _handleVoiceCommand(CommandRecognitionResult result) {
    switch (result.command) {
      case 'navigate':
        final destination = result.parameters?['destination'];
        if (destination != null) {
          // Navigate to the specified destination
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Navigating to $destination')));
        } else {
          Navigator.pushNamed(context, '/map');
        }
        break;
      case 'startNavigation':
        // Start navigation with current route
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Starting navigation')));
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'help':
        // Show help screen
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Opening help')));
        break;
      default:
        // Unknown command
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unrecognized command: ${result.transcript}')),
        );
    }
  }

  void _handleGesture(GestureType gesture) {
    switch (gesture) {
      case GestureType.shake:
        // Report status
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current status: Ready for navigation')),
        );
        break;
      case GestureType.doubleTap:
        // Already handled by button press
        break;
      case GestureType.swipeDown:
        // Cancel current operation
        break;
      default:
        break;
    }
  }

  void _startVoiceRecognition() async {
    final available = await _voiceCommandService.isAvailable();
    if (available) {
      await _voiceCommandService.startListening();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice recognition not available')),
        );
      }
    }
  }

  @override
  void dispose() {
    _voiceCommandService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoMap', semanticsLabel: 'EchoMap Navigation App'),
        actions: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            tooltip: 'Voice commands',
            onPressed: _startVoiceRecognition,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: AccessibleGestureDetector(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'Welcome to EchoMap',
                hint: 'A navigation app for blind and low vision users',
                header: true,
                child: Text(
                  'Welcome to EchoMap',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: ThemeConfig.largePadding),
              Semantics(
                button: true,
                label: 'Open map',
                hint: 'Navigate to the map screen',
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/map');
                  },
                  icon: const Icon(Icons.map),
                  label: const Text(
                    'Open Map',
                    style: TextStyle(fontSize: ThemeConfig.largeText),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(250, ThemeConfig.minimumTouchSize),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ThemeConfig.standardPadding),
              Semantics(
                button: true,
                label: 'Start Navigation',
                hint: 'Begin a new navigation route',
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Will implement navigation functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigation starting...')),
                    );
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text(
                    'Start Navigation',
                    style: TextStyle(fontSize: ThemeConfig.largeText),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(250, ThemeConfig.minimumTouchSize),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    backgroundColor: ThemeConfig.secondaryColor,
                  ),
                ),
              ),
              const SizedBox(height: ThemeConfig.standardPadding),
              Semantics(
                button: true,
                label: 'Test vibration patterns',
                hint: 'Open the vibration test screen',
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/vibration_test');
                  },
                  icon: const Icon(Icons.vibration),
                  label: const Text(
                    'Vibration Test',
                    style: TextStyle(fontSize: ThemeConfig.largeText),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(250, ThemeConfig.minimumTouchSize),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ThemeConfig.standardPadding),
              Semantics(
                button: true,
                label: 'Test location service',
                hint: 'Open the location test screen',
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/location_test');
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text(
                    'Location Test',
                    style: TextStyle(fontSize: ThemeConfig.largeText),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(250, ThemeConfig.minimumTouchSize),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        onDoubleTap: () {
          // Double tap functionality for the main screen
        },
        onSwipeDown: () {
          // Swipe down to close the app or cancel
        },
      ),
      floatingActionButton: Semantics(
        button: true,
        label: 'Voice commands',
        hint: 'Tap to speak a command',
        child: FloatingActionButton(
          onPressed: _startVoiceRecognition,
          tooltip: 'Voice Commands',
          child: Icon(_isListening ? Icons.mic : Icons.mic_none),
        ),
      ),
    );
  }
}
