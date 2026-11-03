import 'package:intl/intl.dart';

class FamilyReminder {
  final String reminderId;
  final String title;
  final DateTime eventDateTime;
  final String createdById;
  final String createdByName;
  final List<String> targetMemberIds;
  final String? notes;
  final bool isCompleted;

  const FamilyReminder({
    required this.reminderId,
    required this.title,
    required this.eventDateTime,
    required this.createdById,
    required this.createdByName,
    required this.targetMemberIds,
    this.notes,
    this.isCompleted = false,
  });

  String get formattedDate => DateFormat('EEE, MMM d, y').format(eventDateTime);
  String get formattedTime => DateFormat.jm().format(eventDateTime);

  factory FamilyReminder.fromJson(Map<String, dynamic> json) {
    return FamilyReminder(
      reminderId: json['reminder_id'] as String,
      title: json['title'] as String,
      eventDateTime: DateTime.parse(json['event_date_time'] as String),
      createdById: json['created_by_id'] as String,
      createdByName: json['created_by_name'] as String? ?? 'Family Member',
      targetMemberIds: (json['target_member_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      notes: json['notes'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'reminder_id': reminderId,
        'title': title,
        'event_date_time': eventDateTime.toIso8601String(),
        'created_by_id': createdById,
        'created_by_name': createdByName,
        'target_member_ids': targetMemberIds,
        if (notes != null) 'notes': notes,
        'is_completed': isCompleted,
      };

  FamilyReminder copyWith({
    String? title,
    DateTime? eventDateTime,
    String? notes,
    bool? isCompleted,
  }) {
    return FamilyReminder(
      reminderId: reminderId,
      title: title ?? this.title,
      eventDateTime: eventDateTime ?? this.eventDateTime,
      createdById: createdById,
      createdByName: createdByName,
      targetMemberIds: targetMemberIds,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
