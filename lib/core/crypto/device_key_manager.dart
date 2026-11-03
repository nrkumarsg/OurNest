import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sodium_libs/sodium_libs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/supabase_client.dart';
import 'crypto_service.dart';

final deviceKeyManagerProvider = Provider<DeviceKeyManager>((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  final client = ref.watch(supabaseClientProvider);
  return DeviceKeyManager(crypto, client);
});

class DeviceKeyManager {
  static const _kPrivateKeyStorageKey = 'ournest_device_private_key_v1';
  static const _kPublicKeyStorageKey = 'ournest_device_public_key_v1';
  static const _kDeviceIdStorageKey = 'ournest_device_id_v1';

  final CryptoService _crypto;
  final SupabaseClient _client;
  final FlutterSecureStorage _storage;

  String? _deviceId;
  Uint8List? _publicKey;
  SecureKey? _secretKey;

  DeviceKeyManager(this._crypto, this._client)
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  String? get currentDeviceId => _deviceId;
  Uint8List? get currentPublicKey => _publicKey;
  SecureKey? get currentSecretKey => _secretKey;

  /// Ensures a valid X25519 key pair exists for this device, and is registered in Supabase.
  Future<void> ensureDeviceKeys() async {
    await _crypto.init();

    final storedPubKeyB64 = await _storage.read(key: _kPublicKeyStorageKey);
    final storedPrivKeyB64 = await _storage.read(key: _kPrivateKeyStorageKey);
    final storedDeviceId = await _storage.read(key: _kDeviceIdStorageKey);

    if (storedPubKeyB64 != null && storedPrivKeyB64 != null && storedDeviceId != null) {
      _publicKey = base64Decode(storedPubKeyB64);
      final privBytes = base64Decode(storedPrivKeyB64);
      _secretKey = SecureKey.fromList(_crypto.sodium, privBytes);
      _deviceId = storedDeviceId;
      return;
    }

    // Otherwise generate fresh X25519 keypair
    final keypair = _crypto.generateDeviceKeyPair();
    _publicKey = keypair.publicKey;
    _secretKey = keypair.secretKey;

    final pubKeyB64 = base64Encode(_publicKey!);
    final privKeyB64 = base64Encode(keypair.secretKey.extractBytes());

    // Register with Supabase user_devices
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be logged in to register device keys.');
    }

    final platformStr =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

    final insertRes = await _client
        .from('user_devices')
        .insert({
          'user_id': userId,
          'public_key': pubKeyB64,
          'platform': platformStr,
        })
        .select('id')
        .single();

    _deviceId = insertRes['id'] as String;

    // Persist securely
    await _storage.write(key: _kPublicKeyStorageKey, value: pubKeyB64);
    await _storage.write(key: _kPrivateKeyStorageKey, value: privKeyB64);
    await _storage.write(key: _kDeviceIdStorageKey, value: _deviceId);
  }
}
