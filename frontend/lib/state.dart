import 'dart:convert';
import 'dart:async';
import 'auth/auth_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/artlog_api.dart';
import 'config.dart';
import 'models.dart';
import 'member_profile.dart';

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
  void setAuthUiOpen(bool value) {
    authUiOpen = value;
    notifyListeners();
  }

  String get _profileKey => 'flutter.profile.firebase.$_uid';
  MemberProfile? get memberProfile {
    if (!config.firebaseAuth || !authenticated) return null;
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    try {
      return MemberProfile.fromJson(object(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  bool get needsOnboarding =>
      config.firebaseAuth && authenticated && memberProfile == null;
  Future<void> saveMemberProfile(MemberProfile profile) async {
    if (!config.firebaseAuth || !authenticated) {
      throw const AuthFailure('로그인 후 저장할 수 있어요.');
    }
    final revision = _identityRevision;
    final key = _profileKey;
    if (!await prefs.setString(key, jsonEncode(profile.toJson()))) {
      throw const AuthFailure('프로필을 저장하지 못했어요. 다시 시도해 주세요.');
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
    _recorded.clear();
    _works.clear();
    _artists.clear();
    libraryError = null;
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
        libraryError = '서재를 불러오지 못했어요. ${message(e)}';
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
  final Set<String> _recorded = {};
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
    final result = await api.artwork(id);
    _works[id] = result;
    return result;
  }

  Future<Artist> artistDetail(String id) async {
    if (!config.demo) {
      final result = await api.artist(id);
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
    final key = '$today/$id';
    if (!_recorded.add(key)) return;
    try {
      if (!config.demo) {
        await api.view(id);
        return;
      }
      final day = views.putIfAbsent(today, () => []);
      if (!day.contains(id)) day.add(id);
      await prefs.setString(_localKey('views'), jsonEncode(views));
      notifyListeners();
    } catch (_) {
      if (revision != _identityRevision) return;
      _recorded.remove(key);
      rethrow;
    }
  }

  Future<List<Artwork>> similar(Artwork work) async {
    if (!config.demo) return api.similar(work.id);
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
    List<ChatTurn> history,
  ) async {
    if (!config.demo) return api.chat(art.id, question, history);
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
        : '${art.description}\n\n어떤 부분이 가장 먼저 눈에 들어오나요? 지금 답변은 목업을 체험하기 위해 준비된 감상 안내예요.';
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
