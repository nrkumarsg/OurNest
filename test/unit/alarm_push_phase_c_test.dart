import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/core/notifications/push_service.dart';
import 'package:our_nest/core/platform/alarm_scheduler_service.dart';
import 'package:our_nest/features/alarm/data/alarm_coordinator.dart';
import 'package:our_nest/features/alarm/domain/alarm_event_payload.dart';
import 'package:our_nest/features/alarm/domain/shared_alarm_model.dart';
import 'package:our_nest/features/chat/domain/message_payload.dart';

SharedAlarm _alarm({AlarmStatus status = AlarmStatus.active}) => SharedAlarm(
      alarmId: 'a1',
      time: DateTime.utc(2030, 1, 1, 7),
      label: 'School',
      ownerId: 'kid',
      ownerName: 'Kid',
      participants: const ['kid', 'amma'],
      escalateAfterMin: 5,
      status: status,
    );

String _plain({Map<String, dynamic>? alarmMeta}) =>
    MessagePayload(text: 'x', alarmMeta: alarmMeta).toEncodedJson();

void main() {
  group('F05 – alarms react to messages on every device', () {
    test('alarm message schedules the alarm', () {
      final action = AlarmCoordinator.decide(
          messageType: 'alarm', plaintext: _plain(alarmMeta: _alarm().toJson()));
      expect(action, isA<ScheduleAlarmAction>());
      expect((action as ScheduleAlarmAction).alarm.alarmId, 'a1');
    });

    test('"I am awake" ack cancels the escalation', () {
      final ack = AlarmEventPayload(
        alarmId: 'a1',
        eventType: AlarmEventType.ack,
        senderId: 'kid',
        timestamp: DateTime.utc(2030, 1, 1, 7, 1),
      );
      final action = AlarmCoordinator.decide(
          messageType: 'alarm_event', plaintext: _plain(alarmMeta: ack.toJson()));
      expect(action, isA<CancelAlarmAction>());
      expect((action as CancelAlarmAction).alarmId, 'a1');
    });

    test('owner cancel event cancels everywhere', () {
      final cancel = AlarmEventPayload(
        alarmId: 'a1',
        eventType: AlarmEventType.cancel,
        senderId: 'kid',
        timestamp: DateTime.utc(2030),
      );
      expect(
          AlarmCoordinator.decide(
              messageType: 'alarm_event',
              plaintext: _plain(alarmMeta: cancel.toJson())),
          isA<CancelAlarmAction>());
    });

    test('ordinary messages, reminders and junk do nothing', () {
      expect(AlarmCoordinator.decide(messageType: 'text', plaintext: _plain()),
          isA<NoAlarmAction>());
      expect(
          AlarmCoordinator.decide(
              messageType: 'alarm',
              plaintext: _plain(alarmMeta: {'reminder_id': 'r1'})),
          isA<NoAlarmAction>());
      expect(
          AlarmCoordinator.decide(
              messageType: 'alarm', plaintext: _plain(alarmMeta: {'bad': true})),
          isA<NoAlarmAction>());
    });

    test('already acknowledged alarm is cancelled, not scheduled', () {
      final action = AlarmCoordinator.decide(
          messageType: 'alarm',
          plaintext:
              _plain(alarmMeta: _alarm(status: AlarmStatus.acknowledged).toJson()));
      expect(action, isA<CancelAlarmAction>());
    });

    test('chat sync hands every stored message to the coordinator', () {
      final src = File('lib/features/chat/data/chat_repository.dart')
          .readAsStringSync();
      expect(src, contains('alarmCoordinatorProvider'));
      expect(src, contains('onMessageStored('));
    });
  });

  group('Alarm notifications', () {
    test('notification ids are stable and distinct', () {
      expect(AlarmSchedulerService.ringId('a1'),
          AlarmSchedulerService.ringId('a1'));
      expect(AlarmSchedulerService.ringId('a1'),
          isNot(AlarmSchedulerService.escalationId('a1')));
      // Known FNV-1a value so the id never silently changes between versions.
      expect(AlarmSchedulerService.stableId(''), 0x811c9dc5 & 0x7FFFFFFF);
      expect(AlarmSchedulerService.stableId('ring:a1'), greaterThanOrEqualTo(0));
    });

    test('tap payload round-trips the alarm and keeps the lock-screen prefix',
        () {
      final payload =
          AlarmSchedulerService.buildPayload(alarm: _alarm(), escalation: true);
      expect(payload, startsWith('alarm_escalate:a1|'));
      final tap = AlarmSchedulerService.parsePayload(payload)!;
      expect(tap.isEscalation, isTrue);
      expect(tap.alarm.label, 'School');
      expect(tap.alarm.participants, ['kid', 'amma']);

      final ring =
          AlarmSchedulerService.buildPayload(alarm: _alarm(), escalation: false);
      expect(ring, startsWith('alarm_ring:'));
      expect(AlarmSchedulerService.parsePayload(ring)!.isEscalation, isFalse);
    });

    test('non-alarm or broken payloads are ignored', () {
      expect(AlarmSchedulerService.parsePayload('chat:fam'), isNull);
      expect(AlarmSchedulerService.parsePayload('alarm_ring:a1'), isNull);
      expect(
          AlarmSchedulerService.parsePayload(
              'alarm_ring:a1|${base64Url.encode(utf8.encode("not json"))}'),
          isNull);
      expect(AlarmSchedulerService.parsePayload(null), isNull);
    });
  });

  group('F06 – Android alarm plumbing', () {
    late String manifest;
    setUpAll(() => manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync());

    test('scheduled-notification receivers are declared', () {
      expect(manifest, contains('ScheduledNotificationReceiver'));
      expect(manifest, contains('ScheduledNotificationBootReceiver'));
      expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    });

    test('notifications plugin is initialised at startup', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('LocalNotifications.ensureInitialized()'));
    });
  });

  group('F04 – push notifications', () {
    test('push text never contains message content', () {
      final t = pushNotificationText({
        'sender_name': 'Amma',
        'message_type': 'text',
        'message_id': 'm1',
      });
      expect(t.title, 'Amma');
      expect(t.body, 'New message');
      expect(pushNotificationText({'message_type': 'alarm'}).body,
          contains('alarm'));
      expect(pushNotificationText({}).title, 'OurNest');
    });

    test('push is off (not crashing) when Firebase is not configured', () {
      // Tests run without --dart-define, so config must be absent.
      expect(FirebaseConfig.isConfigured, isFalse);
    });

    test('edge function uses FCM HTTP v1 and checks the webhook secret', () {
      final fn = File('supabase/functions/push-dispatcher/index.ts')
          .readAsStringSync();
      expect(fn, contains('fcm.googleapis.com/v1/projects/'));
      expect(fn.contains('fcm.googleapis.com/fcm/send'), isFalse);
      expect(fn, contains('x-webhook-secret'));
      expect(fn.contains('ciphertext'), isFalse);
    });

    test('database trigger calls the function without message content', () {
      final sql = File('supabase/migrations/20261105000007_push_webhook.sql')
          .readAsStringSync();
      expect(sql, contains('after insert on public.messages'));
      expect(sql, contains("vault.decrypted_secrets"));
      expect(sql.contains("'ciphertext', new.ciphertext"), isFalse);
    });
  });
}
