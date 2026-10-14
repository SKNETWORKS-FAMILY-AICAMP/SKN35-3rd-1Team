import 'models.dart';

class MemberProfile {
  const MemberProfile({
    this.ageRange,
    this.gender,
    this.explanationStyle = 'standard',
    this.birthDate,
    this.onboardingCompleted = true,
    this.nickname = '',
  });
  // Version 1 demographics stay local until a user explicitly saves new settings.
  static const ages = <String, String>{
    'under_20': '20세 미만',
    '20s': '20대',
    '30s': '30대',
    '40s': '40대',
    '50s': '50대',
    '60_plus': '60대 이상',
  };
  static const genders = <String, String>{
    'female': '여성',
    'male': '남성',
    'other': '기타',
  };
  static const styles = <String, String>{
    'easy': '편안하고 쉬운 대화',
    'standard': '편안하고 쉬운 대화',
    'deep': '전문용어 적극 사용',
  };
  final String? ageRange, gender, birthDate;
  final String explanationStyle, nickname;
  final bool onboardingCompleted;
  String get conversationStyle =>
      explanationStyle == 'deep' ? 'professional' : 'easy';
  Json toServerJson() => {
    'birth_date': birthDate,
    'conversation_style': conversationStyle,
    'onboarding_completed': onboardingCompleted,
  };
  Json toJson() => {
    'version': 2,
    'age_range': ageRange,
    'gender': gender,
    'explanation_style': explanationStyle,
    ...toServerJson(),
    'nickname': nickname,
  };
  factory MemberProfile.fromServer(Json j) => MemberProfile(
    birthDate: j['birth_date'] as String?,
    explanationStyle: j['conversation_style'] == 'professional'
        ? 'deep'
        : 'easy',
    onboardingCompleted: j['onboarding_completed'] == true,
    nickname: text(j['nickname']),
  );
  factory MemberProfile.fromJson(Json j) {
    if (![1, 2].contains(j['version']) ||
        (j['age_range'] != null && !ages.containsKey(j['age_range'])) ||
        (j['gender'] != null && !genders.containsKey(j['gender'])) ||
        !styles.containsKey(j['explanation_style'])) {
      throw const FormatException('프로필 형식을 확인해 주세요.');
    }
    if (j['version'] == 1) {
      return MemberProfile(
        ageRange: j['age_range'] as String?,
        gender: j['gender'] as String?,
        explanationStyle: j['explanation_style'] as String,
      );
    }
    final p = MemberProfile.fromServer(j);
    return MemberProfile(
      ageRange: j['age_range'] as String?,
      gender: j['gender'] as String?,
      birthDate: p.birthDate,
      explanationStyle: j['explanation_style'] as String,
      onboardingCompleted: p.onboardingCompleted,
      nickname: p.nickname,
    );
  }
}
