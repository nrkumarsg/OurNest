import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/platform/alarm_scheduler_service.dart';
import '../../family/presentation/family_controller.dart';
import '../domain/shared_alarm_model.dart';
import 'alarm_controller.dart';

class AlarmRingingScreen extends ConsumerStatefulWidget {
  final SharedAlarm alarm;
  final bool isEscalation;

  const AlarmRingingScreen({
    super.key,
    required this.alarm,
    this.isEscalation = false,
  });

  @override
  ConsumerState<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends ConsumerState<AlarmRingingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(alarmSchedulerServiceProvider).startBuzzer();
      }
    });
  }

  @override
  void dispose() {
    ref.read(alarmSchedulerServiceProvider).stopBuzzer();
    super.dispose();
  }

  Future<void> _callMember(String? phone) async {
    await ref.read(alarmSchedulerServiceProvider).stopBuzzer();
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  /// Works whether the screen was pushed from chat or opened by tapping the
  /// alarm notification on a cold start (no screen to go back to).
  Future<void> _close(BuildContext context) async {
    await ref.read(alarmSchedulerServiceProvider).stopBuzzer();
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final alarm = widget.alarm;
    final isEscalation = widget.isEscalation;
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
                    isEscalation ? Icons.warning_rounded : Icons.notifications_active_rounded,
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
                    ? '🚨 ${alarm.ownerName ?? "Family Member"} Wake-Up Alert!'
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
                    ? 'Shared family wake-up buzzer is ringing on both phones!'
                    : 'Your family is counting on you to wake up!',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.85),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),

              // OWNER CONTROLS: "I'M AWAKE" & "Snooze"
              if (isOwner) ...[
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
                    await ref.read(alarmSchedulerServiceProvider).stopBuzzer();
                    if (membership != null) {
                      await ref.read(alarmControllerProvider.notifier).acknowledgeAlarm(
                            familyId: membership.familyId,
                            alarmId: alarm.alarmId,
                          );
                    }
                    if (context.mounted) await _close(context);
                  },
                  child: Text(
                    'I\'M AWAKE ✓ (Stop Buzzer)',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
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
                  onPressed: () async {
                    final scheduler = ref.read(alarmSchedulerServiceProvider);
                    await scheduler.stopBuzzer();
                    await scheduler.cancelAlarm(alarm.alarmId);
                    await scheduler.scheduleAlarm(
                      alarm: alarm.copyWith(
                          time: DateTime.now().add(const Duration(minutes: 5))),
                      currentUserId: membership?.userId ?? '',
                    );
                    if (context.mounted) await _close(context);
                  },
                  child: const Text('Snooze (5 mins)'),
                ),
              ],

              // PARTICIPANT / ESCALATION CONTROLS: [📞 Call] & [Stop Buzzer]
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
                  onPressed: () {
                    final owner = ref
                        .read(activeMembersProvider)
                        .where((m) => m.userId == alarm.ownerId)
                        .firstOrNull;
                    final phone =
                        owner?.profile?.phone ?? owner?.profile?.whatsappNumber;
                    if (phone == null || phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('No phone number saved for this member.')));
                      return;
                    }
                    _callMember(phone);
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 2),
                    minimumSize: const Size(double.infinity, 54),
                  ),
                  icon: const Icon(Icons.volume_off_rounded),
                  label: Text(
                    'Stop Buzzer / Dismiss Alert',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () async {
                    await ref
                        .read(alarmSchedulerServiceProvider)
                        .cancelAlarm(alarm.alarmId);
                    if (context.mounted) await _close(context);
                  },
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
