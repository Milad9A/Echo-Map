import 'package:echo_map/blocs/navigation/navigation_bloc.dart';
import 'package:echo_map/blocs/navigation/navigation_state.dart';
import 'package:echo_map/widgets/navigation_status_widget.dart';
import 'package:echo_map/widgets/accessible_gesture_detector.dart' as widgets;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../blocs/location/location_state.dart';
import '../../blocs/location/location_event.dart';
import '../../services/gesture_handler_service.dart';
import '../../services/voice_command_service.dart';
import '../../services/vibration_service.dart';
import '../../utils/theme_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final VoiceCommandService _voiceCommandService = VoiceCommandService();
  final GestureHandlerService _gestureHandler = GestureHandlerService();
  final VibrationService _vibrationService = VibrationService();

  bool _isListening = false;
  bool _vibrationAvailable = false;
  bool _isCompactView = false; // Add this state variable
  late AnimationController _welcomeAnimationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimations();
    _setupVoiceCommandListener();

    // Initialize location bloc
    context.read<LocationBloc>().add(LocationInitialize());
  }

  void _setupAnimations() {
    _welcomeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _welcomeAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _welcomeAnimationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    _welcomeAnimationController.forward();
  }

  Future<void> _initializeServices() async {
    _gestureHandler.initialize();
    final vibrationAvailable = await _vibrationService.hasVibrator();
    if (mounted) {
      setState(() {
        _vibrationAvailable = vibrationAvailable;
      });
    }
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Navigating to $destination')),
          );
        } else {
          Navigator.pushNamed(context, '/map');
        }
        break;
      case 'startNavigation':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting navigation')),
        );
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'help':
        _showHelpDialog();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unrecognized command: ${result.transcript}')),
        );
    }
  }

  void _handleGesture(GestureType gesture) {
    switch (gesture) {
      case GestureType.shake:
        _announceStatus();
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

  void _announceStatus() {
    final locationState = context.read<LocationBloc>().state;
    String status = 'EchoMap is ready. ';

    if (locationState is LocationTracking) {
      status += 'Location tracking is active. ';
    } else if (locationState is LocationReady) {
      status += 'Location services are ready. ';
    } else {
      status += 'Location services need setup. ';
    }

    if (_vibrationAvailable) {
      status += 'Vibration feedback is available.';
    } else {
      status += 'Vibration feedback is not available.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status),
        duration: const Duration(seconds: 4),
      ),
    );

    // Provide haptic feedback if available
    if (_vibrationAvailable) {
      _vibrationService.simpleVibrate(duration: 200);
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('EchoMap Help'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Voice Commands:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• "Navigate" - Open map screen'),
                Text('• "Settings" - Open settings'),
                Text('• "Help" - Show this help'),
                SizedBox(height: 16),
                Text(
                  'Gestures:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Shake device - Announce current status'),
                Text('• Double tap - Confirm action'),
                Text('• Swipe down - Cancel operation'),
                SizedBox(height: 16),
                Text(
                  'Accessibility:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• All buttons work with screen readers'),
                Text('• Vibration patterns guide navigation'),
                Text('• High contrast mode supported'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _voiceCommandService.stopListening();
    _welcomeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoMap', semanticsLabel: 'EchoMap Navigation App'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Improved compact view toggle with better tooltip and icon
          IconButton(
            icon: Icon(_isCompactView ? Icons.unfold_more : Icons.unfold_less),
            tooltip: _isCompactView
                ? 'Switch to detailed navigation view'
                : 'Switch to compact navigation view',
            onPressed: () {
              setState(() {
                _isCompactView = !_isCompactView;
              });

              // Provide feedback about the change
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isCompactView
                      ? 'Switched to compact view - navigation info is summarized'
                      : 'Switched to detailed view - navigation info shows more details'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            tooltip: 'Voice commands',
            onPressed: _startVoiceRecognition,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: widgets.AccessibleGestureDetector(
        child: AnimatedBuilder(
          animation: _welcomeAnimationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeInAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    // Add a header to explain what compact view does
                    if (_isCompactView)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8.0),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.unfold_less,
                                color: Colors.blue.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Compact View: Navigation info is summarized',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Navigation status widget with proper compact setting
                    BlocBuilder<NavigationBloc, NavigationState>(
                      builder: (context, navigationState) {
                        return NavigationStatusWidget(
                          isCompact: _isCompactView,
                          showControls: navigationState is NavigationActive ||
                              navigationState is NavigationPaused,
                          onTap: () {
                            if (navigationState is NavigationIdle ||
                                navigationState is NavigationError) {
                              Navigator.pushNamed(context, '/map');
                            }
                          },
                        );
                      },
                    ),
                    // Simplified main content area for a cleaner UI
                    Expanded(
                      child: SingleChildScrollView(
                        padding:
                            const EdgeInsets.all(ThemeConfig.standardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildWelcomeSection(),
                            const SizedBox(height: ThemeConfig.largePadding),
                            _buildStatusSection(),
                            const SizedBox(height: ThemeConfig.largePadding),
                            _buildMainActions(),
                            // Removed Testing and Quick Tips sections for a less cluttered interface
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: Semantics(
        button: true,
        label: _isListening ? 'Stop voice commands' : 'Start voice commands',
        hint: 'Tap to toggle voice recognition',
        child: FloatingActionButton.extended(
          onPressed: _startVoiceRecognition,
          icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
          label: Text(_isListening ? 'Listening...' : 'Voice'),
          backgroundColor: _isListening ? ThemeConfig.accentColor : null,
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.largePadding),
        child: Column(
          children: [
            Semantics(
              label: 'Welcome to EchoMap',
              hint: 'A navigation app designed for blind and low vision users',
              header: true,
              child: const Text(
                'Welcome to EchoMap',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: ThemeConfig.standardPadding),
            const Text(
              'Navigate confidently with vibration-guided directions',
              style: TextStyle(
                fontSize: ThemeConfig.largeText,
                color: ThemeConfig.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ThemeConfig.smallPadding),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.vibration,
                  color: _vibrationAvailable
                      ? ThemeConfig.accentColor
                      : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _vibrationAvailable
                      ? 'Vibration Ready'
                      : 'Vibration Unavailable',
                  style: TextStyle(
                    color: _vibrationAvailable
                        ? ThemeConfig.accentColor
                        : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, state) {
        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(ThemeConfig.standardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Status',
                  style: TextStyle(
                    fontSize: ThemeConfig.mediumText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: ThemeConfig.smallPadding),
                _buildStatusItem(
                  'Location Services',
                  _getLocationStatusText(state),
                  _getLocationStatusIcon(state),
                  _getLocationStatusColor(state),
                ),
                _buildStatusItem(
                  'Vibration Feedback',
                  _vibrationAvailable ? 'Available' : 'Not Available',
                  _vibrationAvailable ? Icons.check_circle : Icons.error,
                  _vibrationAvailable ? ThemeConfig.accentColor : Colors.orange,
                ),
                _buildStatusItem(
                  'Voice Commands',
                  _isListening ? 'Listening' : 'Ready',
                  _isListening ? Icons.mic : Icons.mic_none,
                  _isListening
                      ? ThemeConfig.accentColor
                      : ThemeConfig.primaryColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusItem(
      String label, String status, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: ThemeConfig.smallText),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: ThemeConfig.smallText,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActions() {
    return Semantics(
      button: true,
      label: 'Open map and start navigation',
      hint: 'Navigate to the map screen to plan your route',
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/map'),
        icon: const Icon(Icons.map, size: 28),
        label: const Text(
          'Start Navigation',
          style: TextStyle(fontSize: ThemeConfig.largeText),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          backgroundColor: ThemeConfig.primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  String _getLocationStatusText(LocationState state) {
    if (state is LocationTracking) return 'Active';
    if (state is LocationReady) return 'Ready';
    if (state is LocationPermissionDenied) return 'Permission Needed';
    if (state is LocationServiceDisabled) return 'Service Disabled';
    if (state is LocationError) return 'Error';
    return 'Initializing';
  }

  IconData _getLocationStatusIcon(LocationState state) {
    if (state is LocationTracking) return Icons.gps_fixed;
    if (state is LocationReady) return Icons.gps_not_fixed;
    if (state is LocationPermissionDenied) return Icons.gps_off;
    if (state is LocationServiceDisabled) return Icons.location_disabled;
    if (state is LocationError) return Icons.error;
    return Icons.hourglass_empty;
  }

  Color _getLocationStatusColor(LocationState state) {
    if (state is LocationTracking) return ThemeConfig.accentColor;
    if (state is LocationReady) return ThemeConfig.primaryColor;
    if (state is LocationPermissionDenied) return Colors.orange;
    if (state is LocationTracking) return ThemeConfig.accentColor;
    if (state is LocationReady) return ThemeConfig.primaryColor;
    if (state is LocationPermissionDenied) return Colors.orange;
    if (state is LocationServiceDisabled) return Colors.red;
    if (state is LocationError) return Colors.red;
    return Colors.grey;
  }
}
