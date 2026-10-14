import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/docent_conversation.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/models.dart';
import 'package:artlog_web/state.dart';
import 'connected_features_test.dart' show SessionFake;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ArtlogState> demo(SessionFake session) async {
    final s = ArtlogState(
      const AppConfig(demo: true, authProvider: 'firebase'),
      ArtlogApi(baseUrl: 'https://example.org'),
      await SharedPreferences.getInstance(),
      session: session,
    );
    await s.load();
    return s;
  }

  test(
    'auto collections follow view history and saving keeps the first as cover',
    () async {
      final session = SessionFake(), s = await demo(session);
      expect(await s.autoCollections(), isEmpty);
      final [a, b, c, ...] = s.artworks;
      final today = seoulDate(), month = today.substring(0, 7);
      s.views = {
        '2000-01-01': [b.id, a.id],
        today: [c.id, a.id],
      };
      final autos = {for (final x in await s.autoCollections()) x.key: x};
      expect(autos['recent']!.cover!.id, a.id);
      expect(autos['frequent']!.count, 1); // only a was seen on two days
      expect(
        autos['month-$month']!.name,
        '${int.parse(month.substring(5))}월의 감상',
      );
      final (recent, works) = await s.autoCollection('recent');
      expect(recent.name, '최근 본 작품');
      expect(works.map((w) => w.id), [a.id, c.id, b.id]);
      final saved = await s.saveCollection(
        recent.name,
        '',
        artworkIds: [c.id, a.id, c.id],
      );
      expect(saved.previews.first.id, c.id);
      expect((await s.collections()).single.count, 2);
      s.dispose();
      await session.events.close();
    },
  );

  testWidgets('collection tab shows auto cards that open and can be saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = SessionFake();
    final s = (await tester.runAsync(() => demo(session)))!;
    final first = s.artworks.first;
    s.views = {
      seoulDate(): [first.id],
    };
    await tester.pumpWidget(
      ArtlogApp(state: s, initialLocation: '/library?tab=collections'),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('collection-auto-recent'));
    expect(card, findsOneWidget);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('auto-collection-header')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('auto-collection-save')));
    await tester.pumpAndSettle();
    final saved = (await tester.runAsync(s.collections))!.single;
    expect(saved.name, '최근 본 작품');
    expect(saved.previews.first.id, first.id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
    await session.events.close();
  });

  test(
    'docent offer is parsed and shown at most once per conversation',
    () async {
      const work = {
        'id': 42,
        'slug': 'ssireum',
        'title': '씨름',
        'artist_id': 7,
        'artist_name': '김홍도',
      };
      const offer = {
        'kind': 'add_artwork',
        'message': '『씨름』에 관심이 많으시네요. 컬렉션에 담아 드릴까요?',
        'artwork_id': 42,
        'collections': [
          {'id': 3, 'name': '풍속화'},
        ],
        'proposal': null,
        'artworks': [],
      };
      http.Response respond(http.Request r) {
        final body = switch (r.url.path) {
          '/api/artworks/42/chat/stream' =>
            'event: done\ndata: ${jsonEncode({'answer': '답변', 'refused': false, 'sources': [], 'suggestion': offer})}\n\n',
          '/api/artworks' || '/api/artists' || '/api/movements' => '[]',
          '/api/artworks/42/chat/messages' || '/api/me/likes' => '[]',
          _ => '{}',
        };
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: {
            'content-type': r.url.path.endsWith('/stream')
                ? 'text/event-stream; charset=utf-8'
                : 'application/json; charset=utf-8',
          },
        );
      }

      final session = SessionFake();
      final s = ArtlogState(
        const AppConfig(demo: false, authProvider: 'firebase'),
        ArtlogApi(
          baseUrl: 'https://example.org/',
          client: MockClient((r) async => respond(r)),
        ),
        await SharedPreferences.getInstance(),
        session: session,
      );
      await s.load();
      final c = DocentConversation(s, Artwork.fromJson(work));
      await pumpEventQueue(); // let the saved history finish restoring
      expect(c.canSend, isTrue);
      await c.ask('질문 하나');
      final shown = c.messages.last.suggestion!;
      expect(shown.collections, [('3', '풍속화')]);
      expect(shown.createsCollection, isFalse);
      await c.ask('질문 둘');
      expect(c.messages.last.suggestion, isNull); // not offered again
      c.closeSuggestion(c.messages[1]);
      expect(c.messages[1].suggestion, isNull);
      c.dispose();
      s.dispose();
      await session.events.close();
    },
  );
}
