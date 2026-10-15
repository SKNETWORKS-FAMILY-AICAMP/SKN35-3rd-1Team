import 'models.dart';

/// Another member as shown in follow lists. `id` is the opaque public id.
class MemberCard {
  const MemberCard({required this.id, required this.nickname});
  final String id, nickname;
  factory MemberCard.fromJson(Json j) =>
      MemberCard(id: text(j['id']), nickname: text(j['nickname'], '감상가'));
}

/// Public profile header. Counts are null when the member hides follow lists.
class PublicMember extends MemberCard {
  const PublicMember({
    required super.id,
    required super.nickname,
    this.intro,
    this.followerCount,
    this.followingCount,
    this.followListPublic = true,
    this.isFollowing = false,
    this.isMe = false,
  });
  final String? intro;
  final int? followerCount, followingCount;
  final bool followListPublic, isFollowing, isMe;
  factory PublicMember.fromJson(Json j) => PublicMember(
    id: text(j['id']),
    nickname: text(j['nickname'], '감상가'),
    intro: j['intro'] as String?,
    followerCount: (j['follower_count'] as num?)?.toInt(),
    followingCount: (j['following_count'] as num?)?.toInt(),
    followListPublic: j['follow_list_public'] != false,
    isFollowing: j['is_following'] == true,
    isMe: j['is_me'] == true,
  );
  PublicMember copyWith({
    String? intro,
    int? followerCount,
    bool? followListPublic,
    bool? isFollowing,
  }) => PublicMember(
    id: id,
    nickname: nickname,
    intro: intro ?? this.intro,
    followerCount: followerCount ?? this.followerCount,
    followingCount: followingCount,
    followListPublic: followListPublic ?? this.followListPublic,
    isFollowing: isFollowing ?? this.isFollowing,
    isMe: isMe,
  );
}
