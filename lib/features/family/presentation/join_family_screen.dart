import 'package:flutter/material.dart';
import '../../../core/errors/friendly_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../domain/relation_type.dart';
import 'family_controller.dart';
import 'widgets/family_qr_scanner_modal.dart';

class JoinFamilyScreen extends ConsumerStatefulWidget {
  final String? initialCode;
  final String? initialFamilyName;

  const JoinFamilyScreen({
    super.key,
    this.initialCode,
    this.initialFamilyName,
  });

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  late final TextEditingController _codeController;
  final _labelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  RelationType _selectedRelation = RelationType.mother;
  String? _detectedFamilyName;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: widget.initialCode?.trim().toUpperCase() ?? '',
    );
    _detectedFamilyName = widget.initialFamilyName;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _openQrScanner() async {
    final result = await Navigator.of(context).push<ParsedFamilyInvite>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const FamilyQrScannerModal(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _codeController.text = result.code;
        if (result.familyName != null && result.familyName!.isNotEmpty) {
          _detectedFamilyName = result.familyName;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.familyName != null
                ? 'QR Scanned: ${result.familyName} (${result.code})! Choose your relation below.'
                : 'QR Scanned: Code ${result.code}! Choose your relation below.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final parsed = parseInviteQrPayload(_codeController.text) ??
        ParsedFamilyInvite(code: _codeController.text.trim().toUpperCase());
    final code = parsed.code;
    final customLabel = _labelController.text.trim();

    final success = await ref.read(familyControllerProvider.notifier).joinFamily(
          inviteCode: code,
          applicantRelation: _selectedRelation.name,
          applicantRelationLabel: customLabel.isNotEmpty ? customLabel : null,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join request submitted! Waiting for admin approval.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/pending-approval');
    } else {
      final error = ref.read(familyControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(error,
              fallback: 'Failed to join family. Check the code and try again.')),
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
        title: const Text('Join Family Circle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan QR Code',
            onPressed: _openQrScanner,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_detectedFamilyName != null &&
                    _detectedFamilyName!.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.success, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.success,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QR Linked: $_detectedFamilyName',
                                style: GoogleFonts.nunito(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryTealDark,
                                ),
                              ),
                              Text(
                                'Select your family relation below and tap Join.',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Prominent Scan QR Button at top (WhatsApp Linked Devices style)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
                  label: const Text('Open Camera / Gallery QR Scanner'),
                  onPressed: _openQrScanner,
                ),
                const SizedBox(height: 20),

                Text(
                  'Family Invite Code',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4.0,
                    color: AppColors.primaryTeal,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. FMS258',
                    labelText: '6-Character Code',
                    prefixIcon: const Icon(
                      Icons.vpn_key_rounded,
                      color: AppColors.primaryTeal,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primaryTeal,
                      ),
                      tooltip: 'Scan QR Code',
                      onPressed: _openQrScanner,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter or scan the 6-character code';
                    }
                    final parsed = parseInviteQrPayload(value);
                    if (parsed == null && value.trim().length != 6) {
                      return 'Code must be 6 characters (e.g. FMS258)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
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
                      hintText: 'e.g. Temple Volunteer, Church Member, Cousin',
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
                    '🧳 Tour Group Member',
                    '✈️ Tour Co-Leader',
                    '✨ Custom Group Member',
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
                const SizedBox(height: 36),
                ElevatedButton.icon(
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.link_rounded),
                  label: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Link & Join Family Circle'),
                  onPressed: isLoading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
