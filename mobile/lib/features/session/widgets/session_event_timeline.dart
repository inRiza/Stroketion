import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/session_event_timeline.dart';

class SessionEventTimelineView extends StatelessWidget {
  const SessionEventTimelineView({super.key, required this.events});

  final List<SessionTimelineEvent> events;

  Color _dotColor(SessionEventSeverity severity) {
    switch (severity) {
      case SessionEventSeverity.high:
        return AppColors.primary;
      case SessionEventSeverity.medium:
        return AppColors.primaryLight;
      case SessionEventSeverity.low:
        return const Color(0xFF81C784);
      case SessionEventSeverity.info:
        return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Text(
        'Belum ada kejadian tercatat.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _EventRow(
            event: events[i],
            dotColor: _dotColor(events[i].severity),
            showLine: i < events.length - 1,
          ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.dotColor,
    required this.showLine,
  });

  final SessionTimelineEvent event;
  final Color dotColor;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 14 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        SessionEventTimeline.formatOffset(event.offsetSec),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (event.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
