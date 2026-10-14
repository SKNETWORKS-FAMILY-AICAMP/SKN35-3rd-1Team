part of 'state.dart';

/// Member profiles and follows. The preview keeps one local member, `me`.
extension SocialState on ArtlogState {
  static const demoMemberId = 'me';

  String get _myNickname {
    final name = memberProfile?.nickname ?? '';
    return name.isNotEmpty ? name : '나';
  }

  bool get _demoFollowListPublic =>
      prefs.getBool(_localKey('follow_list_public')) ?? true;

  PublicMember _demoMe() => PublicMember(
    id: demoMemberId,
    nickname: _myNickname,
    followerCount: 0,
    followingCount: 0,
    followListPublic: _demoFollowListPublic,
    isMe: true,
  );

  /// My own header: counts are always visible to the owner.
  Future<PublicMember> mySocial({bool force = false}) async {
    _requireMember();
    if (config.demo) return _demoMe();
    return _cached(
      'social/me/$_identityRevision/$socialRevision',
      api.mySocial,
      force: force,
    );
  }

  Future<PublicMember> setFollowListPublic(bool value) async {
    _requireMember();
    final revision = _identityRevision;
    late PublicMember result;
    if (config.demo) {
      if (!await prefs.setBool(_localKey('follow_list_public'), value)) {
        throw const ApiException('설정을 저장하지 못했어요.');
      }
      result = _demoMe();
    } else {
      result = await api.saveSocial(followListPublic: value);
    }
    _checkMember(revision);
    _socialChanged();
    return result;
  }

  Future<PublicMember> member(String id) async {
    if (config.demo) {
      if (id == demoMemberId && authenticated) return _demoMe();
      throw const ApiException('이용자를 찾을 수 없어요.', status: 404);
    }
    return _cached(
      'social/member/$_identityRevision/$socialRevision/$id',
      () => api.member(id),
      ttl: const Duration(seconds: 30),
    );
  }

  Future<DiaryFeed> memberDiary(String id, {String? cursor}) async {
    if (!config.demo) return api.memberDiary(id, cursor: cursor);
    if (id != demoMemberId) return const DiaryFeed([], null);
    return diaryFeed(cursor: cursor);
  }

  /// Loads my public id and following list once per account.
  Future<void> loadFollowing() {
    if (!authenticated) return Future.value();
    return _followingLoad ??= () async {
      final revision = _identityRevision;
      try {
        final me = await mySocial();
        final rows = config.demo
            ? const <MemberCard>[]
            : await api.memberList(me.id, followers: false);
        if (revision != _identityRevision) return;
        myPublicId = me.id;
        followingMembers = rows.map((m) => m.id).toSet();
        notifyListeners();
      } catch (_) {
        if (revision == _identityRevision) _followingLoad = null;
      }
    }();
  }

  Future<void> followMember(String id, bool enable) async {
    _requireMember();
    if (config.demo) {
      throw const ApiException('미리보기에서는 다른 감상가를 팔로우할 수 없어요.');
    }
    if (!pendingMemberFollows.add(id)) return;
    final revision = _identityRevision;
    notifyListeners();
    try {
      await api.followMember(id, enable);
      _checkMember(revision);
      enable ? followingMembers.add(id) : followingMembers.remove(id);
      _socialChanged();
    } finally {
      if (revision == _identityRevision) {
        pendingMemberFollows.remove(id);
        notifyListeners();
      }
    }
  }

  Future<List<MemberCard>> memberList(
    String id, {
    required bool followers,
  }) async {
    if (config.demo) return const [];
    return api.memberList(id, followers: followers);
  }

  void _socialChanged() {
    ++socialRevision;
    _requests.removeWhere((k, v) => k.startsWith('social/'));
    _requestTimes.removeWhere((k, v) => k.startsWith('social/'));
    notifyListeners();
  }
}
