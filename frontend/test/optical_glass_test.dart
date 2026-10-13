import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:artlog_web/ui/design.dart';
import 'package:artlog_web/ui/app_theme.dart';

void main() {
  testWidgets('selected glass chip retains its dark surface and toggles', (
    tester,
  ) async {
    var selected = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: artlogTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => GlassChoiceChip(
              label: const Text('내 컬렉션'),
              selected: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    final chip = find.byType(ChoiceChip);
    final material = find.descendant(of: chip, matching: find.byType(Material));
    expect(material, findsOneWidget);
    // A transparent Ink alone still hides the dark glass if Material is white.
    expect(Theme.of(tester.element(material)).canvasColor, Colors.transparent);
    expect(tester.widget<ChoiceChip>(chip).labelStyle!.color, Colors.white);
    expect(tester.widget<GlassSurface>(find.byType(GlassSurface)).dark, isTrue);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(selected, false);
    expect(tester.widget<ChoiceChip>(chip).labelStyle!.color, ink);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'glass buttons preserve keyboard activation and disabled actions',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var activated = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: artlogTheme(),
          home: Scaffold(
            body: Column(
              children: [
                OutlinedButton(
                  focusNode: focus,
                  onPressed: () => activated++,
                  child: const Text('키보드로 담기'),
                ),
                const ArtButton('저장 대기', onTap: null),
              ],
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(activated, 1);
      await tester.tap(find.text('저장 대기'));
      await tester.pumpAndSettle();
      expect(activated, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('pointer reflections settle without scheduling idle frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: artlogTheme(),
        home: Scaffold(
          body: Center(
            child: GlassSurface(
              padding: const EdgeInsets.all(28),
              child: ArtButton('그림 감상하기', onTap: () {}),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(GlassSurface)));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, false);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, false);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'glass dialog keeps layout and focus at 320px with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: artlogTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ArtButton(
                '설정 열기',
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (c) => GlassAlertDialog(
                    title: const Text('나만의 감상 설정'),
                    content: const SizedBox(
                      width: 400,
                      child: TextField(
                        decoration: InputDecoration(labelText: '컬렉션 이름'),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('닫기'),
                      ),
                      ArtButton('설정 저장', onTap: () => Navigator.pop(c)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('설정 열기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '빛이 머무는 그림');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('설정 저장'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
