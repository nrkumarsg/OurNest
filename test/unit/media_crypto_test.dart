import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/core/crypto/media_crypto_service.dart';
import 'package:our_nest/features/chat/domain/message_payload.dart';

void main() {
  group('Media & Voice Notes - Serialization & Encryption Meta', () {
    test('EncryptedMediaResult correctly serializes all necessary decryption metadata', () {
      const result = EncryptedMediaResult(
        storagePath: 'fam-123/voice_note_1.m4a.enc',
        fileKeyBase64: 'fake_media_key_base64==',
        fileNonceBase64: 'fake_media_nonce_base64==',
        fileSizeBytes: 65536,
        durationMs: 14200,
      );

      final json = result.toJson();
      expect(json['storage_path'], equals('fam-123/voice_note_1.m4a.enc'));
      expect(json['file_key'], equals('fake_media_key_base64=='));
      expect(json['file_nonce'], equals('fake_media_nonce_base64=='));
      expect(json['file_size'], equals(65536));
      expect(json['duration_ms'], equals(14200));
    });

    test('MessagePayload correctly embeds and preserves encrypted media metadata', () {
      final mediaMeta = {
        'storage_path': 'fam-456/photo_holiday.jpg.enc',
        'file_key': 'key_b64==',
        'file_nonce': 'nonce_b64==',
        'file_size': 1048576,
      };

      final payload = MessagePayload(
        text: 'Look at this photo from yesterday!',
        mediaMeta: mediaMeta,
      );

      final encoded = payload.toEncodedJson();
      final decoded = MessagePayload.fromDecryptedJson(encoded);

      expect(decoded.text, equals('Look at this photo from yesterday!'));
      expect(decoded.mediaMeta, isNotNull);
      expect(decoded.mediaMeta!['storage_path'], equals('fam-456/photo_holiday.jpg.enc'));
      expect(decoded.mediaMeta!['file_key'], equals('key_b64=='));
    });
  });
}
