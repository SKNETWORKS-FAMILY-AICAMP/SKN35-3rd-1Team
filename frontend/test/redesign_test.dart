import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/models.dart';
import 'package:artlog_web/pages/artists_page.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/ui/daily_artwork_hero.dart';
import 'package:artlog_web/ui/design.dart';

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

  void desktop(WidgetTester tester, [double width = 1280]) {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('random banner picks distinct pictured works per seed', () async {
    final s = await demo();
    final picked = randomArtworks(s.artworks, 7);
    expect(picked, hasLength(3));
    expect(picked.map((a) => a.id).toSet(), hasLength(3));
    expect(
      randomArtworks(s.artworks, 7).map((a) => a.id),
      picked.map((a) => a.id),
    );
    expect(randomArtworks(const [], 1), isEmpty);
    s.dispose();
  });

  test('chat style tab value is sent with streamed questions', () async {
    late Map<String, dynamic> body;
    final api = ArtlogApi(
      baseUrl: 'https://example.org',
      client: MockClient.streaming((request, stream) async {
        body =
            jsonDecode(await utf8.decodeStream(stream)) as Map<String, dynamic>;
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              'event: done\ndata: ${jsonEncode({'answer': '답', 'refused': false, 'sources': []})}\n\n',
            ),
          ),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );
    await api.chatStream(
      '1',
      '질문',
      const [],
      style: 'deep',
      onToken: (_) async {},
      onReplace: (_) async {},
    );
    expect(body['explanation_style'], 'deep');
    api.close();
  });

  testWidgets('docent chat starts on Standard and switches tabs', (
    tester,
  ) async {
    desktop(tester);
    final s = (await tester.runAsync(demo))!;
    final id = s.artworks.first.id;
    await tester.pumpWidget(
      ArtlogApp(state: s, initialLocation: '/artwork/$id'),
    );
    await tester.pumpAndSettle();
    Semantics tab(String style) => tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(ValueKey('docent-style-$style')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(tab('standard').properties.selected, isTrue);
    await tester.tap(find.byKey(const ValueKey('docent-style-easy')));
    await tester.pumpAndSettle();
    expect(tab('easy').properties.selected, isTrue);
    expect(tab('standard').properties.selected, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('artwork list toggles views and the artist view has no tabs', (
    tester,
  ) async {
    desktop(tester);
    final s = (await tester.runAsync(demo))!;
    await tester.pumpWidget(ArtlogApp(state: s, initialLocation: '/artworks'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtworkCard), findsWidgets);
    expect(find.byKey(const ValueKey('artworks-tab-')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('artworks-view-artists')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('artworks-tab-')), findsNothing);
    expect(find.byType(ArtistGrid), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('artworks-search')),
      s.artists.first.name,
    );
    await tester.pumpAndSettle();
    expect(find.text(s.artists.first.name), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('artwork card heart sits bottom-right and turns red when liked', (
    tester,
  ) async {
    desktop(tester);
    final s = (await tester.runAsync(demo))!;
    await tester.pumpWidget(ArtlogApp(state: s, initialLocation: '/artworks'));
    await tester.pumpAndSettle();
    final art = s.artworks.first;
    final like = find.byKey(ValueKey('artwork-like-${art.id}'));
    Icon heart() => tester.widget<Icon>(
      find.descendant(of: like, matching: find.byType(Icon)),
    );
    expect(heart().color, Colors.white);
    await tester.tap(like);
    await tester.pumpAndSettle();
    expect(heart().color, likeRed);
    expect(s.likes, contains(art.id));
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('settings panel replaces 마이페이지 and has no 감상 설정', (tester) async {
    desktop(tester);
    final s = (await tester.runAsync(demo))!;
    await tester.pumpWidget(ArtlogApp(state: s));
    await tester.pumpAndSettle();
    expect(find.byTooltip('작품 검색'), findsNothing);
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-drawer')), findsOneWidget);
    expect(find.text('감상 설정'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('main page sends more artworks to the artwork list', (
    tester,
  ) async {
    desktop(tester);
    final s = (await tester.runAsync(demo))!;
    await tester.pumpWidget(ArtlogApp(state: s));
    await tester.pumpAndSettle();
    expect(find.text('새롭게 만나볼 작가'), findsNothing);
    expect(find.text('그림 너머, 작가의 이야기'), findsOneWidget);
    final more = find.byKey(const ValueKey('gallery-more-artworks'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('작품 리스트'), findsWidgets);
    expect(find.byKey(const ValueKey('artworks-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('liked artworks appear as the default collection', (
    tester,
  ) async {
    desktop(tester);
    final s = (await tester.runAsync(demo))!;
    await s.toggleLike(s.artworks.first.id);
    await tester.pumpWidget(
      ArtlogApp(state: s, initialLocation: '/library?tab=collections'),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('collection-liked-default'));
    expect(card, findsOneWidget);
    expect(find.text('1점 · 좋아요를 누르면 자동으로 담겨요'), findsOneWidget);
    await tester.tap(find.text('좋아요한 작품'));
    await tester.pumpAndSettle();
    expect(find.byType(ArtworkCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('side panel toggles follow-list visibility', (tester) async {
    desktop(tester);
    final s = (await tester.runAsync(demo))!;
    await tester.pumpWidget(ArtlogApp(state: s));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-/mypage')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('drawer-follow-visibility'));
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect((await s.mySocial()).followListPublic, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('artwork impressions render as comments and post publicly', (
    tester,
  ) async {
    desktop(tester);
    final s = (await tester.runAsync(demo))!;
    final art = s.artworks.first;
    await tester.pumpWidget(
      ArtlogApp(state: s, initialLocation: '/artwork/${art.id}'),
    );
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('impression-input'));
    await Scrollable.ensureVisible(tester.element(input), alignment: .5);
    await tester.pumpAndSettle();
    await tester.enterText(input, '붓질이 오래 남는다');
    await tester.tap(find.byKey(const ValueKey('impression-submit')));
    await tester.pumpAndSettle();
    final today = seoulDate();
    final entry = (await s.diaryMonth(today.substring(0, 7))).single;
    expect(find.byKey(ValueKey('comment-${entry.id}')), findsOneWidget);
    expect(entry.isPublic, isTrue);
    expect(entry.artwork?.id, art.id);
    final author = find.byKey(ValueKey('comment-author-${entry.id}'));
    await Scrollable.ensureVisible(tester.element(author), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(author);
    await tester.pumpAndSettle();
    expect(find.text('내 피드로'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
