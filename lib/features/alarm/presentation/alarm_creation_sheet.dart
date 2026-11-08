import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/platform/alarm_scheduler_service.dart';
import '../../family/presentation/family_controller.dart';
import 'alarm_controller.dart';

class AlarmCreationSheet extends ConsumerStatefulWidget {
  final DateTime? initialTime;

  const AlarmCreationSheet({super.key, this.initialTime});

  @override
  ConsumerState<AlarmCreationSheet> createState() => _AlarmCreationSheetState();
}

class _AlarmCreationSheetState extends ConsumerState<AlarmCreationSheet> {
  late TimeOfDay _selectedTime;
  final _labelController = TextEditingController(text: 'Wake-up for Family');
  int _escalateMin = 0; // Default 0 min so selected phones ring together!
  bool _isTestingBuzzer = false;
  Timer? _testBuzzerStopTimer;
  final Set<String> _selectedParticipantIds = {};
  bool _initializedParticipants = false;

  @override
  void initState() {
    super.initState();
    final init =
        widget.initialTime ?? DateTime.now().add(const Duration(minutes: 2));
    _selectedTime = TimeOfDay(hour: init.hour, minute: init.minute);
  }

  @override
  void dispose() {
    _testBuzzerStopTimer?.cancel();
    if (_isTestingBuzzer) {
      ref.read(alarmSchedulerServiceProvider).stopBuzzer();
    }
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _setQuickOffsetMinutes(int minutesFromNow) {
    final target = DateTime.now().add(Duration(minutes: minutesFromNow));
    setState(() {
      _selectedTime = TimeOfDay(hour: target.hour, minute: target.minute);
    });
  }

  Future<void> _toggleTestBuzzer() async {
    final scheduler = ref.read(alarmSchedulerServiceProvider);
    if (_isTestingBuzzer) {
      _testBuzzerStopTimer?.cancel();
      await scheduler.stopBuzzer();
      if (mounted) setState(() => _isTestingBuzzer = false);
      return;
    }

    setState(() => _isTestingBuzzer = true);
    await scheduler.startBuzzer();
    _testBuzzerStopTimer?.cancel();
    _testBuzzerStopTimer = Timer(const Duration(seconds: 5), () async {
      await scheduler.stopBuzzer();
      if (mounted) setState(() => _isTestingBuzzer = false);
    });
  }

  Future<void> _submit({bool ringImmediately = false}) async {
    _testBuzzerStopTimer?.cancel();
    if (_isTestingBuzzer) {
      await ref.read(alarmSchedulerServiceProvider).stopBuzzer();
      _isTestingBuzzer = false;
    }

    final membership = await ref.read(currentMembershipProvider.future);
    if (membership == null) return;

    final allMembers = await ref.read(familyMembersProvider.future);
    final activeIds = allMembers
        .where((m) => m.isActive)
        .map((m) => m.userId)
        .toList();

    final chosenIds = _selectedParticipantIds.isNotEmpty
        ? _selectedParticipantIds.toList()
        : activeIds;
    if (!chosenIds.contains(membership.userId)) {
      chosenIds.add(membership.userId);
    }

    // Build human-readable list of member names whose phones will ring
    final chosenNames = allMembers
        .where((m) => chosenIds.contains(m.userId))
        .map((m) => m.displayName)
        .toList();
    final namesSummary = chosenNames.isNotEmpty
        ? chosenNames.join(', ')
        : membership.displayName;

    final now = DateTime.now();
    DateTime targetDateTime;

    if (ringImmediately) {
      targetDateTime = now.add(const Duration(seconds: 2));
    } else {
      targetDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final diffSeconds = targetDateTime.difference(now).inSeconds;
      if (diffSeconds <= 0 && diffSeconds >= -60) {
        targetDateTime = now.add(const Duration(seconds: 3));
      } else if (targetDateTime.isBefore(now)) {
        targetDateTime = targetDateTime.add(const Duration(days: 1));
      }
    }

    final baseLabel = _labelController.text.trim().isNotEmpty
        ? _labelController.text.trim()
        : 'Wake-up Alarm';

    final success =
        await ref.read(alarmControllerProvider.notifier).createAlarm(
              familyId: membership.familyId,
              time: targetDateTime,
              label: baseLabel,
              ownerId: membership.userId,
              ownerName: namesSummary,
              participants: chosenIds,
              escalateAfterMin: _escalateMin,
            );

    if (mounted) {
      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ringImmediately
                  ? '🔔 Ringing NOW on: $namesSummary!'
                  : '⏰ Alarm set for ${_selectedTime.format(context)} on phones: $namesSummary',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider);
    final membership = ref.watch(currentMembershipProvider).value;
    final activeMembers = membersAsync.maybeWhen(
      data: (list) => list.where((m) => m.isActive).toList(),
      orElse: () => [],
    );

    if (!_initializedParticipants && activeMembers.isNotEmpty) {
      for (final m in activeMembers) {
        _selectedParticipantIds.add(m.userId);
      }
      _initializedParticipants = true;
    }

    final now = DateTime.now();
    final previewDate = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final isToday = previewDate.isAfter(now.subtract(const Duration(minutes: 1)));

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '⏰ Shared Family Wake-Up Alarm',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 18.5,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Large Time Display Card + Today/Tomorrow badge
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.accentCoral, width: 2),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _pickTime,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 12.0),
                  child: Column(
                    children: [
                      Text(
                        _selectedTime.format(context),
                        style: GoogleFonts.nunito(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentCoralDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.success.withOpacity(0.15)
                              : AppColors.accentCoral.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isToday
                              ? '📅 Rings TODAY at ${_selectedTime.format(context)} (Tap to change)'
                              : '📅 Rings TOMORROW at ${_selectedTime.format(context)} (Check AM/PM!)',
                          style: GoogleFonts.nunito(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isToday
                                ? AppColors.success
                                : AppColors.accentCoralDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Quick Time Chips so user never confuses AM vs PM
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('In 1 Min (Test)',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  onPressed: () => _setQuickOffsetMinutes(1),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('In 2 Mins',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  onPressed: () => _setQuickOffsetMinutes(2),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('In 5 Mins',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  onPressed: () => _setQuickOffsetMinutes(5),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('6:00 AM',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  onPressed: () => setState(() =>
                      _selectedTime = const TimeOfDay(hour: 6, minute: 0)),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('7:00 AM',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  onPressed: () => setState(() =>
                      _selectedTime = const TimeOfDay(hour: 7, minute: 0)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // WHICH PHONES WILL RING SELECTOR (Explicit Confirmation!)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryTeal.withOpacity(0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📲 Which Phones Will Ring (${_selectedParticipantIds.isEmpty ? 1 : _selectedParticipantIds.length} Selected):',
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (activeMembers.length <= 1)
                    Text(
                      '• ✅ ${membership?.displayName ?? "Your Phone"} (You)\n'
                      'ℹ️ Only 1 phone is currently in this family. Once your Wife/Son/Family joins using your 6-digit Family Code or QR, their phone will appear here so both phones ring together!',
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: activeMembers.map((member) {
                        final isMe = member.userId == membership?.userId;
                        final isSelected =
                            _selectedParticipantIds.contains(member.userId);
                        return FilterChip(
                          visualDensity: VisualDensity.compact,
                          selected: isSelected,
                          selectedColor: AppColors.primaryTeal,
                          checkmarkColor: Colors.white,
                          label: Text(
                            isMe
                                ? '${member.displayName} (My Phone)'
                                : '${member.displayName} (${member.formattedRelation})',
                            style: GoogleFonts.nunito(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedParticipantIds.add(member.userId);
                              } else if (_selectedParticipantIds.length > 1) {
                                _selectedParticipantIds.remove(member.userId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Label input
            TextField(
              controller: _labelController,
              style: GoogleFonts.nunito(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                labelText: 'Alarm Reason / Label',
                hintText: 'e.g. Wake-up for School, Morning Medicine',
                prefixIcon: Icon(Icons.label_outline_rounded,
                    color: AppColors.primaryTeal),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            // Escalation Option
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Follow-Up Alert:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                DropdownButton<int>(
                  value: _escalateMin,
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('🔔 Ring Selected Phones Together'),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text('Ring + 3 min Escalation'),
                    ),
                    DropdownMenuItem(
                      value: 5,
                      child: Text('Ring + 5 min Escalation'),
                    ),
                    DropdownMenuItem(
                      value: 10,
                      child: Text('Ring + 10 min Escalation'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _escalateMin = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 1. Test Sound & Vibration Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    _isTestingBuzzer ? AppColors.error : AppColors.primaryTeal,
                side: BorderSide(
                  color: _isTestingBuzzer
                      ? AppColors.error
                      : AppColors.primaryTeal,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: Icon(
                _isTestingBuzzer
                    ? Icons.stop_circle_rounded
                    : Icons.volume_up_rounded,
              ),
              label: Text(
                _isTestingBuzzer
                    ? 'Stop Test Sound & Vibration'
                    : '🔊 Test Volume & Vibration on This Phone (5s)',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
              onPressed: _toggleTestBuzzer,
            ),
            const SizedBox(height: 8),

            // 2. Ring Selected Phones Right Now vs Set Scheduled Time
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.notifications_active_rounded,
                        size: 18),
                    label: Text(
                      'Ring Now',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () => _submit(ringImmediately: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCoral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.alarm_add_rounded, size: 18),
                    label: Text(
                      'Set for ${_selectedTime.format(context)}',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () => _submit(ringImmediately: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
