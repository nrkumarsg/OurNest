import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/features/reminder/domain/family_reminder_model.dart';

void main() {
  group('Family Reminders & Calendar Events', () {
    test('FamilyReminder serializes and deserializes correctly', () {
      final eventTime = DateTime(2026, 11, 8, 16, 0); // Sun, Nov 8, 4:00 PM
      final reminder = FamilyReminder(
        reminderId: 'rem-101',
        title: 'Grandma Doctor Appointment',
        eventDateTime: eventTime,
        createdById: 'father-uid',
        createdByName: 'Papa',
        targetMemberIds: ['mother-uid', 'grandma-uid'],
        notes: 'Bring previous prescription and blood test reports',
      );

      final json = reminder.toJson();
      expect(json['reminder_id'], equals('rem-101'));
      expect(json['title'], equals('Grandma Doctor Appointment'));
      expect(json['created_by_name'], equals('Papa'));
      expect(json['target_member_ids'], contains('grandma-uid'));

      final fromJson = FamilyReminder.fromJson(json);
      expect(fromJson.title, equals(reminder.title));
      expect(fromJson.formattedTime.replaceAll('\u202F', ' '), equals('4:00 PM'));
      expect(fromJson.formattedDate, contains('Nov 8'));
      expect(fromJson.notes, contains('prescription'));
    });

    test('Reminder supports targeting all or individual members', () {
      final allReminder = FamilyReminder(
        reminderId: 'rem-102',
        title: 'Sunday Family Dinner',
        eventDateTime: DateTime(2026, 11, 8, 19, 0),
        createdById: 'father-uid',
        createdByName: 'Papa',
        targetMemberIds: ['all'],
      );

      expect(allReminder.targetMemberIds.length, equals(1));
      expect(allReminder.targetMemberIds.first, equals('all'));
    });
  });
}
