import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../alarm/domain/alarm_time_parser.dart';
import '../../alarm/presentation/alarm_creation_sheet.dart';
import '../../family/presentation/family_controller.dart';
import '../../reminder/presentation/reminder_creation_sheet.dart';
import '../../share/share_intake.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message_model.dart';
import 'chat_controller.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/family_checklist_sheet.dart';
import 'widgets/location_share_sheet.dart';
import 'widgets/member_picker_sheet.dart';
import 'widgets/smart_family_composer.dart';
import 'widgets/voice_recorder_sheet.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String threadId; // 'family' or user_id for 1-to-1

  const ChatScreen({super.key, required this.threadId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isDirect = false;
  String? _directMemberId;
  ParsedAlarmIntent? _detectedAlarmIntent;
  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _isDirect = widget.threadId != 'family';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeOpenThreadProvider.notifier).state = widget.threadId;
      ref.read(chatRepositoryProvider).markThreadRead(widget.threadId);
      if (_isDirect) {
        ref.read(audienceStateProvider.notifier).setSelected([_directMemberId!]);
      } else {
        _consumePendingShare();
      }
    });
    if (_isDirect) {
      _directMemberId = widget.threadId;
    }

    _textController.addListener(() {
      final text = _textController.text;
      final detected = AlarmTimeParser.detectAlarmIntent(text);

      if (detected != _detectedAlarmIntent && mounted) {
        setState(() {
          _detectedAlarmIntent = detected;
        });
      }
    });
  }

  @override
  void dispose() {
    try {
      ref.read(activeOpenThreadProvider.notifier).state = null;
    } catch (_) {}
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Shows why a send failed so the message never silently disappears (F23).
  void _showSendError() {
    if (!mounted) return;
    final err = ref.read(chatControllerProvider).error;
    final detail = err is StateError ? err.message : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(detail ??
            'Message not sent. Check your internet connection and try again.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  bool _sending = false;

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return; // ignore double taps

    final membership = ref.read(currentMembershipProvider).value;
    if (membership == null) return;

    final audienceState = ref.read(audienceStateProvider);
    final replyingTo = _replyingTo;
    final replySnippet = replyingTo != null
        ? '${replyingTo.senderName ?? "Member"}: ${replyingTo.displayText}'
        : null;

    // Clear optimistically, but put everything back if sending fails.
    _sending = true;
    _textController.clear();
    setState(() => _replyingTo = null);

    final ok = await ref.read(chatControllerProvider.notifier).sendMessage(
          familyId: membership.familyId,
          text: text,
          audience: _isDirect ? MessageAudience.selected : audienceState.audience,
          selectedRecipientIds: _isDirect
              ? [_directMemberId!]
              : audienceState.selectedRecipientIds,
          replyToId: replySnippet,
          replyToMessageId: replyingTo?.id,
        );
    _sending = false;

    if (!ok) {
      if (mounted) {
        if (_textController.text.isEmpty) _textController.text = text;
        setState(() => _replyingTo = replyingTo);
      }
      _showSendError();
      return;
    }

    _scrollToBottom();
  }

  Future<void> _consumePendingShare() async {
    if (!mounted) return;
    final share = ref.read(pendingShareProvider);
    if (share == null) return;
    ref.read(pendingShareProvider.notifier).state = null;

    final text = share.text;
    if (text != null && text.isNotEmpty && _textController.text.isEmpty) {
      _textController.text = text; // the user reviews it and taps Send
      _focusNode.requestFocus();
    }
    if (share.imagePaths.isEmpty) return;

    final count = share.imagePaths.length;
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(count == 1 ? 'Send this photo?' : 'Send $count photos?'),
        content: const Text(
            'They will be encrypted and sent to your family chat.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send')),
        ],
      ),
    );
    if (send != true || !mounted) return;

    final membership = ref.read(currentMembershipProvider).value;
    if (membership == null) return;
    final audienceState = ref.read(audienceStateProvider);
    for (final path in share.imagePaths) {
      final bytes = await XFile(path).readAsBytes();
      final ext = path.contains('.') ? path.split('.').last.toLowerCase() : 'jpg';
      final ok = await ref.read(chatControllerProvider.notifier).sendMediaMessage(
            familyId: membership.familyId,
            audience: audienceState.audience,
            selectedRecipientIds: audienceState.selectedRecipientIds,
            rawBytes: bytes,
            fileExtension: ext.length <= 5 ? ext : 'jpg',
            type: MessageType.photo,
            caption: 'Photo',
          );
      if (!ok) {
        _showSendError();
        return;
      }
    }
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final membership = ref.read(currentMembershipProvider).value;
    if (membership == null) return;

    final audienceState = ref.read(audienceStateProvider);

    final ok = await ref.read(chatControllerProvider.notifier).sendMediaMessage(
          familyId: membership.familyId,
          audience: _isDirect ? MessageAudience.selected : audienceState.audience,
          selectedRecipientIds: _isDirect
              ? [_directMemberId!]
              : audienceState.selectedRecipientIds,
          rawBytes: bytes,
          fileExtension: 'jpg',
          type: MessageType.photo,
          caption: 'Photo',
        );

    if (!ok) {
      _showSendError();
      return;
    }
    _scrollToBottom();
  }

  void _openAlarmCreationSheet({DateTime? initialTime}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AlarmCreationSheet(initialTime: initialTime),
    );
  }

  void _openReminderCreationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const ReminderCreationSheet(),
    );
  }

  void _openLocationShareSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => LocationShareSheet(
        onSendLocationMessage: (locationText) async {
          final membership = ref.read(currentMembershipProvider).value;
          if (membership == null) return;
          final audienceState = ref.read(audienceStateProvider);

          final ok = await ref.read(chatControllerProvider.notifier).sendMessage(
                familyId: membership.familyId,
                text: locationText,
                audience: _isDirect
                    ? MessageAudience.selected
                    : audienceState.audience,
                selectedRecipientIds: _isDirect
                    ? [_directMemberId!]
                    : audienceState.selectedRecipientIds,
              );
          if (!ok) {
            _showSendError();
            return;
          }
          _scrollToBottom();
        },
      ),
    );
  }

  void _openChecklistSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => FamilyChecklistSheet(
        onSendChecklist: (checklistText) async {
          final membership = ref.read(currentMembershipProvider).value;
          if (membership == null) return;
          final audienceState = ref.read(audienceStateProvider);

          final ok = await ref.read(chatControllerProvider.notifier).sendMessage(
                familyId: membership.familyId,
                text: checklistText,
                audience: _isDirect
                    ? MessageAudience.selected
                    : audienceState.audience,
                selectedRecipientIds: _isDirect
                    ? [_directMemberId!]
                    : audienceState.selectedRecipientIds,
              );
          if (!ok) {
            _showSendError();
            return;
          }
          _scrollToBottom();
        },
      ),
    );
  }

  void _openVoiceRecorder() {
    final membership = ref.read(currentMembershipProvider).value;
    if (membership == null) return;

    final audienceState = ref.read(audienceStateProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => VoiceRecorderSheet(
        onComplete: (bytes, durationMs) async {
          final ok = await ref.read(chatControllerProvider.notifier).sendMediaMessage(
                familyId: membership.familyId,
                audience:
                    _isDirect ? MessageAudience.selected : audienceState.audience,
                selectedRecipientIds: _isDirect
                    ? [_directMemberId!]
                    : audienceState.selectedRecipientIds,
                rawBytes: bytes,
                fileExtension: 'm4a',
                type: MessageType.voice,
                durationMs: durationMs,
              );
          if (!ok) {
            _showSendError();
            return;
          }
          _scrollToBottom();
        },
      ),
    );
  }

  void _openMemberPicker() {
    final currentSelected = ref.read(audienceStateProvider).selectedRecipientIds;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => MemberPickerSheet(
        initiallySelectedIds: currentSelected,
        onSelected: (selectedIds) {
          if (selectedIds.isEmpty) {
            ref.read(audienceStateProvider.notifier).setEveryone();
          } else {
            ref.read(audienceStateProvider.notifier).setSelected(selectedIds);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final family = ref.watch(currentFamilyProvider).value;
    final activeMembers = ref.watch(activeMembersProvider);
    final audienceState = ref.watch(audienceStateProvider);
    final onlineUserIds = ref.watch(onlineUserIdsProvider);

    // Stream for messages based on thread
    final messagesAsync = _isDirect
        ? ref.watch(directMessagesProvider(_directMemberId!))
        : ref.watch(familyMessagesProvider);

    // Title info + Live Online/Offline Status
    String screenTitle = family?.name ?? 'Family Chat';
    String screenSubtitle = onlineUserIds.isNotEmpty
        ? '🟢 ${onlineUserIds.length} Online • End-to-End Encrypted'
        : 'End-to-End Encrypted';

    if (_isDirect) {
      final targetMember =
          activeMembers.where((m) => m.userId == _directMemberId).firstOrNull;
      final isOnline =
          _directMemberId != null && onlineUserIds.contains(_directMemberId);
      final lastSeenMap = ref.watch(lastSeenByUserProvider);
      final memberLastSeen = (_directMemberId != null
              ? lastSeenMap[_directMemberId!]
              : null) ??
          targetMember?.createdAt;
      final seenText = formatLastSeen(memberLastSeen, isOnline: isOnline);
      if (targetMember != null) {
        screenTitle = targetMember.displayName;
        screenSubtitle = '$seenText • ${targetMember.formattedRelation}';
      } else {
        screenSubtitle = seenText;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              screenTitle,
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 12, color: AppColors.primaryTeal),
                const SizedBox(width: 4),
                Text(
                  screenSubtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_checkout_rounded),
            tooltip: 'Grocery List & Family Tasks',
            onPressed: _openChecklistSheet,
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Share Live Location',
            onPressed: _openLocationShareSheet,
          ),
          IconButton(
            icon: const Icon(Icons.alarm_add_rounded),
            tooltip: 'Set Shared Alarm',
            onPressed: () => _openAlarmCreationSheet(),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Help & Instructions',
            onPressed: () => context.push('/help'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Message List
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                size: 40,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'End-to-End Encrypted',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Messages are encrypted with device keys. The server only sees ciphertext. Only members you choose can read them.',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  _scrollToBottom();

                  // Broadcast read receipts for incoming messages
                  final incomingIds = messages
                      .where((m) => !m.isMine && !m.isDeleted)
                      .map((m) => m.id)
                      .toList();
                  if (incomingIds.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref
                          .read(chatRepositoryProvider)
                          .markMessagesAsRead(incomingIds);
                    });
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = messages[i];
                      return ChatBubble(
                        message: msg,
                        onReply: () {
                          setState(() => _replyingTo = msg);
                          _focusNode.requestFocus();
                        },
                        onDelete: () => ref
                            .read(chatControllerProvider.notifier)
                            .deleteMessage(msg.id),
                        onUpdateChecklist: (updatedText) async {
                          final membership =
                              ref.read(currentMembershipProvider).value;
                          if (membership == null) return;
                          final audienceState = ref.read(audienceStateProvider);
                          final ok = await ref
                              .read(chatControllerProvider.notifier)
                              .sendMessage(
                                familyId: membership.familyId,
                                text: updatedText,
                                audience: _isDirect
                                    ? MessageAudience.selected
                                    : audienceState.audience,
                                selectedRecipientIds: _isDirect
                                    ? [_directMemberId!]
                                    : audienceState.selectedRecipientIds,
                              );
                          if (!ok) {
                            _showSendError();
                            return;
                          }
                          _scrollToBottom();
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading messages: $e')),
              ),
            ),

            // OurNest Smart Family Composer (Floating Pill + Docked Family Hub + Emoji/Quick Phrases)
            SmartFamilyComposer(
              controller: _textController,
              focusNode: _focusNode,
              isDirect: _isDirect,
              audience: audienceState.audience,
              selectedRecipientCount: audienceState.selectedRecipientIds.length,
              detectedAlarmIntent: _detectedAlarmIntent,
              replyingTo: _replyingTo,
              onCancelReply: () => setState(() => _replyingTo = null),
              onSend: _sendMessage,
              onOpenVoiceRecorder: _openVoiceRecorder,
              onPickCamera: () => _pickAndSendImage(ImageSource.camera),
              onPickGallery: () => _pickAndSendImage(ImageSource.gallery),
              onOpenAlarmSheet: () => _openAlarmCreationSheet(),
              onOpenReminderSheet: _openReminderCreationSheet,
              onOpenLocationSheet: _openLocationShareSheet,
              onOpenChecklistSheet: _openChecklistSheet,
              onSelectEveryone: () =>
                  ref.read(audienceStateProvider.notifier).setEveryone(),
              onOpenMemberPicker: _openMemberPicker,
              onTapAlarmSuggestion: (targetTime) =>
                  _openAlarmCreationSheet(initialTime: targetTime),
            ),
          ],
        ),
      ),
    );
  }
}
