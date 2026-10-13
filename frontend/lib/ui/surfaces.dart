import 'package:flutter/material.dart';

const paper = Color(0xfff8f7f4);
const ink = Color(0xff252823);
const green = Color(0xff435247);
const muted = Color(0xff6c7068);
const line = Color(0xffdfE1d9);
const sage = Color(0xff90998b);
const pearl = Color(0xffffffff);
const soft = Color(0xffeeefe9);

BoxDecoration surfaceDecoration({
  double radius = 12,
  bool dark = false,
  bool tinted = false,
}) => BoxDecoration(
  color: dark
      ? ink
      : tinted
      ? soft
      : pearl,
  borderRadius: BorderRadius.circular(radius.clamp(0, 12)),
  border: Border.all(color: dark ? ink : line),
);

/// Opaque paper surfaces keep artwork colours and text contrast predictable.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(color: paper, child: child);
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 12,
    this.dark = false,
    this.tinted = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool dark, tinted;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: surfaceDecoration(radius: radius, dark: dark, tinted: tinted),
    child: Padding(padding: padding, child: child),
  );
}

ButtonStyle editorialButtonStyle({
  bool dark = false,
  bool quiet = false,
  bool tinted = false,
  double radius = 8,
  Size minimumSize = const Size(44, 46),
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 12,
  ),
}) => ButtonStyle(
  minimumSize: WidgetStatePropertyAll(minimumSize),
  padding: WidgetStatePropertyAll(padding),
  elevation: const WidgetStatePropertyAll(0),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  textStyle: const WidgetStatePropertyAll(
    TextStyle(
      fontFamily: 'NotoSansKR',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.45,
    ),
  ),
  backgroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled)
        ? (quiet ? Colors.transparent : soft)
        : dark
        ? ink
        : quiet
        ? Colors.transparent
        : tinted
        ? soft
        : Colors.white,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled)
        ? muted
        : dark
        ? Colors.white
        : ink,
  ),
  overlayColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.pressed)
        ? (dark ? const Color(0x25ffffff) : const Color(0x17252823))
        : s.contains(WidgetState.hovered)
        ? (dark ? const Color(0x15ffffff) : const Color(0x0a252823))
        : Colors.transparent,
  ),
  side: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.focused)
        ? BorderSide(color: dark ? sage : green, width: 2)
        : BorderSide(color: dark || quiet ? Colors.transparent : line),
  ),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius.clamp(0, 10)),
    ),
  ),
  animationDuration: Duration.zero,
  splashFactory: NoSplash.splashFactory,
);

class FilterPill extends StatelessWidget {
  const FilterPill({
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
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
    child: ChoiceChip(
      label: label,
      avatar: avatar,
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      color: WidgetStatePropertyAll(selected ? ink : Colors.transparent),
      side: BorderSide(color: selected ? ink : line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      elevation: 0,
      pressElevation: 0,
      shadowColor: Colors.transparent,
      selectedShadowColor: Colors.transparent,
      labelStyle: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected ? Colors.white : ink,
      ),
      iconTheme: IconThemeData(
        color: selected ? Colors.white : muted,
        size: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}

class SourceChip extends StatelessWidget {
  const SourceChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.avatar,
  });
  final Widget label;
  final Widget? avatar;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => ActionChip(
    label: label,
    avatar: avatar,
    onPressed: onPressed,
    backgroundColor: soft,
    disabledColor: soft,
    side: const BorderSide(color: line),
    elevation: 0,
    pressElevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  );
}

class SurfaceDialog extends AlertDialog {
  const SurfaceDialog({
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
}
