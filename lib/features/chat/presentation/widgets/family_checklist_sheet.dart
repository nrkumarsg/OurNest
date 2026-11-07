import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class FamilyChecklistSheet extends StatefulWidget {
  final void Function(String formattedChecklistMessage) onSendChecklist;
  final String? initialRawChecklist;

  const FamilyChecklistSheet({
    super.key,
    required this.onSendChecklist,
    this.initialRawChecklist,
  });

  @override
  State<FamilyChecklistSheet> createState() => _FamilyChecklistSheetState();
}

class _FamilyChecklistSheetState extends State<FamilyChecklistSheet> {
  static const _storage = FlutterSecureStorage();
  static const _savedGroceryKey = 'ournest_saved_custom_grocery_v1';
  static const _savedTasksKey = 'ournest_saved_custom_tasks_v1';
  static const _lastGroceryListKey = 'ournest_last_grocery_items_v1';
  static const _lastTaskListKey = 'ournest_last_task_items_v1';

  String _mode = 'grocery'; // 'grocery' | 'tasks' | 'volunteer'
  String _assignedTo = 'Spouse / Partner';
  String _selectedFreqOrQty = '';
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _itemInputCtrl = TextEditingController();
  final List<String> _items = [];
  final Set<int> _checkedIndices = {};
  List<String> _savedCustomGrocery = [];
  List<String> _savedCustomTasks = [];
  List<String> _lastGroceryItems = [];
  List<String> _lastTaskItems = [];
  int? _editingIndex;

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
    '🥣 Toor Dal / Lentils',
    '🧀 Curd / Yogurt & Paneer',
    '🍪 Biscuits & Snacks',
    '🧼 Dishwash & Laundry Soap',
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
    '🗑️ Take Out Kitchen Trash',
    '📞 Call Grandparents (Evening)',
    '👕 Fold & Iron Clothes',
  ];

  static const List<String> _volunteerPresets = [
    '🌸 Altar / Flower Decoration',
    '🍲 Annadhanam / Fellowship Food Serving',
    '🎵 Choir / Audio Mic Setup',
    '🪑 Welcome Desk & Seating',
    '🧹 Hall Clean-Up After Service',
  ];

  static const List<String> _groceryQtyChips = [
    '500g',
    '1 kg',
    '2 kg',
    '1 L',
    '2 L',
    '1 pkt',
    '2 pcs',
    '1 doz',
  ];

  static const List<String> _taskRepeatChips = [
    'Today',
    'Every Morning',
    'Every Evening',
    'Daily Repeat',
    'Weekend',
    'Urgent ⚡',
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
  void initState() {
    super.initState();
    if (widget.initialRawChecklist != null &&
        widget.initialRawChecklist!.trim().isNotEmpty) {
      _parseInitialChecklist(widget.initialRawChecklist!);
    }
    _loadSavedMemory();
  }

  void _parseInitialChecklist(String raw) {
    final lines = raw.split('\n');
    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('☐ ')) {
        _items.add(t.substring(2).trim());
      } else if (t.startsWith('☑ ')) {
        _checkedIndices.add(_items.length);
        _items.add(t.substring(2).trim());
      } else if (t.isNotEmpty) {
        if (t.contains('Task') || t.contains('✅')) {
          _mode = 'tasks';
          _assignedTo = 'Son';
        } else if (t.contains('Volunteer') || t.contains('🛕')) {
          _mode = 'volunteer';
          _assignedTo = 'Temple / Church Volunteers';
        }
        final forIdx = t.indexOf('For:');
        if (forIdx != -1) {
          final endBracket = t.indexOf(']', forIdx);
          final extracted = t
              .substring(forIdx + 4, endBracket != -1 ? endBracket : t.length)
              .trim();
          if (extracted.isNotEmpty) _assignedTo = extracted;
        }
      }
    }
  }

  Future<void> _loadSavedMemory() async {
    try {
      final gRaw = await _storage.read(key: _savedGroceryKey);
      final tRaw = await _storage.read(key: _savedTasksKey);
      final lgRaw = await _storage.read(key: _lastGroceryListKey);
      final ltRaw = await _storage.read(key: _lastTaskListKey);
      if (!mounted) return;
      setState(() {
        if (gRaw != null) {
          _savedCustomGrocery = List<String>.from(jsonDecode(gRaw) as List);
        }
        if (tRaw != null) {
          _savedCustomTasks = List<String>.from(jsonDecode(tRaw) as List);
        }
        if (lgRaw != null) {
          _lastGroceryItems = List<String>.from(jsonDecode(lgRaw) as List);
        }
        if (ltRaw != null) {
          _lastTaskItems = List<String>.from(jsonDecode(ltRaw) as List);
        }
      });
    } catch (_) {}
  }

  Future<void> _rememberCustomItem(String item) async {
    try {
      if (_mode == 'grocery') {
        if (!_groceryPresets.contains(item) &&
            !_savedCustomGrocery.contains(item)) {
          _savedCustomGrocery = [item, ..._savedCustomGrocery].take(16).toList();
          await _storage.write(
              key: _savedGroceryKey, value: jsonEncode(_savedCustomGrocery));
        }
      } else {
        if (!_taskPresets.contains(item) && !_savedCustomTasks.contains(item)) {
          _savedCustomTasks = [item, ..._savedCustomTasks].take(16).toList();
          await _storage.write(
              key: _savedTasksKey, value: jsonEncode(_savedCustomTasks));
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteSavedCustomChip(String item) async {
    setState(() {
      _savedCustomGrocery.remove(item);
      _savedCustomTasks.remove(item);
      _items.remove(item);
    });
    try {
      await _storage.write(
          key: _savedGroceryKey, value: jsonEncode(_savedCustomGrocery));
      await _storage.write(
          key: _savedTasksKey, value: jsonEncode(_savedCustomTasks));
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _itemInputCtrl.dispose();
    super.dispose();
  }

  void _addOrSaveItem() {
    var text = _itemInputCtrl.text.trim();
    if (text.isEmpty) return;
    if (_selectedFreqOrQty.isNotEmpty && !text.contains(_selectedFreqOrQty)) {
      text = '$text ($_selectedFreqOrQty)';
    }

    setState(() {
      if (_editingIndex != null &&
          _editingIndex! >= 0 &&
          _editingIndex! < _items.length) {
        _items[_editingIndex!] = text;
        _editingIndex = null;
      } else if (!_items.contains(text)) {
        _items.add(text);
      }
      _itemInputCtrl.clear();
      _selectedFreqOrQty = '';
    });
    _rememberCustomItem(text);
  }

  void _startEditingItem(int index) {
    setState(() {
      _editingIndex = index;
      _itemInputCtrl.text = _items[index];
    });
  }

  void _applyModifierToLastOrInput(String chip) {
    setState(() {
      if (_itemInputCtrl.text.trim().isNotEmpty) {
        _selectedFreqOrQty = _selectedFreqOrQty == chip ? '' : chip;
      } else if (_items.isNotEmpty) {
        final lastIdx = _editingIndex ?? (_items.length - 1);
        final base = _items[lastIdx].replaceAll(RegExp(r'\s*\([^)]*\)$'), '');
        _items[lastIdx] = '$base ($chip)';
      } else {
        _selectedFreqOrQty = _selectedFreqOrQty == chip ? '' : chip;
      }
    });
  }

  void _togglePresetItem(String item) {
    setState(() {
      final existingIdx = _items.indexWhere(
          (e) => e == item || e.startsWith('${item.split(' (').first} ('));
      if (existingIdx != -1) {
        _items.removeAt(existingIdx);
      } else {
        final toAdd = _selectedFreqOrQty.isNotEmpty
            ? '${item.replaceAll(RegExp(r'\s*\([^)]*\)$'), '')} ($_selectedFreqOrQty)'
            : item;
        _items.add(toAdd);
      }
    });
  }

  void _loadPreviousList() {
    final prev = _mode == 'grocery' ? _lastGroceryItems : _lastTaskItems;
    if (prev.isEmpty) return;
    setState(() {
      for (final item in prev) {
        if (!_items.contains(item)) _items.add(item);
      }
    });
  }

  Future<void> _send() async {
    // If the user typed something in the box and tapped Send directly, auto-include it!
    if (_itemInputCtrl.text.trim().isNotEmpty) {
      _addOrSaveItem();
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap or add at least 1 item to the list.'),
        ),
      );
      return;
    }

    try {
      if (_mode == 'grocery') {
        await _storage.write(
            key: _lastGroceryListKey, value: jsonEncode(_items));
      } else {
        await _storage.write(key: _lastTaskListKey, value: jsonEncode(_items));
      }
    } catch (_) {}

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
    for (var i = 0; i < _items.length; i++) {
      final box = _checkedIndices.contains(i) ? '☑' : '☐';
      buffer.writeln('$box ${_items[i]}');
    }

    if (mounted) Navigator.pop(context);
    widget.onSendChecklist(buffer.toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface =
        isDark ? const Color(0xFFF5F7F7) : AppColors.textPrimaryLight;
    final presets = _mode == 'grocery'
        ? _groceryPresets
        : _mode == 'tasks'
            ? _taskPresets
            : _volunteerPresets;
    final savedCustom =
        _mode == 'grocery' ? _savedCustomGrocery : _savedCustomTasks;
    final prevList = _mode == 'grocery' ? _lastGroceryItems : _lastTaskItems;
    final modifierChips =
        _mode == 'grocery' ? _groceryQtyChips : _taskRepeatChips;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                    widget.initialRawChecklist != null
                        ? 'Edit / Update List'
                        : 'Grocery Basket & Family Tasks',
                    style: GoogleFonts.nunito(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: onSurface,
                    ),
                  ),
                ),
                if (prevList.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Reuse Last'),
                    onPressed: _loadPreviousList,
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 1. Mode Switcher (Grocery vs Tasks vs Volunteer)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('🛒 Grocery List'),
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
                  label: const Text('✅ Family Tasks'),
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
                  label: const Text('🛕⛪ Volunteer'),
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
            const SizedBox(height: 10),

            // 2. Assign To Selector
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _assigneePresets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, idx) {
                  final person = _assigneePresets[idx];
                  final isSel = _assignedTo == person;
                  return ChoiceChip(
                    label: Text('For: $person',
                        style: const TextStyle(fontSize: 12)),
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
            const SizedBox(height: 10),

            // 3. Single-Flow Add / Edit Input Bar + 1-Tap Quantity / Repeat Chips
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemInputCtrl,
                    onSubmitted: (_) => _addOrSaveItem(),
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: _editingIndex != null
                          ? 'Editing item #${_editingIndex! + 1}...'
                          : (_mode == 'grocery'
                              ? 'Type item once (auto-saved for future)...'
                              : 'Type task once (auto-saved for future)...'),
                      isDense: true,
                      suffixIcon: _editingIndex != null
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded, size: 18),
                              onPressed: () => setState(() {
                                _editingIndex = null;
                                _itemInputCtrl.clear();
                              }),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _editingIndex != null
                        ? AppColors.accentCoral
                        : AppColors.primaryTeal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  icon: Icon(
                    _editingIndex != null
                        ? Icons.check_rounded
                        : Icons.add_rounded,
                    size: 18,
                  ),
                  label: Text(_editingIndex != null ? 'Update' : 'Add'),
                  onPressed: _addOrSaveItem,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 1-Tap Quantity / Repeat Schedule Strip (No typing needed!)
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: modifierChips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final chip = modifierChips[i];
                  final isSel = _selectedFreqOrQty == chip;
                  return ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isSel
                        ? AppColors.accentCoral
                        : AppColors.primaryTeal.withOpacity(0.1),
                    label: Text(
                      '+ $chip',
                      style: GoogleFonts.nunito(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isSel ? Colors.white : onSurface,
                      ),
                    ),
                    onPressed: () => _applyModifierToLastOrInput(chip),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // 4. Saved / Remembered Custom Items (Zero Repeat Typing!)
            if (savedCustom.isNotEmpty) ...[
              Text(
                '⭐ Your Saved Items (1-Tap — No Repeat Typing, Long-Press to Delete):',
                style: GoogleFonts.nunito(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentCoral,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: savedCustom.map((item) {
                  final added = _items.contains(item);
                  return GestureDetector(
                    onLongPress: () => _deleteSavedCustomChip(item),
                    child: FilterChip(
                      label: Text(
                        item,
                        style: GoogleFonts.nunito(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: added ? Colors.white : onSurface,
                        ),
                      ),
                      selected: added,
                      selectedColor: AppColors.accentCoral,
                      checkmarkColor: Colors.white,
                      onSelected: (_) => _togglePresetItem(item),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // 5. 1-Tap Easy Pick Presets
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _mode == 'grocery'
                      ? '1-Tap Easy Pick Groceries:'
                      : '1-Tap Easy Pick Tasks:',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryTeal,
                  ),
                ),
                if (_items.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() {
                      _items.clear();
                      _checkedIndices.clear();
                    }),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: presets.map((preset) {
                final added = _items.any((e) =>
                    e == preset ||
                    e.startsWith('${preset.split(' (').first} ('));
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

            // 6. Editable List Preview (Tap ✏️ to Edit or 🗑️ to Delete in 1 tap!)
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Selected List (${_items.length}) — Tap ✏️ to Edit or 🗑️ to Delete:',
                style: GoogleFonts.nunito(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 165),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primaryTeal.withOpacity(0.3)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final isBeingEdited = _editingIndex == i;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            _checkedIndices.contains(i)
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: AppColors.primaryTeal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _startEditingItem(i),
                              child: Text(
                                item,
                                style: GoogleFonts.nunito(
                                  fontSize: 14.5,
                                  fontWeight: isBeingEdited
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: isBeingEdited
                                      ? AppColors.accentCoral
                                      : onSurface,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_rounded,
                                size: 17, color: AppColors.primaryTeal),
                            tooltip: 'Edit',
                            onPressed: () => _startEditingItem(i),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: AppColors.error),
                            tooltip: 'Delete',
                            onPressed: () => setState(() {
                              _items.removeAt(i);
                              if (_editingIndex == i) {
                                _editingIndex = null;
                                _itemInputCtrl.clear();
                              }
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCoral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                widget.initialRawChecklist != null
                    ? 'Send Updated List (${_items.length} items)'
                    : 'Send List (${_items.length} items) to $_assignedTo',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
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

/// Interactive & Directly Editable Checkable Card rendered inside ChatBubble!
class InteractiveChecklistCard extends StatefulWidget {
  final String rawText;
  final bool isMine;
  final void Function(String updatedChecklistText)? onUpdateChecklist;

  const InteractiveChecklistCard({
    super.key,
    required this.rawText,
    required this.isMine,
    this.onUpdateChecklist,
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
  bool _showQuickAddBar = false;
  int? _inlineEditIndex;
  final TextEditingController _inlineCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _parseText();
  }

  @override
  void didUpdateWidget(covariant InteractiveChecklistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawText != widget.rawText) {
      _parseText();
    }
  }

  @override
  void dispose() {
    _inlineCtrl.dispose();
    super.dispose();
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

  String _serializeCurrentCard() {
    final buf = StringBuffer();
    buf.writeln(_headerLine);
    for (var i = 0; i < _itemLabels.length; i++) {
      final box = _checkedIndices.contains(i) ? '☑' : '☐';
      buf.writeln('$box ${_itemLabels[i]}');
    }
    return buf.toString().trim();
  }

  void _saveInlineAddOrEdit() {
    final val = _inlineCtrl.text.trim();
    if (val.isEmpty) return;
    setState(() {
      if (_inlineEditIndex != null &&
          _inlineEditIndex! >= 0 &&
          _inlineEditIndex! < _itemLabels.length) {
        _itemLabels[_inlineEditIndex!] = val;
        _inlineEditIndex = null;
      } else {
        _itemLabels.add(val);
      }
      _inlineCtrl.clear();
      _showQuickAddBar = false;
    });
  }

  void _openFullEditorSheet(BuildContext context) {
    if (widget.onUpdateChecklist == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FamilyChecklistSheet(
        initialRawChecklist: _serializeCurrentCard(),
        onSendChecklist: (updatedText) {
          widget.onUpdateChecklist!(updatedText);
        },
      ),
    );
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
            ? Colors.black.withOpacity(0.18)
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _headerLine,
                  style: GoogleFonts.nunito(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: fgColor,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Quick Add Item / Task',
                icon: Icon(Icons.add_circle_outline_rounded,
                    size: 20, color: fgColor),
                onPressed: () => setState(() {
                  _inlineEditIndex = null;
                  _inlineCtrl.clear();
                  _showQuickAddBar = !_showQuickAddBar;
                }),
              ),
              if (widget.onUpdateChecklist != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Full Easy-Pick Editor',
                  icon: Icon(Icons.edit_note_rounded, size: 22, color: fgColor),
                  onPressed: () => _openFullEditorSheet(context),
                ),
            ],
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
                : '$done of $total completed • Tap to tick, ✏️ to edit, 🗑️ to delete',
            style: GoogleFonts.nunito(
              fontSize: 11.5,
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
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    Icon(
                      isChecked
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 22,
                      color: isChecked
                          ? (widget.isMine
                              ? Colors.greenAccent
                              : AppColors.success)
                          : fgColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _itemLabels[i],
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: isChecked
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color:
                              isChecked ? fgColor.withOpacity(0.65) : fgColor,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() {
                        _inlineEditIndex = i;
                        _inlineCtrl.text = _itemLabels[i];
                        _showQuickAddBar = true;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(Icons.edit_rounded,
                            size: 16, color: fgColor.withOpacity(0.75)),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() {
                        _itemLabels.removeAt(i);
                        _checkedIndices.remove(i);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.close_rounded,
                            size: 17, color: fgColor.withOpacity(0.75)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_showQuickAddBar) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inlineCtrl,
                      onSubmitted: (_) => _saveInlineAddOrEdit(),
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                      decoration: InputDecoration(
                        hintText: _inlineEditIndex != null
                            ? 'Edit item...'
                            : 'Add item / task...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saveInlineAddOrEdit,
                    child: Text(_inlineEditIndex != null ? 'Save' : 'Add'),
                  ),
                ],
              ),
            ),
          ],
          if (widget.onUpdateChecklist != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: fgColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Easy-Pick / Edit'),
                  onPressed: () => _openFullEditorSheet(context),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCoral,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 15),
                  label: const Text(
                    'Share Updated List',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () =>
                      widget.onUpdateChecklist!(_serializeCurrentCard()),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
