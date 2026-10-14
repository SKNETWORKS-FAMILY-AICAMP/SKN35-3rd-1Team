import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'auth/auth_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/artlog_api.dart';
import 'config.dart';
import 'models.dart';
import 'member_profile.dart';
import 'diary.dart';
import 'mypage.dart';
import 'social.dart';
part 'state_mypage.dart';
part 'state_social.dart';

class ArtlogState extends ChangeNotifier {
  ArtlogState(
    this.config,
    this.api,
    this.prefs, {
    this.session,
    this.authError,
  }) {
    api.onUnauthorized = () {
      if (session != null) {
        libraryError = '서버에서 로그인 정보를 확인하지 못했어요. 잠시 뒤 다시 시도해 주세요.';
        notifyListeners();
      } else {
        unawaited(logout());
      }
    };
    if (session != null) {
      api.tokenProvider = (refresh) => session!.idToken(forceRefresh: refresh);
      _authSubscription = session!.changes.listen(
        _authChanged,
        onError: (Object e) {
          authError = '로그인 상태를 확인하지 못했어요. 새로고침해 다시 시도해 주세요.';
          notifyListeners();
        },
      );
      _authChanged(session!.user);
    }
  }
  final AuthSession? session;
  String? authError, libraryError;
  StreamSubscription<AuthUser?>? _authSubscription;
  String _uid = '';
  int _identityRevision = 0;
  bool _disposed = false;
  bool authUiOpen = false;
  int diaryRevision = 0, socialRevision = 0;
  // Fixed for this visit so the main banner changes on each new visit only.
  final int heroSeed = Random().nextInt(1 << 30);
  final Map<String, Future<dynamic>> _requests = {};
  final Map<String, DateTime> _requestTimes = {};
  Future<T> _cached<T>(
    String key,
    Future<T> Function() fetch, {
    Duration ttl = const Duration(minutes: 5),
    bool force = false,
  }) {
    if (!force &&
        _requests.containsKey(key) &&
        DateTime.now().difference(_requestTimes[key]!) < ttl) {
      return _requests[key]! as Future<T>;
    }
    if (_requests.length >= 80 && !_requests.containsKey(key)) {
      final oldest = _requests.keys.first;
      _requests.remove(oldest);
      _requestTimes.remove(oldest);
    }
    late final Future<T> pending;
    pending = fetch().catchError((Object error, StackTrace stack) {
      if (identical(_requests[key], pending)) {
        _requests.remove(key);
        _requestTimes.remove(key);
      }
      Error.throwWithStackTrace(error, stack);
    });
    _requests[key] = pending;
    _requestTimes[key] = DateTime.now();
    return pending;
  }

  String get recommendationKey {
    final liked = likes.toList()..sort();
    final followed = follows.toList()..sort();
    return '$_identityRevision/${liked.join(',')}/${followed.join(',')}';
  }

  Future<List<Artwork>> personalArtworks({bool force = false}) => _cached(
    'recommended/works/$recommendationKey',
    api.recommendedArtworks,
    ttl: const Duration(seconds: 30),
    force: force,
  );
  Future<List<Artist>> personalArtists({bool force = false}) => _cached(
    'recommended/artists/$recommendationKey',
    api.recommendedArtists,
    ttl: const Duration(seconds: 30),
    force: force,
  );
  void setAuthUiOpen(bool value) {
    authUiOpen = value;
    notifyListeners();
  }

