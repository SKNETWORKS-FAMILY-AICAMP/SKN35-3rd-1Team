import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

// Neutral mineral tones let the artwork supply the strongest colour.
const paper = Color(0xfff1f2f4);
const ink = Color(0xff202c34);
const green = Color(0xff365b67);
const muted = Color(0xff606d77);
const line = Color(0xffd8dfe2);
const sage = Color(0xff7b919d);
const pearl = Color(0xfffafbfc);
const prismMint = Color(0xffb3e4d9);
const prismLilac = Color(0xffd2c9ee);

BoxDecoration glassDecoration({
  double radius = 28,
  bool dark = false,
  bool tinted = false,
  bool translucent = false,
}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: const [0, .42, 1],
    colors: dark
        ? const [Color(0xf23c515a), Color(0xf2213039), Color(0xf519262f)]
        : translucent
        ? const [Color(0xbfffffff), Color(0x80f8fafb), Color(0xb3e4ebef)]
        : tinted
        ? const [Color(0xf2ffffff), Color(0xdfedf3f3), Color(0xe3e8eaf4)]
        : const [Color(0xfaffffff), Color(0xe6f8fafb), Color(0xe6eaf0f2)],
  ),
  border: Border.all(
    color: dark ? const Color(0x80d5e7e9) : const Color(0xedffffff),
    width: 1.15,
  ),
  boxShadow: [
    BoxShadow(
      color: const Color(0xff233540).withValues(alpha: dark ? .20 : .065),
      blurRadius: 32,
      spreadRadius: -8,
      offset: const Offset(0, 16),
    ),
    const BoxShadow(
      color: Color(0x70ffffff),
      blurRadius: 0,
      offset: Offset(0, -.5),
    ),
  ],
);

/// Static ambient light, never a full-screen blur or an idle animation.
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: paper),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (!MediaQuery.highContrastOf(context))
          const IgnorePointer(
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-1, -.7),
                    radius: 1.45,
                    colors: [Color(0x66d8e9e7), Color(0x00ffffff)],
                    stops: [0, 1],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(1, .15),
                      radius: 1.15,
                      colors: [Color(0x5cddd7ec), Color(0x00ffffff)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        child,
      ],
    ),
  );
}

/// Reflections are vector paint. Only floating navigation opts into backdrop blur.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 28,
    this.dark = false,
    this.tinted = false,
    this.blur = false,
    this.interactive = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool dark, tinted, blur, interactive;
  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  final point = ValueNotifier<Offset?>(null);
  @override
  void dispose() {
    point.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contrast = MediaQuery.highContrastOf(context),
        reduced = MediaQuery.disableAnimationsOf(context);
    final useBlur = widget.blur && !contrast && !reduced;
    Widget surface = DecoratedBox(
      decoration: contrast
          ? BoxDecoration(
              color: widget.dark ? ink : Colors.white,
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(color: widget.dark ? Colors.white : muted),
            )
          : glassDecoration(
              radius: widget.radius,
              dark: widget.dark,
              tinted: widget.tinted,
              translucent: useBlur,
            ),
      child: RepaintBoundary(
        child: CustomPaint(
          foregroundPainter: contrast
              ? null
              : GlassRimPainter(
                  radius: widget.radius,
                  dark: widget.dark,
                  point: point,
                ),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
    if (useBlur) {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: surface,
        ),
      );
    }
    if (!widget.interactive || contrast || reduced) return surface;
    return MouseRegion(
      onHover: (event) {
        if (point.value == null ||
            (point.value! - event.localPosition).distance > 6) {
          point.value = event.localPosition;
        }
      },
      onExit: (_) => point.value = null,
      child: surface,
    );
  }
}

