import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class FamilyChecklistSheet extends StatefulWidget {
  final void Function(String formattedChecklistMessage) onSendChecklist;

  const FamilyChecklistSheet({
    super.key,
    required this.onSendChecklist,
  });

  @override
  State<FamilyChecklistSheet> createState() => _FamilyChecklistSheetState();
}

class _FamilyChecklistSheetState extends State<FamilyChecklistSheet> {
  String _mode = 'grocery'; // 'grocery' | 'tasks' | 'volunteer'
  String _assignedTo = 'Spouse / Partner';
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _itemInputCtrl = TextEditingController();
  final List<String> _items = [];

  static const List<String> _groceryPresets = [
    '🥛 Fresh Milk (2L)',
    '🥚 Eggs (1 Dozen)',
    '🍞 Wholemeal Bread',
    '🍚 Basmati / Ponni Rice',
    '🍅 Tomatoes, Onions & Garlic',
    '🥦 Green Vegetables',
    '🍎 Apples & Bananas',
    '🫙 Cooking Oil & Ghee',
    '☕ Filter Coffee / Tea',
    '💊 Pharmacy / Medicines',
  ];

  static const List<String> _taskPresets = [
    '📚 Complete School Homework',
    '🧹 Clean & Tidy Bedroom',
    '🏦 Pay Electricity / Water Bill',
    '💊 Give Grandma Evening Medicine',
    '📦 Pick Up Courier / Parcel',
    '🚗 Wash Car / Two-Wheeler',
    '🪴 Water the Plants',
  ];

  static const List<String> _volunteerPresets = [
    '🌸 Altar / Flower Decoration',
    '🍲 Annadhanam / Fellowship Food Serving',
    '🎵 Choir / Audio Mic Setup',
    '🪑 Welcome Desk & Seating',
    '🧹 Hall Clean-Up After Service',
  ];

  static const List<String> _assigneePresets = [
    'Spouse / Partner',
    'Husband',
    'Wife',
    'Son',
    'Daughter',
    'Father / Mother',
    'All Family',
    'Temple / Church Volunteers',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _itemInputCtrl.dispose();
    super.dispose();
  }

