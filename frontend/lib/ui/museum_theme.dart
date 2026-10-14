import 'package:flutter/material.dart';
import 'design.dart';

/// A local exhibition palette; reading, diary and account forms stay on paper.
class MuseumTheme extends StatelessWidget {
  const MuseumTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    ButtonStyle button({bool primary = false, bool quiet = false}) =>
        editorialButtonStyle(dark: !primary, quiet: quiet, radius: 4).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? museumLine
                : primary
                ? museumText
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? museumMuted
                : primary
                ? museumBlack
                : museumText,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? const Color(0xffd5c4a5)
                  : quiet
                  ? Colors.transparent
                  : museumLine,
              width: states.contains(WidgetState.focused) ? 2 : 1,
            ),
          ),
        );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: museumLine),
    );
    return Theme(
      data: base.copyWith(
        brightness: Brightness.dark,
        colorScheme: base.colorScheme.copyWith(
          brightness: Brightness.dark,
          primary: museumText,
          onPrimary: museumBlack,
          surface: museumBlack,
          onSurface: museumText,
          outline: museumLine,
        ),
        canvasColor: museumBlack,
        dividerColor: museumLine,
        textTheme: base.textTheme.apply(
          bodyColor: museumText,
          displayColor: museumText,
        ),
        iconTheme: const IconThemeData(color: museumText),
        filledButtonTheme: FilledButtonThemeData(style: button(primary: true)),
        outlinedButtonTheme: OutlinedButtonThemeData(style: button()),
        textButtonTheme: TextButtonThemeData(style: button(quiet: true)),
        iconButtonTheme: IconButtonThemeData(style: button(quiet: true)),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          fillColor: museumBlack,
          hoverColor: museumLine,
          hintStyle: sans(12, color: museumMuted),
          prefixIconColor: museumMuted,
          suffixIconColor: museumText,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: museumText, width: 1.5),
          ),
        ),
      ),
      child: child,
    );
  }
}
