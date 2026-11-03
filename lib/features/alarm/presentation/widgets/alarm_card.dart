import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/shared_alarm_model.dart';
import '../alarm_controller.dart';

class AlarmCard extends ConsumerWidget {
  final SharedAlarm alarm;
  final bool isMine;

  const AlarmCard({
    super.key,
    required this.alarm,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAck = alarm.status == AlarmStatus.acknowledged;
    final isEscalated = alarm.status == AlarmStatus.escalated;
    final isCancelled = alarm.status == AlarmStatus.cancelled;

    Color cardBorderColor = AppColors.accentCoral;
    Color statusBadgeColor = AppColors.accentCoral.withOpacity(0.15);
    Color statusTextColor = AppColors.accentCoralDark;
    String statusText = '⏰ Rings at ${alarm.formattedTime}';

    if (isAck) {
      cardBorderColor = AppColors.success;
      statusBadgeColor = AppColors.success.withOpacity(0.15);
      statusTextColor = AppColors.success;
      statusText = '✓ ${alarm.ownerName ?? "Member"} is awake!';
    } else if (isEscalated) {
      cardBorderColor = AppColors.error;
      statusBadgeColor = AppColors.error.withOpacity(0.15);
      statusTextColor = AppColors.error;
      statusText = '🚨 Escalated: Not awake yet!';
    } else if (isCancelled) {
      cardBorderColor = AppColors.dividerLight;
      statusBadgeColor = AppColors.dividerLight;
      statusTextColor = AppColors.textSecondaryLight;
      statusText = 'Cancelled';
    }

    return Container(
      width: 270,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Alarm Icon & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isAck
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.accentCoral.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAck ? Icons.alarm_on_rounded : Icons.alarm_rounded,
                      color: isAck ? AppColors.success : AppColors.accentCoral,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    alarm.formattedTime,
                    style: GoogleFonts.nunito(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Label
          Text(
            alarm.label,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          Text(
            '${alarm.formattedDate} • Escalate after ${alarm.escalateAfterMin}m',
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBadgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: statusTextColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Action Buttons: [Cancel] & [Test Ring]
          if (!isAck && !isCancelled)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(alarmControllerProvider.notifier).cancelAlarm(alarm.alarmId);
                  },
                  child: const Text('Cancel Alarm', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
