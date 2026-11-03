import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/features/alarm/domain/alarm_time_parser.dart';
import 'package:our_nest/features/alarm/domain/shared_alarm_model.dart';

void main() {
  group('Shared Alarm - NLP Intent Detection', () {
    final fixedNow = DateTime(2026, 11, 2, 14, 0); // 2:00 PM

    test('Detects "Amma, wake me up 8am"', () {
      final result = AlarmTimeParser.detectAlarmIntent(
        'Amma, wake me up 8am please',
        referenceTime: fixedNow,
      );

      expect(result, isNotNull);
      expect(result!.formattedTime.replaceAll('\u202F', ' '), equals('8:00 AM'));
      expect(result.targetTime.hour, equals(8));
      expect(result.targetTime.minute, equals(0));
      // Since 8am has passed today at 2pm, it should schedule for tomorrow
      expect(result.targetTime.day, equals(3));
    });

    test('Detects "wake me up at 8:30 pm"', () {
      final result = AlarmTimeParser.detectAlarmIntent(
        'Can someone wake me up at 8:30 pm today',
        referenceTime: fixedNow,
      );

      expect(result, isNotNull);
      expect(result!.formattedTime.replaceAll('\u202F', ' '), equals('8:30 PM'));
      expect(result.targetTime.hour, equals(20));
      expect(result.targetTime.minute, equals(30));
      expect(result.targetTime.day, equals(2));
    });

    test('Detects "alarm for 6 o\'clock tomorrow"', () {
      final result = AlarmTimeParser.detectAlarmIntent(
        'set an alarm for 6 o\'clock tomorrow',
        referenceTime: fixedNow,
      );

      expect(result, isNotNull);
      expect(result!.targetTime.hour, equals(6));
      expect(result.targetTime.day, equals(3));
    });

    test('Returns null for ordinary conversational text without time intent', () {
      final result = AlarmTimeParser.detectAlarmIntent(
        'What are we having for dinner tonight?',
        referenceTime: fixedNow,
      );

      expect(result, isNull);
    });
  });

  group('Shared Alarm - Domain Models & Escalation', () {
    test('Calculates escalation time correctly based on escalateAfterMin', () {
      final alarmTime = DateTime(2026, 11, 3, 8, 0);
      final alarm = SharedAlarm(
        alarmId: 'alm-1',
        time: alarmTime,
        label: 'Wake-up for Rahul',
        ownerId: 'son-id',
        ownerName: 'Rahul',
        participants: ['son-id', 'mother-id'],
        escalateAfterMin: 5,
      );

      expect(alarm.escalationTime, equals(DateTime(2026, 11, 3, 8, 5)));
      expect(alarm.isOwner('son-id'), isTrue);
      expect(alarm.isOwner('mother-id'), isFalse);
      expect(alarm.isParticipant('mother-id'), isTrue);
    });

    test('Alarm status transitions and serialization', () {
      final alarm = SharedAlarm(
        alarmId: 'alm-2',
        time: DateTime.now(),
        label: 'Papa Medicine',
        ownerId: 'father-id',
        participants: ['father-id', 'daughter-id'],
      );

      final json = alarm.toJson();
      expect(json['status'], equals('active'));

      final acknowledged = alarm.copyWith(
        status: AlarmStatus.acknowledged,
        acknowledgedAt: DateTime.now(),
      );
      expect(acknowledged.status, equals(AlarmStatus.acknowledged));
      expect(acknowledged.acknowledgedAt, isNotNull);
    });
  });
}
