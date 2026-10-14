import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/pages/collection_page.dart';
import 'package:artlog_web/ui/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connected_features_test.dart' show SessionFake;

Future<ArtlogState> boot({SessionFake? session}) async {
  SharedPreferences.setMockInitialValues({});
  final s = ArtlogState(
    AppConfig(demo: true, authProvider: session == null ? 'none' : 'firebase'),
    ArtlogApi(baseUrl: 'https://example.org'),
    await SharedPreferences.getInstance(),
    session: session,
  );
  await s.load();
  final c = await s.saveCollection('빛을 따라 걷는 전시', '그림마다 다른 빛과 시간을 모았습니다.');
  for (final art in s.artworks.take(4)) {
    await s.collect(c.id, art.id);
  }
  return s;
}

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'collection opens as a page at $width and supports removing, adding and returning',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = (await tester.runAsync(boot))!;
        await tester.pumpWidget(
          ArtlogApp(state: s, initialLocation: '/mypage?tab=collections'),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('빛을 따라 걷는 전시'));
        await tester.tap(find.text('빛을 따라 걷는 전시'));
        await tester.pumpAndSettle();
        expect(find.byType(CollectionPage), findsOneWidget);
        final router = GoRouter.of(tester.element(find.byType(CollectionPage)));
        expect(
          router.routeInformationProvider.value.uri.path,
          startsWith('/collection/'),
        );
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(ArtworkCard), findsNWidgets(4));
        await tester.ensureVisible(find.text('작품 정리'));
        await tester.tap(find.text('작품 정리'));
        await tester.pumpAndSettle();
        final remove = find.widgetWithText(OutlinedButton, '컬렉션에서 꺼내기').first;
        await Scrollable.ensureVisible(tester.element(remove), alignment: .4);
        await tester.pumpAndSettle();
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect((await s.collections()).single.count, 3);
        expect(find.byType(ArtworkCard), findsNWidgets(3));
        final art = s.artworks.first;
        final search = find.widgetWithText(TextField, '담고 싶은 작품 찾기');
        await tester.ensureVisible(search);
        await tester.enterText(search, art.title);
        await tester.pumpAndSettle();
        final add = find.byTooltip('${art.title} 담기');
        await Scrollable.ensureVisible(tester.element(add), alignment: .4);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect((await s.collections()).single.count, 4);
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('collection-back'))),
          alignment: .2,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('collection-back')));
        await tester.pumpAndSettle();
        expect(find.byType(CollectionPage), findsNothing);
        expect(find.text('빛을 따라 걷는 전시'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
  }

  testWidgets(
    'direct links load from saved collections and hide another account immediately',
    (tester) async {
      final auth = SessionFake();
      final s = (await tester.runAsync(() => boot(session: auth)))!;
      s.setAuthUiOpen(true);
      final id = (await s.collections()).single.id;
      await tester.pumpWidget(
        ArtlogApp(state: s, initialLocation: '/collection/$id'),
      );
      await tester.pumpAndSettle();
      expect(find.text('빛을 따라 걷는 전시'), findsOneWidget);
      auth.change('b');
      await tester.pumpAndSettle();
      expect(find.text('빛을 따라 걷는 전시'), findsNothing);
      expect(find.byType(ArtworkCard), findsNothing);
      expect(find.text('컬렉션을 찾을 수 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
      await auth.events.close();
    },
  );
}
