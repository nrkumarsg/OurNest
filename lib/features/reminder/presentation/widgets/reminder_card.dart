import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/platform/alarm_scheduler_service.dart';
import '../../domain/family_reminder_model.dart';

class ReminderCard extends ConsumerWidget {
  final FamilyReminder reminder;
  final bool isMine;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 270,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryTeal, width: 2),
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
          // Header Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_note_rounded,
                        size: 16, color: AppColors.primaryTeal),
                    const SizedBox(width: 6),
                    Text(
                      'FAMILY EVENT',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryTeal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'By ${reminder.createdByName}',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Event Title
          Text(
            reminder.title,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          // Date & Time
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 16, color: AppColors.accentCoral),
              const SizedBox(width: 6),
              Text(
                '${reminder.formattedDate} • ${reminder.formattedTime}',
                style: GoogleFonts.nunito(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCoralDark,
                ),
              ),
            ],
          ),
          if (reminder.notes != null && reminder.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              reminder.notes!,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Action button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryTeal,
                side: const BorderSide(color: AppColors.primaryTeal),
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.notification_add_rounded, size: 18),
              label: const Text('Remind Me on This Phone'),
              onPressed: () async {
                // Really schedules a notification now (F09); before, this
                // only showed a "scheduled" message.
                final result = await ref
                    .read(alarmSchedulerServiceProvider)
                    .scheduleReminder(
                      reminderKey: reminder.reminderId,
                      title: reminder.title,
                      at: reminder.eventDateTime,
                      notes: reminder.notes,
                    );
                if (!context.mounted) return;
                final (text, color) = switch (result) {
                  ReminderScheduleResult.scheduled => (
                      'You will be reminded on ${reminder.formattedDate} at ${reminder.formattedTime}.',
                      AppColors.primaryTeal
                    ),
                  ReminderScheduleResult.inPast => (
                      'This event time has already passed.',
                      AppColors.error
                    ),
                  ReminderScheduleResult.unsupported => (
                      'Phone reminders are only available in the Android / iPhone app.',
                      AppColors.error
                    ),
                };
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(text), backgroundColor: color),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
