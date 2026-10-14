import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/state.dart';
import 'package:artlog_web/ui/design.dart';
import 'package:artlog_web/ui/shell.dart';
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

  ScrollController outer(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(
        find
            .descendant(
              of: find.byType(AppPage),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      )
      .controller!;

  final header = find.byKey(const ValueKey('primary-header'));
  final panel = find.byKey(const ValueKey('daily-information-panel'));
  final parallax = find.byKey(const ValueKey('daily-artwork-parallax'));

  testWidgets(
    'scroll compacts navigation and expands the daily caption, then resets on route change',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = (await tester.runAsync(boot))!;
      await tester.pumpWidget(ArtlogApp(state: state));
      await tester.pumpAndSettle();
      final originalWidth = tester.getSize(panel).width;
      expect(tester.getSize(header).height, 80);

      // A horizontal artwork change must not collapse the outer navigation.
      await tester.tap(find.byTooltip('다음 오늘의 그림'));
      await tester.pumpAndSettle();
      expect(find.text('02 / 03'), findsOneWidget);
      expect(tester.getSize(header).height, 80);

      outer(tester).jumpTo(260);
      await tester.pumpAndSettle();
      expect(tester.getSize(header).height, 48);
      expect(tester.getSize(panel).width, greaterThan(originalWidth));
      expect(
        tester.widget<Transform>(parallax).transform.storage[13],
        greaterThan(0),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.tap(find.byKey(const ValueKey('navigation-/artworks')));
      await tester.pumpAndSettle();
      expect(tester.getSize(header).height, 80);
      expect(outer(tester).offset, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets(
    'revealed artwork cards stay visible on return and scrolling stops scheduling frames',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = (await tester.runAsync(boot))!;
      await tester.pumpWidget(ArtlogApp(state: state));
      await tester.pumpAndSettle();
      final grid = find.byType(ArtworkGrid).first;
      Finder reveals() =>
          find.descendant(of: grid, matching: find.byType(ScrollReveal));
      double opacityOf(Finder reveal) => tester
          .widget<Opacity>(
            find.descendant(of: reveal, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(opacityOf(reveals().first), 0);
      outer(tester).jumpTo(900);
      await tester.pumpAndSettle();
      expect(opacityOf(reveals().first), 1);
      outer(tester).jumpTo(0);
      await tester.pumpAndSettle();
      expect(opacityOf(reveals().first), 1);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets(
    'mobile keeps navigation stable and returns to the top using its visible control',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = (await tester.runAsync(boot))!;
      await tester.pumpWidget(ArtlogApp(state: state));
      await tester.pumpAndSettle();
      outer(tester).jumpTo(900);
      await tester.pumpAndSettle();
      expect(tester.getSize(header).height, 64);
      expect(tester.widget<Transform>(parallax).transform.storage[13], 0);
      await tester.tap(find.byTooltip('맨 위로'));
      await tester.pumpAndSettle();
      expect(outer(tester).offset, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  for (final accessible in [false, true]) {
    testWidgets(
      '${accessible ? 'accessible navigation' : 'reduced motion'} keeps every section readable and avoids parallax',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(
              disableAnimations: !accessible,
              accessibleNavigation: accessible,
            );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final state = (await tester.runAsync(boot))!;
        await tester.pumpWidget(ArtlogApp(state: state));
        await tester.pumpAndSettle();
        final initialWidth = tester.getSize(panel).width;
        for (final reveal in find.byType(ScrollReveal).evaluate()) {
          final opacity = find
              .descendant(
                of: find.byWidget(reveal.widget),
                matching: find.byType(Opacity),
              )
              .first;
          expect(tester.widget<Opacity>(opacity).opacity, 1);
        }
        outer(tester).jumpTo(900);
        await tester.pumpAndSettle();
        expect(tester.getSize(header).height, 80);
        expect(tester.getSize(panel).width, initialWidth);
        expect(tester.widget<Transform>(parallax).transform.storage[13], 0);
        await tester.tap(find.byTooltip('맨 위로'));
        await tester.pump();
        expect(outer(tester).offset, 0);
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }
}
