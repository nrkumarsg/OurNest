import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/platform/alarm_scheduler_service.dart';
import '../../../family/presentation/family_controller.dart';
import '../../domain/shared_alarm_model.dart';
import '../alarm_controller.dart';
import '../alarm_status_provider.dart';

class AlarmCard extends ConsumerWidget {
  final SharedAlarm alarm;
  final bool isMine;

  const AlarmCard({
    super.key,
    required this.alarm,
    required this.isMine,
  });

  Future<void> _confirmCancel(
      BuildContext context, WidgetRef ref, String familyId,
      {required bool forEveryone}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(forEveryone ? 'Cancel this alarm?' : 'Silence this alarm?'),
        content: Text(forEveryone
            ? "It will be cancelled on every family member's phone."
            : 'It will only be silenced on this phone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await ref
        .read(alarmControllerProvider.notifier)
        .cancelAlarm(familyId: familyId, alarm: alarm);
    if (!sent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Cancelled on this phone, but could not tell the family. Check your connection.'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentMembershipProvider).value;
    final activeMembers = ref.watch(activeMembersProvider);
    final familyId = membership?.familyId;
    final myUserId = membership?.userId ?? '';

    // Resolve the actual names of the phones that will ring
    final participantMembers = activeMembers
        .where((m) =>
            alarm.participants.isEmpty ||
            alarm.participants.contains(m.userId))
        .toList();
    final ringingPhoneNames = participantMembers.isNotEmpty
        ? participantMembers.map((m) {
            final isMe = m.userId == myUserId;
            return isMe
                ? '${m.displayName} (You)'
                : '${m.displayName} (${m.formattedRelation})';
          }).join(' + ')
        : (alarm.ownerName ?? 'Your Phone');

    // Status follows later "I'm awake" / cancel events in the chat.
    final status =
        ref.watch(alarmStatusOverridesProvider)[alarm.alarmId] ?? alarm.status;
    final isAck = status == AlarmStatus.acknowledged;
    final isEscalated = status == AlarmStatus.escalated;
    final isCancelled = status == AlarmStatus.cancelled;

    Color cardBorderColor = AppColors.accentCoral;
    Color statusBadgeColor = AppColors.accentCoral.withOpacity(0.15);
    Color statusTextColor = AppColors.accentCoralDark;
    String statusText =
        '⏰ Rings on ${participantMembers.length <= 1 ? "1 Phone" : "${participantMembers.length} Phones"} at ${alarm.formattedTime}';

    if (isAck) {
      cardBorderColor = AppColors.success;
      statusBadgeColor = AppColors.success.withOpacity(0.15);
      statusTextColor = AppColors.success;
      statusText = '✓ Confirmed Awake — All phones silenced!';
    } else if (isEscalated) {
      cardBorderColor = AppColors.error;
      statusBadgeColor = AppColors.error.withOpacity(0.15);
      statusTextColor = AppColors.error;
      statusText = '🚨 Escalated: Not awake yet!';
    } else if (isCancelled) {
      cardBorderColor = AppColors.dividerLight;
      statusBadgeColor = AppColors.dividerLight;
      statusTextColor = AppColors.textSecondaryLight;
      statusText = '🔕 Alarm Cancelled';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? const Color(0xFFF5F7F7) : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? const Color(0xFFCFD8DC) : AppColors.textSecondaryLight;

    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
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
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Ring / Test Buzzer Now',
                icon: const Icon(Icons.notifications_active_rounded,
                    color: AppColors.accentCoral, size: 22),
                onPressed: () {
                  context.push(
                    '/alarm',
                    extra: AlarmNotificationTap(
                      alarm,
                      isEscalation: !alarm.isOwner(myUserId),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Label
          Text(
            alarm.label,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          Text(
            '📅 ${alarm.formattedDate} (${alarm.escalateAfterMin == 0 ? "Rings Together" : "${alarm.escalateAfterMin}m follow-up"})',
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          // EXPLICIT CONFIRMATION OF WHICH PHONES WILL RING
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryTeal.withOpacity(0.3),
              ),
            ),
            child: Text(
              '📲 Phones Ringing: $ringingPhoneNames',
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.tealAccent : AppColors.primaryTeal,
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: statusTextColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Action Buttons wrapped cleanly so "Cancel Alarm" never overflows
          if (!isAck && !isCancelled)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                if (alarm.isOwner(myUserId))
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: AppColors.success),
                    label: const Text(
                      "I'm awake ✓",
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: familyId == null
                        ? null
                        : () => ref
                            .read(alarmControllerProvider.notifier)
                            .acknowledgeAlarm(
                                familyId: familyId, alarmId: alarm.alarmId),
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.notifications_off_outlined,
                      size: 16, color: AppColors.error),
                  label: Text(
                    alarm.isOwner(myUserId) ? 'Cancel Alarm' : 'Silence Phone',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: familyId == null
                      ? null
                      : () => _confirmCancel(context, ref, familyId,
                          forEveryone: alarm.isOwner(myUserId)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
