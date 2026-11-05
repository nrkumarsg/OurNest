import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../family/data/family_repository.dart';
import '../../family/presentation/family_controller.dart';
import 'profile_controller.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final bool isEditing;

  const ProfileSetupScreen({super.key, this.isEditing = false});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _statusController =
      TextEditingController(text: 'Available for family ❤️');
  final _livingPlaceController = TextEditingController();
  final _homeAddressController = TextEditingController();
  final _educationController = TextEditingController();
  final _occupationController = TextEditingController();
  final _workingPlaceController = TextEditingController();
  final _workingDetailsController = TextEditingController();
  final _bioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedSex;
  String? _selectedBloodGroup;
  DateTime? _selectedDob;
  String? _avatarBase64DataUri;
  bool _sameAsPhone = false;
  bool _initializedFromExisting = false;

  static const List<String> _sexOptions = ['Male', 'Female', 'Other'];
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
  static const List<String> _statusPresets = [
    'Available for family ❤️',
    'At work 💼',
    'In school / class 📚',
    'Resting at home 🏡',
    'Travelling ✈️',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _statusController.dispose();
    _livingPlaceController.dispose();
    _homeAddressController.dispose();
    _educationController.dispose();
    _occupationController.dispose();
    _workingPlaceController.dispose();
    _workingDetailsController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _populateExistingProfile() {
    if (_initializedFromExisting) return;
    final existing = ref.read(currentProfileProvider).value;
    if (existing != null) {
      _initializedFromExisting = true;
      _nameController.text = existing.displayName;
      _phoneController.text = existing.phone ?? '';
      _whatsappController.text = existing.whatsappNumber ?? existing.phone ?? '';
      _sameAsPhone = (existing.whatsappNumber != null &&
          existing.whatsappNumber == existing.phone &&
          existing.phone?.isNotEmpty == true);
      _statusController.text =
          existing.statusText ?? 'Available for family ❤️';
      _livingPlaceController.text = existing.livingPlace ?? existing.city ?? '';
      _homeAddressController.text = existing.homeAddress ?? '';
      _educationController.text = existing.education ?? '';
      _occupationController.text = existing.occupation ?? '';
      _workingPlaceController.text = existing.workingPlace ?? '';
      _workingDetailsController.text = existing.workingDetails ?? '';
      _bioController.text = existing.bioDescription ?? '';
      _selectedSex = existing.sex;
      _selectedBloodGroup = existing.bloodGroup;
      _selectedDob = existing.dateOfBirth;
      _avatarBase64DataUri = existing.avatarUrl;
    }
  }

  Future<void> _pickAvatarImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primaryTeal),
              title: const Text('Take Profile Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.accentCoral),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _avatarBase64DataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1985, 1, 1),
      firstDate: DateTime(1920, 1, 1),
      lastDate: now,
      helpText: 'Select Date of Birth (for Family Tree & Birthdays)',
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(profileControllerProvider.notifier)
        .saveProfile(
          displayName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          whatsappNumber: _sameAsPhone
              ? _phoneController.text.trim()
              : _whatsappController.text.trim(),
          avatarUrl: _avatarBase64DataUri,
          sex: _selectedSex,
          dateOfBirth: _selectedDob,
          bloodGroup: _selectedBloodGroup,
          livingPlace: _livingPlaceController.text.trim(),
          homeAddress: _homeAddressController.text.trim(),
          city: _livingPlaceController.text.trim(),
          education: _educationController.text.trim(),
          occupation: _occupationController.text.trim(),
          workingPlace: _workingPlaceController.text.trim(),
          workingDetails: _workingDetailsController.text.trim(),
          statusText: _statusController.text.trim(),
          bioDescription: _bioController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      ref.invalidate(familyMembersProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Family profile saved!'),
          backgroundColor: AppColors.success,
        ),
      );
      if (widget.isEditing && context.canPop()) {
        context.pop();
      } else {
        final membership = await ref
            .read(familyRepositoryProvider)
            .getCurrentUserMembership()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (!mounted) return;
        if (membership == null) {
          context.go('/family-entry');
        } else if (membership.isPending) {
          context.go('/pending-approval');
        } else {
          context.go('/home');
        }
      }
    } else {
      final err = ref.read(profileControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err is StateError
              ? err.message
              : 'Failed to save profile. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildAvatarPreview() {
    if (_avatarBase64DataUri != null &&
        _avatarBase64DataUri!.startsWith('data:image')) {
      try {
        final commaIdx = _avatarBase64DataUri!.indexOf(',');
        final bytes = base64Decode(_avatarBase64DataUri!.substring(commaIdx + 1));
        return CircleAvatar(
          radius: 54,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: 54,
      backgroundColor: AppColors.primaryTeal.withOpacity(0.12),
      child: const Icon(
        Icons.person_rounded,
        size: 64,
        color: AppColors.primaryTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _populateExistingProfile();
    final profileState = ref.watch(profileControllerProvider);
    final isLoading = profileState.isLoading;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Family Profile' : 'Your Family Profile'),
        automaticallyImplyLeading: widget.isEditing,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Profile Photo
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatarImage,
                    child: Stack(
                      children: [
                        _buildAvatarPreview(),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: AppColors.accentCoral,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap photo to upload from Camera or Gallery',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Section 1: Basic Identity
                _buildSectionHeader(context, '1. Basic Identity & Status'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Full Name / Family Display Name *',
                    hintText: 'e.g. N.R. Kumar, Amma, Rahul',
                    prefixIcon:
                        Icon(Icons.badge_rounded, color: AppColors.primaryTeal),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name should be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Status Input + Quick Chips
                TextFormField(
                  controller: _statusController,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Current Status',
                    hintText: 'e.g. Available for family ❤️, At work 💼',
                    prefixIcon: Icon(Icons.sentiment_satisfied_alt_rounded,
                        color: AppColors.accentCoral),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statusPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) {
                      final preset = _statusPresets[i];
                      return ActionChip(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        label: Text(
                          preset,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                          ),
                        ),
                        onPressed: () {
                          setState(() => _statusController.text = preset);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // Sex & Blood Group Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSex,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Sex / Gender',
                          prefixIcon: Icon(Icons.wc_rounded,
                              color: AppColors.primaryTeal),
                        ),
                        items: _sexOptions
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedSex = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBloodGroup,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
                  ],
                ),
                const SizedBox(height: 14),

                // Date of Birth Picker (for Family Tree Birthday Reminders)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickDateOfBirth,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth (Auto-syncs Family Birthday Reminders)',
                      prefixIcon: Icon(Icons.cake_rounded,
                          color: AppColors.accentCoral),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDob != null
                              ? DateFormat('d MMMM yyyy').format(_selectedDob!)
                              : 'Tap to select Date of Birth',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _selectedDob != null
                                ? onSurface
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const Icon(Icons.calendar_month_rounded,
                            color: AppColors.primaryTeal),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Mobile Phone Number + WhatsApp Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: (v) {
                    if (_sameAsPhone) {
                      _whatsappController.text = v;
                    }
                  },
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Mobile Phone Number (For Alarm Call Escalation)',
                    hintText: 'e.g. +65 9123 4567 / +91 98765 43210',
                    prefixIcon: Icon(Icons.phone_rounded,
                        color: AppColors.primaryTeal),
                  ),
                ),
                const SizedBox(height: 6),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryTeal,
                  value: _sameAsPhone,
                  onChanged: (val) {
                    setState(() {
                      _sameAsPhone = val ?? false;
                      if (_sameAsPhone) {
                        _whatsappController.text = _phoneController.text;
                      }
                    });
                  },
                  title: Text(
                    'WhatsApp number is same as Mobile Phone Number',
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _whatsappController,
                  enabled: !_sameAsPhone,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number (With Country Code)',
                    hintText: 'e.g. +65 9123 4567 / +91 98765 43210',
                    prefixIcon: Icon(Icons.chat_rounded,
                        color: Color(0xFF25D366)),
                  ),
                ),
                const SizedBox(height: 24),

                // Section 2: Living Place, Home Address, Education & Work Details
                _buildSectionHeader(
                    context, '2. Living Place, Home Address, Education & Work'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _livingPlaceController,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Living Place / Residence City',
                    hintText: 'e.g. Tampines, Singapore / Chennai, India',
                    prefixIcon: Icon(Icons.location_city_rounded,
                        color: AppColors.accentCoral),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _homeAddressController,
                  maxLines: 2,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Home / Residential Address (Door No, Street, Postal Code)',
                    hintText: 'e.g. Blk 123 Tampines St 11, #08-45, Singapore 521123',
                    prefixIcon: Icon(Icons.home_rounded,
                        color: AppColors.primaryTeal),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _educationController,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Education / Qualification',
                    hintText: 'e.g. B.Eng Mechanical, MBA, High School',
                    prefixIcon: Icon(Icons.school_rounded,
                        color: AppColors.primaryTeal),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _occupationController,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Profession / Occupation',
                    hintText: 'e.g. Director, Software Engineer, Doctor, Student',
                    prefixIcon:
                        Icon(Icons.work_rounded, color: AppColors.primaryTeal),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _workingPlaceController,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Working Place / Company / School',
                    hintText: 'e.g. ARKIS PTE LTD, National University Hospital',
                    prefixIcon: Icon(Icons.business_rounded,
                        color: AppColors.accentCoral),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _workingDetailsController,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Working Details / Department & Hours',
                    hintText: 'e.g. Operations Division • Mon–Fri 9am–6pm',
                    prefixIcon: Icon(Icons.assignment_ind_rounded,
                        color: AppColors.primaryTeal),
                  ),
                ),
                const SizedBox(height: 24),

                // Section 3: Bio / About Description
                _buildSectionHeader(context, '3. Family Bio & About Note'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Bio / Description',
                    hintText:
                        'Share a short bio, hobbies, or helpful notes for the family tree...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton.icon(
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_rounded),
                  label: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(widget.isEditing
                          ? 'Save Profile Updates'
                          : 'Save Profile & Continue'),
                  onPressed: isLoading ? null : _saveProfile,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primaryTeal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryTeal,
          ),
        ),
      ],
    );
  }
}