  void _addCustomItem() {
    final text = _itemInputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_items.contains(text)) {
        _items.add(text);
      }
      _itemInputCtrl.clear();
    });
  }

  void _togglePresetItem(String item) {
    setState(() {
      if (_items.contains(item)) {
        _items.remove(item);
      } else {
        _items.add(item);
      }
    });
  }

  void _send() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap or add at least 1 item to the list.'),
        ),
      );
      return;
    }

    final headerEmoji = _mode == 'grocery'
        ? '🛒'
        : _mode == 'tasks'
            ? '✅'
            : '🛕';
    final defaultTitle = _mode == 'grocery'
        ? 'Grocery & Shopping List'
        : _mode == 'tasks'
            ? 'Family Task & Chore List'
            : 'Volunteer Duty Checklist';
    final customTitle = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : defaultTitle;

    final buffer = StringBuffer();
    buffer.writeln('$headerEmoji [$customTitle • For: $_assignedTo]');
    for (final item in _items) {
      buffer.writeln('☐ $item');
    }

    Navigator.pop(context);
    widget.onSendChecklist(buffer.toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final presets = _mode == 'grocery'
        ? _groceryPresets
        : _mode == 'tasks'
            ? _taskPresets
            : _volunteerPresets;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _mode == 'grocery'
                      ? Icons.shopping_cart_checkout_rounded
                      : Icons.checklist_rtl_rounded,
                  color: AppColors.primaryTeal,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Grocery List & Family Tasks',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 1. Mode Switcher (Grocery vs Tasks vs Volunteer)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('🛒 Grocery List (Husband/Wife)'),
                  selected: _mode == 'grocery',
                  selectedColor: AppColors.primaryTeal,
                  labelStyle: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    color: _mode == 'grocery' ? Colors.white : onSurface,
                  ),
                  onSelected: (_) => setState(() {
                    _mode = 'grocery';
                    _assignedTo = 'Spouse / Partner';
                  }),
                ),
                ChoiceChip(
                  label: const Text('✅ Task List (Father → Son/Kids)'),
                  selected: _mode == 'tasks',
                  selectedColor: AppColors.accentCoral,
                  labelStyle: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    color: _mode == 'tasks' ? Colors.white : onSurface,
                  ),
                  onSelected: (_) => setState(() {
                    _mode = 'tasks';
                    _assignedTo = 'Son';
                  }),
                ),
                ChoiceChip(
                  label: const Text('🛕⛪ Volunteer Checklist'),
                  selected: _mode == 'volunteer',
                  selectedColor: AppColors.info,
                  labelStyle: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    color: _mode == 'volunteer' ? Colors.white : onSurface,
                  ),
                  onSelected: (_) => setState(() {
                    _mode = 'volunteer';
                    _assignedTo = 'Temple / Church Volunteers';
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Assign To Selector
            Text(
              'Who is this list for?',
              style: GoogleFonts.nunito(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _assigneePresets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, idx) {
                  final person = _assigneePresets[idx];
                  final isSel = _assignedTo == person;
                  return ChoiceChip(
                    label: Text(person, style: const TextStyle(fontSize: 12.5)),
                    selected: isSel,
                    selectedColor: AppColors.primaryTeal,
                    labelStyle: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : onSurface,
                    ),
                    onSelected: (_) => setState(() => _assignedTo = person),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // 3. 1-Tap Quick Items
            Text(
              _mode == 'grocery'
                  ? 'Tap items to add to Grocery Basket:'
                  : _mode == 'tasks'
                      ? 'Tap tasks to assign:'
                      : 'Tap volunteer duties to include:',
              style: GoogleFonts.nunito(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: presets.map((preset) {
                final added = _items.contains(preset);
                return FilterChip(
                  label: Text(
                    preset,
                    style: GoogleFonts.nunito(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: added ? Colors.white : onSurface,
                    ),
                  ),
                  selected: added,
                  selectedColor: AppColors.primaryTeal,
                  checkmarkColor: Colors.white,
                  onSelected: (_) => _togglePresetItem(preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // 4. Add Custom Item Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemInputCtrl,
                    onSubmitted: (_) => _addCustomItem(),
                    style: GoogleFonts.nunito(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: _mode == 'grocery'
                          ? 'Add custom grocery item (e.g. Curd, Dal)...'
                          : 'Add custom task (e.g. Call Grandpa at 6pm)...',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add'),
                  onPressed: _addCustomItem,
                ),
              ],
            ),

            // 5. Preview of Current Checklist Items
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primaryTeal.withOpacity(0.25)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.check_box_outline_blank_rounded,
                              size: 18, color: AppColors.primaryTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: GoogleFonts.nunito(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _items.removeAt(i)),
                            child: const Icon(Icons.close_rounded,
                                size: 18, color: AppColors.error),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCoral,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                'Send Interactive List (${_items.length} items) to $_assignedTo',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Checkable Card rendered inside ChatBubble when a message contains a Grocery or Task list!
class InteractiveChecklistCard extends StatefulWidget {
  final String rawText;
  final bool isMine;

  const InteractiveChecklistCard({
    super.key,
    required this.rawText,
    required this.isMine,
  });

  static bool isChecklistMessage(String text) {
    return text.contains('☐ ') || text.contains('☑ ');
  }

  @override
  State<InteractiveChecklistCard> createState() =>
      _InteractiveChecklistCardState();
}

class _InteractiveChecklistCardState extends State<InteractiveChecklistCard> {
  late String _headerLine;
  late List<String> _itemLabels;
  late Set<int> _checkedIndices;

  @override
  void initState() {
    super.initState();
    _parseText();
  }

  void _parseText() {
    final lines = widget.rawText.split('\n');
    _headerLine = '🛒 Family Checklist';
    _itemLabels = [];
    _checkedIndices = {};

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('☐ ')) {
        _itemLabels.add(trimmed.substring(2).trim());
      } else if (trimmed.startsWith('☑ ')) {
        _checkedIndices.add(_itemLabels.length);
        _itemLabels.add(trimmed.substring(2).trim());
      } else if (trimmed.isNotEmpty) {
        _headerLine = trimmed;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _itemLabels.length;
    final done = _checkedIndices.length;
    final progress = total > 0 ? done / total : 0.0;
    final fgColor =
        widget.isMine ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMine
            ? Colors.black.withOpacity(0.16)
            : AppColors.primaryTeal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isMine
              ? Colors.white30
              : AppColors.primaryTeal.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _headerLine,
            style: GoogleFonts.nunito(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: fgColor,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor:
                  widget.isMine ? Colors.white24 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                done == total && total > 0
                    ? AppColors.success
                    : AppColors.accentCoral,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            done == total && total > 0
                ? '🎉 All $total items completed!'
                : '$done of $total completed • Tap items to tick off',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fgColor.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_itemLabels.length, (i) {
            final isChecked = _checkedIndices.contains(i);
            return InkWell(
              onTap: () {
                setState(() {
                  if (isChecked) {
                    _checkedIndices.remove(i);
                  } else {
                    _checkedIndices.add(i);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isChecked
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 22,
                      color: isChecked
                          ? (widget.isMine ? Colors.greenAccent : AppColors.success)
                          : fgColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _itemLabels[i],
                        style: GoogleFonts.nunito(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          decoration: isChecked
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: isChecked
                              ? fgColor.withOpacity(0.65)
                              : fgColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

