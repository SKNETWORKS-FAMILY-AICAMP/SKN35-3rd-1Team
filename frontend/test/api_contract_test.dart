import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/models.dart';

const work = {'id': 42, 'slug': 'ssireum', 'title': '씨름', 'artist_id': 7};
const artist = {'id': 7, 'slug': 'kim-hong-do', 'name': '김홍도'};
http.Response jsonResponse(Object data) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), 200);

void main() {
  testWidgets('timeout also covers waiting for response headers', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final api = ArtlogApi(
      baseUrl: 'https://example.org',
      client: MockClient((_) => pending.future),
    );
    final check = expectLater(
      api.artworks(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('응답이 늦어지고'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 46));
    await check;
    pending.complete(jsonResponse([]));
    await tester.pump();
    api.close();
  });
  test('base URL accepts root and /api without duplicating prefix', () {
    for (final base in [
      'https://example.org',
      'https://example.org/',
      'https://example.org/api/',
    ]) {
      final api = ArtlogApi(baseUrl: base);
      expect(
        api.uri('artworks', {'artist_id': '7'}).toString(),
        'https://example.org/api/artworks?artist_id=7',
      );
      api.close();
    }
  });

  test(
    'public catalog and detail use database IDs, snake_case filters and UTF8',
    () async {
      final requests = <http.Request>[];
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient((r) async {
          requests.add(r);
          return jsonResponse(switch (r.url.path) {
            '/api/movements' => [
              {'id': 3, 'name': '조선 회화'},
            ],
            '/api/artists' => {
              'items': [artist],
            },
            '/api/artists/7' => artist,
            '/api/artworks/42' => work,
            _ => {
              'data': [work],
            },
          });
        }),
      );
      expect((await api.movements()).single.name, '조선 회화');
      expect((await api.artists(movementId: '3')).single.id, '7');
      expect((await api.artist('7')).slug, 'kim-hong-do');
      expect(
        (await api.artworks(artistId: '7', movementId: '3')).single.title,
        '씨름',
      );
      expect((await api.artwork('42')).id, '42');
      await api.similar('42');
      expect(requests.map((r) => r.method), everyElement('GET'));
      expect(requests[1].url.queryParameters, {'movement_id': '3'});
      expect(requests[3].url.queryParameters, {
        'artist_id': '7',
        'movement_id': '3',
      });
      expect(requests.last.url.path, '/api/artworks/42/similar');
      api.close();
    },
  );

  test(
    'chat sends current question separately from bounded history and keeps source fields',
    () async {
      late http.Request sent;
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient((r) async {
          sent = r;
          return jsonResponse({
            'answer': '원문에 따른 답변',
            'refused': false,
            'sources': [
              {
                'document_id': 123,
                'title': '작품 해설',
                'doc_type': 'artwork_commentary',
                'source_name': '국립중앙박물관',
                'source_url': 'https://museum.go.kr/source',
                'license': '공공누리 제1유형',
                'basis_sources': [
                  {
                    'source_name': '국립중앙박물관 연구자료',
                    'source_url': 'https://museum.go.kr/basis',
                  },
                ],
              },
            ],
          });
        }),
      );
      final reply = await api.chat(
        '42',
        '누가 그렸나요?',
        List.generate(
          14,
          (i) => ChatTurn(i.isEven ? 'user' : 'assistant', 'turn$i'),
        ),
      );
      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/artworks/42/chat');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body.keys, unorderedEquals(['question', 'history']));
      expect(body['question'], '누가 그렸나요?');
      expect(body['history'], hasLength(12));
      expect(body['history'][0], {'role': 'user', 'content': 'turn2'});
      expect(reply.sources.single.id, '123');
      expect(reply.sources.single.name, '국립중앙박물관');
      expect(reply.sources.single.license, '공공누리 제1유형');
      expect(reply.sources.single.basisSources.single.name, '국립중앙박물관 연구자료');
      expect(
        reply.sources.single.basisSources.single.url,
        'https://museum.go.kr/basis',
      );
      expect(reply.refused, false);
      expect(
        () => ChatReply.fromJson({'answer': '출처 없는 응답'}),
        throwsFormatException,
      );
      final refusal = ChatReply.fromJson({
        'answer': '자료가 없어요.',
        'refused': true,
        'sources': [],
      });
      expect(refusal.sources, isEmpty);
      expect(refusal.refused, true);
      api.close();
    },
  );

  test('chat SSE forwards tokens and uses the final response', () async {
    late http.Request sent;
    final shown = <String>[];
    final api = ArtlogApi(
      baseUrl: 'https://example.org',
      client: MockClient((request) async {
        sent = request;
        return http.Response(
          'event: token\ndata: {"content":"초안"}\n\n'
          'event: replace\ndata: {"content":"수정된 초안"}\n\n'
          'event: done\ndata: {"answer":"최종 답변","refused":false,"sources":[]}\n\n',
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );
    final reply = await api.chatStream(
      '42',
      '언제 그렸나요?',
      const [],
      onToken: (text) async {
        shown.add(text);
      },
      onReplace: (text) async {
        shown.add('replace:$text');
      },
    );
    expect(sent.url.path, '/api/artworks/42/chat/stream');
    expect(sent.headers['Accept'], 'text/event-stream');
    expect(shown, ['초안', 'replace:수정된 초안']);
    expect(reply.answer, '최종 답변');
    api.close();
  });

  for (final status in [404, 405, 501]) {
    test('unsupported stream ($status) falls back once to JSON chat', () async {
      final paths = <String>[];
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('/stream')) return http.Response('', status);
          return jsonResponse({
            'answer': '검증된 답변',
            'refused': false,
            'sources': [],
          });
        }),
      );
      final reply = await api.chatStream(
        '42',
        '설명해줘',
        const [],
        onToken: (_) async {},
        onReplace: (_) async {},
      );
      expect(reply.answer, '검증된 답변');
      expect(paths, ['/api/artworks/42/chat/stream', '/api/artworks/42/chat']);
      api.close();
    });
  }

  test(
    'a started stream failure never replays or saves a second question',
    () async {
      var requests = 0;
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient((_) async {
          requests++;
          return http.Response(
            'event: token\ndata: {"content":"초안"}\n\n'
            'event: error\ndata: {"message":"연결 실패"}\n\n',
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }),
      );
      await expectLater(
        api.chatStream(
          '42',
          '설명해줘',
          const [],
          onToken: (_) async {},
          onReplace: (_) async {},
        ),
        throwsA(isA<ApiException>()),
      );
      expect(requests, 1);
      api.close();
    },
  );

  test('malformed token text becomes a readable API error', () async {
    final api = ArtlogApi(
      baseUrl: 'https://example.org',
      client: MockClient(
        (_) async => http.Response(
          'event: token\ndata: {"content":12}\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );
    await expectLater(
      api.chatStream(
        '42',
        '설명해줘',
        const [],
        onToken: (_) async {},
        onReplace: (_) async {},
      ),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', contains('형식')),
      ),
    );
    api.close();
  });

  test('JSON fallback cannot continue under a different account', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    final api = ArtlogApi(
      baseUrl: 'https://example.org',
      client: MockClient((_) {
        requests++;
        return response.future;
      }),
    );
    final check = expectLater(
      api.chatStream(
        '42',
        '설명해줘',
        const [],
        onToken: (_) async {},
        onReplace: (_) async {},
      ),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    await Future<void>.delayed(Duration.zero);
    api.invalidateSession();
    response.complete(http.Response('', 404));
    await check;
    expect(requests, 1);
    api.close();
  });

  test(
    'authenticated mutations use PUT/DELETE; views POST; 204 is valid',
    () async {
      final requests = <http.Request>[];
      final api = ArtlogApi(
        baseUrl: 'https://example.org/api',
        client: MockClient((r) async {
          requests.add(r);
          return http.Response('', 204);
        }),
      );
      await expectLater(
        api.like('42', true),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(requests, isEmpty);
      api.token = 'test-token';
      await api.like('42', true);
      await api.like('42', false);
      await api.follow('7', true);
      await api.follow('7', false);
      await api.view('42');
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'PUT /api/artworks/42/like',
        'DELETE /api/artworks/42/like',
        'PUT /api/artists/7/follow',
        'DELETE /api/artists/7/follow',
        'POST /api/artworks/42/views',
      ]);
      for (final r in requests) {
        expect(r.headers['Authorization'], 'Bearer test-token');
        expect(r.body, isEmpty);
      }
      api.close();
    },
  );

  test('library and recommendations use /me and ISO date parameters', () async {
    final requests = <http.Request>[];
    final api = ArtlogApi(
      baseUrl: 'https://example.org',
      client: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/calendar')) {
          return jsonResponse([
            {'date': '2026-10-12', 'artwork_count': 2},
          ]);
        }
        return jsonResponse(
          r.url.path.endsWith('/follows') || r.url.path.endsWith('/artists')
              ? [artist]
              : [work],
        );
      }),
    )..token = 'test-token';
    await api.likes();
    await api.follows();
    expect(await api.calendar('2026-10'), {'2026-10-12': 2});
    await api.day('2026-10-12');
    await api.recommendedArtworks();
    await api.recommendedArtists();
    expect(requests.map((r) => r.url.path), [
      '/api/me/likes',
      '/api/me/follows',
      '/api/me/library/calendar',
      '/api/me/library/days/2026-10-12',
      '/api/me/recommendations/artworks',
      '/api/me/recommendations/artists',
    ]);
    expect(requests[2].url.queryParameters, {'month': '2026-10'});
    api.close();
  });

  test(
    'provisional login adapter uses JSON and handles expired token',
    () async {
      var expired = false;
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient((r) async {
          if (r.url.path == '/api/auth/login') {
            expect(r.method, 'POST');
            expect(r.headers['Content-Type'], contains('application/json'));
            expect(jsonDecode(r.body), {
              'email': 'member@example.org',
              'password': 'test-only',
            });
            return jsonResponse({'access_token': 'test-token'});
          }
          return http.Response('not JSON', 401);
        }),
      )..onUnauthorized = () => expired = true;
      await api.login('member@example.org', 'test-only');
      expect(api.token, 'test-token');
      await expectLater(
        api.likes(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(api.token, isNull);
      expect(expired, true);
      api.close();
    },
  );

  test('server and malformed response errors are explicit', () async {
    final server = ArtlogApi(
      baseUrl: 'https://example.org',
      client: MockClient((_) async => http.Response('<html>error</html>', 500)),
    );
    await expectLater(
      server.artworks(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 500)),
    );
    server.close();
    final malformed = ArtlogApi(
      baseUrl: 'https://example.org',
      client: MockClient((_) async => http.Response('invalid', 200)),
    );
    await expectLater(malformed.artworks(), throwsA(isA<ApiException>()));
    malformed.close();
  });

  test(
    'unimplemented docent is shown as preparing without demo fallback',
    () async {
      final api = ArtlogApi(
        baseUrl: 'https://example.org/',
        client: MockClient((_) async => http.Response('', 501)),
      );
      await expectLater(
        api.chat('42', '작품을 소개해 주세요.', []),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 501)
              .having((e) => e.message, 'message', contains('준비 중')),
        ),
      );
      api.close();
    },
  );
}
