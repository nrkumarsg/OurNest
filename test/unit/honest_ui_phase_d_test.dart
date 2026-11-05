import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/core/constants/app_version.dart';
import 'package:our_nest/features/alarm/domain/alarm_event_payload.dart';
import 'package:our_nest/features/alarm/domain/shared_alarm_model.dart';
import 'package:our_nest/features/alarm/presentation/alarm_status_provider.dart';
import 'package:our_nest/features/chat/domain/chat_message_model.dart';
import 'package:our_nest/features/chat/domain/message_payload.dart';
import 'package:our_nest/features/family/data/family_repository.dart';
import 'package:our_nest/features/family/domain/family_member_model.dart';
import 'package:our_nest/features/profile/data/profile_repository.dart';

FamilyMember _member(String family, String status, DateTime created) =>
    FamilyMember.fromJson({
      'family_id': family,
      'user_id': 'me',
      'relation': 'son',
      'role': 'member',
      'status': status,
      'created_at': created.toIso8601String(),
    });

ChatMessage _event(String alarmId, AlarmEventType type, int minute) {
  final event = AlarmEventPayload(
    alarmId: alarmId,
    eventType: type,
    senderId: 'kid',
    timestamp: DateTime.utc(2030, 1, 1, 7, minute),
  );
  return ChatMessage(
    id: 'm$minute',
    familyId: 'f',
    senderId: 'kid',
    type: MessageType.alarmEvent,
    audience: MessageAudience.all,
    plaintext: MessagePayload(text: 'x', alarmMeta: event.toJson()).toEncodedJson(),
    isMine: false,
    createdAt: DateTime.utc(2030, 1, 1, 7, minute),
  );
}

void main() {
  group('F13 – more than one membership no longer locks the user out', () {
    test('active membership is preferred over pending', () {
      final picked = FamilyRepository.pickPrimaryMembership([
        _member('pending-fam', 'pending', DateTime.utc(2026, 1, 1)),
        _member('active-fam', 'active', DateTime.utc(2026, 6, 1)),
      ]);
      expect(picked!.familyId, 'active-fam');
    });

    test('oldest wins when both have the same status', () {
      final picked = FamilyRepository.pickPrimaryMembership([
        _member('newer', 'active', DateTime.utc(2026, 6, 1)),
        _member('older', 'active', DateTime.utc(2026, 1, 1)),
      ]);
      expect(picked!.familyId, 'older');
    });

    test('no memberships gives null', () {
      expect(FamilyRepository.pickPrimaryMembership([]), isNull);
    });

    test('lookup no longer uses maybeSingle()', () {
      final src = File('lib/features/family/data/family_repository.dart')
          .readAsStringSync();
      final method = src.substring(src.indexOf('getCurrentUserMembership() async'),
          src.indexOf('static FamilyMember? pickPrimaryMembership'));
      expect(method.contains('.maybeSingle()'), isFalse);
    });
  });

  group('F07 / U19 – no fake links or hidden local overrides', () {
    late String repo;
    setUpAll(() => repo =
        File('lib/features/family/data/family_repository.dart').readAsStringSync());

    test('fake fallback state is gone', () {
      expect(repo.contains('_localFallbackLinks'), isFalse);
      expect(repo.contains('_peaceOverrides'), isFalse);
      expect(repo.contains("status: 'active',"), isFalse);
    });

    test('"0 rows changed" (blocked by RLS) is reported as an error', () {
      expect(() => FamilyRepository.expectChanged([], 'not allowed'),
          throwsA(isA<StateError>()));
      FamilyRepository.expectChanged([
        {'id': 'x'}
      ], 'not allowed');
    });

    test('linked family names come from the secure RPC', () {
      expect(repo, contains("'get_linked_family_names'"));
      final sql = File(
              'supabase/migrations/20261105000008_linked_names_and_applicants.sql')
          .readAsStringSync();
      expect(sql, contains('is_active_member(my_family_id)'));
      expect(sql.contains('invite_code'), isFalse,
          reason: 'other families\' invite codes must stay private');
    });
  });

  group('F08 – broadcast wording is honest', () {
    test('no "delivered" claim for connected families', () {
      // The family screen is split into part files (F39); read all of them.
      final ui = [
        'family_screen.dart',
        'family_screen_link_sheets.dart',
        'family_screen_tabs.dart',
      ]
          .map((f) =>
              File('lib/features/family/presentation/$f').readAsStringSync())
          .join('\n');
      expect(ui.contains('Broadcast delivered to'), isFalse);
      expect(ui, contains("Connected families don\\'t receive broadcasts yet"));
      expect(ui, contains('Unlink this family?'));
    });
  });

  group('F09 – reminder button really schedules', () {
    test('reminder card calls the scheduler', () {
      final card = File(
              'lib/features/reminder/presentation/widgets/reminder_card.dart')
          .readAsStringSync();
      expect(card, contains('scheduleReminder('));
      expect(card.contains('Add to My Device Calendar'), isFalse);
    });
  });

  group('F10 – profile save errors are real', () {
    test('fallback that pretended to save is gone', () {
      final src = File('lib/features/profile/data/profile_repository.dart')
          .readAsStringSync();
      expect(src.contains('return profile;'), isFalse);
    });

    test('friendly error messages', () {
      expect(
          ProfileRepository.friendlyProfileError(
              '23505', 'duplicate key value violates unique constraint "profiles_phone_key"'),
          contains('phone number is already used'));
      expect(ProfileRepository.friendlyProfileError(null, 'boom'),
          contains('Could not save'));
    });
  });

  group('F17 – admins can see who is asking to join', () {
    test('policy lets an active admin read pending applicant profiles', () {
      final sql = File(
              'supabase/migrations/20261105000008_linked_names_and_applicants.sql')
          .readAsStringSync();
      expect(sql, contains("app.status = 'pending'"));
      expect(sql, contains("adm.role = 'admin'"));
      expect(sql, contains("adm.status = 'active'"));
    });
  });

  group('Alarm card follows "I\'m awake" / cancel events', () {
    test('later events win', () {
      final status = alarmStatusFromMessages([
        _event('a1', AlarmEventType.ack, 1),
        _event('a2', AlarmEventType.cancel, 2),
      ]);
      expect(status['a1'], AlarmStatus.acknowledged);
      expect(status['a2'], AlarmStatus.cancelled);
      expect(status.containsKey('a3'), isFalse);
    });
  });

  group('F35 – settings shows real values', () {
    test('no hardcoded version or "ready" permission text', () {
      final src = File('lib/features/settings/presentation/settings_screen.dart')
          .readAsStringSync();
      expect(src.contains('v1.2.1 (Build 4)'), isFalse);
      expect(src.contains('Exact alarms ready for shared wake-up'), isFalse);
      expect(src, contains('appVersionLabel'));
    });

    test('version constant matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'^version:\s*([0-9.]+)\+([0-9]+)', multiLine: true)
          .firstMatch(pubspec)!;
      expect(appVersionName, m.group(1),
          reason: 'update lib/core/constants/app_version.dart');
      expect(appBuildNumber, m.group(2),
          reason: 'update lib/core/constants/app_version.dart');
    });
  });
}
