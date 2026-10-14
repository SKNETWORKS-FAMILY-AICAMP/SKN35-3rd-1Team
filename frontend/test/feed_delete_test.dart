import 'dart:convert';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/diary.dart';
import 'package:artlog_web/pages/feed_page.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/ui/design.dart';
import 'package:artlog_web/ui/diary_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connected_features_test.dart' show SessionFake;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ArtlogState> demo() async {
    final s = ArtlogState(
      const AppConfig(demo: true, authProvider: 'none'),
      ArtlogApi(baseUrl: 'https://example.org'),
      await SharedPreferences.getInstance(),
    );
    await s.load();
    return s;
  }

  Widget host(ArtlogState s, Widget child) => ArtlogScope(
    state: s,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('confirm-impression-delete')));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'public feed cancel and delete preserve other entries at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = (await tester.runAsync(demo))!;
        final own = await s.saveDiary('2026-10-14', '삭제할 공개 감상', true, null);
        final keep = await s.saveDiary('2026-10-14', '유지할 비공개 감상', false, null);
        await tester.pumpWidget(host(s, const DiaryFeedView()));
        await tester.pumpAndSettle();
        final button = find.byKey(ValueKey('delete-impression-${own.id}'));
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect((await s.diaryFeed()).entries.single.id, own.id);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await confirm(tester);
        expect(find.text('삭제할 공개 감상'), findsNothing);
        expect((await s.diaryMonth('2026-10')).single.id, keep.id);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
  }

  testWidgets('my feed removes a private impression and refreshes its rows', (
    tester,
  ) async {
    final s = (await tester.runAsync(demo))!;
    final own = await s.saveDiary('2026-10-14', '나만 보는 감상', false, null);
    await tester.pumpWidget(host(s, const MyFeedPage()));
    await tester.pumpAndSettle();
    final button = find.byKey(ValueKey('delete-impression-${own.id}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(find.byKey(ValueKey('impression-row-${own.id}')), findsNothing);
    expect(await s.diaryMonth('2026-10'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('private artwork comment deletion updates the artwork feed', (
    tester,
  ) async {
    final s = (await tester.runAsync(demo))!;
    final art = s.artworks.first;
    final own = await s.saveDiary('2026-10-14', '작품의 비공개 감상', false, art.id);
    await tester.pumpWidget(host(s, DiaryFeedView(artworkId: art.id)));
    await tester.pumpAndSettle();
    final button = find.byKey(ValueKey('delete-impression-${own.id}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(find.byKey(ValueKey('comment-${own.id}')), findsNothing);
    expect(await s.diaryForArtwork(art.id), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  for (final switchAccount in [false, true]) {
    testWidgets(
      switchAccount
          ? 'account switch closes delete confirmation without DELETE'
          : 'only owner can delete, failed DELETE preserves entry and permits retry',
      (tester) async {
        final session = SessionFake();
        final deletes = <http.Request>[];
        var fail = true, refreshed = 0;
        final s = ArtlogState(
          const AppConfig(demo: false, authProvider: 'firebase'),
          ArtlogApi(
            baseUrl: 'https://example.org',
            client: MockClient((r) async {
              if (r.method == 'DELETE') {
                deletes.add(r);
                return http.Response('', fail ? 500 : 204);
              }
              return http.Response(
                jsonEncode(switch (r.url.path) {
                  '/api/me/social' => {
                    'id': 'public-${session.user!.uid}',
                    'nickname': '감상가',
                    'is_me': true,
                  },
                  '/api/me/profile' => {'onboarding_completed': true},
                  _ => [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
          await SharedPreferences.getInstance(),
          session: session,
        );
        await s.load();
        await tester.runAsync(s.loadFollowing);
        final beforeRevision = s.diaryRevision;
        const own = DiaryEntry(
          id: '71',
          date: '2026-10-14',
          content: '내 감상',
          authorId: 'public-a',
        );
        const other = DiaryEntry(
          id: '72',
          date: '2026-10-14',
          content: '다른 감상',
          authorId: 'public-b',
        );
        await tester.pumpWidget(
          host(
            s,
            Column(
              children: [
                ImpressionDeleteButton(
                  entry: own,
                  onDeleted: () => refreshed++,
                ),
                const ImpressionDeleteButton(entry: other),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('delete-impression-72')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('delete-impression-71')));
        await tester.pumpAndSettle();
        if (switchAccount) {
          session.change('b');
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('confirm-impression-delete')),
            findsNothing,
          );
          expect(deletes, isEmpty);
        } else {
          await confirm(tester);
          expect(refreshed, 0);
          expect(
            s.diaryRevision,
            beforeRevision,
          );
          fail = false;
          await tester.tap(find.byKey(const ValueKey('delete-impression-71')));
          await tester.pumpAndSettle();
          await confirm(tester);
          expect(refreshed, 1);
          expect(deletes, hasLength(2));
          expect(deletes.last.url.path, '/api/me/diary/71');
          expect(deletes.last.headers['Authorization'], 'Bearer token-a');
        }
        await tester.pumpWidget(const SizedBox());
        s.dispose();
        await session.events.close();
      },
    );
  }
}
