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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationBloc, NavigationState>(
      builder: (context, state) {
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
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.isOnRoute ? 'Navigating' : 'Off Route',
                style: TextStyle(
                  fontSize: isCompact ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color:
                      state.isOnRoute ? ThemeConfig.accentColor : Colors.orange,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Destination
        Text(
          'To: ${state.destination}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),

        if (!isCompact) ...[
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
                color: ThemeConfig.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getTurnIcon(state.nextStep!.turnDirection),
                    size: 20,
                    color: ThemeConfig.accentColor,
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

          // Controls
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
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Navigation Paused',
                style: TextStyle(
                  fontSize: isCompact ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Destination
        Text(
          'To: ${state.destination}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),

        if (!isCompact) ...[
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
      case 'uturn':
        return Icons.u_turn_left;
      case 'straight':
        return Icons.straight;
      default:
        return Icons.navigation;
    }
  }
}
