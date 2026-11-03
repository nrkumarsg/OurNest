import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
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
  final _labelController = TextEditingController(text: 'Wake-up for Son');
  int _escalateMin = 5;

  @override
  void initState() {
    super.initState();
    final init = widget.initialTime ?? DateTime.now().add(const Duration(hours: 8));
    _selectedTime = TimeOfDay(hour: init.hour, minute: init.minute);
  }

  @override
  void dispose() {
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

  Future<void> _submit() async {
    final membership = ref.read(currentMembershipProvider).value;
    if (membership == null) return;

    final activeMembers = ref.read(activeMembersProvider);
    final now = DateTime.now();

    var targetDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (targetDateTime.isBefore(now)) {
      targetDateTime = targetDateTime.add(const Duration(days: 1));
    }

    final allMemberIds = activeMembers.map((m) => m.userId).toList();

    final success = await ref.read(alarmControllerProvider.notifier).createAlarm(
          familyId: membership.familyId,
          time: targetDateTime,
          label: _labelController.text.trim().isNotEmpty
              ? _labelController.text.trim()
              : 'Wake-up Alarm',
          ownerId: membership.userId,
          ownerName: membership.displayName,
          participants: allMemberIds,
          escalateAfterMin: _escalateMin,
        );

    if (mounted) {
      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared alarm created and scheduled! ⏰'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set Shared Alarm',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Large Time Display Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.accentCoral, width: 2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _pickTime,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Text(
                      _selectedTime.format(context),
                      style: GoogleFonts.nunito(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accentCoralDark,
                      ),
                    ),
                    Text(
                      'Tap to change time',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Label input
          TextField(
            controller: _labelController,
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: const InputDecoration(
              labelText: 'Alarm Label',
              hintText: 'e.g. Wake-up for Son, Amma Medication',
              prefixIcon: Icon(Icons.label_outline_rounded, color: AppColors.primaryTeal),
            ),
          ),
          const SizedBox(height: 18),
          // Escalation Option
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Escalate after:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              DropdownButton<int>(
                value: _escalateMin,
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3 minutes')),
                  DropdownMenuItem(value: 5, child: Text('5 minutes')),
                  DropdownMenuItem(value: 10, child: Text('10 minutes')),
                  DropdownMenuItem(value: 15, child: Text('15 minutes')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _escalateMin = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCoral,
            ),
            icon: const Icon(Icons.alarm_add_rounded),
            label: const Text('Set Shared Alarm'),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
