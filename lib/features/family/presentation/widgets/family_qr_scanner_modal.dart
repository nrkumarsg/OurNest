import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/family_model.dart';

class ParsedFamilyInvite {
  final String code;
  final String? familyName;

  const ParsedFamilyInvite({
    required this.code,
    this.familyName,
  });
}

/// Universal parser for OurNest QR codes and invite strings.
/// Supports:
/// - ournest://invite/FMS258?name=N.R.K%20Family
/// - https://ournest.app/join?code=FMS258&name=N.R.K+Family
/// - OURNEST:FMS258:N.R.K Family
/// - Plain 6-char code: FMS258
/// - Shared invite text containing a 6-char code
ParsedFamilyInvite? parseInviteQrPayload(String? rawValue) {
  if (rawValue == null) return null;
  final raw = rawValue.trim();
  if (raw.isEmpty) return null;

  // 1. Check URI formats (ournest://invite/CODE?name=... or https://...?code=CODE)
  final uri = Uri.tryParse(raw);
  if (uri != null && (uri.scheme == 'ournest' || uri.scheme == 'http' || uri.scheme == 'https')) {
    String? code = uri.queryParameters['code'];
    final String? name = uri.queryParameters['name'];

    if ((code == null || code.isEmpty) && uri.pathSegments.isNotEmpty) {
      code = uri.pathSegments.last;
    }
    if (code != null && RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(code.trim())) {
      return ParsedFamilyInvite(
        code: code.trim().toUpperCase(),
        familyName: (name != null && name.trim().isNotEmpty) ? name.trim() : null,
      );
    }
  }

  // 2. Check OURNEST:CODE:NAME format
  if (raw.toUpperCase().startsWith('OURNEST:')) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final candidate = parts[1].trim().toUpperCase();
      if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(candidate)) {
        final name = parts.length >= 3 ? parts.sublist(2).join(':').trim() : null;
        return ParsedFamilyInvite(
          code: candidate,
          familyName: (name != null && name.isNotEmpty) ? name : null,
        );
      }
    }
  }

  // 3. Check if raw string contains a slash like invite/FMS258
  if (raw.contains('/')) {
    final lastPart = raw.split('/').last.split('?').first.trim().toUpperCase();
    if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(lastPart)) {
      return ParsedFamilyInvite(code: lastPart);
    }
  }

  // 4. Direct 6-character alphanumeric code
  final directClean = raw.toUpperCase();
  if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(directClean)) {
    return ParsedFamilyInvite(code: directClean);
  }

  // 5. Fallback: extract "code: XXXXXX" from shared invite text
  final textMatch = RegExp(r'code[:\s]+([A-Za-z0-9]{6})\b', caseSensitive: false).firstMatch(raw);
  if (textMatch != null) {
    return ParsedFamilyInvite(code: textMatch.group(1)!.toUpperCase());
  }

  return null;
}

/// Builds the canonical QR payload for a Family so both OurNest's embedded scanner
/// and external camera readers can parse the code and family name reliably.
String buildFamilyQrData(Family family) {
  final encodedName = Uri.encodeQueryComponent(family.name);
  return 'ournest://invite/${family.inviteCode.toUpperCase()}?name=$encodedName';
}

/// WhatsApp-style 2-Tab Modal / Fullscreen Sheet:
/// - Tab 1: "My Family QR" (High-contrast Black-on-White QR + 6-char code + Share)
/// - Tab 2: "Scan QR Code" (Live Camera + Torch + Flip Camera + Pick QR from Gallery)
class FamilyQrScannerModal extends StatefulWidget {
  final Family? family;
  final int initialTabIndex;
  final ValueChanged<ParsedFamilyInvite>? onInviteScanned;

  /// Admin only: replaces the invite code (F20). Returns the new code, or
  /// null if it failed (the caller shows the error).
  final Future<String?> Function()? onResetInviteCode;

  const FamilyQrScannerModal({
    super.key,
    this.family,
    this.initialTabIndex = 0,
    this.onInviteScanned,
    this.onResetInviteCode,
  });

  @override
  State<FamilyQrScannerModal> createState() => _FamilyQrScannerModalState();
}

