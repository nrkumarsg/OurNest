import 'package:flutter_test/flutter_test.dart';
import 'package:our_nest/features/family/domain/family_member_model.dart';
import 'package:our_nest/features/family/domain/family_model.dart';
import 'package:our_nest/features/family/domain/relation_type.dart';
import 'package:our_nest/features/family/presentation/widgets/family_qr_scanner_modal.dart';
import 'package:our_nest/features/profile/domain/profile_model.dart';

void main() {
  group('Family - Domain Models & Permissions', () {
    test('RelationType correctly formats standard and custom labels', () {
      expect(RelationType.father.label, equals('Father'));
      expect(RelationType.father.displayString(null), contains('Father'));

      expect(
        RelationType.other.displayString('Godmother'),
        equals('👤 Godmother'),
      );

      // Parsing string fallback
      expect(RelationType.fromString('mother'), equals(RelationType.mother));
      expect(RelationType.fromString('unknown_role'), equals(RelationType.other));
    });

    test('Family serialization round-trip', () {
      final now = DateTime.now();
      final family = Family(
        id: 'fam-uuid-1',
        name: 'The Sharma Family',
        inviteCode: 'SHRM92',
        createdBy: 'usr-1',
        createdAt: now,
      );

      final json = family.toJson();
      expect(json['id'], equals('fam-uuid-1'));
      expect(json['name'], equals('The Sharma Family'));
      expect(json['invite_code'], equals('SHRM92'));

      final fromJson = Family.fromJson({
        ...json,
        'created_at': now.toIso8601String(),
      });
      expect(fromJson.name, equals(family.name));
      expect(fromJson.inviteCode, equals('SHRM92'));
    });

    test('FamilyMember role and status accessors', () {
      final adminMember = FamilyMember(
        familyId: 'fam-1',
        userId: 'usr-1',
        relation: 'father',
        role: 'admin',
        status: 'active',
        createdAt: DateTime.now(),
        profile: Profile(
          id: 'usr-1',
          displayName: 'Papa',
          createdAt: DateTime.now(),
        ),
      );

      expect(adminMember.isAdmin, isTrue);
      expect(adminMember.isActive, isTrue);
      expect(adminMember.isPending, isFalse);
      expect(adminMember.displayName, equals('Papa'));

      final pendingMember = FamilyMember(
        familyId: 'fam-1',
        userId: 'usr-2',
        relation: 'son',
        role: 'member',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      expect(pendingMember.isAdmin, isFalse);
      expect(pendingMember.isActive, isFalse);
      expect(pendingMember.isPending, isTrue);
      expect(pendingMember.formattedRelation, contains('Son'));
    });

    test('Invite codes conform to 6-character unambiguous pattern', () {
      const validCode = 'SHRM92';
      expect(validCode.length, equals(6));
      expect(validCode, matches(RegExp(r'^[A-Z0-9]{6}$')));
    });

    test('QR invite payload builder and parser round-trip all formats', () {
      final family = Family(
        id: 'fam-1',
        name: 'N.R.K Family',
        inviteCode: 'FMS258',
        createdBy: 'usr-1',
        createdAt: DateTime.now(),
      );

      final qrData = buildFamilyQrData(family);
      final parsedUri = parseInviteQrPayload(qrData);
      expect(parsedUri, isNotNull);
      expect(parsedUri!.code, equals('FMS258'));
      expect(parsedUri.familyName, equals('N.R.K Family'));

      final parsedPlain = parseInviteQrPayload('fms258');
      expect(parsedPlain?.code, equals('FMS258'));

      final parsedLegacy = parseInviteQrPayload('ournest://invite/FMS258');
      expect(parsedLegacy?.code, equals('FMS258'));

      final parsedSharedText = parseInviteQrPayload(
          'Join our family circle on OurNest! Use code: FMS258');
      expect(parsedSharedText?.code, equals('FMS258'));
    });
  });
}
