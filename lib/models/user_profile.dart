import 'dart:convert';
import '../core/constants/app_constants.dart';

class UserProfile {
  final String id;
  final String serviceId;
  final String fullName;
  final String rank;
  final String unit;
  final UserRole role;
  final String? phone;
  final String? avatarUrl;
  final int streakCount;
  final int readinessScore;
  final String stressZone;
  final Map<String, dynamic> consentSettings;

  UserProfile({
    required this.id,
    required this.serviceId,
    required this.fullName,
    required this.rank,
    required this.unit,
    required this.role,
    this.phone,
    this.avatarUrl,
    this.streakCount = 3,
    this.readinessScore = 88,
    this.stressZone = 'Zone A',
    Map<String, dynamic>? consentSettings,
  }) : consentSettings = consentSettings ?? {
          'mandatory_hr_sync': true,
          'optional_wearable_sync': false,
          'companion_memory': true,
          'anonymized_research': true,
        };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? 'user-demo-1',
      serviceId: json['service_id'] as String? ?? 'CAPF-8821',
      fullName: json['full_name'] as String? ?? 'Constable Dhruv',
      rank: json['rank'] as String? ?? 'Constable',
      unit: json['unit'] as String? ?? '144th Bn CAPF',
      role: UserRole.fromString(json['role'] as String?),
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      streakCount: json['streak_count'] as int? ?? 3,
      readinessScore: json['readiness_score'] as int? ?? 88,
      stressZone: json['stress_zone'] as String? ?? 'Zone A',
      consentSettings: json['consent_settings'] != null
          ? (json['consent_settings'] is String
              ? jsonDecode(json['consent_settings'] as String)
              : Map<String, dynamic>.from(json['consent_settings'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_id': serviceId,
      'full_name': fullName,
      'rank': rank,
      'unit': unit,
      'role': role.toDbValue(),
      'phone': phone,
      'avatar_url': avatarUrl,
      'streak_count': streakCount,
      'readiness_score': readinessScore,
      'stress_zone': stressZone,
      'consent_settings': consentSettings,
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? rank,
    String? unit,
    int? streakCount,
    int? readinessScore,
    String? stressZone,
    Map<String, dynamic>? consentSettings,
  }) {
    return UserProfile(
      id: id,
      serviceId: serviceId,
      fullName: fullName ?? this.fullName,
      rank: rank ?? this.rank,
      unit: unit ?? this.unit,
      role: role,
      phone: phone,
      avatarUrl: avatarUrl,
      streakCount: streakCount ?? this.streakCount,
      readinessScore: readinessScore ?? this.readinessScore,
      stressZone: stressZone ?? this.stressZone,
      consentSettings: consentSettings ?? this.consentSettings,
    );
  }

  // Pre-configured Test Personas
  static final UserProfile dhruvPersonnel = UserProfile(
    id: 'usr-dhruv-8821',
    serviceId: 'CAPF-8821',
    fullName: 'Constable Dhruv',
    rank: 'Constable',
    unit: '144th Bn CAPF',
    role: UserRole.personnel,
    phone: '+91 98765 88214',
    streakCount: 3,
    readinessScore: 88,
    stressZone: 'Zone A',
  );

  static final UserProfile sharmaHrAdmin = UserProfile(
    id: 'usr-sharma-hr',
    serviceId: 'HR-ADMIN-01',
    fullName: 'Inspector Sharma',
    rank: 'Inspector (HR)',
    unit: 'Sector HQ HR Cell',
    role: UserRole.hrAdmin,
    phone: '+91 98111 22334',
    streakCount: 12,
    readinessScore: 92,
    stressZone: 'Optimal',
  );

  static final UserProfile ananyaWelfare = UserProfile(
    id: 'usr-ananya-wo',
    serviceId: 'WELFARE-07',
    fullName: 'Dr. Ananya Varma',
    rank: 'Clinical Welfare Officer',
    unit: 'Medical & Psychological Wing',
    role: UserRole.welfareOfficer,
    phone: '+91 99222 33445',
    streakCount: 20,
    readinessScore: 95,
    stressZone: 'Optimal',
  );

  static final UserProfile raoCommander = UserProfile(
    id: 'usr-rao-cmd',
    serviceId: 'CMD-UNIT-42',
    fullName: 'Col. Rajesh Rao',
    rank: 'Commandant',
    unit: 'Northern Frontier Command',
    role: UserRole.commander,
    phone: '+91 97333 44556',
    streakCount: 15,
    readinessScore: 90,
    stressZone: 'Optimal',
  );
}
