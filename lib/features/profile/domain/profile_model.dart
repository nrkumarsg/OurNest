import 'dart:convert';
import 'package:intl/intl.dart';

class Profile {
  final String id;
  final String displayName;
  final String? phone;
  final String? whatsappNumber;
  final String? avatarUrl;
  final String? sex; // 'Male', 'Female', 'Other'
  final DateTime? dateOfBirth;
  final String? bloodGroup;
  final String? education;
  final String? occupation;
  final String? workingPlace;
  final String? workingDetails;
  final String? livingPlace;
  final String? homeAddress;
  final String? city;
  final String? statusText;
  final String? bioDescription;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.displayName,
    this.phone,
    this.whatsappNumber,
    this.avatarUrl,
    this.sex,
    this.dateOfBirth,
    this.bloodGroup,
    this.education,
    this.occupation,
    this.workingPlace,
    this.workingDetails,
    this.livingPlace,
    this.homeAddress,
    this.city,
    this.statusText,
    this.bioDescription,
    required this.createdAt,
  });

  /// Calculates current age in years from dateOfBirth.
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years >= 0 ? years : null;
  }

  /// Calculates how many days until this person's next birthday (0 = Today!).
  int? get daysUntilNextBirthday {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var nextBday = DateTime(now.year, dateOfBirth!.month, dateOfBirth!.day);
    if (nextBday.isBefore(today)) {
      nextBday = DateTime(now.year + 1, dateOfBirth!.month, dateOfBirth!.day);
    }
    return nextBday.difference(today).inDays;
  }

  bool get isBirthdayToday => daysUntilNextBirthday == 0;

  bool get isBirthdaySoon {
    final days = daysUntilNextBirthday;
    return days != null && days <= 30;
  }

  String? get formattedDob {
    if (dateOfBirth == null) return null;
    return DateFormat('d MMM yyyy').format(dateOfBirth!);
  }

  String? get formattedBirthdayShort {
    if (dateOfBirth == null) return null;
    return DateFormat('MMM d').format(dateOfBirth!);
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    String? rawAvatar = json['avatar_url'] as String?;
    Map<String, dynamic>? embeddedMeta;

    if (rawAvatar != null && rawAvatar.startsWith('ournest_meta:')) {
      try {
        final decoded = utf8.decode(
            base64Decode(rawAvatar.substring('ournest_meta:'.length)));
        embeddedMeta = jsonDecode(decoded) as Map<String, dynamic>;
        rawAvatar = embeddedMeta['avatar_url'] as String?;
      } catch (_) {}
    }

    final dobString = (json['date_of_birth'] as String?) ??
        (embeddedMeta?['date_of_birth'] as String?);
    DateTime? parsedDob;
    if (dobString != null && dobString.isNotEmpty) {
      parsedDob = DateTime.tryParse(dobString);
    }

    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '',
      phone: (json['phone'] as String?) ?? (embeddedMeta?['phone'] as String?),
      whatsappNumber: (json['whatsapp_number'] as String?) ??
          (embeddedMeta?['whatsapp_number'] as String?),
      avatarUrl: rawAvatar,
      sex: (json['sex'] as String?) ?? (embeddedMeta?['sex'] as String?),
      dateOfBirth: parsedDob,
      bloodGroup: (json['blood_group'] as String?) ??
          (embeddedMeta?['blood_group'] as String?),
      education: (json['education'] as String?) ??
          (embeddedMeta?['education'] as String?),
      occupation: (json['occupation'] as String?) ??
          (embeddedMeta?['occupation'] as String?),
      workingPlace: (json['working_place'] as String?) ??
          (embeddedMeta?['working_place'] as String?),
      workingDetails: (json['working_details'] as String?) ??
          (embeddedMeta?['working_details'] as String?),
      livingPlace: (json['living_place'] as String?) ??
          (embeddedMeta?['living_place'] as String?),
      homeAddress: (json['home_address'] as String?) ??
          (embeddedMeta?['home_address'] as String?),
      city: (json['city'] as String?) ?? (embeddedMeta?['city'] as String?),
      statusText: (json['status_text'] as String?) ??
          (embeddedMeta?['status_text'] as String?),
      bioDescription: (json['bio_description'] as String?) ??
          (embeddedMeta?['bio_description'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'phone': phone,
      if (whatsappNumber != null) 'whatsapp_number': whatsappNumber,
      'avatar_url': avatarUrl,
      if (sex != null) 'sex': sex,
      if (dateOfBirth != null)
        'date_of_birth': DateFormat('yyyy-MM-dd').format(dateOfBirth!),
      if (bloodGroup != null) 'blood_group': bloodGroup,
      if (education != null) 'education': education,
      if (occupation != null) 'occupation': occupation,
      if (workingPlace != null) 'working_place': workingPlace,
      if (workingDetails != null) 'working_details': workingDetails,
      if (livingPlace != null) 'living_place': livingPlace,
      if (homeAddress != null) 'home_address': homeAddress,
      if (city != null) 'city': city,
      if (statusText != null) 'status_text': statusText,
      if (bioDescription != null) 'bio_description': bioDescription,
    };
  }

  /// Fallback serializer that packs extended profile fields safely into `avatar_url`
  /// if the remote Supabase instance hasn't applied migration 20261103000004 yet.
  Map<String, dynamic> toFallbackCoreJson({bool includePhoneColumn = true}) {
    final metaMap = {
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (phone != null) 'phone': phone,
      if (whatsappNumber != null) 'whatsapp_number': whatsappNumber,
      if (sex != null) 'sex': sex,
      if (dateOfBirth != null)
        'date_of_birth': DateFormat('yyyy-MM-dd').format(dateOfBirth!),
      if (bloodGroup != null) 'blood_group': bloodGroup,
      if (education != null) 'education': education,
      if (occupation != null) 'occupation': occupation,
      if (workingPlace != null) 'working_place': workingPlace,
      if (workingDetails != null) 'working_details': workingDetails,
      if (livingPlace != null) 'living_place': livingPlace,
      if (homeAddress != null) 'home_address': homeAddress,
      if (city != null) 'city': city,
      if (statusText != null) 'status_text': statusText,
      if (bioDescription != null) 'bio_description': bioDescription,
    };

    final encodedMeta = metaMap.isNotEmpty
        ? 'ournest_meta:${base64Encode(utf8.encode(jsonEncode(metaMap)))}'
        : avatarUrl;

    return {
      'id': id,
      'display_name': displayName,
      'phone': includePhoneColumn ? phone : null,
      'avatar_url': encodedMeta,
    };
  }

  Profile copyWith({
    String? displayName,
    String? phone,
    String? whatsappNumber,
    String? avatarUrl,
    String? sex,
    DateTime? dateOfBirth,
    String? bloodGroup,
    String? education,
    String? occupation,
    String? workingPlace,
    String? workingDetails,
    String? livingPlace,
    String? homeAddress,
    String? city,
    String? statusText,
    String? bioDescription,
  }) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      sex: sex ?? this.sex,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      education: education ?? this.education,
      occupation: occupation ?? this.occupation,
      workingPlace: workingPlace ?? this.workingPlace,
      workingDetails: workingDetails ?? this.workingDetails,
      livingPlace: livingPlace ?? this.livingPlace,
      homeAddress: homeAddress ?? this.homeAddress,
      city: city ?? this.city,
      statusText: statusText ?? this.statusText,
      bioDescription: bioDescription ?? this.bioDescription,
      createdAt: createdAt,
    );
  }
}
