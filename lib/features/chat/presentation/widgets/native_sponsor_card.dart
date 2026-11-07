import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';

class NativeSponsorCard extends StatefulWidget {
  const NativeSponsorCard({super.key});

  @override
  State<NativeSponsorCard> createState() => _NativeSponsorCardState();
}

class _NativeSponsorCardState extends State<NativeSponsorCard> {
  static const _storage = FlutterSecureStorage();
  static const _customBannerKey = 'ournest_custom_sponsor_banner_b64';
  static const _customTitleKey = 'ournest_custom_sponsor_title';
  static const _customSubKey = 'ournest_custom_sponsor_subtitle';

  Uint8List? _customBannerBytes;
  String _title = 'Warm Deepavali Greetings from N.R.Kumar Family!';
  String _subtitle =
      'My Deepavali Gift for this Deepavali — OurNest: Where your family talks.';

  @override
  void initState() {
    super.initState();
    _loadCustomSponsor();
  }

  Future<void> _loadCustomSponsor() async {
    try {
      final b64 = await _storage.read(key: _customBannerKey);
      final t = await _storage.read(key: _customTitleKey);
      final s = await _storage.read(key: _customSubKey);
      if (!mounted) return;
      setState(() {
        if (b64 != null && b64.isNotEmpty) {
          _customBannerBytes = base64Decode(b64);
        }
        if (t != null && t.isNotEmpty) _title = t;
        if (s != null && s.isNotEmpty) _subtitle = s;
      });
    } catch (_) {}
  }

  Future<void> _openCustomizeSheet() async {
    final titleCtrl = TextEditingController(text: _title);
    final subCtrl = TextEditingController(text: _subtitle);
    Uint8List? previewBytes = _customBannerBytes;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textPrimary =
              isDark ? const Color(0xFFF5F7F7) : AppColors.textPrimaryLight;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded,
                          color: AppColors.accentCoral, size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Customize Sponsor / Festival Banner',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: previewBytes != null
                        ? Image.memory(previewBytes!,
                            height: 110, fit: BoxFit.cover)
                        : Image.asset('assets/icons/sponsor_banner.jpg',
                            height: 110, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_rounded,
                              size: 18),
                          label: const Text('Pick Banner from Gallery'),
                          onPressed: () async {
                            final picked = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1200,
                              imageQuality: 82,
                            );
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              setModalState(() => previewBytes = bytes);
                            }
                          },
                        ),
                      ),
                      if (previewBytes != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              setModalState(() => previewBytes = null),
                          child: const Text('Reset Default'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sponsor / Greeting Headline',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sponsor / Greeting Subtitle',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCoral,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save Sponsor Banner'),
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved == true) {
      final newTitle = titleCtrl.text.trim().isNotEmpty
          ? titleCtrl.text.trim()
          : 'Warm Deepavali Greetings from N.R.Kumar Family!';
      final newSub = subCtrl.text.trim().isNotEmpty
          ? subCtrl.text.trim()
          : 'My Deepavali Gift for this Deepavali — OurNest: Where your family talks.';
      try {
        if (previewBytes != null) {
          await _storage.write(
              key: _customBannerKey, value: base64Encode(previewBytes!));
        } else {
          await _storage.delete(key: _customBannerKey);
        }
        await _storage.write(key: _customTitleKey, value: newTitle);
        await _storage.write(key: _customSubKey, value: newSub);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _customBannerBytes = previewBytes;
          _title = newTitle;
          _subtitle = newSub;
        });
      }
    }
  }

  void _showFullBannerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _customBannerBytes != null
                  ? Image.memory(_customBannerBytes!, fit: BoxFit.contain)
                  : Image.asset('assets/icons/sponsor_banner.jpg',
                      fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCoral,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Change Banner / Text'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openCustomizeSheet();
                  },
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? const Color(0xFFF5F7F7) : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? const Color(0xFFCFD8DC) : AppColors.textSecondaryLight;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: AppColors.accentCoral.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      color: Theme.of(context).cardTheme.color,
      child: InkWell(
        onTap: _showFullBannerDialog,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4.1,
                  child: _customBannerBytes != null
                      ? Image.memory(
                          _customBannerBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Image.asset(
                          'assets/icons/sponsor_banner.jpg',
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                ),
                Positioned(
                  top: 8,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.amber.withOpacity(0.7), width: 1),
                    ),
                    child: Text(
                      '🪔 SPONSORED GREETING',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber.shade200,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 8,
                  child: InkWell(
                    onTap: _openCustomizeSheet,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Edit Ad',
                            style: GoogleFonts.nunito(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.zoom_out_map_rounded,
                    size: 18,
                    color: AppColors.accentCoral.withOpacity(0.85),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
