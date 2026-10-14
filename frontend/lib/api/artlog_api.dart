import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';
import '../diary.dart';
import '../mypage.dart';
import '../member_profile.dart';
import '../social.dart';

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
          409 => '같은 이름이 있는지 확인하고, 취향 소개를 만들 때는 작품을 먼저 담아 주세요.',
          422 => '입력 내용을 확인해 주세요. 글자 수와 날짜가 올바른지 확인해 주세요.',
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
    List<ChatTurn> history, {
    String style = 'standard',
  }) async {
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
            'explanation_style': style,
          },
        ),
      ),
    );
  }

  /// Read the project's POST SSE endpoint without buffering the response body.
  /// `onToken` receives newly generated text; `onReplace` handles a parser
  /// correction in a provisional LangChain JSON snapshot.
  Future<ChatReply> chatStream(
    String id,
    String question,
    List<ChatTurn> history, {
    required Future<void> Function(String) onToken,
    required Future<void> Function(String) onReplace,
    String style = 'standard',
  }) => _chatStream(
    id,
    question,
    history,
    onToken: onToken,
    onReplace: onReplace,
    style: style,
    revision: _sessionRevision,
  );

  Future<ChatReply> _chatStream(
    String id,
    String question,
    List<ChatTurn> history, {
    required Future<void> Function(String) onToken,
    required Future<void> Function(String) onReplace,
    required int revision,
    String style = 'standard',
    bool retryAuthentication = true,
  }) async {
    if (question.trim().isEmpty || question.runes.length > 500) {
      throw const ApiException('질문은 1~500자까지 보낼 수 있어요.', status: 422);
    }
    void checkSession() {
      if (revision != _sessionRevision) {
        throw const ApiException('로그인 상태가 바뀌었어요. 다시 시도해 주세요.', status: 401);
      }
    }

    checkSession();
    final accessToken = tokenProvider == null
        ? token
        : await tokenProvider!(false);
    checkSession();
    final previous = history.length > 12
        ? history.sublist(history.length - 12)
        : history;
    final request = http.Request(
      'POST',
      uri('artworks/${Uri.encodeComponent(id)}/chat/stream'),
    );
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Content-Type'] = 'application/json';
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    request.body = jsonEncode({
      'question': question,
      'history': previous.map((h) => h.toHistory()).toList(),
      'explanation_style': style,
    });

    try {
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 45));
      checkSession();
      if (response.statusCode == 401 &&
          tokenProvider != null &&
          accessToken != null &&
          retryAuthentication) {
        await response.stream.drain<void>().timeout(
          const Duration(seconds: 45),
        );
        await tokenProvider!(true);
        checkSession();
        return await _chatStream(
          id,
          question,
          history,
          onToken: onToken,
          onReplace: onReplace,
          style: style,
          revision: revision,
          retryAuthentication: false,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>().timeout(
          const Duration(seconds: 45),
        );
        checkSession();
        // Only an unsupported endpoint can safely fall back. Never replay a
        // generation that has started or failed midway: it may already be saved.
        if ({404, 405, 501}.contains(response.statusCode)) {
          return ChatReply.fromJson(
            object(
              await _request(
                'POST',
                'artworks/${Uri.encodeComponent(id)}/chat',
                sessionBound: true,
                expectedSessionRevision: revision,
                retryAuthentication: retryAuthentication,
                body: {
                  'question': question,
                  'history': previous.map((h) => h.toHistory()).toList(),
                  'explanation_style': style,
                },
              ),
            ),
          );
        }
        if (response.statusCode == 401) onUnauthorized?.call();
        throw ApiException(switch (response.statusCode) {
          401 => '로그인이 만료되었어요. 다시 로그인해 주세요.',
          404 => '요청한 작품을 찾을 수 없어요.',
          422 => '질문은 1~500자까지 보낼 수 있어요.',
          429 => '요청이 잠시 많아요. 조금 뒤 다시 시도해 주세요.',
          503 => 'AI 서비스를 잠시 이용하기 어려워요.',
          _ => '답변을 불러오지 못했어요. 다시 시도해 주세요.',
        }, status: response.statusCode);
      }
      if (!(response.headers['content-type']?.contains('text/event-stream') ??
          false)) {
        throw const ApiException('서버의 채팅 스트림 형식을 확인해 주세요.');
      }

      String event = 'message';
      final data = <String>[];
      ChatReply? reply;
      Future<void> dispatch() async {
        if (data.isEmpty) return;
        final payload = jsonDecode(data.join('\n'));
        if (event == 'token' || event == 'replace') {
          final content = object(payload)['content'];
          if (content is! String) {
            throw const FormatException('Invalid chat text');
          }
          if (event == 'token') {
            await onToken(content);
          } else {
            await onReplace(content);
          }
        } else if (event == 'done') {
          reply = ChatReply.fromJson(object(payload));
        } else if (event == 'error') {
          throw ApiException(
            object(payload)['message'] as String? ?? 'AI 응답이 중단되었어요.',
          );
        }
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 45))) {
        checkSession();
        if (line.isEmpty) {
          await dispatch();
          event = 'message';
          data.clear();
          if (reply != null) break;
        } else if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data.add(line.substring(5).trimLeft());
        }
      }
      if (data.isNotEmpty) await dispatch();
      checkSession();
      if (reply == null) throw const ApiException('답변이 완료되기 전에 연결이 끊겼어요.');
      return reply!;
    } on TimeoutException {
      throw const ApiException('응답이 늦어지고 있어요. 다시 시도해 주세요.');
    } on http.ClientException {
      throw const ApiException('서버에 연결하지 못했어요. 연결 상태를 확인해 주세요.');
    } on FormatException {
      throw const ApiException('서버의 채팅 응답 형식을 확인해 주세요.');
    }
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

  Future<List<DiaryEntry>> diaryMonth(String month) async => items(
    await _request(
      'GET',
      'me/diary',
      query: {'month': month},
      authenticated: true,
    ),
  ).map((v) => DiaryEntry.fromJson(object(v))).toList();

  /// Creates an entry when [id] is null, otherwise updates that entry.
  /// One entry per artwork; any number per day.
  Future<DiaryEntry> saveDiary(
    String date,
    String content,
    bool isPublic,
    String? artworkId, {
    String? id,
  }) async {
    final body = {
      'content': content,
      'is_public': isPublic,
      'artwork_id': artworkId == null ? null : int.parse(artworkId),
    };
    return DiaryEntry.fromJson(
      object(
        id == null
            ? await _request(
                'POST',
                'me/diary',
                authenticated: true,
                body: {'entry_date': date, ...body},
              )
            : await _request(
                'PUT',
                'me/diary/${Uri.encodeComponent(id)}',
                authenticated: true,
                body: body,
              ),
      ),
    );
  }

  Future<DiaryEntry?> diaryForArtwork(String artworkId) async {
    final j = await _request(
      'GET',
      'me/diary/artworks/${Uri.encodeComponent(artworkId)}',
      authenticated: true,
    );
    return j == null ? null : DiaryEntry.fromJson(object(j));
  }

  Future<void> deleteDiary(String id) async {
    await _request(
      'DELETE',
      'me/diary/${Uri.encodeComponent(id)}',
      authenticated: true,
    );
  }

  Future<DiaryFeed> diaryFeed({String? cursor, String? artworkId}) async =>
      DiaryFeed.fromJson(
        object(
          await _request(
            'GET',
            'diary/feed',
            query: {
              'limit': '12',
              'before_id': ?cursor,
              'artwork_id': ?artworkId,
            },
          ),
        ),
      );

  Future<MemberProfile> profile() async => MemberProfile.fromServer(
    object(await _request('GET', 'me/profile', authenticated: true)),
  );
  Future<MemberProfile> saveProfile(MemberProfile profile) async =>
      MemberProfile.fromServer(
        object(
          await _request(
            'PUT',
            'me/profile',
            authenticated: true,
            body: profile.toServerJson(),
          ),
        ),
      );
  Future<List<ArtCollection>> collections() async => items(
    await _request('GET', 'me/collections', authenticated: true),
  ).map((e) => ArtCollection.fromJson(object(e))).toList();
  Future<ArtCollection> saveCollection(
    String name,
    String description, {
    String? id,
  }) async => ArtCollection.fromJson(
    object(
      await _request(
        id == null ? 'POST' : 'PUT',
        id == null
            ? 'me/collections'
            : 'me/collections/${Uri.encodeComponent(id)}',
        authenticated: true,
        body: {'name': name, 'description': description},
      ),
    ),
  );
  Future<void> deleteCollection(String id) async {
    await _request(
      'DELETE',
      'me/collections/${Uri.encodeComponent(id)}',
      authenticated: true,
    );
  }

  Future<ArtCollection> collect(
    String id,
    String artworkId,
  ) async => ArtCollection.fromJson(
    object(
      await _request(
        'PUT',
        'me/collections/${Uri.encodeComponent(id)}/items/${Uri.encodeComponent(artworkId)}',
        authenticated: true,
      ),
    ),
  );
  Future<void> uncollect(String id, String artworkId) async {
    await _request(
      'DELETE',
      'me/collections/${Uri.encodeComponent(id)}/items/${Uri.encodeComponent(artworkId)}',
      authenticated: true,
    );
  }

  Future<ArtworkPage> collectionItems(String id, {String? cursor}) async =>
      ArtworkPage.fromJson(
        object(
          await _request(
            'GET',
            'me/collections/${Uri.encodeComponent(id)}/items',
            authenticated: true,
            query: {'limit': '12', 'before_id': ?cursor},
          ),
        ),
      );
  Future<CritiquePage> critiques({String? cursor}) async =>
      CritiquePage.fromJson(
        object(
          await _request(
            'GET',
            'me/critiques',
            authenticated: true,
            query: {'limit': '12', 'before_id': ?cursor},
          ),
        ),
      );
  Future<List<MemberActivity>> activity({int offset = 0}) async => items(
    await _request(
      'GET',
      'me/activity',
      authenticated: true,
      query: {'limit': '20', 'offset': '$offset'},
    ),
  ).map((e) => MemberActivity.fromJson(object(e))).toList();
  Future<TasteIntro> taste({bool generate = false}) async =>
      TasteIntro.fromJson(
        object(
          await _request(
            generate ? 'POST' : 'GET',
            'me/taste',
            authenticated: true,
          ),
        ),
      );
  Future<CollectionReply> collectionChat(
    String message, {
    String? collectionId,
  }) async => CollectionReply.fromJson(
    object(
      await _request(
        'POST',
        'me/collections/chat',
        authenticated: true,
        body: {
          'message': message,
          'collection_id': collectionId == null
              ? null
              : int.parse(collectionId),
        },
      ),
    ),
  );

  Future<PublicMember> mySocial() async => PublicMember.fromJson(
    object(await _request('GET', 'me/social', authenticated: true)),
  );
  Future<PublicMember> saveSocial({required bool followListPublic}) async =>
      PublicMember.fromJson(
        object(
          await _request(
            'PUT',
            'me/social',
            authenticated: true,
            body: {'follow_list_public': followListPublic},
          ),
        ),
      );
  Future<PublicMember> member(String id) async => PublicMember.fromJson(
    object(await _request('GET', 'users/${Uri.encodeComponent(id)}')),
  );
  Future<DiaryFeed> memberDiary(String id, {String? cursor}) async =>
      DiaryFeed.fromJson(
        object(
          await _request(
            'GET',
            'users/${Uri.encodeComponent(id)}/diary',
            query: {'limit': '12', 'before_id': ?cursor},
          ),
        ),
      );
  Future<void> followMember(String id, bool enabled) async {
    await _request(
      enabled ? 'PUT' : 'DELETE',
      'users/${Uri.encodeComponent(id)}/follow',
      authenticated: true,
    );
  }

  Future<List<MemberCard>> memberList(
    String id, {
    required bool followers,
  }) async => items(
    await _request(
      'GET',
      'users/${Uri.encodeComponent(id)}/${followers ? 'followers' : 'following'}',
    ),
  ).map((e) => MemberCard.fromJson(object(e))).toList();

  void close() => _client.close();
}
