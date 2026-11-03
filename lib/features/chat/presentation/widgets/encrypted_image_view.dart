import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/crypto/media_crypto_service.dart';

class EncryptedImageView extends ConsumerStatefulWidget {
  final Map<String, dynamic> mediaMeta;

  const EncryptedImageView({
    super.key,
    required this.mediaMeta,
  });

  @override
  ConsumerState<EncryptedImageView> createState() => _EncryptedImageViewState();
}

class _EncryptedImageViewState extends ConsumerState<EncryptedImageView> {
  Uint8List? _decryptedImageBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final storagePath = widget.mediaMeta['storage_path'] as String;
      final fileKey = widget.mediaMeta['file_key'] as String;
      final fileNonce = widget.mediaMeta['file_nonce'] as String;

      final mediaService = ref.read(mediaCryptoServiceProvider);
      final bytes = await mediaService.downloadAndDecryptMediaBytes(
        storagePath: storagePath,
        fileKeyBase64: fileKey,
        fileNonceBase64: fileNonce,
        fileExtension: 'jpg',
      );

      if (mounted) {
        setState(() {
          _decryptedImageBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _openFullScreen(BuildContext context) {
    if (_decryptedImageBytes == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(_decryptedImageBytes!),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 180,
        width: 220,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_error != null || _decryptedImageBytes == null) {
      return Container(
        height: 120,
        width: 200,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Text('Failed to decrypt image', style: TextStyle(fontSize: 12)),
      );
    }

    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Hero(
          tag: widget.mediaMeta['storage_path'],
          child: Image.memory(
            _decryptedImageBytes!,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
