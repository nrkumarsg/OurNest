import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../alarm/domain/alarm_time_parser.dart';
import '../../domain/chat_message_model.dart';

enum ComposerPanelType {
  none,
  attachments,
  emoji,
}

class SmartFamilyComposer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDirect;
  final MessageAudience audience;
  final int selectedRecipientCount;
  final ParsedAlarmIntent? detectedAlarmIntent;
  final ChatMessage? replyingTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;
  final VoidCallback onOpenVoiceRecorder;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onOpenAlarmSheet;
  final VoidCallback onOpenReminderSheet;
  final VoidCallback onOpenLocationSheet;
  final VoidCallback? onOpenChecklistSheet;
  final VoidCallback onSelectEveryone;
  final VoidCallback onOpenMemberPicker;
  final ValueChanged<DateTime> onTapAlarmSuggestion;

  const SmartFamilyComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDirect,
    required this.audience,
    required this.selectedRecipientCount,
    this.detectedAlarmIntent,
    this.replyingTo,
    required this.onCancelReply,
    required this.onSend,
    required this.onOpenVoiceRecorder,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onOpenAlarmSheet,
    required this.onOpenReminderSheet,
    required this.onOpenLocationSheet,
    this.onOpenChecklistSheet,
    required this.onSelectEveryone,
    required this.onOpenMemberPicker,
    required this.onTapAlarmSuggestion,
  });

  @override
  State<SmartFamilyComposer> createState() => _SmartFamilyComposerState();
}

class _SmartFamilyComposerState extends State<SmartFamilyComposer> {
  ComposerPanelType _activePanel = ComposerPanelType.none;
  int _selectedEmojiCategory = 0;
  bool _hasText = false;

  static const List<String> _quickFamilyPhrases = [
    '🏠 I reached safely! ❤️',
    '🍲 Did you eat yet?',
    '📞 Call me when free',
    '⏰ Wake me up at 7:00 AM',
    '☀️ Good morning family!',
    '🙏 Thank you so much!',
    '👍 Okay, got it!',
    '💊 Took my medicine ✓',
  ];

  static const List<Map<String, dynamic>> _emojiCategories = [
    {
      'icon': Icons.favorite_rounded,
      'label': 'Family',
      'emojis': [
        '❤️', '🥰', '😘', '🤗', '🙏', '👨‍👩‍👧', '👨‍👩‍👧‍👦', '👵',
        '👴', '👨', '👩', '👦', '👧', '👶', '🏠', '💖',
        '💝', '💞', '💓', '✨', '🌟', '🌹', '🌺', '🌻',
      ],
    },
    {
      'icon': Icons.emoji_emotions_rounded,
      'label': 'Smileys',
      'emojis': [
        '😊', '😄', '😁', '😂', '🤣', '😅', '😇', '🙂',
        '😉', '😌', '😍', '🤩', '😋', '😎', '🥳', '🤭',
        '🤔', '😮', '😴', '🥱', '😢', '😭', '🥺', '😤',
      ],
    },
    {
      'icon': Icons.front_hand_rounded,
      'label': 'Hands',
      'emojis': [
        '👍', '👌', '👏', '🙌', '🤝', '🙏', '✌️', '🤞',
        '🫶', '💪', '👋', '🤚', '☝️', '👆', '👇', '👈',
        '👉', '🫡', '🫂', '✍️', '💅', '🤳', '🕺', '💃',
      ],
    },
    {
      'icon': Icons.restaurant_rounded,
      'label': 'Home & Food',
      'emojis': [
        '🍲', '🍛', '🍚', '🍜', '☕', '🍵', '🥛', '🍎',
        '🍌', '🥭', '🍉', '🎂', '🍰', '🍫', '🍬', '🎉',
        '🎊', '🎁', '🎈', '⏰', '📅', '💊', '🩺', '🚗',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText && mounted) {
      setState(() => _hasText = has);
    }
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus && _activePanel != ComposerPanelType.none) {
      setState(() => _activePanel = ComposerPanelType.none);
    }
  }

  void _togglePanel(ComposerPanelType panel) {
    HapticFeedback.selectionClick();
    if (_activePanel == panel) {
      // Switch back to system keyboard
      setState(() => _activePanel = ComposerPanelType.none);
      widget.focusNode.requestFocus();
    } else {
      // Hide system keyboard and open docked drawer
      widget.focusNode.unfocus();
      setState(() => _activePanel = panel);
    }
  }

