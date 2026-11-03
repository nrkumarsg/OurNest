import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../family/presentation/family_controller.dart';
import '../domain/shared_alarm_model.dart';
import 'alarm_controller.dart';

class AlarmRingingScreen extends ConsumerWidget {
  final SharedAlarm alarm;
  final bool isEscalation;

  const AlarmRingingScreen({
    super.key,
    required this.alarm,
    this.isEscalation = false,
  });

  Future<void> _callMember(String? phone) async {
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentMembershipProvider).value;
    final isOwner = alarm.isOwner(membership?.userId ?? '');

    return Scaffold(
      backgroundColor: isEscalation ? const Color(0xFF330B0B) : AppColors.primaryTealDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              // Ringing Bell Icon Animation
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: (isEscalation ? AppColors.error : AppColors.accentCoral)
                        .withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEscalation ? Icons.warning_rounded : Icons.alarm_rounded,
                    size: 60,
                    color: isEscalation ? AppColors.error : AppColors.accentCoral,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Time
              Text(
                alarm.formattedTime,
                style: GoogleFonts.nunito(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Title / Warning
              Text(
                isEscalation
                    ? '🚨 ${alarm.ownerName ?? "Family Member"} hasn\'t woken up yet!'
                    : alarm.label,
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isEscalation ? AppColors.accentCoralLight : Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isEscalation
                    ? 'This alarm has escalated to you because they did not confirm waking up.'
                    : 'Your family is counting on you to wake up!',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),

              // OWNER CONTROLS: "I'M AWAKE" & "Snooze"
              if (!isEscalation && isOwner) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () async {
                    if (membership != null) {
                      await ref.read(alarmControllerProvider.notifier).acknowledgeAlarm(
                            familyId: membership.familyId,
                            alarmId: alarm.alarmId,
                          );
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(
                    'I\'M AWAKE ✓',
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 2),
                    minimumSize: const Size(double.infinity, 54),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Snooze (5 mins)'),
                ),
              ],

              // ESCALATION CONTROLS: [📞 Call him]
              if (isEscalation || !isOwner) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.phone_rounded, size: 28),
                  label: Text(
                    'Call ${alarm.ownerName ?? "Member"} Now',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed: () => _callMember(null),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Dismiss Alert',
                    style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ],
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
