import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/domain/chat_message_model.dart';
import '../../family/presentation/family_controller.dart';
import '../domain/family_reminder_model.dart';

class ReminderCreationSheet extends ConsumerStatefulWidget {
  const ReminderCreationSheet({super.key});

  @override
  ConsumerState<ReminderCreationSheet> createState() => _ReminderCreationSheetState();
}

class _ReminderCreationSheetState extends ConsumerState<ReminderCreationSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  bool _sendToAll = true;
  final Set<String> _selectedMemberIds = {};

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
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
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final membership = ref.read(currentMembershipProvider).value;
    if (membership == null) return;

    final activeMembers = ref.read(activeMembersProvider);
    final targetIds = _sendToAll
        ? activeMembers.map((m) => m.userId).toList()
        : _selectedMemberIds.toList();

    final eventDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final reminder = FamilyReminder(
      reminderId: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      eventDateTime: eventDateTime,
      createdById: membership.userId,
      createdByName: membership.displayName,
      targetMemberIds: targetIds,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    // Broadcast encrypted reminder message
    final chatRepo = ref.read(chatRepositoryProvider);
    await chatRepo.sendEncryptedMessage(
      familyId: membership.familyId,
      text: '📅 Event: $title on ${reminder.formattedDate} at ${reminder.formattedTime}',
      audience: _sendToAll ? MessageAudience.all : MessageAudience.selected,
      selectedRecipientUserIds: targetIds,
      type: MessageType.text, // Encrypted payload holds the reminderMeta
      alarmMeta: reminder.toJson(), // Transport inside payload
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Family reminder created and shared! 📅'),
          backgroundColor: AppColors.primaryTeal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeMembers = ref.watch(activeMembersProvider);
    final myUid = ref.watch(currentMembershipProvider).value?.userId;
    final otherMembers = activeMembers.where((m) => m.userId != myUid).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Set Family Event / Reminder',
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
            // Title
            TextField(
              controller: _titleController,
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                labelText: 'Event Title',
                hintText: 'e.g. Grandma Doctor Appointment, Rahul Tuition',
                prefixIcon: Icon(Icons.edit_calendar_rounded, color: AppColors.primaryTeal),
              ),
            ),
            const SizedBox(height: 16),
            // Date & Time Selectors
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primaryTeal),
                    ),
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(DateFormat('EEE, MMM d').format(_selectedDate)),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.accentCoral),
                      foregroundColor: AppColors.accentCoralDark,
                    ),
                    icon: const Icon(Icons.access_time_rounded, size: 18),
                    label: Text(_selectedTime.format(context)),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Notes
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'e.g. Bring medical reports, check in 15 mins early',
              ),
            ),
            const SizedBox(height: 20),
            // Audience: All vs Individual
            Text(
              'Remind:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: Text(
                    'All Family Members',
                    style: GoogleFonts.nunito(
                      fontWeight: _sendToAll ? FontWeight.w700 : FontWeight.w500,
                      color: _sendToAll
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  selected: _sendToAll,
                  selectedColor: AppColors.primaryTeal,
                  onSelected: (val) {
                    if (val) setState(() => _sendToAll = true);
                  },
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: Text(
                    'Individual Members',
                    style: GoogleFonts.nunito(
                      fontWeight: !_sendToAll ? FontWeight.w700 : FontWeight.w500,
                      color: !_sendToAll
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  selected: !_sendToAll,
                  selectedColor: AppColors.primaryTeal,
                  onSelected: (val) {
                    if (val) setState(() => _sendToAll = false);
                  },
                ),
              ],
            ),
            if (!_sendToAll) ...[
              const SizedBox(height: 10),
              ...otherMembers.map((member) {
                final isSelected = _selectedMemberIds.contains(member.userId);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isSelected,
                  title: Text(member.displayName),
                  subtitle: Text(member.formattedRelation),
                  activeColor: AppColors.primaryTeal,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedMemberIds.add(member.userId);
                      } else {
                        _selectedMemberIds.remove(member.userId);
                      }
                    });
                  },
                );
              }),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text('Set & Share with Family'),
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
