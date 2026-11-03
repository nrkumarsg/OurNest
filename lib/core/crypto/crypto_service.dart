import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium_libs/sodium_libs.dart';

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

class CryptoKeyPair {
  final Uint8List publicKey;
  final Uint8List secretKey;

  const CryptoKeyPair({
    required this.publicKey,
    required this.secretKey,
  });

  String get publicKeyBase64 => base64Encode(publicKey);
  String get secretKeyBase64 => base64Encode(secretKey);
}

class EncryptedPayload {
  final String ciphertextBase64;
  final String nonceBase64;
  final Uint8List rawMessageKey;

  const EncryptedPayload({
    required this.ciphertextBase64,
    required this.nonceBase64,
    required this.rawMessageKey,
  });
}

class CryptoService {
  Sodium? _sodium;

  bool get isInitialized => _sodium != null;

  Future<void> init() async {
    if (_sodium != null) return;
    _sodium = await SodiumInit.init();
  }

  Sodium get _sodiumInstance {
    if (_sodium == null) {
      throw StateError('CryptoService must be initialized before use. Call init() first.');
    }
    return _sodium!;
  }

  Sodium get sodium => _sodiumInstance;

  /// Generates a new X25519 key pair for device-level encryption.
  KeyPair generateDeviceKeyPair() {
    return _sodiumInstance.crypto.box.keyPair();
  }

  /// Generates a random 32-byte symmetric message key for XChaCha20-Poly1305
  SecureKey generateMessageKey() {
    return _sodiumInstance.crypto.aeadXChaCha20Poly1305IETF.keygen();
  }

  /// Encrypts a plaintext JSON string with XChaCha20-Poly1305 using a random nonce.
  EncryptedPayload encryptMessagePayload({
    required String jsonPlaintext,
    SecureKey? existingKey,
  }) {
    final sodium = _sodiumInstance;
    final messageKey = existingKey ?? sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    final nonce = sodium.randombytes.buf(sodium.crypto.aeadXChaCha20Poly1305IETF.nonceBytes);

    final plaintextBytes = Uint8List.fromList(utf8.encode(jsonPlaintext));

    final ciphertext = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: plaintextBytes,
      nonce: nonce,
      key: messageKey,
    );

    return EncryptedPayload(
      ciphertextBase64: base64Encode(ciphertext),
      nonceBase64: base64Encode(nonce),
      rawMessageKey: messageKey.extractBytes(),
    );
  }

  /// Decrypts a ciphertext with XChaCha20-Poly1305 given the nonce and 32-byte message key.
  String decryptMessagePayload({
    required String ciphertextBase64,
    required String nonceBase64,
    required Uint8List messageKeyBytes,
  }) {
    final sodium = _sodiumInstance;
    final ciphertext = base64Decode(ciphertextBase64);
    final nonce = base64Decode(nonceBase64);
    final key = SecureKey.fromList(sodium, messageKeyBytes);

    final decrypted = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: ciphertext,
      nonce: nonce,
      key: key,
    );

    return utf8.decode(decrypted);
  }

  /// Locks (seals) a 32-byte message key for a specific recipient device's X25519 public key.
  /// Uses crypto_box_seal (anonymous public key encryption).
  String sealMessageKey({
    required Uint8List messageKeyBytes,
    required String recipientPublicKeyBase64,
  }) {
    final sodium = _sodiumInstance;
    final recipientPubKey = base64Decode(recipientPublicKeyBase64);

    final sealed = sodium.crypto.box.seal(
      message: messageKeyBytes,
      publicKey: recipientPubKey,
    );

    return base64Encode(sealed);
  }

  /// Opens (unseals) a sealed message key using the recipient device's X25519 key pair.
  Uint8List openSealedMessageKey({
    required String lockedKeyBase64,
    required Uint8List devicePublicKey,
    required SecureKey deviceSecretKey,
  }) {
    final sodium = _sodiumInstance;
    final sealedBytes = base64Decode(lockedKeyBase64);

    final unsealed = sodium.crypto.box.sealOpen(
      cipherText: sealedBytes,
      publicKey: devicePublicKey,
      secretKey: deviceSecretKey,
    );

    return Uint8List.fromList(unsealed);
  }
}
