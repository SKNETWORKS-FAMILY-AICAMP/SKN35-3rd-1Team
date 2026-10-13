import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    // Flutter Web sets accessibleNavigation whenever its semantics tree is
    // enabled, including our always-available keyboard/screen-reader support.
    // The browser's prefers-reduced-motion maps to disableAnimations instead.
    (!kIsWeb && MediaQuery.accessibleNavigationOf(context));

/// Only the active route's outer scroll view drives the shared choreography.
/// Nested conversations, carousels and sheets never move the app header.
class PageMotionController extends ChangeNotifier {
  ScrollController? _scroll;
  double offset = 0, viewport = 0, extent = 0;
  bool _disposed = false;
  double get progress => extent <= 0 ? 0 : (offset / extent).clamp(0, 1);

  void returnToTop({required bool immediately}) {
    if (_scroll?.hasClients != true) return;
    if (immediately) {
      _scroll!.jumpTo(0);
    } else {
      _scroll!.animateTo(
        0,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void bind(ScrollController scroll) {
    if (identical(_scroll, scroll)) return;
    _scroll?.removeListener(refresh);
    _scroll = scroll..addListener(refresh);
    offset = viewport = extent = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && identical(_scroll, scroll)) refresh();
    });
  }

  void unbind(ScrollController scroll) {
    if (!identical(_scroll, scroll)) return;
    scroll.removeListener(refresh);
    _scroll = null;
  }

  void refresh() {
    if (_disposed || _scroll?.hasClients != true) return;
    final position = _scroll!.position;
    if (!position.hasContentDimensions) return;
    final nextOffset = position.pixels.clamp(0.0, position.maxScrollExtent);
    if (offset == nextOffset &&
        viewport == position.viewportDimension &&
        extent == position.maxScrollExtent) {
      return;
    }
    offset = nextOffset;
    viewport = position.viewportDimension;
    extent = position.maxScrollExtent;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scroll?.removeListener(refresh);
    super.dispose();
  }
}

class PageMotionScope extends InheritedWidget {
  const PageMotionScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final PageMotionController controller;
  static PageMotionController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageMotionScope>()?.controller;
  @override
  bool updateShouldNotify(PageMotionScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Reveals a section once when it enters the outer viewport. After completing,
/// it detaches from scrolling; there are no timers or perpetual frame callbacks.
class ScrollReveal extends StatefulWidget {
  const ScrollReveal({super.key, required this.child, this.order = 0});
  final Widget child;
  final int order;
  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(vsync: this, value: 1);
  PageMotionController? motion;
  bool initialized = false, revealed = false;
  double distance = 24;
  late Animation<double> eased;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PageMotionScope.maybeOf(context);
    final reduced = reduceMotion(context);
    final mobile = MediaQuery.sizeOf(context).width < 850;
    distance = mobile ? 12 : 24;
    final delay = widget.order.clamp(0, 3) * (mobile ? 30 : 45);
    final duration = mobile ? 380 : 540;
    animation.duration = Duration(milliseconds: duration + delay);
    eased = animation.drive(
      CurveTween(
        curve: Interval(
          delay / (duration + delay),
          1,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    if (motion != next) {
      motion?.removeListener(checkVisibility);
      motion = next;
      if (!revealed) motion?.addListener(checkVisibility);
    }
    if (reduced || next == null) {
      reveal(immediately: true);
    } else if (!initialized) {
      animation.value = 0;
    }
    initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => checkVisibility());
  }

  void checkVisibility() {
    if (!mounted || revealed || motion == null || motion!.viewport <= 0) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final top = viewport.getOffsetToReveal(box, 0).offset;
    final threshold = math.min(box.size.height * .12, 64);
    if (top + threshold <= motion!.offset + motion!.viewport) reveal();
  }

  void reveal({bool immediately = false}) {
    revealed = true;
    motion?.removeListener(checkVisibility);
    if (immediately) {
      animation.value = 1;
    } else {
      animation.forward();
    }
  }

  @override
  void dispose() {
    motion?.removeListener(checkVisibility);
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onFocusChange: (focused) {
      if (focused && !revealed) reveal(immediately: true);
    },
    child: AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: eased.value,
        alwaysIncludeSemantics: true,
        child: Transform.translate(
          offset: Offset(0, distance * (1 - eased.value)),
          child: child,
        ),
      ),
    ),
  );
}

/// Button content reacts to pointer and keyboard states while its native hit
/// area, focus ring and disabled behavior remain unchanged.
Widget buttonMotionBuilder(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) {
  if (reduceMotion(context)) return child ?? const SizedBox.shrink();
  final pressed = states.contains(WidgetState.pressed);
  final hovered =
      states.contains(WidgetState.hovered) &&
      !states.contains(WidgetState.disabled);
  return AnimatedScale(
    scale: pressed ? .97 : 1,
    duration: const Duration(milliseconds: 160),
    curve: Curves.easeOutCubic,
    child: AnimatedSlide(
      offset: Offset(0, hovered && !pressed ? -.035 : 0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: child,
    ),
  );
}
