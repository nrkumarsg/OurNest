import 'dart:convert';
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

/// Builds the secure-storage key names for one user.
///
/// Keys are scoped per user so that when a second person signs in on the same
/// phone they never reuse the first person's device identity (audit F11).
@visibleForTesting
class DeviceKeyStorageNames {
  final String privateKey;
  final String publicKey;
  final String deviceId;

  DeviceKeyStorageNames.forUser(String userId)
      : privateKey = 'ournest_device_private_key_v2_$userId',
        publicKey = 'ournest_device_public_key_v2_$userId',
        deviceId = 'ournest_device_id_v2_$userId';
}

class DeviceKeyManager {
  // Legacy (v1) names were shared by every user of the device.
  static const _kLegacyPrivateKey = 'ournest_device_private_key_v1';
  static const _kLegacyPublicKey = 'ournest_device_public_key_v1';
  static const _kLegacyDeviceId = 'ournest_device_id_v1';

  final CryptoService _crypto;
  final SupabaseClient _client;
  final FlutterSecureStorage _storage;

  String? _userId;
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

  /// Ensures a valid X25519 key pair exists for this device AND the signed-in
  /// user, and is registered in Supabase.
  Future<void> ensureDeviceKeys() async {
    await _crypto.init();

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      clearInMemory();
      throw StateError('User must be logged in to register device keys.');
    }

    // Already loaded for this user in this session.
    if (_userId == userId && _deviceId != null && _secretKey != null) return;
    clearInMemory();

    final names = DeviceKeyStorageNames.forUser(userId);
    await _migrateLegacyKeysIfOwned(userId, names);

    final storedPubKeyB64 = await _storage.read(key: names.publicKey);
    final storedPrivKeyB64 = await _storage.read(key: names.privateKey);
    final storedDeviceId = await _storage.read(key: names.deviceId);

    if (storedPubKeyB64 != null &&
        storedPrivKeyB64 != null &&
        storedDeviceId != null) {
      _publicKey = base64Decode(storedPubKeyB64);
      _secretKey =
          SecureKey.fromList(_crypto.sodium, base64Decode(storedPrivKeyB64));
      _deviceId = storedDeviceId;
      _userId = userId;
      return;
    }

    // Otherwise generate a fresh X25519 keypair for this user on this device.
    final keypair = _crypto.generateDeviceKeyPair();
    final pubKeyB64 = base64Encode(keypair.publicKey);
    final privKeyB64 = base64Encode(keypair.secretKey.extractBytes());

    final deviceId = await _registerDevice(userId, pubKeyB64);

    // Persist securely before using, so a crash can't leave a half state.
    await _storage.write(key: names.publicKey, value: pubKeyB64);
    await _storage.write(key: names.privateKey, value: privKeyB64);
    await _storage.write(key: names.deviceId, value: deviceId);

    _publicKey = keypair.publicKey;
    _secretKey = keypair.secretKey;
    _deviceId = deviceId;
    _userId = userId;
  }

  /// The real platform (audit F40: web, Windows, macOS and Linux used to be
  /// recorded as 'android').
  @visibleForTesting
  static String platformName({required bool isWeb, required TargetPlatform platform}) {
    if (isWeb) return 'web';
    switch (platform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'android';
    }
  }

  Future<String> _registerDevice(String userId, String pubKeyB64) async {
    Future<String> insert(String platform) async {
      final res = await _client
          .from('user_devices')
          .insert({
            'user_id': userId,
            'public_key': pubKeyB64,
            'platform': platform,
          })
          .select('id')
          .single();
      return res['id'] as String;
    }

    final platform =
        platformName(isWeb: kIsWeb, platform: defaultTargetPlatform);
    try {
      return await insert(platform);
    } on PostgrestException catch (e) {
      // Migration 20261105000010 not applied yet: the old check constraint
      // only allows android/ios. Register anyway rather than break chat.
      if (e.code == '23514' && platform != 'android' && platform != 'ios') {
        return insert('android');
      }
      rethrow;
    }
  }

  /// Moves v1 (shared) keys into the current user's scope, but only if the
  /// stored device row really belongs to this user. Otherwise the legacy keys
  /// belonged to someone else and are deleted.
  Future<void> _migrateLegacyKeysIfOwned(
      String userId, DeviceKeyStorageNames names) async {
    final legacyDeviceId = await _storage.read(key: _kLegacyDeviceId);
    if (legacyDeviceId == null) return;

    final legacyPub = await _storage.read(key: _kLegacyPublicKey);
    final legacyPriv = await _storage.read(key: _kLegacyPrivateKey);

    bool ownedByUser = false;
    try {
      final row = await _client
          .from('user_devices')
          .select('id')
          .eq('id', legacyDeviceId)
          .eq('user_id', userId)
          .maybeSingle();
      ownedByUser = row != null;
    } catch (_) {
      // Offline: leave legacy keys untouched and try again next time.
      return;
    }

    if (ownedByUser && legacyPub != null && legacyPriv != null) {
      await _storage.write(key: names.publicKey, value: legacyPub);
      await _storage.write(key: names.privateKey, value: legacyPriv);
      await _storage.write(key: names.deviceId, value: legacyDeviceId);
    }

    await _storage.delete(key: _kLegacyPublicKey);
    await _storage.delete(key: _kLegacyPrivateKey);
    await _storage.delete(key: _kLegacyDeviceId);
  }

  /// Forgets the keys held in memory (called on sign-out). The per-user keys
  /// stay in secure storage so the same user can read their messages again
  /// after signing back in; other users can never load them.
  void clearInMemory() {
    _userId = null;
    _deviceId = null;
    _publicKey = null;
    _secretKey?.dispose();
    _secretKey = null;
  }
}
