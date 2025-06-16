import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../utils/theme_config.dart';
import '../../services/vibration_service.dart';
import '../../services/settings_service.dart';
import '../../services/recent_places_service.dart';
import '../../services/geocoding_service.dart';
import '../../blocs/location/location_bloc.dart';
import '../../blocs/location/location_event.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _progressAnimation;

  final VibrationService _vibrationService = VibrationService();
  final SettingsService _settingsService = SettingsService();
  final RecentPlacesService _recentPlacesService = RecentPlacesService();
  final GeocodingService _geocodingService = GeocodingService();

  String _currentStatus = 'Starting EchoMap...';
  bool _initializationComplete = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    // Logo animation controller - reduced duration
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Text animation controller - reduced duration
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Progress animation controller - reduced duration
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Logo animations
    _logoScaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    // Text animations
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    // Progress animation
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    // Start logo animation immediately
    _logoController.forward();

    // Start text animation with reduced delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _textController.forward();
      }
    });

    // Start progress animation with reduced delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _progressController.forward();
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize vibration service first - reduced delay
      await _updateStatus('Setting up haptic feedback...', 200);
      await _vibrationService.initialize();

      // Check if vibration is available and provide initial feedback
      final hasVibrator = await _vibrationService.hasVibrator();
      if (hasVibrator) {
        await _vibrationService.simpleVibrate(duration: 50);
      }

      // Initialize settings service - reduced delay
      await _updateStatus('Loading your preferences...', 200);
      await _settingsService.initialize();

      // Initialize location services through bloc - reduced delay
      await _updateStatus('Preparing location services...', 200);
      if (mounted) {
        context.read<LocationBloc>().add(LocationInitialize());
      }

      // Initialize geocoding service - reduced delay
      await _updateStatus('Connecting to mapping services...', 200);
      await _geocodingService.initialize();

      // Initialize recent places service - reduced delay
      await _updateStatus('Loading your favorite places...', 200);
      await _recentPlacesService.initialize();

      // Final setup - reduced delay
      await _updateStatus('Finalizing setup...', 150);

      // Completion feedback - reduced delay
      await _updateStatus('Welcome to EchoMap!', 100);
      if (hasVibrator) {
        // Success pattern: short-short-long
        await _vibrationService.simpleVibrate(duration: 100);
        await Future.delayed(const Duration(milliseconds: 50));
        await _vibrationService.simpleVibrate(duration: 100);
        await Future.delayed(const Duration(milliseconds: 50));
        await _vibrationService.simpleVibrate(duration: 200);
      }

      _initializationComplete = true;

      // Reduced wait time before navigating
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      await _updateStatus('Setup encountered an issue', 200);

      // Error feedback
      final hasVibrator = await _vibrationService.hasVibrator();
      if (hasVibrator) {
        // Error pattern: long-short-long
        await _vibrationService.simpleVibrate(duration: 200);
        await Future.delayed(const Duration(milliseconds: 100));
        await _vibrationService.simpleVibrate(duration: 100);
        await Future.delayed(const Duration(milliseconds: 100));
        await _vibrationService.simpleVibrate(duration: 200);
      }

      await _updateStatus('Continuing anyway...', 200);

      // Continue to app even if there were initialization errors
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  Future<void> _updateStatus(String status, int delayMs) async {
    if (mounted) {
      setState(() {
        _currentStatus = status;
      });
    }
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we're in dark mode
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDarkMode
        ? Theme.of(context).colorScheme.surface
        : ThemeConfig.primaryColor;
    final Color foregroundColor =
        isDarkMode ? Theme.of(context).colorScheme.onSurface : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Semantics(
            label: 'EchoMap is starting up',
            hint: 'Please wait while the navigation app initializes',
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Logo section with EchoMap-specific icon
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Opacity(
                          opacity: _logoOpacityAnimation.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Theme.of(context).colorScheme.surface
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 25,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Main navigation icon
                                Icon(
                                  Icons.navigation,
                                  size: 65,
                                  color: isDarkMode
                                      ? Theme.of(context).colorScheme.primary
                                      : ThemeConfig.primaryColor,
                                ),
                                // Vibration indicator (subtle pulse effect)
                                Positioned(
                                  bottom: 15,
                                  right: 15,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: ThemeConfig.accentColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: ThemeConfig.accentColor
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.vibration,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // App name and tagline
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _textSlideAnimation,
                        child: FadeTransition(
                          opacity: _textFadeAnimation,
                          child: Column(
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'EchoMap',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: foregroundColor,
                                    letterSpacing: 3,
                                    shadows: [
                                      Shadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        offset: const Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Navigate with Vibration',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: foregroundColor.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Designed for Accessibility',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: foregroundColor.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w300,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(flex: 2),

                  // Progress section
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return Column(
                        children: [
                          // Status text with live region for screen readers
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              height:
                                  60, // Fixed height to prevent layout jumps
                              alignment: Alignment.center,
                              child: Text(
                                _currentStatus,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: foregroundColor.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Progress indicator
                          Container(
                            width: double.infinity,
                            height: 6,
                            decoration: BoxDecoration(
                              color: foregroundColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Stack(
                                children: [
                                  // Progress bar
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _progressAnimation.value,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            isDarkMode
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .secondary
                                                : ThemeConfig.accentColor,
                                            isDarkMode
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .secondary
                                                    .withValues(alpha: 0.7)
                                                : ThemeConfig.accentColor
                                                    .withValues(alpha: 0.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isDarkMode
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .secondary
                                                    : ThemeConfig.accentColor)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Shimmer effect
                                  if (_progressAnimation.value > 0 &&
                                      _progressAnimation.value < 1)
                                    Positioned(
                                      left: (_progressAnimation.value *
                                              MediaQuery.of(context)
                                                  .size
                                                  .width) -
                                          60,
                                      child: Container(
                                        width: 60,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withValues(alpha: 0),
                                              Colors.white
                                                  .withValues(alpha: 0.3),
                                              Colors.white.withValues(alpha: 0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Features preview
                  if (_initializationComplete)
                    FadeTransition(
                      opacity: _textFadeAnimation,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFeatureIcon(
                            Icons.vibration,
                            'Haptic\nGuidance',
                            foregroundColor,
                          ),
                          _buildFeatureIcon(
                            Icons.accessibility,
                            'Screen Reader\nFriendly',
                            foregroundColor,
                          ),
                          _buildFeatureIcon(
                            Icons.navigation,
                            'Turn-by-Turn\nNavigation',
                            foregroundColor,
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: color.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
