import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/relation_type.dart';
import 'family_controller.dart';

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _nameController = TextEditingController();
  final _labelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  RelationType _selectedRelation = RelationType.father;
  String _selectedGroupType = 'family'; // 'family' | 'tour' | 'temple' | 'church' | 'friends' | 'custom'

  @override
  void dispose() {
    _nameController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final familyName = _nameController.text.trim();
    final customLabel = _labelController.text.trim();

    final success = await ref.read(familyControllerProvider.notifier).createFamily(
          name: familyName,
          adminRelation: _selectedRelation.name,
          adminRelationLabel: customLabel.isNotEmpty ? customLabel : null,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Family created successfully! You are the Admin.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/family');
    } else {
      final error = ref.read(familyControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error?.toString() ?? 'Failed to create family. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(familyControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Family'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create a Family, Tour, or Custom Group',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a standard group type below or choose "✨ Custom Group" to create any group you like. You will be the Admin and can also assign Shared Admins (Co-Admins) anytime.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFCFD8DC)
                            : AppColors.textSecondaryLight,
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ('family', '👨‍👩‍👧‍👦 Family Circle', 'The Kumar Family', RelationType.father, ''),
                    ('tour', '✈️ Tour Group', 'Malaysia Family Tour 2026', RelationType.other, '✈️ Tour Leader / Admin'),
                    ('temple', '🛕 Temple Group', 'Sri Mariamman Temple Seva', RelationType.other, '🛕 Temple Coordinator'),
                    ('church', '⛪ Church Group', 'St. Mary\'s Parish Fellowship', RelationType.other, '⛪ Parish Coordinator'),
                    ('friends', '🤝 Friends Group', 'Close Friends & Alumni Club', RelationType.other, '🤝 Group Admin'),
                    ('custom', '✨ Custom Group', '', RelationType.other, '👑 Custom Group Admin'),
                  ].map((item) {
                    final isSelected = _selectedGroupType == item.$1;
                    return ChoiceChip(
                      label: Text(
                        item.$2,
                        style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: item.$1 == 'custom' || item.$1 == 'tour'
                          ? AppColors.accentCoral
                          : AppColors.primaryTeal,
                      backgroundColor: Theme.of(context).cardTheme.color,
                      onSelected: (val) {
                        if (!val) return;
                        setState(() {
                          _selectedGroupType = item.$1;
                          _selectedRelation = item.$4;
                          if (item.$5.isNotEmpty) {
                            _labelController.text = item.$5;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: _selectedGroupType == 'tour'
                        ? 'Tour Group Name'
                        : _selectedGroupType == 'custom'
                            ? 'Custom Group Name (Type Any Name)'
                            : 'Family or Community Group Name',
                    hintText: _selectedGroupType == 'tour'
                        ? 'e.g. Malaysia Tour Group / Europe Trip 2026'
                        : _selectedGroupType == 'custom'
                            ? 'e.g. Weekend Badminton Club / Wedding Committee'
                            : 'e.g. The Sharma Family / Temple Volunteers',
                    prefixIcon: const Icon(Icons.home_work_rounded, color: AppColors.primaryTeal),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a group or family name';
                    }
                    if (value.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'What is your relation in this family?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: RelationType.values.map((rel) {
                    final isSelected = _selectedRelation == rel;
                    return ChoiceChip(
                      label: Text(
                        '${rel.emoji} ${rel.label}',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primaryTeal,
                      backgroundColor: Theme.of(context).cardTheme.color,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedRelation = rel);
                      },
                    );
                  }).toList(),
                ),
                if (_selectedRelation == RelationType.other) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _labelController,
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Custom Role / Relation Label',
                      hintText: 'e.g. Temple Volunteer, Church Member, Coordinator',
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Or 1-Tap Tour / Custom / Community / Volunteer Role:',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryTeal,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '✈️ Tour Leader / Admin',
                    '🧳 Tour Group Member',
                    '✨ Custom Group Admin',
                    '🛕 Temple Volunteer',
                    '⛪ Church Member',
                    '👑 Group Coordinator',
                    '🤲 Community Volunteer',
                    '🤝 Family Friend',
                    '👤 Single / Solo Member',
                  ].map((roleLabel) {
                    final isCurrent = _selectedRelation == RelationType.other &&
                        _labelController.text == roleLabel;
                    return ActionChip(
                      backgroundColor: isCurrent
                          ? AppColors.accentCoral
                          : Theme.of(context).cardTheme.color,
                      label: Text(
                        roleLabel,
                        style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedRelation = RelationType.other;
                          _labelController.text = roleLabel;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create Family & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
