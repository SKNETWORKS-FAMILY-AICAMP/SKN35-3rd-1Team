import 'package:flutter/material.dart';
import 'design.dart';

ThemeData docentalkTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  fontFamily: 'ChironSungHK',
  colorScheme: ColorScheme.fromSeed(
    seedColor: green,
    surface: paper,
  ).copyWith(primary: green, secondary: green, onSurface: ink, outline: line),
  dividerColor: line,
  textTheme: ThemeData.light().textTheme.apply(
    fontFamily: 'ChironSungHK',
    bodyColor: ink,
    displayColor: ink,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xffffffff),
    hoverColor: const Color(0xfff8f7f4),
    labelStyle: sans(12, color: muted),
    hintStyle: sans(12, color: muted),
    floatingLabelStyle: sans(11, color: green, weight: FontWeight.w600),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: green, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: line),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: editorialButtonStyle(dark: true),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: editorialButtonStyle(dark: true),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(style: editorialButtonStyle()),
  textButtonTheme: TextButtonThemeData(
    style: editorialButtonStyle(
      quiet: true,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: editorialButtonStyle(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.all(11),
    ),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: editorialButtonStyle(quiet: true).copyWith(
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? green : muted,
      ),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xfff8f7f4),
    selectedColor: ink,
    disabledColor: const Color(0xffeeefe9),
    side: const BorderSide(color: line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    labelStyle: sans(11),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    elevation: 0,
    pressElevation: 0,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xffffffff),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: line),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: pearl,
    surfaceTintColor: Colors.transparent,
    elevation: 2,
    shadowColor: const Color(0x30233540),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: line),
    ),
    titleTextStyle: serif(22),
    contentTextStyle: sans(13),
    barrierColor: const Color(0x66202c34),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: pearl,
    surfaceTintColor: Colors.transparent,
    elevation: 2,
    shadowColor: Color(0x30233540),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: line),
    ),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: pearl,
    surfaceTintColor: Colors.transparent,
    elevation: 2,
    shadowColor: const Color(0x20233540),
    textStyle: sans(12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: line),
    ),
  ),
  dropdownMenuTheme: DropdownMenuThemeData(
    textStyle: sans(12),
    menuStyle: MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(pearl),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(8),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: const WidgetStatePropertyAll(Colors.white),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? green : const Color(0xffa5b4bd),
    ),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    thumbIcon: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected)
          ? const Icon(Icons.check, size: 13, color: green)
          : null,
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    side: const BorderSide(color: sage, width: 1.2),
  ),
  datePickerTheme: DatePickerThemeData(
    backgroundColor: pearl,
    surfaceTintColor: Colors.transparent,
    headerBackgroundColor: const Color(0xffe8efef),
    headerForegroundColor: ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: ink,
    contentTextStyle: sans(12, color: Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: Color(0x55ffffff)),
    ),
    elevation: 4,
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x55ffffff)),
    ),
    textStyle: sans(10, color: Colors.white),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  ),
  listTileTheme: ListTileThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    selectedTileColor: const Color(0xffe4eeee),
    iconColor: green,
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: green,
    linearTrackColor: line,
  ),
  scrollbarTheme: ScrollbarThemeData(
    radius: const Radius.circular(100),
    thickness: const WidgetStatePropertyAll(5),
    thumbColor: WidgetStatePropertyAll(sage.withValues(alpha: .35)),
  ),
);
