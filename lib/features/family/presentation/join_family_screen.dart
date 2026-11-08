import 'package:flutter/material.dart';
import '../../../core/errors/friendly_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/relation_type.dart';
import 'family_controller.dart';
import 'widgets/family_qr_scanner_modal.dart';

class JoinFamilyScreen extends ConsumerStatefulWidget {
  final String? initialCode;
  final String? initialFamilyName;
  final String? initialAdminCity;
  final String? initialAdminAddress;

  const JoinFamilyScreen({
    super.key,
    this.initialCode,
    this.initialFamilyName,
    this.initialAdminCity,
    this.initialAdminAddress,
  });

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  late final TextEditingController _codeController;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _labelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  RelationType _selectedRelation = RelationType.mother;
  String? _detectedFamilyName;
  String? _inheritedAdminCity;
  String? _inheritedAdminAddress;
  String? _selectedBloodGroup;
  DateTime? _selectedDob;
  bool _populatedExisting = false;

  static const List<String> _bloodGroups = [
    'O+',
    'O-',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
  ];

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: widget.initialCode?.trim().toUpperCase() ?? '',
    );
    _detectedFamilyName = widget.initialFamilyName;
    _inheritedAdminCity = widget.initialAdminCity;
    _inheritedAdminAddress = widget.initialAdminAddress;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _populateFromExistingProfile() {
    if (_populatedExisting) return;
    final existing = ref.read(currentProfileProvider).value;
    if (existing != null) {
      _populatedExisting = true;
      if (_nameController.text.isEmpty && existing.displayName.isNotEmpty) {
        _nameController.text = existing.displayName;
      }
      if (_phoneController.text.isEmpty && existing.phone != null) {
        _phoneController.text = existing.phone!;
      }
      _selectedBloodGroup ??= existing.bloodGroup;
      _selectedDob ??= existing.dateOfBirth;
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920, 1, 1),
      lastDate: now,
      helpText: 'Select Date of Birth (for Family Tree & Birthdays)',
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
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
        if (result.adminCity != null && result.adminCity!.isNotEmpty) {
          _inheritedAdminCity = result.adminCity;
        }
        if (result.adminAddress != null && result.adminAddress!.isNotEmpty) {
          _inheritedAdminAddress = result.adminAddress;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.familyName != null
                ? 'QR Scanned: ${result.familyName} (${result.code})! Family info copied automatically.'
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
    final displayName = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final existing = ref.read(currentProfileProvider).value;

    // 1. Save or update personal details + auto-copied Admin City/Address first
    // so the foreign key on family_members(user_id -> profiles.id) is satisfied
    // and the Admin sees the applicant's real name, blood group & DOB!
    final profileSaved = await ref
        .read(profileControllerProvider.notifier)
        .saveProfile(
          displayName: displayName,
          phone: phone.isNotEmpty ? phone : existing?.phone,
          whatsappNumber: phone.isNotEmpty ? phone : existing?.whatsappNumber,
          avatarUrl: existing?.avatarUrl,
          sex: existing?.sex,
          dateOfBirth: _selectedDob ?? existing?.dateOfBirth,
          bloodGroup: _selectedBloodGroup ?? existing?.bloodGroup,
          livingPlace: parsed.adminCity ??
              _inheritedAdminCity ??
              existing?.livingPlace,
          homeAddress: parsed.adminAddress ??
              _inheritedAdminAddress ??
              existing?.homeAddress,
          city: parsed.adminCity ?? _inheritedAdminCity ?? existing?.city,
          education: existing?.education,
          occupation: existing?.occupation,
          workingPlace: existing?.workingPlace,
          workingDetails: existing?.workingDetails,
          statusText: existing?.statusText ?? 'Available for family ❤️',
          bioDescription: existing?.bioDescription,
        );

    if (!mounted) return;
    if (!profileSaved) {
      final pErr = ref.read(profileControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(pErr,
              fallback: 'Could not save your profile details. Please try again.')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

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
    _populateFromExistingProfile();
    final state = ref.watch(familyControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final isLoading = state.isLoading || profileState.isLoading;
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
                                (_inheritedAdminCity != null ||
                                        _inheritedAdminAddress != null)
                                    ? '🏠 Auto-copied Family Address: ${[_inheritedAdminCity, _inheritedAdminAddress].where((s) => s != null && s.isNotEmpty).join(" • ")}'
                                    : 'Family general info (City & Home Address) copies from Admin automatically!',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryTeal,
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
                  '1. Family / Group 6-Digit Invite Code',
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

                const SizedBox(height: 22),
                Text(
                  '2. Your Personal Details (Family Address Auto-Copies from Admin)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Your Full Name / Display Name *',
                    hintText: 'e.g. Anitha Kumar, Rahul, Amma',
                    prefixIcon:
                        Icon(Icons.badge_rounded, color: AppColors.primaryTeal),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 2) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBloodGroup,
                        style: GoogleFonts.nunito(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Blood Group',
                          prefixIcon: Icon(Icons.bloodtype_rounded,
                              color: AppColors.error),
                        ),
                        items: _bloodGroups
                            .map((bg) => DropdownMenuItem(
                                  value: bg,
                                  child: Text(bg),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedBloodGroup = val),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _pickDob,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            prefixIcon: Icon(Icons.cake_rounded,
                                color: AppColors.accentCoral),
                          ),
                          child: Text(
                            _selectedDob != null
                                ? DateFormat('d MMM yyyy').format(_selectedDob!)
                                : 'Select DOB',
                            style: GoogleFonts.nunito(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: _selectedDob != null
                                  ? onSurface
                                  : AppColors.textSecondaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Mobile / WhatsApp Number (Optional)',
                    hintText: 'e.g. +65 9123 4567 / +91 98765 43210',
                    prefixIcon:
                        Icon(Icons.phone_rounded, color: AppColors.primaryTeal),
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  '3. What is your relation in this family / group?',
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
