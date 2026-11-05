/// Rules for which chat thread a message belongs to (audit F22).
///
/// * Family thread: messages to everyone, plus "selected members" messages
///   that went to a group (3+ people incl. sender).
/// * Direct thread with X: "selected" messages whose recipients are exactly
///   {me, X}.
///
/// [recipientIds] is the comma separated list stored locally. It is empty for
/// messages received from older app versions; those fall back to the old
/// sender-based rule so they don't disappear.
class ThreadFilter {
  ThreadFilter._();

  static Set<String> parseRecipients(String? csv) {
    if (csv == null || csv.trim().isEmpty) return <String>{};
    return csv
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  static bool belongsInFamilyThread({
    required String audience,
    required String? recipientIds,
  }) {
    if (audience != 'selected') return true;
    return parseRecipients(recipientIds).length > 2;
  }

  static bool belongsInDirectThread({
    required String audience,
    required String senderId,
    required String? recipientIds,
    required String myUserId,
    required String otherUserId,
  }) {
    if (audience != 'selected') return false;
    final recipients = parseRecipients(recipientIds);
    if (recipients.isEmpty) {
      // Legacy message without a recipient list: only trust "they sent it to me".
      return senderId == otherUserId;
    }
    return recipients.length == 2 &&
        recipients.contains(myUserId) &&
        recipients.contains(otherUserId);
  }
}
