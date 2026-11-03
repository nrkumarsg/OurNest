import 'dart:convert';
import 'package:intl/intl.dart';

enum AlarmStatus {
  active,
  acknowledged, // Owner tapped "I'm awake"
  snoozed,
  escalated,   // Owner didn't wake up -> escalation ringing on participants
  cancelled;

  static AlarmStatus fromString(String val) {
    switch (val) {
      case 'acknowledged':
        return AlarmStatus.acknowledged;
      case 'snoozed':
        return AlarmStatus.snoozed;
      case 'escalated':
        return AlarmStatus.escalated;
      case 'cancelled':
        return AlarmStatus.cancelled;
      default:
        return AlarmStatus.active;
    }
  }
}

class SharedAlarm {
  final String alarmId;
  final DateTime time;
  final String label;
  final String ownerId;
  final String? ownerName;
  final List<String> participants;
  final int escalateAfterMin;
  final AlarmStatus status;
  final DateTime? acknowledgedAt;

  const SharedAlarm({
    required this.alarmId,
    required this.time,
    required this.label,
    required this.ownerId,
    this.ownerName,
    required this.participants,
    this.escalateAfterMin = 5,
    this.status = AlarmStatus.active,
    this.acknowledgedAt,
  });

  DateTime get escalationTime => time.add(Duration(minutes: escalateAfterMin));
  String get formattedTime => DateFormat.jm().format(time);
  String get formattedDate => DateFormat('EEE, MMM d').format(time);

  bool isOwner(String currentUserId) => ownerId == currentUserId;
  bool isParticipant(String currentUserId) => participants.contains(currentUserId);

  factory SharedAlarm.fromJson(Map<String, dynamic> json) {
    return SharedAlarm(
      alarmId: json['alarm_id'] as String,
      time: DateTime.parse(json['time'] as String),
      label: json['label'] as String? ?? 'Shared Alarm',
      ownerId: json['owner_id'] as String,
      ownerName: json['owner_name'] as String?,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      escalateAfterMin: json['escalate_after_min'] as int? ?? 5,
      status: AlarmStatus.fromString(json['status'] as String? ?? 'active'),
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'alarm_id': alarmId,
        'time': time.toIso8601String(),
        'label': label,
        'owner_id': ownerId,
        if (ownerName != null) 'owner_name': ownerName,
        'participants': participants,
        'escalate_after_min': escalateAfterMin,
        'status': status.name,
        if (acknowledgedAt != null) 'acknowledged_at': acknowledgedAt!.toIso8601String(),
      };

  SharedAlarm copyWith({
    DateTime? time,
    String? label,
    List<String>? participants,
    int? escalateAfterMin,
    AlarmStatus? status,
    DateTime? acknowledgedAt,
  }) {
    return SharedAlarm(
      alarmId: alarmId,
      time: time ?? this.time,
      label: label ?? this.label,
      ownerId: ownerId,
      ownerName: ownerName,
      participants: participants ?? this.participants,
      escalateAfterMin: escalateAfterMin ?? this.escalateAfterMin,
      status: status ?? this.status,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }
}
