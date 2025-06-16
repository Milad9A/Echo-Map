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
                    // Navigation Status Widget - more prominent when active
                    BlocBuilder<NavigationBloc, NavigationState>(
                      builder: (context, navigationState) {
                        return NavigationStatusWidget(
                          isCompact: navigationState is NavigationActive
                              ? false
                              : true,
                          showControls: navigationState is NavigationActive,
                          onTap: () {
                            // Navigate to map when tapped, but only if not already navigating
                            if (navigationState is NavigationIdle ||
                                navigationState is NavigationError) {
                              Navigator.pushNamed(context, '/map');
                            }
                          },
                        );
                      },
                    ),

                    // Main content in scrollable area
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
                            const SizedBox(height: ThemeConfig.largePadding),
                            _buildTestingSection(),
                            const SizedBox(height: ThemeConfig.largePadding),
                            _buildQuickTips(),
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
        onDoubleTap: () {
          // Double tap to start navigation quickly
          Navigator.pushNamed(context, '/map');
        },
        onSwipeDown: () {
          // Swipe down for status announcement
          _announceStatus();
        },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Main Actions',
          style: TextStyle(
            fontSize: ThemeConfig.largeText,
            fontWeight: FontWeight.bold,
            color: ThemeConfig.primaryColor,
          ),
        ),
        const SizedBox(height: ThemeConfig.standardPadding),
        Semantics(
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
        ),
        const SizedBox(height: ThemeConfig.standardPadding),
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Open map view',
                hint: 'View the map without starting navigation',
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/map'),
                  icon: const Icon(Icons.explore),
                  label: const Text('Explore Map'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: ThemeConfig.secondaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: ThemeConfig.standardPadding),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Open settings',
                hint: 'Configure app preferences and accessibility options',
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  icon: const Icon(Icons.settings),
                  label: const Text('Settings'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTestingSection() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Testing & Setup',
              style: TextStyle(
                fontSize: ThemeConfig.mediumText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: ThemeConfig.standardPadding),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Test vibration patterns',
                    hint: 'Test and configure vibration feedback patterns',
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/vibration_test'),
                      icon: const Icon(Icons.vibration),
                      label: const Text('Vibration'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: ThemeConfig.smallPadding),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Test location services',
                    hint: 'Test and verify location tracking functionality',
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/location_test'),
                      icon: const Icon(Icons.location_on),
                      label: const Text('Location'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTips() {
    return Card(
      elevation: 1,
      color: ThemeConfig.accentColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: ThemeConfig.accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Quick Tips',
                  style: TextStyle(
                    fontSize: ThemeConfig.mediumText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ThemeConfig.standardPadding),
            _buildTip('Shake your device to hear the current status'),
            _buildTip('Double tap the screen to quickly start navigation'),
            _buildTip('Use voice commands by tapping the microphone'),
            _buildTip(
                'Use the touch icon to select destinations by tapping the map'),
            _buildTip('All features work with your screen reader'),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: ThemeConfig.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(fontSize: ThemeConfig.smallText),
            ),
          ),
        ],
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
    if (state is LocationServiceDisabled) return Colors.red;
    if (state is LocationError) return Colors.red;
    return Colors.grey;
  }
}
