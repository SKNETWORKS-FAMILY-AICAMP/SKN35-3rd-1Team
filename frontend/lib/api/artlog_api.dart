import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

// Paths and response shapes follow docs/api.md.
class ArtlogApi {
  ArtlogApi({required String baseUrl, http.Client? client})
    : _base = Uri.parse(baseUrl.isEmpty ? Uri.base.origin : baseUrl),
      _client = client ?? http.Client();
  final Uri _base;
  final http.Client _client;
  String? token;
  void Function()? onUnauthorized;
  Future<String?> Function(bool forceRefresh)? tokenProvider;
  int _sessionRevision = 0;
  void invalidateSession() {
    ++_sessionRevision;
    token = null;
  }

  Uri uri(String path, [Map<String, String>? query]) {
    var prefix = _base.path.replaceAll(RegExp(r'/+$'), '');
    if (prefix.endsWith('/api')) {
      prefix = prefix.substring(0, prefix.length - 4);
    }
    return _base
        .replace(path: '$prefix/api/$path', queryParameters: query)
        .removeFragment();
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Json? body,
    Map<String, String>? query,
    bool authenticated = false,
    bool retryAuthentication = true,
    bool sessionBound = false,
    int? expectedSessionRevision,
  }) async {
    final revision = expectedSessionRevision ?? _sessionRevision;
    void checkSession() {
      if ((authenticated || sessionBound) && revision != _sessionRevision) {
        throw const ApiException('로그인 상태가 바뀌었어요. 다시 시도해 주세요.', status: 401);
      }
    }

    checkSession();
    final accessToken = tokenProvider == null
        ? token
        : await tokenProvider!(false);
    checkSession();
    if (authenticated && accessToken == null) {
      throw const ApiException('로그인 후 이용할 수 있어요.', status: 401);
    }
    final request = http.Request(method, uri(path, query));
    request.headers['Accept'] = 'application/json';
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 45));
      checkSession();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) {
          if (tokenProvider != null &&
              accessToken != null &&
              retryAuthentication) {
            await tokenProvider!(true);
            checkSession();
            return await _request(
              method,
              path,
              body: body,
              query: query,
              authenticated: authenticated,
              retryAuthentication: false,
              sessionBound: sessionBound,
              expectedSessionRevision: revision,
            );
          }
          token = null;
          onUnauthorized?.call();
        }
        throw ApiException(switch (response.statusCode) {
          401 => '로그인이 만료되었어요. 다시 로그인해 주세요.',
          403 => '이 기능을 이용할 권한이 없어요.',
          404 => '요청한 자료를 찾을 수 없어요.',
          422 => '입력 내용을 확인해 주세요. 질문은 1~500자까지 보낼 수 있어요.',
          429 => '요청이 잠시 많아요. 조금 뒤 다시 시도해 주세요.',
          501 => '이 기능은 준비 중이에요. 조금 뒤 다시 이용해 주세요.',
          503 => '서비스를 잠시 이용하기 어려워요. 조금 뒤 다시 시도해 주세요.',
          _ => '자료를 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.',
        }, status: response.statusCode);
      }
      if (response.bodyBytes.isEmpty || response.statusCode == 204) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const ApiException('응답이 늦어지고 있어요. 다시 시도해 주세요.');
    } on http.ClientException {
      throw const ApiException('서버에 연결하지 못했어요. 연결 상태를 확인해 주세요.');
    } on FormatException {
      throw const ApiException('서버 응답 형식을 확인해 주세요.');
    }
  }

  Future<List<Movement>> movements() async => items(
    await _request('GET', 'movements'),
  ).map((j) => Movement.fromJson(object(j))).toList();
  Future<List<Artist>> artists({String? movementId}) async => items(
    await _request(
      'GET',
      'artists',
      query: movementId == null ? null : {'movement_id': movementId},
    ),
  ).map((j) => Artist.fromJson(object(j))).toList();
  Future<Artist> artist(String id) async => Artist.fromJson(
    object(await _request('GET', 'artists/${Uri.encodeComponent(id)}')),
  );
  Future<List<Artwork>> artworks({String? artistId, String? movementId}) async {
    final query = <String, String>{};
    if (artistId != null) {
      query['artist_id'] = artistId;
    }
    if (movementId != null) {
      query['movement_id'] = movementId;
    }
    return items(
      await _request('GET', 'artworks', query: query),
    ).map((j) => Artwork.fromJson(object(j))).toList();
  }

  Future<Artwork> artwork(String id) async => Artwork.fromJson(
    object(await _request('GET', 'artworks/${Uri.encodeComponent(id)}')),
  );
  Future<ChatReply> chat(
    String id,
    String question,
    List<ChatTurn> history,
  ) async {
    if (question.trim().isEmpty || question.runes.length > 500) {
      throw const ApiException('질문은 1~500자까지 보낼 수 있어요.', status: 422);
    }
    final previous = history.length > 12
        ? history.sublist(history.length - 12)
        : history;
    return ChatReply.fromJson(
      object(
        await _request(
          'POST',
          'artworks/${Uri.encodeComponent(id)}/chat',
          sessionBound: true,
          body: {
            'question': question,
            'history': previous.map((h) => h.toHistory()).toList(),
          },
        ),
      ),
    );
  }

  Future<List<ChatTurn>> chatMessages(String id) async => items(
    await _request(
      'GET',
      'artworks/${Uri.encodeComponent(id)}/chat/messages',
      authenticated: true,
    ),
  ).map((j) => ChatTurn.fromJson(object(j))).toList();

  Future<void> resetChat(String id) async {
    await _request(
      'DELETE',
      'artworks/${Uri.encodeComponent(id)}/chat',
      authenticated: true,
    );
  }

  Future<List<ChatSummary>> chats() async => items(
    await _request('GET', 'me/chats', authenticated: true),
  ).map((j) => ChatSummary.fromJson(object(j))).toList();

  Future<void> like(String id, bool enabled) async {
    await _request(
      enabled ? 'PUT' : 'DELETE',
      'artworks/${Uri.encodeComponent(id)}/like',
      authenticated: true,
    );
  }

  Future<void> follow(String id, bool enabled) async {
    await _request(
      enabled ? 'PUT' : 'DELETE',
      'artists/${Uri.encodeComponent(id)}/follow',
      authenticated: true,
    );
  }

  Future<List<Artwork>> likes() async => items(
    await _request('GET', 'me/likes', authenticated: true),
  ).map((j) => Artwork.fromJson(object(j))).toList();
  Future<List<Artist>> follows() async => items(
    await _request('GET', 'me/follows', authenticated: true),
  ).map((j) => Artist.fromJson(object(j))).toList();
  Future<void> view(String id) async {
    await _request(
      'POST',
      'artworks/${Uri.encodeComponent(id)}/views',
      authenticated: true,
    );
  }

  Future<List<Artwork>> similar(String id) async => items(
    await _request('GET', 'artworks/${Uri.encodeComponent(id)}/similar'),
  ).map((j) => Artwork.fromJson(object(j))).toList();
  Future<List<Artwork>> recommendedArtworks() async => items(
    await _request('GET', 'me/recommendations/artworks', authenticated: true),
  ).map((j) => Artwork.fromJson(object(j))).toList();
  Future<List<Artist>> recommendedArtists() async => items(
    await _request('GET', 'me/recommendations/artists', authenticated: true),
  ).map((j) => Artist.fromJson(object(j))).toList();
  Future<List<CalendarDay>> calendarDays(String month) async => items(
    await _request(
      'GET',
      'me/library/calendar',
      query: {'month': month},
      authenticated: true,
    ),
  ).map((j) => CalendarDay.fromJson(object(j))).toList();
  Future<Map<String, int>> calendar(String month) async => {
    for (final day in await calendarDays(month)) day.date: day.artworkCount,
  };

  Future<List<Artwork>> day(String date) async => items(
    await _request(
      'GET',
      'me/library/days/${Uri.encodeComponent(date)}',
      authenticated: true,
    ),
  ).map((j) => Artwork.fromJson(object(j))).toList();
  Future<String> login(String email, String password) async {
    final j = object(
      await _request(
        'POST',
        'auth/login',
        body: {'email': email, 'password': password},
      ),
    );
    final value = text(j['access_token']);
    if (value.isEmpty) throw const ApiException('로그인 응답에 access_token이 없어요.');
    token = value;
    return value;
  }

  void close() => _client.close();
}