class _FamilyQrScannerModalState extends State<FamilyQrScannerModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _hasScanned = false;
  bool _torchOn = false;
  late Family? _family = widget.family;
  bool _resetting = false;

  Future<void> _resetInviteCode() async {
    final reset = widget.onResetInviteCode;
    final family = _family;
    if (reset == null || family == null || _resetting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create a new invite code?'),
        content: const Text(
            "The current code and QR will stop working. Use this if the code was shared with someone it shouldn't have been."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep current code')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create new code')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _resetting = true);
    final newCode = await reset();
    if (!mounted) return;
    setState(() {
      _resetting = false;
      if (newCode != null) _family = family.copyWith(inviteCode: newCode);
    });
    if (newCode != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('New invite code: $newCode. The old one no longer works.'),
        backgroundColor: AppColors.primaryTeal,
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    final hasFamily = widget.family != null;
    _tabController = TabController(
      length: hasFamily ? 2 : 1,
      vsync: this,
      initialIndex: hasFamily ? widget.initialTabIndex.clamp(0, 1) : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleRawDetection(String? raw) {
    if (_hasScanned) return;
    final parsed = parseInviteQrPayload(raw);
    if (parsed != null) {
      _hasScanned = true;
      HapticFeedback.mediumImpact();
      if (widget.onInviteScanned != null) {
        Navigator.of(context).pop(parsed);
        widget.onInviteScanned!(parsed);
      } else {
        Navigator.of(context).pop(parsed);
      }
    }
  }

  Future<void> _scanFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final BarcodeCapture? capture =
          await _scannerController.analyzeImage(image.path);
      if (!mounted) return;

      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          final parsed = parseInviteQrPayload(barcode.rawValue);
          if (parsed != null) {
            _handleRawDetection(barcode.rawValue);
            return;
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid OurNest family QR code found in that image.'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not read image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFamily = widget.family != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        title: Text(
          hasFamily ? 'Family QR & Scanner' : 'Scan Family QR Code',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: hasFamily
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accentCoral,
                indicatorWeight: 4,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.qr_code_2_rounded),
                    text: 'My Family QR',
                  ),
                  Tab(
                    icon: Icon(Icons.qr_code_scanner_rounded),
                    text: 'Scan QR Code',
                  ),
                ],
              )
            : null,
      ),
      body: hasFamily
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildMyFamilyQrTab(_family!),
                _buildScannerTab(),
              ],
            )
          : _buildScannerTab(),
    );
  }

  Widget _buildMyFamilyQrTab(Family family) {
    final qrPayload = buildFamilyQrData(family);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 3,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.dividerLight, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.family_restroom_rounded,
                          color: AppColors.primaryTeal,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            family.name,
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryTeal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // High-contrast Pure Black on Pure White QR Code with quiet zone
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black12, width: 2),
                    ),
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 220.0,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Open OurNest on your family member\'s phone and tap "Scan QR to Join" to link right away.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  // 6-Character Invite Code Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryTeal,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '6-DIGIT INVITE CODE',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondaryLight,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              family.inviteCode,
                              style: GoogleFonts.nunito(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: AppColors.primaryTeal,
                          ),
                          tooltip: 'Copy Code',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: family.inviteCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invite code copied!'),
                                backgroundColor: AppColors.primaryTeal,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded),
            label: const Text('Copy & Share Invite Message'),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      'Join our "${family.name}" family circle on OurNest! Open OurNest and enter invite code: ${family.inviteCode}',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite message copied ready to send!'),
                  backgroundColor: AppColors.primaryTeal,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Switch to QR Camera Scanner'),
            onPressed: () {
              _tabController.animateTo(1);
            },
          ),
          if (widget.onResetInviteCode != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              icon: _resetting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.autorenew_rounded),
              label: const Text('Create a new invite code'),
              onPressed: _resetting ? null : _resetInviteCode,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Stack(
      children: [
        // Live Camera Feed
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final raw = barcode.rawValue;
              if (raw != null && raw.trim().isNotEmpty) {
                _handleRawDetection(raw);
                break;
              }
            }
          },
        ),

        // Darkened Overlay with Cutout Reticle (WhatsApp Web / Linked Devices style)
         IgnorePointer(
          child: Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.accentCoral,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Top Camera Controls (Flashlight & Flip Camera)
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Point camera at Family QR Code',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor:
                          _torchOn ? AppColors.accentCoral : Colors.black54,
                    ),
                    icon: Icon(
                      _torchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'Toggle Flashlight',
                    onPressed: () {
                      _scannerController.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    icon: const Icon(
                      Icons.cameraswitch_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'Switch Camera',
                    onPressed: () => _scannerController.switchCamera(),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Bottom Actions: Scan from Gallery Image or Enter Code
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Received a QR screenshot on WhatsApp or Email?',
                  style: GoogleFonts.nunito(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCoral,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Scan QR from Gallery Photo'),
                  onPressed: _scanFromGallery,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

