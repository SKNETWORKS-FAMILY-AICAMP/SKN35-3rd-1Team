import 'dart:convert';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/models.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/ui/daily_artwork_hero.dart';
import 'package:artlog_web/ui/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('daily selection is stable, contains only three and varies artists', () {
    final works = [
      for (var i = 0; i < 8; i++)
        Artwork(
          id: '$i',
          slug: '$i',
          title: '작품 $i',
          artistId: '${i ~/ 2}',
          image: 'https://example.org/$i.jpg',
          isFeatured: i < 6,
        ),
    ];
    final first = dailyArtworks(works, '2026-10-14');
    expect(first.length, 3);
    expect(first.map((w) => w.artistId).toSet().length, 3);
    expect(first.every((w) => w.isFeatured), isTrue);
    expect(
      dailyArtworks(works, '2026-10-14').map((w) => w.id),
      first.map((w) => w.id),
    );
    expect(dailyArtworks([], '2026-10-14'), isEmpty);
    expect(dailyArtworks(works.take(1).toList(), '2026-10-14').length, 1);
  });

  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'fullscreen hero cycles exactly three works at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final state = ArtlogState(
          const AppConfig(demo: true),
          ArtlogApi(baseUrl: 'https://example.org'),
          await SharedPreferences.getInstance(),
        );
        await tester.runAsync(state.load);
        await tester.pumpWidget(ArtlogApp(state: state));
        await tester.pumpAndSettle();
        final hero = find.byKey(const ValueKey('daily-fullscreen-hero'));
        expect(tester.getSize(hero), Size(width, 900 - 128));
        expect(
          tester
              .widget<DailyArtworkHero>(find.byType(DailyArtworkHero))
              .works
              .length,
          3,
        );
        for (final index in [1, 2, 0]) {
          await tester.tap(find.byTooltip('다음 오늘의 그림'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(ValueKey('hero-dot-$index-active')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }

  testWidgets(
    'hero caption fits below the museum navigation at a 720px desktop height',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final state = ArtlogState(
        const AppConfig(demo: true),
        ArtlogApi(baseUrl: 'https://example.org'),
        await SharedPreferences.getInstance(),
      );
      await tester.runAsync(state.load);
      await tester.pumpWidget(ArtlogApp(state: state));
      await tester.pumpAndSettle();
      final hero = find.byType(DailyArtworkHero);
      final art = tester.widget<DailyArtworkHero>(hero).works.first;
      expect(tester.getSize(hero).height, 592);
      expect(
        tester
            .getBottomRight(find.text('${state.artistName(art)} · ${art.year}'))
            .dy,
        lessThanOrEqualTo(720),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets(
    'journal previews three works and opens remaining works in a bounded sheet',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final works = [
        for (var i = 1; i <= 5; i++)
          {'id': i, 'slug': '$i', 'title': '작품 $i', 'artist_id': 1},
      ];
      final api = ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient(
          (r) async => http.Response.bytes(
            utf8.encode(
              jsonEncode(
                r.url.path == '/api/artworks' ||
                        r.url.path.contains('/library/days/')
                    ? works
                    : [],
              ),
            ),
            200,
          ),
        ),
      )..token = 'test';
      final state = ArtlogState(
        const AppConfig(demo: false),
        api,
        await SharedPreferences.getInstance(),
      );
      await state.load();
      await tester.pumpWidget(
        ArtlogApp(state: state, initialLocation: '/library?tab=calendar'),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('journal-preview-'),
        ),
        findsNWidgets(3),
      );
      await tester.ensureVisible(find.text('전체 5점 보기'));
      await tester.tap(find.text('전체 5점 보기'));
      await tester.pumpAndSettle();
      expect(find.text('이날 감상한 5점'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('day-works-sheet')),
          matching: find.byType(ListTile),
        ),
        findsNWidgets(5),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets('surfaces remain opaque with high contrast', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: SurfacePanel(child: Text('읽기 쉬운 메뉴')),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('읽기 쉬운 메뉴'), findsOneWidget);
  });
}