/// A thin optical rim and two asymmetric reflections; content remains untouched.
class GlassRimPainter extends CustomPainter {
  GlassRimPainter({
    required this.radius,
    this.dark = false,
    this.focused = false,
    this.active = false,
    this.point,
  }) : super(repaint: point);
  final double radius;
  final bool dark, focused, active;
  final ValueNotifier<Offset?>? point;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(
      rect.deflate(.8),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = focused ? 2 : 1.2;
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0, .22, .48, .72, 1],
      colors: [
        Colors.white.withValues(alpha: dark ? .72 : .98),
        prismMint.withValues(alpha: active ? .8 : .4),
        Colors.white.withValues(alpha: .15),
        prismLilac.withValues(alpha: active ? .8 : .55),
        Colors.white.withValues(alpha: .88),
      ],
    ).createShader(rect);
    canvas.drawRRect(rr, paint);
    if (focused) {
      canvas.drawRRect(
        rr.deflate(2),
        Paint()
          ..color = (dark ? prismMint : green)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    // Short specular accents on the upper and lower edges resemble polished glass.
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawLine(
      Offset(radius * .7, 2),
      Offset(size.width * .58, 2),
      Paint()
        ..strokeWidth = 1
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: .2),
            Colors.white.withValues(alpha: .85),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    final p = point?.value;
    if (p != null) {
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(rr)
        ..addRRect(rr.deflate(3));
      canvas.clipPath(ring);
      canvas.drawCircle(
        p,
        180,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white,
              prismMint.withValues(alpha: .65),
              prismLilac.withValues(alpha: 0),
            ],
            stops: const [0, .4, 1],
          ).createShader(Rect.fromCircle(center: p, radius: 180)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GlassRimPainter old) =>
      radius != old.radius ||
      dark != old.dark ||
      active != old.active ||
      focused != old.focused ||
      point != old.point;
}

ButtonStyle crystalButtonStyle({
  bool dark = false,
  bool quiet = false,
  bool tinted = false,
  double radius = 100,
  Size minimumSize = const Size(44, 46),
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
    horizontal: 19,
    vertical: 12,
  ),
}) => ButtonStyle(
  backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
  foregroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled)
        ? muted
        : dark
        ? Colors.white
        : ink,
  ),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  shadowColor: const WidgetStatePropertyAll(Color(0x28233540)),
  elevation: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled) || quiet
        ? 0
        : s.contains(WidgetState.hovered)
        ? 3
        : 1,
  ),
  minimumSize: WidgetStatePropertyAll(minimumSize),
  padding: WidgetStatePropertyAll(padding),
  side: const WidgetStatePropertyAll(BorderSide.none),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
  ),
  textStyle: const WidgetStatePropertyAll(
    TextStyle(
      fontFamily: 'NotoSansKR',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: .1,
    ),
  ),
  splashFactory: NoSplash.splashFactory,
  animationDuration: Duration.zero,
  backgroundBuilder: (context, states, child) {
    final disabled = states.contains(WidgetState.disabled),
        hover = states.contains(WidgetState.hovered),
        pressed = states.contains(WidgetState.pressed),
        focus = states.contains(WidgetState.focused);
    final contrast = MediaQuery.highContrastOf(context),
        reduced = MediaQuery.disableAnimationsOf(context);
    final isDark = dark && !disabled;
    final showSurface =
        !quiet ||
        hover ||
        pressed ||
        focus ||
        states.contains(WidgetState.selected);
    return AnimatedContainer(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      decoration: !showSurface
          ? BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
            )
          : contrast
          ? BoxDecoration(
              color: isDark ? ink : Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: focus ? green : muted,
                width: focus ? 2 : 1,
              ),
            )
          : glassDecoration(
              radius: radius,
              dark: isDark,
              translucent: quiet && !hover,
              tinted: tinted,
            ).copyWith(boxShadow: const []),
      child: CustomPaint(
        foregroundPainter: contrast || !showSurface
            ? null
            : GlassRimPainter(
                radius: radius,
                dark: isDark,
                focused: focus,
                active: hover || pressed,
              ),
        child: child,
      ),
    );
  },
  foregroundBuilder: (context, states, child) => AnimatedScale(
    scale:
        states.contains(WidgetState.pressed) &&
            !states.contains(WidgetState.disabled)
        ? .965
        : 1,
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120),
    curve: Curves.easeOutCubic,
    child: child,
  ),
);

class GlassChoiceChip extends StatelessWidget {
  const GlassChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.avatar,
  });
  final Widget label;
  final Widget? avatar;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 100,
    dark: selected,
    interactive: false,
    // RawChip's own Material must not hide the glass beneath transparent Ink.
    child: Theme(
      data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
      child: ChoiceChip(
        label: label,
        avatar: avatar,
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        color: const WidgetStatePropertyAll(Colors.transparent),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
        labelStyle: TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? Colors.white : ink,
        ),
        iconTheme: IconThemeData(
          color: selected ? Colors.white : muted,
          size: 16,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    ),
  );
}

class GlassActionChip extends StatelessWidget {
  const GlassActionChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.avatar,
  });
  final Widget label;
  final Widget? avatar;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 100,
    interactive: false,
    child: Theme(
      data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
      child: ActionChip(
        label: label,
        avatar: avatar,
        onPressed: onPressed,
        color: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: Colors.transparent,
        disabledColor: Colors.transparent,
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    ),
  );
}

/// Keep Flutter's dialog sizing, keyboard avoidance and semantics intact.
class GlassAlertDialog extends AlertDialog {
  const GlassAlertDialog({
    super.key,
    super.title,
    super.content,
    super.actions,
    super.insetPadding,
    super.backgroundColor,
    super.scrollable,
    super.contentPadding,
    super.actionsPadding,
    super.titlePadding,
    super.constraints,
    super.semanticLabel,
  });
  @override
  Widget build(BuildContext context) {
    final dialog = super.build(context) as Dialog;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: dialog.insetPadding,
      insetAnimationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : dialog.insetAnimationDuration,
      insetAnimationCurve: dialog.insetAnimationCurve,
      alignment: dialog.alignment,
      constraints: dialog.constraints,
      semanticsRole: dialog.semanticsRole,
      child: GlassSurface(radius: 32, interactive: false, child: dialog.child!),
    );
  }
}
