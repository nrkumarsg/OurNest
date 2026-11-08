/// Standard family relation categories supported by OurNest.
/// Section 4: "father, mother, son, daughter, grandfather, grandmother,
/// brother, sister, uncle, aunt, nephew, niece, cousin, grandson, granddaughter,
/// brotherInLaw, sisterInLaw, sonInLaw, daughterInLaw, fatherInLaw, motherInLaw,
/// spouse, other (with a custom label)."
enum RelationType {
  father('Father', '👨'),
  mother('Mother', '👩'),
  son('Son', '👦'),
  daughter('Daughter', '👧'),
  grandfather('Grandfather', '👴'),
  grandmother('Grandmother', '👵'),
  brother('Brother', '👱‍♂️'),
  sister('Sister', '👱‍♀️'),
  uncle('Uncle', '🧔'),
  aunt('Aunt', '🧕'),
  nephew('Nephew', '👦'),
  niece('Niece', '👧'),
  cousin('Cousin', '🧑'),
  grandson('Grandson', '🧒'),
  granddaughter('Granddaughter', '👧'),
  sonInLaw('Son-in-Law', '🤵'),
  daughterInLaw('Daughter-in-Law', '👰'),
  brotherInLaw('Brother-in-Law', '🧔‍♂️'),
  sisterInLaw('Sister-in-Law', '👩'),
  fatherInLaw('Father-in-Law', '👴'),
  motherInLaw('Mother-in-Law', '👵'),
  spouse('Spouse', '💍'),
  other('Other', '👤');

  final String label;
  final String emoji;

  const RelationType(this.label, this.emoji);

  static RelationType fromString(String value) {
    return RelationType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RelationType.other,
    );
  }

  String displayString(String? customLabel) {
    if (this == RelationType.other && customLabel != null && customLabel.trim().isNotEmpty) {
      return '$emoji $customLabel';
    }
    return '$emoji $label';
  }
}
