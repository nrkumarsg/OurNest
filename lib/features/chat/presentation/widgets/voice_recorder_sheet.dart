import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/constants/app_colors.dart';

class VoiceRecorderSheet extends StatefulWidget {
  final Function(Uint8List rawBytes, int durationMs) onComplete;

  const VoiceRecorderSheet({super.key, required this.onComplete});

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _timer;
  int _seconds = 0;
  bool _isRecording = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (kIsWeb) {
      _filePath = '';
    } else {
      final tempDir = await getTemporaryDirectory();
      _filePath = '${tempDir.path}/temp_voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: _filePath!,
    );

    setState(() => _isRecording = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _seconds++);
      }
    });
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _audioRecorder.cancel();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendVoiceNote() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    if (path == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final bytes = await XFile(path).readAsBytes();
      final durationMs = _seconds * 1000;
      widget.onComplete(bytes, durationMs);
    } catch (_) {}

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  String _formatTimer(int totalSecs) {
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Recording Voice Note...',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimer(_seconds),
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withOpacity(0.12),
                    minimumSize: const Size(56, 56),
                  ),
                  icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 28),
                  tooltip: 'Cancel',
                  onPressed: _cancelRecording,
                ),
                // Send
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    minimumSize: const Size(64, 64),
                  ),
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 30),
                  tooltip: 'Send Voice Note',
                  onPressed: _sendVoiceNote,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
