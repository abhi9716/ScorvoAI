import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scorvoai/data/exam_taxonomy.dart';

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String exam;
  final List<String> goals;
  final DateTime createdAt;
  final bool onboardingComplete;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.exam,
    required this.goals,
    required this.createdAt,
    required this.onboardingComplete,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photo_url'] as String? ?? '',
      exam: map['exam'] as String? ?? 'SSC',
      goals: List<String>.from(map['goals'] as List? ?? []),
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      onboardingComplete: map['onboarding_complete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'photo_url': photoUrl,
    'exam': exam,
    'goals': goals,
    'created_at': Timestamp.fromDate(createdAt),
    'onboarding_complete': onboardingComplete,
  };

  UserProfile copyWith({
    String? name,
    String? exam,
    List<String>? goals,
    bool? onboardingComplete,
  }) => UserProfile(
    uid: uid,
    name: name ?? this.name,
    email: email,
    photoUrl: photoUrl,
    exam: exam ?? this.exam,
    goals: goals ?? this.goals,
    createdAt: createdAt,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
  );

  String get examLabel {
    // New taxonomy ids first
    final ex = findExam(exam);
    if (ex != null) return ex.shortName;
    // Legacy fallback
    switch (exam) {
      case 'SSC': return 'SSC CGL / CHSL';
      case 'UPSC': return 'UPSC Civil Services';
      case 'Banking': return 'Banking PO / Clerk';
      case 'State': return 'State PCS / PSC';
      case 'Railway': return 'Railway RRB / NTPC';
      default: return exam;
    }
  }

  String get firstName => name.split(' ').first;
}
