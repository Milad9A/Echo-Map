import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/navigation/navigation_bloc.dart';
import '../blocs/navigation/navigation_state.dart';
import '../blocs/navigation/navigation_event.dart';
import '../utils/theme_config.dart';

class NavigationStatusWidget extends StatelessWidget {
  final bool isCompact;
  final bool showControls;
  final VoidCallback? onTap;

  const NavigationStatusWidget({
    super.key,
    this.isCompact = true,
    this.showControls = false,
    this.onTap,
  });

  // Add a method to show rerouting status
  Widget _buildReroutingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Recalculating route...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationBloc, NavigationState>(
      builder: (context, state) {
        // Add rerouting state handling
        if (state is NavigationRerouting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.black.withValues(alpha: 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReroutingIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Finding new route to ${state.destination}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }

        if (state is NavigationIdle) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Card(
            margin: const EdgeInsets.all(16.0),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildContent(context, state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, NavigationState state) {
    if (state is NavigationActive) {
      return _buildActiveState(context, state);
    } else if (state is NavigationPaused) {
      return _buildPausedState(context, state);
    } else if (state is NavigationRerouting) {
      return _buildReroutingState(context, state);
    } else if (state is NavigationArrived) {
      return _buildArrivedState(context, state);
    } else if (state is NavigationError) {
      return _buildErrorState(context, state);
    } else if (state is NavigationEmergency) {
      return _buildEmergencyState(context, state);
    }

    return _buildIdleState(context);
  }

  Widget _buildIdleState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.navigation,
          size: 32,
          color: Colors.grey,
        ),
        const SizedBox(height: 8),
        Text(
          'Navigation Ready',
          style: TextStyle(
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
        if (!isCompact) ...[
          const SizedBox(height: 8),
          const Text(
            'Tap "Start Navigation" to begin your journey',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildActiveState(BuildContext context, NavigationActive state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              state.isOnRoute ? Icons.navigation : Icons.warning,
              color: state.isOnRoute ? ThemeConfig.accentColor : Colors.orange,
              size: isCompact ? 20 : 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.isOnRoute ? 'Navigating' : 'Off Route',
                style: TextStyle(
                  fontSize: isCompact ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  color:
                      state.isOnRoute ? ThemeConfig.accentColor : Colors.orange,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Add compact view indicator
            if (isCompact)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'COMPACT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Destination - always show but adjust size
        Text(
          'To: ${state.destination}',
          style: TextStyle(
            fontSize: isCompact ? 12 : 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),

        if (isCompact) ...[
          // COMPACT VIEW - Show only essential info in one line
          const SizedBox(height: 8),
          Row(
            children: [
              // Distance and time in compact format
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      state.distanceText,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      state.timeText,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // Next turn in compact format
              if (state.nextStep != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getTurnIcon(state.nextStep!.turnDirection),
                      size: 16,
                      color: ThemeConfig.accentColor,
                    ),
                    const SizedBox(width: 4),
                    if (state.distanceToNextStep != null)
                      Text(
                        _formatDistance(state.distanceToNextStep!),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: ThemeConfig.accentColor,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ] else ...[
          // DETAILED VIEW - Show full information with better layout
          // Next Step - Make this more prominent
          if (state.nextStep != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeConfig.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ThemeConfig.accentColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getTurnIcon(state.nextStep!.turnDirection),
                        size: 24,
                        color: ThemeConfig.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getTurnText(state.nextStep!.turnDirection),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ThemeConfig.accentColor,
                          ),
                        ),
                      ),
                      if (state.distanceToNextStep != null) ...[
                        Text(
                          'in ${_formatDistance(state.distanceToNextStep!)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                ThemeConfig.accentColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (state.nextStep!.friendlyInstruction.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      state.nextStep!.friendlyInstruction,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Distance and Time Row - Detailed view
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: state.distanceText,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.schedule,
                  label: 'Time',
                  value: state.timeText,
                ),
              ),
            ],
          ),

          // Controls - only in detailed view
          if (showControls) ...[
            const SizedBox(height: 12),
            _buildControlButtons(context),
          ],
        ],
      ],
    );
  }

  Widget _buildPausedState(BuildContext context, NavigationPaused state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.pause_circle,
              color: Colors.orange,
              size: isCompact ? 20 : 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Navigation Paused',
                style: TextStyle(
                  fontSize: isCompact ? 14 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Add compact view indicator
            if (isCompact)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'COMPACT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Destination
        Text(
          'To: ${state.destination}',
          style: TextStyle(
            fontSize: isCompact ? 12 : 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),

        if (isCompact) ...[
          // COMPACT VIEW for paused state
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      state.distanceText,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      state.timeText,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  context.read<NavigationBloc>().add(ResumeNavigation());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.accentColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  'Resume',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ] else ...[
          // DETAILED VIEW for paused state
          const SizedBox(height: 8),

          // Distance and Time Row
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: state.distanceText,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  icon: Icons.schedule,
                  label: 'Time',
                  value: state.timeText,
                ),
              ),
            ],
          ),

          // Next Step
          if (state.nextStep != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getTurnIcon(state.nextStep!.turnDirection),
                    size: 20,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.nextStep!.instruction,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Pause info
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Navigation is paused. Tap Resume to continue.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Controls
          if (showControls) ...[
            const SizedBox(height: 12),
            _buildPausedControlButtons(context),
          ],
        ],
      ],
    );
  }

  Widget _buildReroutingState(BuildContext context, NavigationRerouting state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          'Recalculating Route',
          style: TextStyle(
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (!isCompact) ...[
          const SizedBox(height: 8),
          Text(
            'To: ${state.destination}',
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildArrivedState(BuildContext context, NavigationArrived state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle,
          size: 32,
          color: ThemeConfig.accentColor,
        ),
        const SizedBox(height: 8),
        Text(
          'Arrived!',
          style: TextStyle(
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: ThemeConfig.accentColor,
          ),
          textAlign: TextAlign.center,
        ),
        if (!isCompact) ...[
          const SizedBox(height: 8),
          Text(
            'Welcome to ${state.destination}',
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          if (showControls) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.read<NavigationBloc>().add(StopNavigation());
                },
                child: const Text('Finish'),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, NavigationError state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error,
          size: 32,
          color: Colors.red,
        ),
        const SizedBox(height: 8),
        Text(
          'Navigation Error',
          style: TextStyle(
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
          textAlign: TextAlign.center,
        ),
        if (!isCompact) ...[
          const SizedBox(height: 8),
          Text(
            state.message,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          if (showControls) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.read<NavigationBloc>().add(StopNavigation());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Stop'),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildEmergencyState(BuildContext context, NavigationEmergency state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.warning,
          size: 32,
          color: Colors.orange,
        ),
        const SizedBox(height: 8),
        Text(
          'Emergency: ${state.emergencyType}',
          style: TextStyle(
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        if (!isCompact) ...[
          const SizedBox(height: 8),
          Text(
            state.description,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          if (state.actionRequired != null) ...[
            const SizedBox(height: 8),
            Text(
              state.actionRequired!,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
          if (showControls && state.isResolvable) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<NavigationBloc>().add(
                            const EmergencyResolved('User resolved emergency'),
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Resume',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<NavigationBloc>().add(StopNavigation());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Stop',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              context.read<NavigationBloc>().add(PauseNavigation());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text(
              'Pause',
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              context.read<NavigationBloc>().add(StopNavigation());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text(
              'Stop',
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPausedControlButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              context.read<NavigationBloc>().add(ResumeNavigation());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConfig.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text(
              'Resume',
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              context.read<NavigationBloc>().add(StopNavigation());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text(
              'Stop',
              style: TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getTurnIcon(String turnDirection) {
    switch (turnDirection.toLowerCase()) {
      case 'left':
        return Icons.turn_left;
      case 'right':
        return Icons.turn_right;
      case 'slight_left':
        return Icons.turn_slight_left;
      case 'slight_right':
        return Icons.turn_slight_right;
      case 'sharp_left':
        return Icons.turn_sharp_left;
      case 'sharp_right':
        return Icons.turn_sharp_right;
      case 'uturn':
        return Icons.u_turn_left;
      case 'straight':
        return Icons.straight;
      case 'merge':
        return Icons.merge;
      case 'exit':
        return Icons.exit_to_app;
      default:
        return Icons.navigation;
    }
  }

  String _getTurnText(String turnDirection) {
    switch (turnDirection.toLowerCase()) {
      case 'left':
        return 'Turn left';
      case 'right':
        return 'Turn right';
      case 'slight_left':
        return 'Slight left';
      case 'slight_right':
        return 'Slight right';
      case 'sharp_left':
        return 'Sharp left';
      case 'sharp_right':
        return 'Sharp right';
      case 'uturn':
        return 'Make U-turn';
      case 'straight':
        return 'Continue straight';
      case 'merge':
        return 'Merge';
      case 'exit':
        return 'Take exit';
      default:
        return 'Continue';
    }
  }

  String _formatDistance(int distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters}m';
    } else {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)}km';
    }
  }
}
