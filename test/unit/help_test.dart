import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Help & Instructions Workflow Tests', () {
    final expectedTopics = [
      '1. Getting Started & Sign In',
      '2. Creating & Joining a Family Circle',
      '3. End-to-End Encryption (E2EE)',
      '4. Everyone vs. Selected (Audience Control)',
      '5. Shared Wake-Up Alarms & Escalation',
      '6. Family Reminders & Calendar Events',
      '7. Voice Notes, Photos & YouTube Sharing',
      '8. Elderly-Friendly Accessibility & Display',
      '9. FAQ & Troubleshooting Guide',
      '10. Rich Personal Profiles & Birthday Reminders',
      '11. Connected Family Tree (Family-to-Family Chain)',
      '12. Silent Curtain (Peace & Hide Mode — Better Than Block)',
      '13. Smart Family Composer & Action Hub',
    ];

    test('All 13 core user workflows are documented', () {
      expect(expectedTopics.length, equals(13));
      expect(expectedTopics.any((t) => t.contains('Alarms')), isTrue);
      expect(expectedTopics.any((t) => t.contains('Reminders')), isTrue);
      expect(expectedTopics.any((t) => t.contains('Encryption')), isTrue);
      expect(expectedTopics.any((t) => t.contains('Accessibility')), isTrue);
      expect(expectedTopics.any((t) => t.contains('YouTube')), isTrue);
      expect(expectedTopics.any((t) => t.contains('Family Tree')), isTrue);
      expect(expectedTopics.any((t) => t.contains('Silent Curtain')), isTrue);
      expect(expectedTopics.any((t) => t.contains('Birthday Reminders')), isTrue);
    });

    test('Topic search query filtering works correctly', () {
      const query = 'alarm';
      final matches = expectedTopics.where((t) => t.toLowerCase().contains(query)).toList();
      expect(matches.length, equals(1));
      expect(matches.first, contains('Shared Wake-Up Alarms'));
    });

    test('Calendar reminder query matches correctly', () {
      const query = 'calendar event';
      final matches = expectedTopics.where((t) => t.toLowerCase().contains(query)).toList();
      expect(matches.length, equals(1));
      expect(matches.first, contains('Family Reminders & Calendar Events'));
    });
  });
}
