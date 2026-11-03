import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/crypto/media_crypto_service.dart';

class VoiceNotePlayer extends ConsumerStatefulWidget {
  final Map<String, dynamic> mediaMeta;
  final bool isMine;

  const VoiceNotePlayer({
    super.key,
    required this.mediaMeta,
    required this.isMine,
  });

  @override
  ConsumerState<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends ConsumerState<VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;
  Uint8List? _decryptedAudioBytes;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _playerState = PlayerState.stopped;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }

    if (_decryptedAudioBytes == null) {
      setState(() => _isLoading = true);
      try {
        final storagePath = widget.mediaMeta['storage_path'] as String;
        final fileKey = widget.mediaMeta['file_key'] as String;
        final fileNonce = widget.mediaMeta['file_nonce'] as String;

        final mediaService = ref.read(mediaCryptoServiceProvider);
        final bytes = await mediaService.downloadAndDecryptMediaBytes(
          storagePath: storagePath,
          fileKeyBase64: fileKey,
          fileNonceBase64: fileNonce,
          fileExtension: 'm4a',
        );

        _decryptedAudioBytes = bytes;
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      setState(() => _isLoading = false);
    }

    if (_decryptedAudioBytes != null) {
      await _player.play(BytesSource(_decryptedAudioBytes!));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final textColor = widget.isMine ? Colors.white : AppColors.textPrimaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 34,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: _isLoading
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isMine ? Colors.white : AppColors.primaryTeal,
                      ),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: widget.isMine ? Colors.white : AppColors.primaryTeal,
                  ),
            onPressed: _isLoading ? null : _togglePlay,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    thumbColor: widget.isMine ? Colors.white : AppColors.primaryTeal,
                    activeTrackColor: widget.isMine ? Colors.white : AppColors.primaryTeal,
                    inactiveTrackColor: widget.isMine
                        ? Colors.white.withOpacity(0.3)
                        : AppColors.dividerLight,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble().clamp(
                          0.0,
                          _duration.inMilliseconds > 0
                              ? _duration.inMilliseconds.toDouble()
                              : 1.0,
                        ),
                    max: _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    onChanged: (val) {
                      _player.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textColor.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
