import 'dart:convert';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/pages/community_page.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/ui/design.dart' show ArtlogScope;
import 'package:artlog_web/ui/feed_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connected_features_test.dart' show SessionFake;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'ChironSungHK',
    )..addFont(rootBundle.load('assets/fonts/ChironSungHK-Web.ttf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ArtlogState> demo() async {
    final s = ArtlogState(
      const AppConfig(demo: true, authProvider: 'api'),
      ArtlogApi(baseUrl: 'https://example.org'),
      await SharedPreferences.getInstance(),
    );
    await s.load();
    return s;
  }

  void size(WidgetTester t, double width, double height) {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Widget host(ArtlogState s, Widget child) => ArtlogScope(
    state: s,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets(
    'feed stays within 1280px and long posts keep equal card heights',
    (t) async {
      size(t, 1920, 1200);
      final s = (await t.runAsync(demo))!;
      final short = await s.saveDiary(
        '2026-10-14',
        '짧은 감상',
        true,
        s.artworks.first.id,
      );
      final longText = List.filled(50, '긴 감상의 모든 문장을 읽을 수 있어요.').join(' ');
      final long = await s.saveDiary(
        '2026-10-14',
        longText,
        true,
        s.artworks[1].id,
      );
      await t.pumpWidget(host(s, const CommunityPage()));
      await t.pumpAndSettle();
      expect(
        t.getSize(find.byKey(const ValueKey('community-content'))).width,
        1280,
      );
      final before = t
          .getSize(find.byKey(ValueKey('feed-post-${short.id}')))
          .height;
      expect(
        t.getSize(find.byKey(ValueKey('feed-post-${long.id}'))).height,
        before,
      );
      await t.tap(find.byKey(ValueKey('read-impression-${long.id}')));
      await t.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(longText)),
        findsOneWidget,
      );
      await t.tap(find.text('닫기'));
      await t.pumpAndSettle();
      expect(
        t.getSize(find.byKey(ValueKey('feed-post-${long.id}'))).height,
        before,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );

  testWidgets(
    'calendar record panel matches actual calendar height across months',
    (t) async {
      size(t, 1280, 1200);
      final s = (await t.runAsync(demo))!;
      await t.pumpWidget(
        host(s, const FeedCalendar(initialDate: '2026-10-14')),
      );
      await t.pumpAndSettle();
      double calendar() =>
          t.getSize(find.byKey(const ValueKey('calendar-main-panel'))).height;
      double records() =>
          t.getSize(find.byKey(const ValueKey('calendar-record-panel'))).height;
      expect(records(), closeTo(calendar(), .5));
      final october = calendar();
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byTooltip('다음 달'));
        await t.pumpAndSettle();
      }
      expect(calendar(), greaterThan(october));
      expect(records(), closeTo(calendar(), .5));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );

  testWidgets('logout stays at the bottom of settings without scrolling', (
    t,
  ) async {
    size(t, 1280, 900);
    final session = SessionFake();
    final s = ArtlogState(
      const AppConfig(demo: false, authProvider: 'firebase'),
      ArtlogApi(
        baseUrl: 'https://example.org',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(
              r.url.path == '/api/me/social'
                  ? {'id': 'public-a', 'nickname': '감상가'}
                  : [],
            ),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ),
      await SharedPreferences.getInstance(),
      session: session,
    );
    await s.load();
    await t.pumpWidget(ArtlogApp(state: s));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('설정'));
    await t.pumpAndSettle();
    final drawer = t.getRect(find.byKey(const ValueKey('account-drawer')));
    final logout = t.getRect(find.byKey(const ValueKey('drawer-logout')));
    expect(drawer.bottom - logout.bottom, closeTo(24, 1));
    expect(logout.top, greaterThan(drawer.center.dy));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
    await session.events.close();
  });
}
