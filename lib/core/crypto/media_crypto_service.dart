import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium_libs/sodium_libs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/supabase_client.dart';
import 'crypto_service.dart';

final mediaCryptoServiceProvider = Provider<MediaCryptoService>((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  final client = ref.watch(supabaseClientProvider);
  return MediaCryptoService(crypto, client);
});

class EncryptedMediaResult {
  final String storagePath;
  final String fileKeyBase64;
  final String fileNonceBase64;
  final int fileSizeBytes;
  final int? durationMs;

  const EncryptedMediaResult({
    required this.storagePath,
    required this.fileKeyBase64,
    required this.fileNonceBase64,
    required this.fileSizeBytes,
    this.durationMs,
  });

  Map<String, dynamic> toJson() => {
        'storage_path': storagePath,
        'file_key': fileKeyBase64,
        'file_nonce': fileNonceBase64,
        'file_size': fileSizeBytes,
        if (durationMs != null) 'duration_ms': durationMs,
      };
}

class MediaCryptoService {
  final CryptoService _crypto;
  final SupabaseClient _client;
  final Map<String, Uint8List> _decryptedCache = {};

  MediaCryptoService(this._crypto, this._client);

  /// Drops decrypted photos / voice notes held in memory (called on sign-out).
  void clearCache() => _decryptedCache.clear();

  /// Encrypts local raw file bytes and uploads the ciphertext to private Supabase Storage
  Future<EncryptedMediaResult> encryptAndUploadMedia({
    required String familyId,
    required Uint8List rawBytes,
    required String fileExtension,
    int? durationMs,
  }) async {
    await _crypto.init();

    // 1. Generate random 32-byte media key and random nonce
    final mediaKey = _crypto.generateMessageKey();
    final nonce = _crypto.sodium.randombytes
        .buf(_crypto.sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes);

    // 2. Encrypt bytes with XChaCha20-Poly1305
    final ciphertext = _crypto.sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: rawBytes,
      nonce: nonce,
      key: mediaKey,
    );

    // 3. Upload to private Supabase bucket: media/{family_id}/{uuid}
    final fileId = DateTime.now().millisecondsSinceEpoch.toString();
    final storagePath = '$familyId/$fileId.$fileExtension.enc';

    await _client.storage.from('media').uploadBinary(
          storagePath,
          ciphertext,
          fileOptions: const FileOptions(contentType: 'application/octet-stream'),
        );

    _decryptedCache[storagePath] = rawBytes;

    return EncryptedMediaResult(
      storagePath: storagePath,
      fileKeyBase64: base64Encode(mediaKey.extractBytes()),
      fileNonceBase64: base64Encode(nonce),
      fileSizeBytes: rawBytes.length,
      durationMs: durationMs,
    );
  }

  /// Downloads encrypted bytes from Supabase Storage and decrypts them in-memory across all platforms
  Future<Uint8List> downloadAndDecryptMediaBytes({
    required String storagePath,
    required String fileKeyBase64,
    required String fileNonceBase64,
    required String fileExtension,
  }) async {
    if (_decryptedCache.containsKey(storagePath)) {
      return _decryptedCache[storagePath]!;
    }

    await _crypto.init();

    // 1. Download ciphertext from private Supabase Storage
    final encryptedBytes =
        await _client.storage.from('media').download(storagePath);

    // 2. Decrypt on-device with the unpacked key and nonce
    final mediaKeyBytes = base64Decode(fileKeyBase64);
    final nonce = base64Decode(fileNonceBase64);
    final key = SecureKey.fromList(_crypto.sodium, mediaKeyBytes);

    final decrypted = _crypto.sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: encryptedBytes,
      nonce: nonce,
      key: key,
    );

    final bytes = Uint8List.fromList(decrypted);
    _decryptedCache[storagePath] = bytes;
    return bytes;
  }
}
