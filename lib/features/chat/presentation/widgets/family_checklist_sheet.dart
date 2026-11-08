import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';

/// Model representing a saved Notepad / Grocery / Task record (Local + Supabase `family_notes`).
class SavedNotepadRecord {
  final String id;
  final String category; // 'grocery' | 'tasks' | 'volunteer' | 'note'
  final String title;
  final String assignedTo;
  final String content; // Formatted checklist or multiline notepad text
  final DateTime updatedAt;

  const SavedNotepadRecord({
    required this.id,
    required this.category,
    required this.title,
    required this.assignedTo,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'assigned_to': assignedTo,
        'content': content,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SavedNotepadRecord.fromJson(Map<String, dynamic> json) {
    return SavedNotepadRecord(
      id: (json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString())
          .toString(),
      category: (json['category'] ?? 'grocery').toString(),
      title: (json['title'] ?? 'Grocery & Shopping List').toString(),
      assignedTo: (json['assigned_to'] ?? 'All Family').toString(),
      content: (json['content'] ?? '').toString(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

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
  static const _savedRecordsKey = 'ournest_notepad_records_v1';
  static const _savedGroceryKey = 'ournest_saved_custom_grocery_v1';
  static const _savedTasksKey = 'ournest_saved_custom_tasks_v1';

  String _mode = 'grocery'; // 'grocery' | 'tasks' | 'volunteer' | 'note'
  String _assignedTo = 'Spouse / Partner';
  String _selectedFreqOrQty = '';
  String? _activeRecordId;
  bool _isNotepadTextMode = false;
  bool _showSavedRecordsList = false;
  bool _showQuickPickPresets = false;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _itemInputCtrl = TextEditingController();
  final TextEditingController _notepadCtrl = TextEditingController();
  final FocusNode _itemInputFocus = FocusNode();
  final FocusNode _notepadFocus = FocusNode();

  final List<String> _items = [];
  final Set<int> _checkedIndices = {};
  List<SavedNotepadRecord> _savedRecords = [];
  List<String> _savedCustomGrocery = [];
  List<String> _savedCustomTasks = [];
  int? _editingIndex;
  bool _isSavingRecord = false;

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
    _titleCtrl.text = _defaultTitleForMode(_mode);
    if (widget.initialRawChecklist != null &&
        widget.initialRawChecklist!.trim().isNotEmpty) {
      _parseInitialChecklist(widget.initialRawChecklist!);
    }
    _syncItemsToNotepadText();
    _loadSavedMemory();
  }

  String _defaultTitleForMode(String mode) {
    switch (mode) {
      case 'tasks':
        return 'Family Task & Chore List';
      case 'volunteer':
        return 'Volunteer Duty Checklist';
      case 'note':
        return 'Family Notepad Record';
      default:
        return 'Grocery & Shopping List';
    }
  }

  void _parseInitialChecklist(String raw) {
    _items.clear();
    _checkedIndices.clear();
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
        } else if (t.contains('Note') || t.contains('📝')) {
          _mode = 'note';
          _assignedTo = 'All Family';
        }
        final openBracket = t.indexOf('[');
        final dotIdx = t.indexOf('• For:');
        if (openBracket != -1 && dotIdx != -1 && dotIdx > openBracket) {
          final parsedTitle = t.substring(openBracket + 1, dotIdx).trim();
          if (parsedTitle.isNotEmpty) _titleCtrl.text = parsedTitle;
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

  void _syncItemsToNotepadText() {
    _notepadCtrl.text = _items.join('\n');
  }

  void _syncNotepadTextToItems() {
    final rawLines = _notepadCtrl.text
        .split('\n')
        .map((line) => line
            .replaceFirst(RegExp(r'^[☐☑•\-*]\s*'), '')
            .trim())
        .where((line) => line.isNotEmpty)
        .toList();
    _items
      ..clear()
      ..addAll(rawLines);
    _checkedIndices.removeWhere((idx) => idx >= _items.length);
  }

  Future<void> _loadSavedMemory() async {
    try {
      final gRaw = await _storage.read(key: _savedGroceryKey);
      final tRaw = await _storage.read(key: _savedTasksKey);
      final recRaw = await _storage.read(key: _savedRecordsKey);

      final loadedRecords = <SavedNotepadRecord>[];
      if (recRaw != null && recRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(recRaw) as List;
        for (final item in decoded) {
          if (item is Map) {
            loadedRecords.add(
              SavedNotepadRecord.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }

      // Also attempt to load shared records from Supabase `family_notes` table if available
      try {
        final client = Supabase.instance.client;
        if (client.auth.currentUser != null) {
          final rows = await client
              .from('family_notes')
              .select()
              .order('updated_at', ascending: false)
              .limit(30);
          for (final row in rows) {
            final rec =
                SavedNotepadRecord.fromJson(Map<String, dynamic>.from(row));
            final existingIdx =
                loadedRecords.indexWhere((r) => r.id == rec.id);
            if (existingIdx == -1) {
              loadedRecords.add(rec);
            } else {
              loadedRecords[existingIdx] = rec;
            }
          }
        }
      } catch (_) {
        // Fallback to local storage gracefully if `family_notes` table is not created yet
      }

      loadedRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (!mounted) return;
      setState(() {
        _savedRecords = loadedRecords;
        if (gRaw != null) {
          _savedCustomGrocery = List<String>.from(jsonDecode(gRaw) as List);
        }
        if (tRaw != null) {
          _savedCustomTasks = List<String>.from(jsonDecode(tRaw) as List);
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _itemInputCtrl.dispose();
    _notepadCtrl.dispose();
    _itemInputFocus.dispose();
    _notepadFocus.dispose();
    super.dispose();
  }

  /// 1. NEW RECORD button handler
  void _createNewRecord() {
    setState(() {
      _activeRecordId = null;
      _editingIndex = null;
      _items.clear();
      _checkedIndices.clear();
      _itemInputCtrl.clear();
      _notepadCtrl.clear();
      _selectedFreqOrQty = '';
      _titleCtrl.text = _defaultTitleForMode(_mode);
      _showSavedRecordsList = false;
    });
    if (_isNotepadTextMode) {
      _notepadFocus.requestFocus();
    } else {
      _itemInputFocus.requestFocus();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📄 Started a new blank Notepad record. Type below!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 2. ADD OR UPDATE SINGLE LINE handler
  void _addOrSaveItem() {
    if (_isNotepadTextMode) {
      _syncNotepadTextToItems();
    }
    var text = _itemInputCtrl.text.trim();
    if (text.isEmpty) {
      _itemInputFocus.requestFocus();
      return;
    }
    if (_selectedFreqOrQty.isNotEmpty && !text.contains(_selectedFreqOrQty)) {
      text = '$text ($_selectedFreqOrQty)';
    }

    setState(() {
      if (_editingIndex != null &&
          _editingIndex! >= 0 &&
          _editingIndex! < _items.length) {
        _items[_editingIndex!] = text;
        _editingIndex = null;
      } else {
        _items.add(text);
      }
      _itemInputCtrl.clear();
      _selectedFreqOrQty = '';
      _syncItemsToNotepadText();
    });
    _rememberCustomItem(text);
  }

  /// 3. EDIT EXISTING LINE via instant popup dialog so keyboard ALWAYS appears
  Future<void> _openEditLineDialog(int index) async {
    if (index < 0 || index >= _items.length) return;
    final editCtrl = TextEditingController(text: _items[index]);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Edit Line #${index + 1}',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          decoration: InputDecoration(
            labelText: 'Item / Note Line',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save Change'),
            onPressed: () => Navigator.pop(ctx, editCtrl.text.trim()),
          ),
        ],
      ),
    );
    if (updated != null && updated.isNotEmpty && mounted) {
      setState(() {
        _items[index] = updated;
        _editingIndex = null;
        _syncItemsToNotepadText();
      });
      _rememberCustomItem(updated);
    }
  }

  String _buildFormattedChecklistString() {
    if (_isNotepadTextMode) {
      _syncNotepadTextToItems();
    }
    if (_itemInputCtrl.text.trim().isNotEmpty) {
      _addOrSaveItem();
    }

    final headerEmoji = _mode == 'grocery'
        ? '🛒'
        : _mode == 'tasks'
            ? '✅'
            : _mode == 'volunteer'
                ? '🛕'
                : '📝';
    final customTitle = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : _defaultTitleForMode(_mode);

    final buffer = StringBuffer();
    buffer.writeln('$headerEmoji [$customTitle • For: $_assignedTo]');
    for (var i = 0; i < _items.length; i++) {
      final box = _checkedIndices.contains(i) ? '☑' : '☐';
      buffer.writeln('$box ${_items[i]}');
    }
    return buffer.toString().trim();
  }

  /// 4. SAVE RECORD (Local Storage + Optional Supabase `family_notes` sync)
  Future<void> _saveCurrentRecord({bool showToast = true}) async {
    if (_isNotepadTextMode) {
      _syncNotepadTextToItems();
    }
    if (_itemInputCtrl.text.trim().isNotEmpty) {
      _addOrSaveItem();
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type or add at least 1 line before saving.'),
        ),
      );
      return;
    }

    setState(() => _isSavingRecord = true);

    final formattedContent = _buildFormattedChecklistString();
    final recordTitle = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : _defaultTitleForMode(_mode);
    final recordId =
        _activeRecordId ?? DateTime.now().millisecondsSinceEpoch.toString();

    var record = SavedNotepadRecord(
      id: recordId,
      category: _mode,
      title: recordTitle,
      assignedTo: _assignedTo,
      content: formattedContent,
      updatedAt: DateTime.now(),
    );

    // Try syncing to Supabase `public.family_notes` if table is present
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        final payload = {
          'category': record.category,
          'title': record.title,
          'assigned_to': record.assignedTo,
          'content': record.content,
          'created_by': uid,
          'updated_at': record.updatedAt.toIso8601String(),
        };
        if (_activeRecordId != null && _activeRecordId!.contains('-')) {
          final res = await client
              .from('family_notes')
              .update(payload)
              .eq('id', _activeRecordId!)
              .select()
              .maybeSingle();
          if (res != null) {
            record = SavedNotepadRecord.fromJson(Map<String, dynamic>.from(res));
          }
        } else {
          final res = await client
              .from('family_notes')
              .insert(payload)
              .select()
              .maybeSingle();
          if (res != null) {
            record = SavedNotepadRecord.fromJson(Map<String, dynamic>.from(res));
          }
        }
      }
    } catch (_) {
      // Gracefully continue with local persistence if Supabase table isn't created yet
    }

    setState(() {
      _activeRecordId = record.id;
      final existingIdx = _savedRecords.indexWhere((r) => r.id == record.id);
      if (existingIdx != -1) {
        _savedRecords[existingIdx] = record;
      } else {
        _savedRecords.insert(0, record);
      }
      _isSavingRecord = false;
    });

    try {
      await _storage.write(
        key: _savedRecordsKey,
        value: jsonEncode(_savedRecords.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}

    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryTeal,
          content: Text(
            '💾 Saved "${record.title}" (${_items.length} lines) to Saved Records!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Load a saved record into the Notepad for editing or sending
  void _openSavedRecord(SavedNotepadRecord rec) {
    setState(() {
      _activeRecordId = rec.id;
      _mode = rec.category;
      _assignedTo = rec.assignedTo;
      _titleCtrl.text = rec.title;
      _parseInitialChecklist(rec.content);
      _syncItemsToNotepadText();
      _showSavedRecordsList = false;
    });
  }

  /// Delete a saved record from local storage & Supabase
  Future<void> _deleteSavedRecord(SavedNotepadRecord rec) async {
    setState(() {
      _savedRecords.removeWhere((r) => r.id == rec.id);
      if (_activeRecordId == rec.id) {
        _activeRecordId = null;
      }
    });
    try {
      await _storage.write(
        key: _savedRecordsKey,
        value: jsonEncode(_savedRecords.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
    try {
      if (rec.id.contains('-')) {
        await Supabase.instance.client
            .from('family_notes')
            .delete()
            .eq('id', rec.id);
      }
    } catch (_) {}
  }

  void _applyModifierToLastOrInput(String chip) {
    setState(() {
      if (_itemInputCtrl.text.trim().isNotEmpty) {
        _selectedFreqOrQty = _selectedFreqOrQty == chip ? '' : chip;
      } else if (_items.isNotEmpty) {
        final lastIdx = _editingIndex ?? (_items.length - 1);
        final base = _items[lastIdx].replaceAll(RegExp(r'\s*\([^)]*\)$'), '');
        _items[lastIdx] = '$base ($chip)';
        _syncItemsToNotepadText();
      } else {
        _selectedFreqOrQty = _selectedFreqOrQty == chip ? '' : chip;
      }
    });
  }

  void _togglePresetItem(String item) {
    if (_isNotepadTextMode) {
      _syncNotepadTextToItems();
    }
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
      _syncItemsToNotepadText();
    });
  }

  Future<void> _send() async {
    if (_isNotepadTextMode) {
      _syncNotepadTextToItems();
    }
    if (_itemInputCtrl.text.trim().isNotEmpty) {
      _addOrSaveItem();
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type or add at least 1 item to the Notepad.'),
        ),
      );
      return;
    }

    // Auto-save record so the user never loses what they sent
    await _saveCurrentRecord(showToast: false);
    final formatted = _buildFormattedChecklistString();
    if (mounted) Navigator.pop(context);
    widget.onSendChecklist(formatted);
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
    final modifierChips =
        _mode == 'grocery' ? _groceryQtyChips : _taskRepeatChips;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===============================================================
              // 1. TOP NOTEPAD HEADER & ACTION BAR (NEW / EDIT MODE / SAVE / SAVED)
              // ===============================================================
              Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primaryTeal,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _activeRecordId != null
                          ? 'Editing Saved Notepad Record'
                          : 'Family Notepad (Groceries & Tasks)',
                      style: GoogleFonts.nunito(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w900,
                        color: onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Notepad Toolbar: [📄 + New]  [📝 Notepad / ☑️ List]  [💾 Save]  [📂 Records]
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryTeal,
                      side: const BorderSide(color: AppColors.primaryTeal),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 34),
                    ),
                    icon: const Icon(Icons.note_add_outlined, size: 17),
                    label: const Text(
                      'New',
                      style:
                          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    onPressed: _createNewRecord,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _isNotepadTextMode
                          ? AppColors.primaryTeal
                          : Colors.transparent,
                      foregroundColor: _isNotepadTextMode
                          ? Colors.white
                          : AppColors.primaryTeal,
                      side: const BorderSide(color: AppColors.primaryTeal),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 34),
                    ),
                    icon: Icon(
                      _isNotepadTextMode
                          ? Icons.checklist_rounded
                          : Icons.notes_rounded,
                      size: 17,
                    ),
                    label: Text(
                      _isNotepadTextMode ? 'Checklist View' : 'Notepad Edit',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    onPressed: () {
                      setState(() {
                        if (_isNotepadTextMode) {
                          _syncNotepadTextToItems();
                          _isNotepadTextMode = false;
                        } else {
                          _syncItemsToNotepadText();
                          _isNotepadTextMode = true;
                        }
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 34),
                    ),
                    icon: _isSavingRecord
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 17),
                    label: Text(
                      _activeRecordId != null ? 'Update Record' : 'Save Record',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    onPressed:
                        _isSavingRecord ? null : () => _saveCurrentRecord(),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _showSavedRecordsList
                          ? AppColors.accentCoral
                          : Colors.transparent,
                      foregroundColor: _showSavedRecordsList
                          ? Colors.white
                          : AppColors.accentCoral,
                      side: const BorderSide(color: AppColors.accentCoral),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 34),
                    ),
                    icon: const Icon(Icons.folder_copy_rounded, size: 16),
                    label: Text(
                      'Saved (${_savedRecords.length})',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => setState(() {
                      _showSavedRecordsList = !_showSavedRecordsList;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ===============================================================
              // 2. SCROLLABLE BODY (Saved Records Drawer OR Notepad Editor)
              // ===============================================================
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SAVED RECORDS DRAWER (Open, Edit, Send, or Delete)
                      if (_showSavedRecordsList) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentCoral.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.accentCoral.withOpacity(0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📂 Saved Notepad Records (Tap to Edit or Share):',
                                style: GoogleFonts.nunito(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.accentCoral,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (_savedRecords.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No saved records yet. Add items below and tap "Save Record"!',
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      color: onSurface.withOpacity(0.75),
                                    ),
                                  ),
                                )
                              else
                                ..._savedRecords.take(10).map((rec) {
                                  final isCurrent = _activeRecordId == rec.id;
                                  return Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: isCurrent
                                            ? AppColors.primaryTeal
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 2),
                                      title: Text(
                                        rec.title,
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'For: ${rec.assignedTo} • ${rec.content.split('\n').length - 1} items',
                                        style: const TextStyle(fontSize: 11.5),
                                      ),
                                      onTap: () => _openSavedRecord(rec),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Open & Edit',
                                            icon: const Icon(Icons.edit_rounded,
                                                size: 18,
                                                color: AppColors.primaryTeal),
                                            onPressed: () =>
                                                _openSavedRecord(rec),
                                          ),
                                          IconButton(
                                            tooltip: 'Send to Chat',
                                            icon: const Icon(Icons.send_rounded,
                                                size: 18,
                                                color: AppColors.accentCoral),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              widget
                                                  .onSendChecklist(rec.content);
                                            },
                                          ),
                                          IconButton(
                                            tooltip: 'Delete Record',
                                            icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: AppColors.error),
                                            onPressed: () =>
                                                _deleteSavedRecord(rec),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ],

                      // Category + Assignee Compact Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('🛒 Grocery'),
                              selected: _mode == 'grocery',
                              selectedColor: AppColors.primaryTeal,
                              labelStyle: GoogleFonts.nunito(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: _mode == 'grocery'
                                    ? Colors.white
                                    : onSurface,
                              ),
                              onSelected: (_) => setState(() {
                                _mode = 'grocery';
                                _assignedTo = 'Spouse / Partner';
                                _titleCtrl.text = _defaultTitleForMode(_mode);
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('✅ Tasks'),
                              selected: _mode == 'tasks',
                              selectedColor: AppColors.accentCoral,
                              labelStyle: GoogleFonts.nunito(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    _mode == 'tasks' ? Colors.white : onSurface,
                              ),
                              onSelected: (_) => setState(() {
                                _mode = 'tasks';
                                _assignedTo = 'Son';
                                _titleCtrl.text = _defaultTitleForMode(_mode);
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('📝 Note'),
                              selected: _mode == 'note',
                              selectedColor: AppColors.info,
                              labelStyle: GoogleFonts.nunito(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    _mode == 'note' ? Colors.white : onSurface,
                              ),
                              onSelected: (_) => setState(() {
                                _mode = 'note';
                                _assignedTo = 'All Family';
                                _titleCtrl.text = _defaultTitleForMode(_mode);
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('🛕 Volunteer'),
                              selected: _mode == 'volunteer',
                              selectedColor: AppColors.info,
                              labelStyle: GoogleFonts.nunito(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: _mode == 'volunteer'
                                    ? Colors.white
                                    : onSurface,
                              ),
                              onSelected: (_) => setState(() {
                                _mode = 'volunteer';
                                _assignedTo = 'Temple / Church Volunteers';
                                _titleCtrl.text = _defaultTitleForMode(_mode);
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Record Title + Assign To Row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _titleCtrl,
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Record Title',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _assigneePresets.contains(_assignedTo)
                                  ? _assignedTo
                                  : _assigneePresets.first,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'For',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              items: _assigneePresets
                                  .map((p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(
                                          p,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              const TextStyle(fontSize: 12.5),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _assignedTo = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // =======================================================
                      // 3. PROMINENT "+ ADD NEW ITEM" BAR (Always Visible!)
                      // =======================================================
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A2C2B)
                              : const Color(0xFFF0FAF8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _editingIndex != null
                                ? AppColors.accentCoral
                                : AppColors.primaryTeal,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _itemInputCtrl,
                                    focusNode: _itemInputFocus,
                                    onSubmitted: (_) => _addOrSaveItem(),
                                    style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _editingIndex != null
                                          ? 'Edit line #${_editingIndex! + 1}...'
                                          : 'Type new item (e.g. Milk, Curd) & tap + Add...',
                                      isDense: true,
                                      border: InputBorder.none,
                                      suffixIcon: _itemInputCtrl.text.isNotEmpty ||
                                              _editingIndex != null
                                          ? IconButton(
                                              icon: const Icon(
                                                  Icons.clear_rounded,
                                                  size: 18),
                                              onPressed: () => setState(() {
                                                _editingIndex = null;
                                                _itemInputCtrl.clear();
                                              }),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _editingIndex != null
                                        ? AppColors.accentCoral
                                        : AppColors.primaryTeal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  icon: Icon(
                                    _editingIndex != null
                                        ? Icons.check_rounded
                                        : Icons.add_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _editingIndex != null ? 'Save' : '+ Add',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900),
                                  ),
                                  onPressed: _addOrSaveItem,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // 1-Tap Quantity / Schedule Modifier Chips
                            SizedBox(
                              height: 28,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: modifierChips.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 6),
                                itemBuilder: (_, i) {
                                  final chip = modifierChips[i];
                                  final isSel = _selectedFreqOrQty == chip;
                                  return ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: isSel
                                        ? AppColors.accentCoral
                                        : AppColors.primaryTeal
                                            .withOpacity(0.12),
                                    label: Text(
                                      '+ $chip',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: isSel ? Colors.white : onSurface,
                                      ),
                                    ),
                                    onPressed: () =>
                                        _applyModifierToLastOrInput(chip),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // =======================================================
                      // 4. THE NOTEPAD / CHECKLIST PAPER AREA (FRONT & CENTER!)
                      // =======================================================
                      if (_isNotepadTextMode) ...[
                        Text(
                          '📝 Free-Text Notepad Mode (Type 1 item per line):',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2827)
                                : const Color(0xFFFFFDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primaryTeal.withOpacity(0.45),
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _notepadCtrl,
                            focusNode: _notepadFocus,
                            maxLines: 6,
                            minLines: 4,
                            onChanged: (_) => _syncNotepadTextToItems(),
                            style: GoogleFonts.nunito(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                              color: onSurface,
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  'Type your list here like a Notepad (1 item per line):\nMilk 2L\nEggs 1 Dozen\nFresh Vegetables\nCurd 500g',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '📋 Notepad Lines (${_items.length}) — Tap any line or ✏️ to Edit:',
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
                                  minimumSize: const Size(50, 22),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => setState(() {
                                  _items.clear();
                                  _checkedIndices.clear();
                                  _notepadCtrl.clear();
                                }),
                                child: const Text(
                                  'Clear All',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.error),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          constraints: const BoxConstraints(
                            minHeight: 90,
                            maxHeight: 190,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E2827)
                                : const Color(0xFFFFFDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primaryTeal.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: _items.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Text(
                                      'Your Notepad is empty.\n• Type in the "+ Add" box above, OR\n• Tap "Notepad Edit" to type freely, OR\n• Tap Quick-Pick items below!',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: onSurface.withOpacity(0.65),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 4,
                                    color:
                                        AppColors.primaryTeal.withOpacity(0.15),
                                  ),
                                  itemBuilder: (_, i) {
                                    final item = _items[i];
                                    final isChecked =
                                        _checkedIndices.contains(i);
                                    return Row(
                                      children: [
                                        InkWell(
                                          onTap: () => setState(() {
                                            if (isChecked) {
                                              _checkedIndices.remove(i);
                                            } else {
                                              _checkedIndices.add(i);
                                            }
                                          }),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(
                                              isChecked
                                                  ? Icons.check_box_rounded
                                                  : Icons
                                                      .check_box_outline_blank_rounded,
                                              size: 20,
                                              color: AppColors.primaryTeal,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _openEditLineDialog(i),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6),
                                              child: Text(
                                                '${i + 1}. $item',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w800,
                                                  decoration: isChecked
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : TextDecoration.none,
                                                  color: onSurface,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.edit_rounded,
                                              size: 18,
                                              color: AppColors.primaryTeal),
                                          tooltip: 'Edit Item',
                                          onPressed: () =>
                                              _openEditLineDialog(i),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: AppColors.error),
                                          tooltip: 'Remove Item',
                                          onPressed: () => setState(() {
                                            _items.removeAt(i);
                                            _syncItemsToNotepadText();
                                          }),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // =======================================================
                      // 5. COMPACT / COLLAPSIBLE QUICK-PICK ITEMS (No screen clutter!)
                      // =======================================================
                      InkWell(
                        onTap: () => setState(() {
                          _showQuickPickPresets = !_showQuickPickPresets;
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  color: AppColors.accentCoral, size: 18),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _showQuickPickPresets
                                      ? 'Hide 1-Tap Quick-Pick Items'
                                      : 'Tap to Open 1-Tap Quick-Pick Items (Milk, Eggs, Rice...)',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accentCoral,
                                  ),
                                ),
                              ),
                              Icon(
                                _showQuickPickPresets
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                color: AppColors.accentCoral,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!_showQuickPickPresets)
                        // Compact 1-line horizontal scroll when collapsed!
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: [...savedCustom, ...presets].length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (_, idx) {
                              final allChips = [...savedCustom, ...presets];
                              final preset = allChips[idx];
                              final added = _items.any((e) =>
                                  e == preset ||
                                  e.startsWith(
                                      '${preset.split(' (').first} ('));
                              return FilterChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  preset,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: added ? Colors.white : onSurface,
                                  ),
                                ),
                                selected: added,
                                selectedColor: AppColors.primaryTeal,
                                checkmarkColor: Colors.white,
                                onSelected: (_) => _togglePresetItem(preset),
                              );
                            },
                          ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [...savedCustom, ...presets].map((preset) {
                            final added = _items.any((e) =>
                                e == preset ||
                                e.startsWith('${preset.split(' (').first} ('));
                            return FilterChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                preset,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ===============================================================
              // 6. BOTTOM ACTION ROW: [💾 Save Record] + [📤 Send to Family Chat]
              // ===============================================================
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryTeal,
                        side: const BorderSide(
                            color: AppColors.primaryTeal, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.save_outlined, size: 19),
                      label: Text(
                        'Save Only',
                        style: GoogleFonts.nunito(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onPressed: () => _saveCurrentRecord(showToast: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCoral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 19),
                      label: Text(
                        'Save & Send (${_items.length})',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive & Directly Editable Notepad / Checklist Card rendered inside ChatBubble!
class InteractiveChecklistCard extends StatefulWidget {
  final String messageId;
  final String rawText;
  final bool isMine;
  final void Function(String updatedChecklistText)? onUpdateChecklist;

  const InteractiveChecklistCard({
    super.key,
    required this.messageId,
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
  static const _storage = FlutterSecureStorage();
  late String _headerLine;
  late List<String> _itemLabels;
  late Set<int> _checkedIndices;

  String get _localOverrideKey => 'ournest_checklist_card_${widget.messageId}';

  @override
  void initState() {
    super.initState();
    _parseText(widget.rawText);
    _loadLocalOverride();
  }

  @override
  void didUpdateWidget(covariant InteractiveChecklistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId ||
        oldWidget.rawText != widget.rawText) {
      _parseText(widget.rawText);
      _loadLocalOverride();
    }
  }

  Future<void> _loadLocalOverride() async {
    try {
      final saved = await _storage.read(key: _localOverrideKey);
      if (saved != null && saved.trim().isNotEmpty && mounted) {
        setState(() {
          _parseText(saved);
        });
      }
    } catch (_) {}
  }

  Future<void> _persistLocalOverride() async {
    try {
      await _storage.write(
        key: _localOverrideKey,
        value: _serializeCurrentCard(),
      );
    } catch (_) {}
  }

  void _parseText(String source) {
    final lines = source.split('\n');
    _headerLine = '🛒 Family Notepad';
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

  /// Instant popup dialog to Add or Edit a line on the Chat Bubble card
  Future<void> _promptAddOrEditItem({int? editIndex}) async {
    final isEdit = editIndex != null &&
        editIndex >= 0 &&
        editIndex < _itemLabels.length;
    final ctrl =
        TextEditingController(text: isEdit ? _itemLabels[editIndex] : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isEdit ? 'Edit Item #${editIndex + 1}' : 'Add New Item to List',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          decoration: InputDecoration(
            hintText: isEdit
                ? 'Update item text...'
                : 'Type new item (e.g. Curd 500g, Bread)...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
            ),
            icon: Icon(isEdit ? Icons.check_rounded : Icons.add_rounded,
                size: 18),
            label: Text(isEdit ? 'Save' : 'Add Item'),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        if (isEdit) {
          _itemLabels[editIndex] = result;
        } else {
          _itemLabels.add(result);
        }
      });
      await _persistLocalOverride();
    }
  }

  void _openFullEditorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FamilyChecklistSheet(
        initialRawChecklist: _serializeCurrentCard(),
        onSendChecklist: (updatedText) {
          setState(() {
            _parseText(updatedText);
          });
          _persistLocalOverride();
          widget.onUpdateChecklist?.call(updatedText);
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
                tooltip: 'Add Item',
                icon: Icon(Icons.add_circle_outline_rounded,
                    size: 20, color: fgColor),
                onPressed: () => _promptAddOrEditItem(),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Open in Family Notepad',
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
                : '$done of $total completed • Tap box to tick, ✏️ to edit, ✕ to delete',
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
                _persistLocalOverride();
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
                      onTap: () => _promptAddOrEditItem(editIndex: i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.edit_rounded,
                            size: 17, color: fgColor.withOpacity(0.85)),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _itemLabels.removeAt(i);
                          final updatedChecked = <int>{};
                          for (final idx in _checkedIndices) {
                            if (idx < i) {
                              updatedChecked.add(idx);
                            } else if (idx > i) {
                              updatedChecked.add(idx - 1);
                            }
                          }
                          _checkedIndices = updatedChecked;
                        });
                        _persistLocalOverride();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: fgColor.withOpacity(0.85)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: fgColor,
                  side: BorderSide(color: fgColor.withOpacity(0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  '+ Add Item',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                onPressed: () => _promptAddOrEditItem(),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: fgColor,
                  side: BorderSide(color: fgColor.withOpacity(0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text(
                  'Notepad / Edit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                onPressed: () => _openFullEditorSheet(context),
              ),
              if (widget.onUpdateChecklist != null)
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
                    'Send Updated List',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () {
                    _persistLocalOverride();
                    widget.onUpdateChecklist!(_serializeCurrentCard());
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
