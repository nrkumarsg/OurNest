import 'package:intl/intl.dart';

class ParsedAlarmIntent {
  final DateTime targetTime;
  final String formattedTime;
  final String matchedText;

  const ParsedAlarmIntent({
    required this.targetTime,
    required this.formattedTime,
    required this.matchedText,
  });
}

class AlarmTimeParser {
  /// Regular expression patterns for wake-up and alarm intent detection
  static final List<RegExp> _intentPatterns = [
    // "wake me up at 8am", "wake me up 8:30 pm", "wake up 7 am tomorrow"
    RegExp(
      r'(?:wake\s*(?:me\s*)?up(?:\s*at)?|alarm(?:\s*for|\s*at)?)\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)(?:\s*(tomorrow|today))?',
      caseSensitive: false,
    ),
    // "8 o'clock tomorrow", "6 oclock"
    RegExp(
      r"(\d{1,2})\s*o\s*'?\s*clock(?:\s*(tomorrow|today))?",
      caseSensitive: false,
    ),
    // Direct time phrases like "at 8:30 am", "at 7pm"
    RegExp(
      r'\bat\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm))\b',
      caseSensitive: false,
    ),
  ];

  /// Parses text locally without contacting any server
  static ParsedAlarmIntent? detectAlarmIntent(String text, {DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();

    for (final reg in _intentPatterns) {
      final match = reg.firstMatch(text.toLowerCase());
      if (match != null) {
        final timeStr = match.group(1)?.trim();
        final dayModifier = match.groupCount >= 2 ? match.group(2)?.trim() : null;

        if (timeStr != null) {
          final parsed = _parseTimeString(timeStr, now, dayModifier: dayModifier);
          if (parsed != null) {
            return ParsedAlarmIntent(
              targetTime: parsed,
              formattedTime: DateFormat.jm().format(parsed),
              matchedText: match.group(0) ?? '',
            );
          }
        }
      }
    }
    return null;
  }

  static DateTime? _parseTimeString(String raw, DateTime now, {String? dayModifier}) {
    String clean = raw.replaceAll(' ', '').toLowerCase();
    int hour = 0;
    int minute = 0;
    bool hasAmPm = clean.contains('am') || clean.contains('pm');
    bool isPm = clean.contains('pm');

    clean = clean.replaceAll('am', '').replaceAll('pm', '');

    if (clean.contains(':')) {
      final parts = clean.split(':');
      hour = int.tryParse(parts[0]) ?? 0;
      minute = int.tryParse(parts[1]) ?? 0;
    } else {
      hour = int.tryParse(clean) ?? 0;
      minute = 0;
    }

    if (hour < 1 || hour > 24 || minute < 0 || minute > 59) {
      return null;
    }

    if (hasAmPm) {
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
    } else {
      // If no AM/PM specified, default to upcoming morning or evening
      if (hour < 12 && now.hour >= 12 && (now.hour - 12) >= hour) {
        // e.g. it's 2pm and user says "wake me up 8", likely means 8am tomorrow
      }
    }

    var target = DateTime(now.year, now.month, now.day, hour, minute);

    if (dayModifier == 'tomorrow') {
      target = target.add(const Duration(days: 1));
    } else if (target.isBefore(now)) {
      // If time has already passed today, assume tomorrow
      target = target.add(const Duration(days: 1));
    }

    return target;
  }
}