  void _insertTextAtCursor(String textToInsert) {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final selection = ctrl.selection;

    if (!selection.isValid || selection.start < 0) {
      final newText = text + textToInsert;
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      return;
    }

    final newText =
        text.replaceRange(selection.start, selection.end, textToInsert);
    final newOffset = selection.start + textToInsert.length;
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void _backspaceAtCursor() {
    final ctrl = widget.controller;
    final text = ctrl.text;
    if (text.isEmpty) return;

    final characters = text.characters;
    if (characters.isEmpty) return;

    final shortened = characters.skipLast(1).toString();
    ctrl.value = TextEditingValue(
      text: shortened,
      selection: TextSelection.collapsed(offset: shortened.length),
    );
  }

  Future<void> _pasteClipboardLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final clipText = data?.text?.trim();
    if (clipText != null && clipText.isNotEmpty) {
      _insertTextAtCursor(
        widget.controller.text.isEmpty ? clipText : ' $clipText',
      );
      setState(() => _activePanel = ComposerPanelType.none);
      widget.focusNode.requestFocus();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard is empty. Copy a link or video first!'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillSurface = isDark ? const Color(0xFF1F302E) : Colors.white;
    final pillBorderColor = isDark
        ? AppColors.primaryTealLight.withOpacity(0.45)
        : AppColors.inputBorderLight;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Smart Context Header Strip (Reply Banner + Audience Pill + Alarm NLP Chip)
        _buildSmartContextHeader(context, isDark, textColor, secondaryColor),

        // 2. Floating Pill Composer Row + Morphing Action Orb
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Floating Rounded Pill Capsule
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 52),
                  decoration: BoxDecoration(
                    color: pillSurface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: widget.focusNode.hasFocus
                          ? AppColors.primaryTeal
                          : pillBorderColor,
                      width: widget.focusNode.hasFocus ? 1.8 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left Inside Pill: Emoji <-> Keyboard Toggle
                      IconButton(
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(
                          minWidth: 46,
                          minHeight: 48,
                        ),
                        icon: Icon(
                          _activePanel == ComposerPanelType.emoji
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          color: _activePanel == ComposerPanelType.emoji
                              ? AppColors.accentCoral
                              : secondaryColor,
                          size: 25,
                        ),
                        tooltip: _activePanel == ComposerPanelType.emoji
                            ? 'Show Keyboard'
                            : 'Emojis & Quick Family Phrases',
                        onPressed: () => _togglePanel(ComposerPanelType.emoji),
                      ),

                      // Center: Multi-line Auto-Expanding TextField
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            style: GoogleFonts.nunito(
                              fontSize: 17, // Elderly-friendly >= 16sp
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              height: 1.35,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.isDirect
                                  ? 'Message privately...'
                                  : (widget.audience == MessageAudience.selected
                                      ? 'Message selected (${widget.selectedRecipientCount})...'
                                      : 'Message family...'),
                              hintStyle: GoogleFonts.nunito(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w500,
                                color: secondaryColor,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 12,
                              ),
                            ),
                            onTap: () {
                              if (_activePanel != ComposerPanelType.none) {
                                setState(
                                    () => _activePanel = ComposerPanelType.none);
                              }
                            },
                          ),
                        ),
                      ),

                      // Right Inside Pill: Attachment Hub Toggle (📎 / ✕)
                      IconButton(
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(
                          minWidth: 42,
                          minHeight: 48,
                        ),
                        icon: AnimatedRotation(
                          turns: _activePanel == ComposerPanelType.attachments
                              ? 0.125
                              : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _activePanel == ComposerPanelType.attachments
                                ? Icons.add_circle_rounded
                                : Icons.attach_file_rounded,
                            color: _activePanel == ComposerPanelType.attachments
                                ? AppColors.accentCoral
                                : secondaryColor,
                            size: 24,
                          ),
                        ),
                        tooltip: 'Family Action Hub',
                        onPressed: () =>
                            _togglePanel(ComposerPanelType.attachments),
                      ),

                      // Right Inside Pill: 1-Tap Quick Camera (auto-collapses while typing)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        child: !_hasText
                            ? Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: IconButton(
                                  padding: const EdgeInsets.all(10),
                                  constraints: const BoxConstraints(
                                    minWidth: 42,
                                    minHeight: 48,
                                  ),
                                  icon: Icon(
                                    Icons.camera_alt_outlined,
                                    color: secondaryColor,
                                    size: 24,
                                  ),
                                  tooltip: 'Quick Camera Photo',
                                  onPressed: () {
                                    setState(() =>
                                        _activePanel = ComposerPanelType.none);
                                    widget.onPickCamera();
                                  },
                                ),
                              )
                            : const SizedBox(width: 8),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Right Outside Pill: Morphing Send (➤) <-> Voice Mic (🎙️) Orb
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_hasText) {
                    widget.onSend();
                  } else {
                    setState(() => _activePanel = ComposerPanelType.none);
                    widget.onOpenVoiceRecorder();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _hasText
                        ? AppColors.primaryTeal
                        : AppColors.accentCoral,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_hasText
                                ? AppColors.primaryTeal
                                : AppColors.accentCoral)
                            .withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: child,
                    ),
                    child: Icon(
                      _hasText ? Icons.send_rounded : Icons.mic_rounded,
                      key: ValueKey<bool>(_hasText),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Inline Docked Drawers (Attachment Grid OR Emoji + Quick Phrases)
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _buildDockedDrawer(context, isDark, textColor, secondaryColor),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. SMART CONTEXT HEADER (Reply Preview + Audience Pill + NLP Alarm Chip)
  // ---------------------------------------------------------------------------
  Widget _buildSmartContextHeader(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply-To Banner
        if (widget.replyingTo != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2827) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: const Border(
                left: BorderSide(color: AppColors.accentCoral, width: 4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.reply_rounded,
                  size: 18,
                  color: AppColors.accentCoral,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.replyingTo!.isMine
                            ? 'Replying to yourself'
                            : 'Replying to ${widget.replyingTo!.senderName ?? "Family Member"}',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentCoral,
                        ),
                      ),
                      Text(
                        widget.replyingTo!.displayText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: secondaryColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onCancelReply,
                ),
              ],
            ),
          ),

        // Real-time NLP Wake-Up Alarm Suggestion Chip
        if (widget.detectedAlarmIntent != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => widget
                  .onTapAlarmSuggestion(widget.detectedAlarmIntent!.targetTime),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentCoral.withOpacity(0.18),
                      AppColors.primaryTeal.withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accentCoral, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.alarm_add_rounded,
                      size: 20,
                      color: AppColors.accentCoralDark,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Set shared wake-up alarm for ${widget.detectedAlarmIntent!.formattedTime}?',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.accentCoralLight
                              : AppColors.accentCoralDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentCoral,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Schedule',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Compact Audience Control Strip (in Family Group Chat)
        if (!widget.isDirect)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
            child: Row(
              children: [
                Icon(
                  widget.audience == MessageAudience.all
                      ? Icons.public_rounded
                      : Icons.lock_person_rounded,
                  size: 15,
                  color: widget.audience == MessageAudience.all
                      ? AppColors.primaryTeal
                      : AppColors.accentCoral,
                ),
                const SizedBox(width: 6),
                Text(
                  'Send to:',
                  style: GoogleFonts.nunito(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: secondaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                // Everyone Pill
                GestureDetector(
                  onTap: widget.onSelectEveryone,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.audience == MessageAudience.all
                          ? AppColors.primaryTeal
                          : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Everyone',
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: widget.audience == MessageAudience.all
                            ? Colors.white
                            : textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Selected Members Pill
                GestureDetector(
                  onTap: widget.onOpenMemberPicker,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.audience == MessageAudience.selected
                          ? AppColors.accentCoral
                          : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.group_rounded,
                          size: 14,
                          color: widget.audience == MessageAudience.selected
                              ? Colors.white
                              : AppColors.primaryTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.audience == MessageAudience.selected
                              ? 'Selected (${widget.selectedRecipientCount})'
                              : 'Selected...',
                          style: GoogleFonts.nunito(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: widget.audience == MessageAudience.selected
                                ? Colors.white
                                : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. INLINE DOCKED DRAWERS (Family Action Hub Grid OR Emoji & Quick Phrases)
  // ---------------------------------------------------------------------------
  Widget _buildDockedDrawer(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    if (_activePanel == ComposerPanelType.none) {
      return const SizedBox.shrink();
    }

    final dockBg = isDark ? const Color(0xFF162221) : Colors.white;

    if (_activePanel == ComposerPanelType.attachments) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: BoxDecoration(
          color: dockBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle Pill
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Row 1 of Family Action Hub (4 items)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHubItem(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF2B7DE9),
                  textColor: textColor,
                  onTap: () {
                    setState(() => _activePanel = ComposerPanelType.none);
                    widget.onPickGallery();
                  },
                ),
                _buildHubItem(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFFE53965),
                  textColor: textColor,
                  onTap: () {
                    setState(() => _activePanel = ComposerPanelType.none);
                    widget.onPickCamera();
                  },
                ),
                _buildHubItem(
                  icon: Icons.alarm_rounded,
                  label: 'Wake Alarm',
                  color: AppColors.accentCoral,
                  textColor: textColor,
                  onTap: () {
                    setState(() => _activePanel = ComposerPanelType.none);
                    widget.onOpenAlarmSheet();
                  },
                ),
                _buildHubItem(
                  icon: Icons.event_available_rounded,
                  label: 'Family Event',
                  color: AppColors.primaryTeal,
                  textColor: textColor,
                  onTap: () {
                    setState(() => _activePanel = ComposerPanelType.none);
                    widget.onOpenReminderSheet();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Row 2 of Family Action Hub (4 items)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHubItem(
                  icon: Icons.mic_rounded,
                  label: 'Voice Note',
                  color: const Color(0xFF2E7D32),
                  textColor: textColor,
                  onTap: () {
                    setState(() => _activePanel = ComposerPanelType.none);
                    widget.onOpenVoiceRecorder();
                  },
                ),
                _buildHubItem(
                  icon: Icons.my_location_rounded,
                  label: 'Live Location',
                  color: const Color(0xFF00897B),
                  textColor: textColor,
                  onTap: () {
                    setState(() => _activePanel = ComposerPanelType.none);
                    widget.onOpenLocationSheet();
                  },
                ),
                _buildHubItem(
                  icon: Icons.shopping_cart_checkout_rounded,
                  label: 'Grocery / Tasks',
                  color: const Color(0xFFF59E0B),
                  textColor: textColor,
                  onTap: () {
                    setState(() => _activePanel = ComposerPanelType.none);
                    if (widget.onOpenChecklistSheet != null) {
                      widget.onOpenChecklistSheet!();
                    } else {
                      _insertTextAtCursor('🛒 Grocery / Task List:\n☐ ');
                      widget.focusNode.requestFocus();
                    }
                  },
                ),
                _buildHubItem(
                  icon: Icons.link_rounded,
                  label: 'Paste Link',
                  color: const Color(0xFF7C3AED),
                  textColor: textColor,
                  onTap: _pasteClipboardLink,
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Emoji & Family Quick-Phrase Tray (Screenshot 2 Upgrade)
    final currentCategory = _emojiCategories[_selectedEmojiCategory];
    final List<String> emojis =
        List<String>.from(currentCategory['emojis'] as List);

    return Container(
      width: double.infinity,
      height: 285,
      decoration: BoxDecoration(
        color: dockBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Strip: 1-Tap Family Quick Phrases (Elderly-Friendly)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickFamilyPhrases.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final phrase = _quickFamilyPhrases[i];
                return ActionChip(
                  label: Text(
                    phrase,
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  backgroundColor: isDark
                      ? AppColors.primaryTeal.withOpacity(0.25)
                      : AppColors.backgroundLight,
                  side: BorderSide(
                    color: AppColors.primaryTeal.withOpacity(0.35),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _insertTextAtCursor(
                      widget.controller.text.isEmpty ? phrase : ' $phrase',
                    );
                  },
                );
              },
            ),
          ),

          // Category Selector Pill Bar + Backspace
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.07)
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(_emojiCategories.length, (index) {
                        final cat = _emojiCategories[index];
                        final isSelected = _selectedEmojiCategory == index;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedEmojiCategory = index);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryTeal
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  cat['icon'] as IconData,
                                  size: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : secondaryColor,
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    cat['label'] as String,
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.backspace_outlined,
                    color: secondaryColor,
                    size: 22,
                  ),
                  tooltip: 'Backspace',
                  onPressed: _backspaceAtCursor,
                ),
              ],
            ),
          ),

          // Emoji Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: emojis.length,
              itemBuilder: (ctx, idx) {
                final emoji = emojis[idx];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _insertTextAtCursor(emoji);
                  },
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubItem({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: color.withOpacity(0.35),
                  width: 1.2,
                ),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

