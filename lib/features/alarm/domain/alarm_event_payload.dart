enum AlarmEventType {
  create,
  ack,      // Owner tapped "I'm awake"
  snooze,   // Owner snoozed
  cancel,   // Cancelled
  update;   // Edited time / label

  static AlarmEventType fromString(String val) {
    switch (val) {
      case 'ack':
        return AlarmEventType.ack;
      case 'snooze':
        return AlarmEventType.snooze;
      case 'cancel':
        return AlarmEventType.cancel;
      case 'update':
        return AlarmEventType.update;
      default:
        return AlarmEventType.create;
    }
  }
}

class AlarmEventPayload {
  final String alarmId;
  final AlarmEventType eventType;
  final String senderId;
  final DateTime timestamp;
  final Map<String, dynamic>? updatedAlarmData;

  const AlarmEventPayload({
    required this.alarmId,
    required this.eventType,
    required this.senderId,
    required this.timestamp,
    this.updatedAlarmData,
  });

  factory AlarmEventPayload.fromJson(Map<String, dynamic> json) {
    return AlarmEventPayload(
      alarmId: json['alarm_id'] as String,
      eventType: AlarmEventType.fromString(json['event_type'] as String),
      senderId: json['sender_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      updatedAlarmData: json['updated_alarm_data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'alarm_id': alarmId,
        'event_type': eventType.name,
        'sender_id': senderId,
        'timestamp': timestamp.toIso8601String(),
        if (updatedAlarmData != null) 'updated_alarm_data': updatedAlarmData,
      };
}
