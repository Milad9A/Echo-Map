import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../blocs/location/location_bloc.dart';
import '../../blocs/location/location_state.dart';
import '../../blocs/location/location_event.dart';
import '../../services/vibration_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme_config.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with TickerProviderStateMixin {
  final VibrationService _vibrationService = VibrationService();

  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _iconScaleAnimation;

  bool _isRequestingPermission = false;
  bool _vibrationAvailable = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeServices();
    _animationController.forward();

    // Track screen view
    AnalyticsService.logNavigation('location_permission_screen');
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    _iconScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
    ));
  }

  Future<void> _initializeServices() async {
    _vibrationAvailable = await _vibrationService.hasVibrator();
  }

  void _handleGrantPermission() async {
    if (_isRequestingPermission) return;

    setState(() {
      _isRequestingPermission = true;
    });

    if (_vibrationAvailable) {
      await _vibrationService.simpleVibrate(duration: 50);
    }

    // Track permission request
    AnalyticsService.analytics.logEvent(
      name: 'location_permission_requested',
    );

    // Request permission through the bloc
    if (mounted) {
      context.read<LocationBloc>().add(LocationPermissionRequest());
    }
  }

  void _handleSkipForNow() async {
    if (_vibrationAvailable) {
      await _vibrationService.simpleVibrate(duration: 30);
    }

    // Track skip action
    AnalyticsService.analytics.logEvent(
      name: 'location_permission_skipped',
    );

    // Navigate to home screen
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _handleOpenSettings() async {
    if (_vibrationAvailable) {
      await _vibrationService.simpleVibrate(duration: 50);
    }

    // Track settings open
    AnalyticsService.analytics.logEvent(
      name: 'location_settings_opened',
    );

    // Open app settings
    await Geolocator.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state is LocationReady) {
            // Permission granted, navigate to home
            Navigator.of(context).pushReplacementNamed('/home');
          } else if (state is LocationError) {
            // Handle error
            setState(() {
              _isRequestingPermission = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is LocationPermissionDenied) {
            setState(() {
              _isRequestingPermission = false;
            });
          } else if (state is LocationPermissionPermanentlyDenied) {
            setState(() {
              _isRequestingPermission = false;
            });
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ThemeConfig.standardPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                AnimatedBuilder(
                  animation: _iconScaleAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Transform.scale(
                        scale: _iconScaleAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.location_on,
                            size: 60,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Title
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeInAnimation,
                    child: BlocBuilder<LocationBloc, LocationState>(
                      builder: (context, state) {
                        String title;
                        if (state is LocationPermissionPermanentlyDenied) {
                          title = 'Location Permission Required';
                        } else if (state is LocationPermissionDenied) {
                          title = 'Enable Location Services';
                        } else {
                          title = 'Welcome to EchoMap';
                        }

                        return Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          textAlign: TextAlign.center,
                          semanticsLabel: title,
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeInAnimation,
                    child: BlocBuilder<LocationBloc, LocationState>(
                      builder: (context, state) {
                        String description;
                        if (state is LocationPermissionPermanentlyDenied) {
                          description =
                              'Location permission was permanently denied. Please enable it in your device settings to use EchoMap\'s navigation features.';
                        } else if (state is LocationPermissionDenied) {
                          description =
                              'EchoMap needs access to your location to provide navigation assistance and audio cues. This helps you navigate safely and independently.';
                        } else {
                          description =
                              'To get started, EchoMap needs access to your location to provide navigation assistance and audio cues. This helps you navigate safely and independently.';
                        }

                        return Text(
                          description,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                          textAlign: TextAlign.center,
                          semanticsLabel: description,
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Permission status indicator
                BlocBuilder<LocationBloc, LocationState>(
                  builder: (context, state) {
                    if (state is LocationPermissionPermanentlyDenied) {
                      return FadeTransition(
                        opacity: _fadeInAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Location permission was permanently denied. Please enable it in settings.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 32),

                // Action buttons
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeInAnimation,
                    child: Column(
                      children: [
                        // Primary action - Grant Permission or Open Settings
                        BlocBuilder<LocationBloc, LocationState>(
                          builder: (context, state) {
                            if (state is LocationPermissionPermanentlyDenied) {
                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _handleOpenSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Open Settings',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    semanticsLabel: 'Open app settings',
                                  ),
                                ),
                              );
                            }

                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isRequestingPermission
                                    ? null
                                    : _handleGrantPermission,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isRequestingPermission
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : BlocBuilder<LocationBloc, LocationState>(
                                        builder: (context, state) {
                                          String buttonText;
                                          String semanticsLabel;

                                          if (state
                                              is LocationPermissionDenied) {
                                            buttonText = 'Grant Permission';
                                            semanticsLabel =
                                                'Grant location permission';
                                          } else {
                                            buttonText =
                                                'Allow Location Access';
                                            semanticsLabel =
                                                'Allow location access';
                                          }

                                          return Text(
                                            buttonText,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            semanticsLabel: semanticsLabel,
                                          );
                                        },
                                      ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // Secondary action - Skip for now
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _handleSkipForNow,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Continue Without Location',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                              semanticsLabel:
                                  'Continue without location access',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Privacy note
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeInAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.privacy_tip,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your location data is used only for navigation and is not shared with third parties.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                              semanticsLabel:
                                  'Privacy notice: location data is used only for navigation',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
