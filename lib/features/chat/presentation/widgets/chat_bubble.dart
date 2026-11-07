import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../alarm/domain/shared_alarm_model.dart';
import '../../../alarm/presentation/widgets/alarm_card.dart';
import '../../../reminder/domain/family_reminder_model.dart';
import '../../../reminder/presentation/widgets/reminder_card.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_message_model.dart';
import 'encrypted_image_view.dart';
import 'family_checklist_sheet.dart';
import 'voice_note_player.dart';

class ChatBubble extends ConsumerWidget {
  final ChatMessage message;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final void Function(String updatedChecklistText)? onUpdateChecklist;

  const ChatBubble({
    super.key,
    required this.message,
    this.onDelete,
    this.onReply,
    this.onUpdateChecklist,
  });

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onReply != null && !message.isDeleted)
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: AppColors.primaryTeal),
                title: const Text('Reply to Message'),
                onTap: () {
                  Navigator.pop(ctx);
                  onReply!();
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy Text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.displayText));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            if (message.isMine && !message.isDeleted && onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppColors.error),
                title: const Text(
                  'Delete for Everyone',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMine = message.isMine;
    final isDeleted = message.isDeleted;
    final timeStr = DateFormat.jm().format(message.createdAt);
    final deliveredIds = ref.watch(deliveredMessageIdsProvider);
    final readIds = ref.watch(readMessageIdsProvider);
    final onlineUserIds = ref.watch(onlineUserIdsProvider);
    final isRead = readIds.contains(message.id);
    final isDelivered =
        isRead || deliveredIds.contains(message.id) || onlineUserIds.length > 1;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMine
                ? (isDeleted
                    ? AppColors.primaryTeal.withOpacity(0.5)
                    : AppColors.primaryTeal)
                : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            border: isMine
                ? null
                : Border.all(
                    color: AppColors.dividerLight.withOpacity(0.8),
                    width: 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Sender Name (if not mine and in family chat)
              if (!isMine && message.senderName != null) ...[
                Text(
                  message.senderName!,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentCoralDark,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              // "To: Selected" badge
              if (message.audience == MessageAudience.selected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isMine
                        ? Colors.white.withOpacity(0.2)
                        : AppColors.primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '🔒 Selected Members',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isMine ? Colors.white : AppColors.primaryTeal,
                    ),
                  ),
                ),
              ],
              // Quoted Reply Preview (if replyToId is present)
              if (message.payload.replyToId != null &&
                  message.payload.replyToId!.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMine
                        ? Colors.black.withOpacity(0.18)
                        : AppColors.primaryTeal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                      left: BorderSide(color: AppColors.accentCoral, width: 3),
                    ),
                  ),
                  child: Text(
                    message.payload.replyToId!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isMine
                          ? Colors.white.withOpacity(0.9)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
              // Decrypted Message Content based on type
              if (message.payload.alarmMeta != null &&
                  message.payload.alarmMeta!['reminder_id'] != null) ...[
                ReminderCard(
                  reminder: FamilyReminder.fromJson(message.payload.alarmMeta!),
                  isMine: isMine,
                ),
              ] else if (message.type == MessageType.alarm &&
                  message.payload.alarmMeta != null) ...[
                AlarmCard(
                  alarm: SharedAlarm.fromJson(message.payload.alarmMeta!),
                  isMine: isMine,
                ),
              ] else if (message.type == MessageType.photo &&
                  message.payload.mediaMeta != null) ...[
                EncryptedImageView(mediaMeta: message.payload.mediaMeta!),
                if (message.displayText.isNotEmpty &&
                    message.displayText != 'Photo') ...[
                  const SizedBox(height: 6),
                  Text(
                    message.displayText,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isMine
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ] else if (message.type == MessageType.voice &&
                  message.payload.mediaMeta != null) ...[
                VoiceNotePlayer(
                  mediaMeta: message.payload.mediaMeta!,
                  isMine: isMine,
                ),
              ] else if (!isDeleted &&
                  InteractiveChecklistCard.isChecklistMessage(
                      message.displayText)) ...[
                InteractiveChecklistCard(
                  rawText: message.displayText,
                  isMine: isMine,
                  onUpdateChecklist: onUpdateChecklist,
                ),
              ] else ...[
                Text(
                  message.displayText,
                  style: GoogleFonts.nunito(
                    fontSize: 16.5, // Elderly friendly >= 16sp
                    fontWeight: FontWeight.w500,
                    fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                    color: isMine
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
                if (!isDeleted &&
                    message.displayText
                        .contains('https://www.google.com/maps/')) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMine
                            ? Colors.white
                            : AppColors.primaryTeal,
                        foregroundColor: isMine
                            ? AppColors.primaryTeal
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.map_rounded, size: 20),
                      label: Text(
                        '🗺️ Open Live Location in Google Maps',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: () {
                        final match = RegExp(
                                r'https://www\.google\.com/maps/[^\s]+')
                            .firstMatch(message.displayText);
                        if (match != null) {
                          launchUrl(
                            Uri.parse(match.group(0)!),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 4),
              // Timestamp + Edited indicator + Double Checkmark
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited) ...[
                    Text(
                      'edited • ',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: isMine
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                  Text(
                    timeStr,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: isMine
                          ? Colors.white.withOpacity(0.75)
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  if (isMine && !isDeleted) ...[
                    const SizedBox(width: 5),
                    Icon(
                      isDelivered
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 15,
                      color: isRead
                          ? const Color(0xFF80DEEA)
                          : Colors.white.withOpacity(isDelivered ? 0.9 : 0.7),
                    ),
                    if (isRead) ...[
                      const SizedBox(width: 2),
                      Text(
                        'Read',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF80DEEA),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
