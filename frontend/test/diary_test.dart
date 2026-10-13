import 'dart:convert';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/diary.dart';
import 'package:artlog_web/models.dart';
import 'package:artlog_web/pages/library_page.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/ui/design.dart';
import 'package:artlog_web/ui/diary_editor.dart';
import 'package:artlog_web/ui/diary_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ArtlogState> state({bool demo = true, http.Client? client}) async {
    SharedPreferences.setMockInitialValues({});
    return ArtlogState(
      AppConfig(demo: demo),
      ArtlogApi(baseUrl: 'https://example.org', client: client)..token = 'test',
      await SharedPreferences.getInstance(),
    );
  }

  Widget host(ArtlogState state, Widget child) => ArtlogScope(
    state: state,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  test(
    'published diary disappears from feed when made private or deleted',
    () async {
      final s = await state();
      await s.saveDiary('2026-10-13', '공개 감상', true, null);
      expect((await s.diaryFeed()).entries.single.content, '공개 감상');
      await s.saveDiary('2026-10-13', '비공개 감상', false, null);
      expect((await s.diaryFeed()).entries, isEmpty);
      expect((await s.diaryMonth('2026-10')).single.isPublic, isFalse);
      await s.deleteDiary('2026-10-13');
      expect(await s.diaryMonth('2026-10'), isEmpty);
      s.dispose();
    },
  );

  test(
    'live diary contract and feed pagination use correct methods and IDs',
    () async {
      final requests = <http.Request>[];
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode(
              r.method == 'DELETE'
                  ? null
                  : r.url.path.endsWith('/feed')
                  ? {'items': [], 'next_cursor': 17}
                  : {
                      'id': 1,
                      'entry_date': '2026-10-13',
                      'content': '기록',
                      'is_public': false,
                    },
            ),
            r.method == 'DELETE' ? 204 : 200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..token = 'test';
      await api.saveDiary('2026-10-13', '기록', false, '42');
      expect(jsonDecode(requests.single.body), {
        'content': '기록',
        'is_public': false,
        'artwork_id': 42,
      });
      expect(requests.single.headers['Authorization'], 'Bearer test');
      expect(
        (await api.diaryFeed(cursor: '21', artworkId: '42')).nextCursor,
        '17',
      );
      expect(requests.last.url.queryParameters, {
        'limit': '12',
        'before_id': '21',
        'artwork_id': '42',
      });
      await api.deleteDiary('2026-10-13');
      expect(requests.last.method, 'DELETE');
      api.close();
    },
  );

  test(
    'detail and recommendations reuse requests and invalidate on logout',
    () async {
      final requests = <String>[];
      final s = await state(
        demo: false,
        client: MockClient((r) async {
          requests.add(r.url.path);
          return http.Response(
            jsonEncode(
              r.url.path.contains('recommendations')
                  ? []
                  : {'id': 1, 'title': '그림'},
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await Future.wait([
        s.detail('1'),
        s.detail('1'),
        s.personalArtworks(),
        s.personalArtworks(),
      ]);
      expect(requests.where((p) => p.endsWith('/artworks/1')).length, 1);
      expect(requests.where((p) => p.contains('recommendations')).length, 1);
      await s.personalArtworks(force: true);
      expect(requests.where((p) => p.contains('recommendations')).length, 2);
      await s.logout();
      s.api.token = 'another-user';
      await s.personalArtworks();
      expect(requests.where((p) => p.contains('recommendations')).length, 3);
      s.dispose();
    },
  );

  testWidgets(
    'typing in the journal does not rebuild calendar cells; saves mark diary-only day',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = await state();
      await tester.pumpWidget(host(s, const LibraryPage()));
      await tester.pumpAndSettle();
      final today = DateTime.parse(seoulDate());
      final label = '${today.month}월 ${today.day}일, 0점 감상';
      final cell = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      );
      final before = tester.widget<Semantics>(cell);
      await tester.enterText(
        find.byKey(const ValueKey('diary-content')),
        '고요한 색이 마음에 남았다.',
      );
      await tester.pump();
      expect(identical(before, tester.widget<Semantics>(cell)), isTrue);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.ensureVisible(find.text('감상평 저장'));
      await tester.tap(find.text('감상평 저장'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == '$label, 감상평 있음',
        ),
        findsOneWidget,
      );
      expect(
        (await s.diaryMonth(seoulDate().substring(0, 7))).single.content,
        '고요한 색이 마음에 남았다.',
      );
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );

  for (final width in [320.0, 1280.0]) {
    testWidgets('diary editor and public feed fit ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = await state();
      await s.saveDiary('2026-10-13', '다른 눈으로 보는 그림', true, null);
      await tester.pumpWidget(
        host(
          s,
          Column(
            children: [
              DiaryEditor(
                date: '2026-10-13',
                entry: const DiaryEntry(
                  id: '1',
                  date: '2026-10-13',
                  content: '감상',
                ),
                onSaved: (_) {},
                onDeleted: () {},
              ),
              const DiaryFeedView(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('다른 눈으로 보는 그림'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await s.saveDiary('2026-10-13', '이제 나만 보는 그림', false, null);
      await tester.pumpAndSettle();
      expect(find.text('다른 눈으로 보는 그림'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    });
  }
}
