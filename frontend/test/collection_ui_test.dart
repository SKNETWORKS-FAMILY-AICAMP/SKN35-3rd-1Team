import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/models.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/ui/app_theme.dart';
import 'package:artlog_web/ui/collection_assistant.dart';
import 'package:artlog_web/ui/design.dart';
import 'package:artlog_web/ui/docent_chat.dart';

const artwork = Artwork(id: '1', slug: 'ssireum', title: '씨름', artistId: '1');

http.Response utf8Response(
  String body,
  int status, {
  Map<String, String>? headers,
}) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
);

Future<ArtlogState> member(MockClient client) async {
  SharedPreferences.setMockInitialValues({});
  return ArtlogState(
      const AppConfig(demo: false, authProvider: 'api'),
      ArtlogApi(baseUrl: 'https://example.test', client: client)
        ..token = 'test-token',
      await SharedPreferences.getInstance(),
    )
    ..email = 'test@example.test'
    ..artworks = [artwork];
}

Widget app(ArtlogState state, Widget child) => ArtlogScope(
  state: state,
  child: MaterialApp(
    theme: docentalkTheme(),
    home: Scaffold(body: child),
  ),
);

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('collection assistant confirms without overflow at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final writes = <http.Request>[];
      final state = await member(
        MockClient((r) async {
          if (r.method == 'GET') return utf8Response('[]', 200);
          if (r.url.path.endsWith('/chat')) {
            return utf8Response(
              jsonEncode({
                'answer': '이 작품을 모아 드릴까요?',
                'proposal': {
                  'action': 'create',
                  'name': '고요한 풍경',
                  'artwork_ids': [1],
                },
              }),
              200,
            );
          }
          writes.add(r);
          return utf8Response(
            '{"id":9,"name":"고요한 풍경","artwork_count":1,"previews":[]}',
            201,
          );
        }),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(
        app(state, CollectionAssistant(state: state, artwork: artwork)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('collection-assistant-input')),
        '씨름 모아줘',
      );
      await tester.tap(find.byTooltip('컬렉션 요청 보내기'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(find.text('씨름'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('collection-proposal-confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(writes.length, 1);
      expect(jsonDecode(writes.single.body)['artwork_ids'], [1]);
      expect(find.text('저장한 컬렉션 열기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('docent offer creates collection and artwork atomically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final writes = <http.Request>[];
    final state = await member(
      MockClient((r) async {
        if (r.method == 'GET') return utf8Response('[]', 200);
        if (r.url.path.endsWith('/stream')) {
          return utf8Response(
            'event: done\ndata: ${jsonEncode({
              'answer': '씨름의 구도를 살펴보세요.',
              'sources': [],
              'refused': false,
              'suggestion': {'kind': 'add_artwork', 'message': '컬렉션에 담아 드릴까요?', 'artwork_id': 1, 'collections': []},
            })}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }
        writes.add(r);
        return utf8Response(
          '{"id":9,"name":"나의 그림","artwork_count":1,"previews":[]}',
          201,
        );
      }),
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(
      app(
        state,
        Center(child: SizedBox(width: 700, child: DocentChat(artwork))),
      ),
    );
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    await tester.enterText(input, '구도를 설명해줘');
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('질문 보내기'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('새 컬렉션'));
    await tester.tap(find.text('새 컬렉션'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '컬렉션 이름'), '나의 그림');
    await tester.tap(find.text('컬렉션 저장'));
    await tester.pumpAndSettle();
    expect(writes.length, 1);
    expect(writes.single.url.path, '/api/me/collections');
    expect(jsonDecode(writes.single.body)['artwork_ids'], [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all demo images remain loadable after moving to Flutter assets',
    (tester) async {
      final catalog = jsonDecode(
        await rootBundle.loadString('assets/catalog.json'),
      );
      expect(catalog['artworks'].length, 12);
      for (final art in catalog['artworks']) {
        expect(
          (await rootBundle.load(art['image_url'])).lengthInBytes,
          greaterThan(0),
        );
      }
    },
  );
}
