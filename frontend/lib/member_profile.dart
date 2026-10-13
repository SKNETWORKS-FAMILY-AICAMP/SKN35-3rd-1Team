import 'models.dart';

class MemberProfile {
  const MemberProfile({
    this.ageRange,
    this.gender,
    this.explanationStyle = 'standard',
  });
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
    'easy': '쉽고 친근하게',
    'standard': '차분하고 편안하게',
    'deep': '깊이 있게',
  };
  final String? ageRange, gender;
  final String explanationStyle;
  Json toJson() => {
    'version': 1,
    'age_range': ageRange,
    'gender': gender,
    'explanation_style': explanationStyle,
  };
  factory MemberProfile.fromJson(Json j) {
    if (j['version'] != 1 ||
        (j['age_range'] != null && !ages.containsKey(j['age_range'])) ||
        (j['gender'] != null && !genders.containsKey(j['gender'])) ||
        !styles.containsKey(j['explanation_style'])) {
      throw const FormatException('프로필 형식을 확인해 주세요.');
    }
    return MemberProfile(
      ageRange: j['age_range'] as String?,
      gender: j['gender'] as String?,
      explanationStyle: j['explanation_style'] as String,
    );
  }
}
