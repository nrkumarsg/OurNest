import '../../profile/domain/profile_model.dart';
import 'relation_type.dart';

class FamilyMember {
  final String familyId;
  final String userId;
  final String relation;
  final String? relationLabel;
  final String role; // 'admin' | 'member'
  final String status; // 'pending' | 'active'
  final DateTime createdAt;
  final Profile? profile;

  const FamilyMember({
    required this.familyId,
    required this.userId,
    required this.relation,
    this.relationLabel,
    required this.role,
    required this.status,
    required this.createdAt,
    this.profile,
  });

  bool get isAdmin => role == 'admin';
  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';

  RelationType get relationType => RelationType.fromString(relation);

  String get formattedRelation => relationType.displayString(relationLabel);

  String get displayName => profile?.displayName ?? 'Family Member';

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      relation: json['relation'] as String,
      relationLabel: json['relation_label'] as String?,
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      profile: json['profiles'] != null
          ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'family_id': familyId,
      'user_id': userId,
      'relation': relation,
      'relation_label': relationLabel,
      'role': role,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  FamilyMember copyWith({
    String? relation,
    String? relationLabel,
    String? role,
    String? status,
    Profile? profile,
  }) {
    return FamilyMember(
      familyId: familyId,
      userId: userId,
      relation: relation ?? this.relation,
      relationLabel: relationLabel ?? this.relationLabel,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
      profile: profile ?? this.profile,
    );
  }
}