  MemberProfile? _serverProfile;
  bool profileLoaded = false;
  String? profileError;
  int collectionRevision = 0;
  String get _profileKey => config.firebaseAuth
      ? 'flutter.profile.firebase.$_uid'
      : 'flutter.profile.demo.$userKey';
  MemberProfile? get memberProfile {
    if (!authenticated) return null;
    if (!config.demo) return _serverProfile;
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    try {
      return MemberProfile.fromJson(object(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  bool get needsOnboarding =>
      config.firebaseAuth &&
      authenticated &&
      (config.demo
          ? memberProfile == null
          : profileLoaded && memberProfile?.onboardingCompleted == false);
  Future<void> loadProfile() async {
    if (!authenticated || config.demo) return;
    final revision = _identityRevision;
    try {
      final result = await api.profile();
      if (revision != _identityRevision || _disposed) return;
      _serverProfile = result;
      profileLoaded = true;
      profileError = null;
    } catch (e) {
      if (revision != _identityRevision || _disposed) return;
      profileError = message(e);
    }
    notifyListeners();
  }

  Future<void> saveMemberProfile(MemberProfile profile) async {
    if (!authenticated) throw const AuthFailure('로그인 후 저장할 수 있어요.');
    final revision = _identityRevision;
    if (config.demo) {
      if (!await prefs.setString(_profileKey, jsonEncode(profile.toJson()))) {
        throw const AuthFailure('프로필을 저장하지 못했어요.');
      }
    } else {
      final result = await api.saveProfile(profile);
      if (revision != _identityRevision) throw const AuthFailure('계정이 바뀌었어요.');
      _serverProfile = result;
      profileLoaded = true;
      profileError = null;
    }
    if (revision != _identityRevision) {
      throw const AuthFailure('계정이 바뀌었어요. 다시 확인해 주세요.');
    }
    notifyListeners();
  }

  bool get loginRequired => config.firebaseAuth || !config.demo;
  bool get canAuthenticate => !config.firebaseAuth || session != null;
  String get userKey => config.firebaseAuth ? _uid : email;
  String _localKey(String name) =>
      config.firebaseAuth ? 'flutter.demo.$_uid.$name' : 'flutter.demo.$name';

  void _loadLocalActivity() {
    if (!authenticated) {
      likes = {};
      follows = {};
      views = {};
      return;
    }
    likes = (prefs.getStringList(_localKey('likes')) ?? []).toSet();
    follows = (prefs.getStringList(_localKey('follows')) ?? []).toSet();
    try {
      final saved = object(
        jsonDecode(prefs.getString(_localKey('views')) ?? '{}'),
      );
      views = saved.map(
        (k, v) => MapEntry(k, (v as List).map((id) => text(id)).toList()),
      );
    } catch (_) {
      views = {};
    }
  }

  void _clearPrivateState() {
    ++_identityRevision;
    api.invalidateSession();
    pendingLikes.clear();
    pendingFollows.clear();
    likes = {};
    follows = {};
    views = {};
    _recordingViews.clear();
    _works.clear();
    _artists.clear();
    libraryError = null;
    _requests.clear();
    _requestTimes.clear();
    ++diaryRevision;
    ++collectionRevision;
    ++socialRevision;
    _serverProfile = null;
    profileLoaded = false;
    profileError = null;
  }

  void _authChanged(AuthUser? user) {
    final uid = user?.uid ?? '';
    if (_uid == uid && email == (user?.email ?? '')) return;
    _clearPrivateState();
    _uid = uid;
    email = user?.email ?? '';
    if (config.demo) {
      _loadLocalActivity();
    } else if (user != null) {
      unawaited(reloadLibrary());
      unawaited(loadProfile());
    }
    notifyListeners();
  }

  Future<void> reloadLibrary() async {
    if (!authenticated) return;
    final revision = _identityRevision;
    libraryError = null;
    notifyListeners();
    if (config.demo) {
      _loadLocalActivity();
      notifyListeners();
      return;
    }
    try {
      final result = await Future.wait([api.likes(), api.follows()]);
      if (revision != _identityRevision || _disposed) return;
      likes = (result[0] as List<Artwork>).map((a) => a.id).toSet();
      follows = (result[1] as List<Artist>).map((a) => a.id).toSet();
      for (final a in result[0] as List<Artwork>) {
        _works[a.id] = a;
      }
      for (final a in result[1] as List<Artist>) {
        _artists[a.id] = a;
      }
    } catch (e) {
      if (revision == _identityRevision) {
        libraryError = '좋아요 목록을 불러오지 못했어요. ${message(e)}';
      }
    }
    if (revision == _identityRevision) notifyListeners();
  }

  final AppConfig config;
  final ArtlogApi api;
  final SharedPreferences prefs;
  bool loading = true;
  String? error;
  String email = '';
  List<Artwork> artworks = [];
  List<Artist> artists = [];
  List<Movement> movements = [];
  Set<String> likes = {};
  Set<String> follows = {};
  final Set<String> pendingLikes = {};
  final Set<String> pendingFollows = {};
  Map<String, List<String>> views = {};
  final Set<String> _recordingViews = {};
  final Map<String, Artwork> _works = {};
  final Map<String, Artist> _artists = {};
  List<Artwork> get likedWorks =>
      likes.map(workFor).whereType<Artwork>().toList();
  List<Artist> get followedArtists =>
      follows.map(artistFor).whereType<Artist>().toList();
  bool get authenticated => config.firebaseAuth
      ? session?.user != null
      : config.demo || api.token != null;
  String artistMovement(Artist a) => a.movement.isNotEmpty
      ? a.movement
      : movements.where((m) => m.id == a.movementId).firstOrNull?.name ?? '미분류';
  String artistName(Artwork a) => a.artistName.isNotEmpty
      ? a.artistName
      : artistFor(a.artistId)?.name ?? '작가 정보 없음';
  String artistEnglish(Artwork a) => a.artistEnglish.isNotEmpty
      ? a.artistEnglish
      : artistFor(a.artistId)?.english ?? '';
  String movementName(Artwork a) => a.movement.isNotEmpty
      ? a.movement
      : movements.where((m) => m.id == a.movementId).firstOrNull?.name ?? '미분류';
  Artist? artistFor(String id) =>
      _artists[id] ?? artists.where((a) => a.id == id).firstOrNull;
  Artwork? workFor(String id) =>
      _works[id] ?? artworks.where((a) => a.id == id).firstOrNull;
  String representativeImage(Artist a) => a.portrait.isNotEmpty
      ? a.portrait
      : artworks.where((w) => w.artistId == a.id).firstOrNull?.image ?? '';

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (config.demo) {
        final j = object(
          jsonDecode(await rootBundle.loadString('assets/catalog.json')),
        );
        artworks = items(
          j['artworks'],
        ).map((r) => Artwork.fromJson(object(r))).toList();
        artists = items(
          j['artists'],
        ).map((r) => Artist.fromJson(object(r))).toList();
        movements = items(
          j['movements'],
        ).map((r) => Movement.fromJson(object(r))).toList();
        _loadLocalActivity();
      } else {
        final result = await Future.wait([
          api.artworks(),
          api.artists(),
          api.movements(),
        ]);
        artworks = result[0] as List<Artwork>;
        artists = result[1] as List<Artist>;
        movements = result[2] as List<Movement>;
      }
    } catch (e) {
      error = message(e);
    }
    loading = false;
    notifyListeners();
  }

  Future<Artwork> detail(String id) async {
    if (config.demo) {
      final result = workFor(id);
      if (result == null) {
        throw const ApiException('이 작품을 찾을 수 없어요.', status: 404);
      }
      return result;
    }
    final result = await _cached('detail/$id', () => api.artwork(id));
    _works[id] = result;
    return result;
  }

  Future<Artist> artistDetail(String id) async {
    if (!config.demo) {
      final result = await _cached('artist/$id', () => api.artist(id));
      _artists[id] = result;
      return result;
    }
    final result = artistFor(id);
    if (result == null) {
      throw const ApiException('이 작가를 찾을 수 없어요.', status: 404);
    }
    return result;
  }

  Future<void> login(String email, String password) async {
    if (config.firebaseAuth) {
      final auth = session;
      if (auth == null) throw AuthFailure(authError ?? '로그인 서비스가 준비되지 않았어요.');
      await auth.signIn(email, password);
      _authChanged(auth.user);
      return;
    }
    final accessToken = await api.login(email, password);
    _clearPrivateState();
    api.token = accessToken;
    this.email = email;
    notifyListeners();
    await reloadLibrary();
    await loadProfile();
  }

  Future<void> register(String email, String password) async {
    final auth = session;
    if (auth == null) throw const AuthFailure('회원가입 서비스가 준비되지 않았어요.');
    await auth.register(email, password);
    _authChanged(auth.user);
  }

  Future<void> resetPassword(String email) async {
    final auth = session;
    if (auth == null) throw const AuthFailure('비밀번호 재설정 서비스가 준비되지 않았어요.');
    await auth.resetPassword(email);
  }

  Future<void> loginWithGoogle() async {
    final auth = session;
    if (auth == null || !config.firebaseAuth) {
      throw const AuthFailure('Google 로그인을 준비하고 있어요.');
    }
    await auth.signInWithGoogle();
    _authChanged(auth.user);
  }

  Future<void> logout() async {
    if (session != null) await session!.signOut();
    api.token = null;
    _uid = '';
    email = '';
    _clearPrivateState();
    notifyListeners();
  }

  Future<void> toggleLike(String id) async {
    if (!authenticated) {
      throw const ApiException('로그인 후 이용할 수 있어요.', status: 401);
    }
    final revision = _identityRevision;
    if (pendingLikes.contains(id)) return;
    pendingLikes.add(id);
    notifyListeners();
    try {
      final enable = !likes.contains(id);
      if (!config.demo) await api.like(id, enable);
      if (revision != _identityRevision) return;
      enable ? likes.add(id) : likes.remove(id);
      if (config.demo) {
        await prefs.setStringList(_localKey('likes'), likes.toList());
      }
    } catch (_) {
      if (revision == _identityRevision) rethrow;
    } finally {
      if (revision == _identityRevision) pendingLikes.remove(id);
      notifyListeners();
    }
  }

  Future<void> toggleFollow(String id) async {
    if (!authenticated) {
      throw const ApiException('로그인 후 이용할 수 있어요.', status: 401);
    }
    final revision = _identityRevision;
    if (pendingFollows.contains(id)) return;
    pendingFollows.add(id);
    notifyListeners();
    try {
      final enable = !follows.contains(id);
      if (!config.demo) await api.follow(id, enable);
      if (revision != _identityRevision) return;
      enable ? follows.add(id) : follows.remove(id);
      if (config.demo) {
        await prefs.setStringList(_localKey('follows'), follows.toList());
      }
    } catch (_) {
      if (revision == _identityRevision) rethrow;
    } finally {
      if (revision == _identityRevision) pendingFollows.remove(id);
      notifyListeners();
    }
  }

  Future<void> recordView(String id) async {
    if (!authenticated) return;
    final revision = _identityRevision;
    final today = seoulDate();
    // Suppress simultaneous calls, but record a later reopening of the work.
    // The server increments view_count on the same user/day/artwork row.
    final key = '$revision/$today/$id';
    if (!_recordingViews.add(key)) return;
    try {
      if (!config.demo) {
        await api.view(id);
        _requests.removeWhere((key, _) => key.startsWith('recommended/'));
        _requestTimes.removeWhere((key, _) => key.startsWith('recommended/'));
        return;
      }
      final day = views.putIfAbsent(today, () => []);
      if (!day.contains(id)) day.add(id);
      await prefs.setString(_localKey('views'), jsonEncode(views));
      notifyListeners();
    } catch (_) {
      if (revision != _identityRevision) return;
      rethrow;
    } finally {
      _recordingViews.remove(key);
    }
  }

  Future<List<Artwork>> similar(Artwork work) async {
    if (!config.demo) {
      return _cached('similar/${work.id}', () => api.similar(work.id));
    }
    final candidates = artworks.where((a) => a.id != work.id).toList();
    candidates.sort(
      (a, b) =>
          ((b.artistId == work.artistId ? 2 : 0) +
                  (b.movementId == work.movementId ? 1 : 0))
              .compareTo(
                (a.artistId == work.artistId ? 2 : 0) +
                    (a.movementId == work.movementId ? 1 : 0),
              ),
    );
    return candidates.take(3).toList();
  }

  Future<ChatReply> ask(
    Artwork art,
    String question,
    List<ChatTurn> history, {
    String style = 'standard',
  }) async {
    if (!config.demo) {
      return api.chat(art.id, question, history, style: style);
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (RegExp(r'주식|날씨|음식|피카소|달리|다빈치|마티스').hasMatch(question)) {
      return const ChatReply(
        '아직 이 질문에 답할 수 있는 자료가 준비되지 않았어요. 지금 함께 보고 있는 작품의 정보나 감상 포인트를 물어보세요.',
        true,
        [],
      );
    }
    final answer = RegExp(r'언제|연도|몇 년').hasMatch(question)
        ? '목록에 기록된 제작 시기는 ${art.year}입니다. 아래 출처에서 작품 정보를 직접 살펴보세요.'
        : switch (style) {
            'easy' =>
              '${art.description.split('.').first}.\n\n쉽게 말하면, 먼저 그림 전체의 분위기를 느껴 보세요. 지금 답변은 미리보기용 쉬운 설명이에요.',
            'deep' =>
              '${art.description}\n\n${art.year} 무렵 ${art.medium.isEmpty ? '작가의 재료' : art.medium}로 제작된 이 작품은 구도와 시대 맥락을 함께 보면 더 깊이 읽을 수 있어요. 지금 답변은 미리보기용 깊이 있는 설명이에요.',
            _ =>
              '${art.description}\n\n어떤 부분이 가장 먼저 눈에 들어오나요? 지금 답변은 목업을 체험하기 위해 준비된 감상 안내예요.',
          };
    return ChatReply(answer, false, [
      Source(
        id: 'demo-${art.id}',
        title: art.title,
        name: '이미지·작품 출처 · 미리보기',
        url: art.sourceUrl,
        type: 'artwork_commentary',
      ),
    ]);
  }

  String _noteKey(String date) =>
      'flutter.notes.${config.firebaseAuth
          ? 'firebase:$_uid'
          : config.demo
          ? 'demo'
          : email}.$date';
  String note(String date) => prefs.getString(_noteKey(date)) ?? '';
  Future<void> saveNote(String date, String value) async {
    if (!await prefs.setString(_noteKey(date), value)) {
      throw const ApiException('이 브라우저에 메모를 저장하지 못했어요.');
    }
  }

  String get _diaryKey => _localKey('diary');
  List<DiaryEntry> _demoDiary() {
    if (!authenticated) return [];
    try {
      return items(
        jsonDecode(prefs.getString(_diaryKey) ?? '[]'),
      ).map((v) => DiaryEntry.fromJson(object(v))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DiaryEntry>> diaryMonth(String month) async {
    if (!authenticated) return [];
    if (!config.demo) return api.diaryMonth(month);
    return _demoDiary().where((e) => e.date.startsWith(month)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<DiaryEntry> saveDiary(
    String date,
    String content,
    bool isPublic,
    String? artworkId,
  ) async {
    if (!authenticated) {
      throw const ApiException('로그인 후 기록할 수 있어요.', status: 401);
    }
    final revision = _identityRevision;
    DiaryEntry result;
    if (config.demo) {
      result = DiaryEntry(
        id: date,
        date: date,
        content: content.trim(),
        isPublic: isPublic,
        author: _myNickname,
        authorId: SocialState.demoMemberId,
        artwork: artworkId == null ? null : workFor(artworkId),
      );
      final entries = _demoDiary()..removeWhere((e) => e.date == date);
      entries.add(result);
      if (!await prefs.setString(
        _diaryKey,
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      )) {
        throw const ApiException('감상평을 저장하지 못했어요.');
      }
    } else {
      result = await api.saveDiary(date, content, isPublic, artworkId);
    }
    if (revision != _identityRevision) {
      throw const ApiException('계정이 바뀌었어요. 다시 확인해 주세요.');
    }
    await prefs.remove(_noteKey(date));
    ++diaryRevision;
    notifyListeners();
    return result;
  }

  Future<void> deleteDiary(String date) async {
    if (!authenticated) throw const ApiException('로그인이 필요해요.', status: 401);
    final revision = _identityRevision;
    if (config.demo) {
      final entries = _demoDiary()..removeWhere((e) => e.date == date);
      if (!await prefs.setString(
        _diaryKey,
        jsonEncode(entries.map((e) => e.toJson()).toList()),
      )) {
        throw const ApiException('감상평을 삭제하지 못했어요.');
      }
    } else {
      await api.deleteDiary(date);
    }
    if (revision != _identityRevision) return;
    await prefs.remove(_noteKey(date));
    ++diaryRevision;
    notifyListeners();
  }

  Future<DiaryFeed> diaryFeed({String? cursor, String? artworkId}) async {
    if (!config.demo) {
      return api.diaryFeed(cursor: cursor, artworkId: artworkId);
    }
    final entries =
        _demoDiary()
            .where(
              (e) =>
                  e.isPublic &&
                  (artworkId == null || e.artwork?.id == artworkId),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final start = (int.tryParse(cursor ?? '') ?? 0).clamp(0, entries.length);
    final page = entries.skip(start).take(12).toList();
    final next = start + page.length;
    return DiaryFeed(page, next < entries.length ? '$next' : null);
  }

  static String message(Object e) => e is ApiException
      ? e.message
      : e is AuthFailure
      ? e.message
      : '자료를 불러오지 못했어요. 다시 시도해 주세요.';
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_authSubscription?.cancel());
    api.close();
    super.dispose();
  }
}
