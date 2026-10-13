import 'package:flutter/material.dart';
import 'design.dart';

ThemeData artlogTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  fontFamily: 'NotoSansKR',
  colorScheme: ColorScheme.fromSeed(seedColor: green, surface: paper).copyWith(
    primary: green,
    secondary: const Color(0xff807596),
    onSurface: ink,
    outline: line,
  ),
  dividerColor: line,
  textTheme: ThemeData.light().textTheme.apply(
    fontFamily: 'NotoSansKR',
    bodyColor: ink,
    displayColor: ink,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xc4ffffff),
    hoverColor: const Color(0xf2ffffff),
    labelStyle: sans(12, color: muted),
    hintStyle: sans(12, color: muted),
    floatingLabelStyle: sans(11, color: green, weight: FontWeight.w600),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: Color(0xffd2dde0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: green, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: line),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: crystalButtonStyle(dark: true),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: crystalButtonStyle(dark: true),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(style: crystalButtonStyle()),
  textButtonTheme: TextButtonThemeData(
    style: crystalButtonStyle(
      quiet: true,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: crystalButtonStyle(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.all(11),
    ),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: crystalButtonStyle(quiet: true).copyWith(
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? green : muted,
      ),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xa8ffffff),
    selectedColor: ink,
    disabledColor: const Color(0x66ffffff),
    side: const BorderSide(color: Colors.white),
    shape: const StadiumBorder(),
    labelStyle: sans(11),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    elevation: 0,
    pressElevation: 0,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xd9ffffff),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: Colors.white),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: pearl,
    surfaceTintColor: Colors.transparent,
    elevation: 12,
    shadowColor: const Color(0x30233540),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(32),
      side: const BorderSide(color: Colors.white),
    ),
    titleTextStyle: serif(22),
    contentTextStyle: sans(13),
    barrierColor: const Color(0x66202c34),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: pearl,
    surfaceTintColor: Colors.transparent,
    elevation: 16,
    shadowColor: Color(0x30233540),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      side: BorderSide(color: Colors.white),
    ),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: pearl,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    shadowColor: const Color(0x20233540),
    textStyle: sans(12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Colors.white),
    ),
  ),
  dropdownMenuTheme: DropdownMenuThemeData(
    textStyle: sans(12),
    menuStyle: MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(pearl),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(8),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: ink,
    contentTextStyle: sans(12, color: Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
