import 'dart:math' as math;
import 'package:artlog_web/api/artlog_api.dart';
import 'package:artlog_web/config.dart';
import 'package:artlog_web/main.dart';
import 'package:artlog_web/state.dart';
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

  for (final (width, columns) in [(1280.0, 3), (390.0, 2), (320.0, 1)]) {
    testWidgets(
      'museum wall fits ${width.toInt()}px in $columns columns and preserves artwork actions',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = (await tester.runAsync(boot))!;
        await tester.pumpWidget(ArtlogApp(state: state));
        await tester.pumpAndSettle();
        final cards = find.byType(ArtworkCard);
        expect(cards, findsNWidgets(6));
        final topByColumn = <int, double>{};
        for (final element in cards.evaluate()) {
          final card = find.byWidget(element.widget);
          final bounds = tester.getRect(card);
          final x = bounds.left.round();
          topByColumn[x] = math.min(
            topByColumn[x] ?? double.infinity,
            bounds.top,
          );
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(width));
        }
        expect(topByColumn.length, columns);
        if (columns > 1) {
          expect(topByColumn.values.toSet().length, greaterThan(1));
        }
        expect(
          tester.widgetList<ArtworkCard>(cards).every((card) => card.museum),
          isTrue,
        );
        final first = tester.widget<ArtworkCard>(cards.first).art;
        final like = find.byTooltip('${first.title} 좋아요');
        await Scrollable.ensureVisible(tester.element(like), alignment: .3);
        await tester.pumpAndSettle();
        await tester.tap(like);
        await tester.pumpAndSettle();
        expect(state.likes, contains(first.id));
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }

  testWidgets(
    'the exhibition page is dark and paper pages retain their palette',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = (await tester.runAsync(boot))!;
      await tester.pumpWidget(ArtlogApp(state: state));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        museumBlack,
      );
      await tester.tap(find.byKey(const ValueKey('navigation-/library')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        paper,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
