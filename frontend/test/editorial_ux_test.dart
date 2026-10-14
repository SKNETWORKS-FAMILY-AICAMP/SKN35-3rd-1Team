import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/models.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/ui/collection_workspace.dart';
import 'package:artlog_web/ui/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ArtlogState> boot() async {
    SharedPreferences.setMockInitialValues({});
    final state = ArtlogState(
      const AppConfig(demo: true),
      ArtlogApi(baseUrl: 'https://example.org'),
      await SharedPreferences.getInstance(),
    );
    await state.load();
    return state;
  }

  test(
    'preview feed shows newest public entries first in bounded pages',
    () async {
      final state = await boot();
      final today = DateTime.parse(seoulDate());
      for (var i = 0; i < 15; i++) {
        await state.saveDiary(
          dateKey(today.subtract(Duration(days: i))),
          '기록 $i',
          true,
          null,
        );
      }
      final first = await state.diaryFeed();
      expect(first.entries.length, 12);
      expect(first.entries.first.date, seoulDate());
      expect(first.nextCursor, isNotNull);
      final second = await state.diaryFeed(cursor: first.nextCursor);
      expect(second.entries.length, 3);
      expect(second.nextCursor, isNull);
      expect(
        {
          ...first.entries.map((e) => e.id),
          ...second.entries.map((e) => e.id),
        }.length,
        15,
      );
      state.dispose();
    },
  );

  testWidgets(
    'account change removes the old form beneath a confirmation dialog',
    (tester) async {
      final state = (await tester.runAsync(boot))!;
      state.email = 'first-account';
      await tester.pumpWidget(
        ArtlogScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AccountGuard(
                      state: state,
                      child: SurfaceDialog(
                        title: const Text('계정 전용 초안'),
                        actions: [
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => SurfaceDialog(
                                title: const Text('이동 확인'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('확인 닫기'),
                                  ),
                                ],
                              ),
                            ),
                            child: const Text('확인 창 열기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('초안 열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('초안 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인 창 열기'));
      await tester.pumpAndSettle();
      state.email = 'second-account';
      state.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('계정 전용 초안', skipOffstage: false), findsNothing);
      expect(find.text('이동 확인'), findsOneWidget);
      await tester.tap(find.text('확인 닫기'));
      await tester.pumpAndSettle();
      expect(find.text('초안 열기'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'my feed lists private impressions with a lock and opens the artwork at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = (await tester.runAsync(boot))!;
        final today = seoulDate();
        final yesterday = dateKey(
          DateTime.parse(today).subtract(const Duration(days: 1)),
        );
        await state.saveDiary(
          today,
          '나만 보관할 오늘의 생각',
          false,
          state.artworks.first.id,
        );
        await state.saveDiary(
          yesterday,
          '함께 나눌 그림 이야기',
          true,
          state.artworks[1].id,
        );
        await tester.pumpWidget(
          ArtlogApp(state: state, initialLocation: '/library'),
        );
        await tester.pumpAndSettle();
        expect(find.text('함께 나눌 그림 이야기'), findsOneWidget);
        expect(find.text('나만 보관할 오늘의 생각'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.text('감상 설정'), findsNothing);
        expect(find.text('로그아웃'), findsNothing);
        await tester.tap(find.text('나만 보관할 오늘의 생각'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('gold-frame')), findsNothing);
        expect(
          find.byKey(const ValueKey('detail-artwork-surface')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );

    testWidgets(
      'feed shows only public impressions and links authors to profiles at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = (await tester.runAsync(boot))!;
        final today = seoulDate();
        final post = await state.saveDiary(
          today,
          '빛의 방향을 따라 바라본 하루',
          true,
          state.artworks.first.id,
        );
        await state.saveDiary(
          dateKey(DateTime.parse(today).subtract(const Duration(days: 1))),
          '혼자 간직할 문장',
          false,
          null,
        );
        await tester.pumpWidget(
          ArtlogApp(state: state, initialLocation: '/community'),
        );
        await tester.pumpAndSettle();
        expect(find.text('오늘의 감상을 남겨보세요'), findsNothing);
        expect(find.textContaining('빛의 방향을 따라 바라본 하루'), findsOneWidget);
        expect(find.textContaining('혼자 간직할 문장'), findsNothing);
        await tester.tap(find.byKey(ValueKey('feed-author-${post.id}')));
        await tester.pumpAndSettle();
        expect(find.text('내 피드로'), findsOneWidget);
        expect(find.byKey(const ValueKey('member-intro')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }
}
