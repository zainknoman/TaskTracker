import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tokens.dart';

/// Light/dark toggle, same as the web app's sidebar "Dark Mode" button.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

ThemeData _build(Brightness brightness, AppColors c) {
  TextStyle t(
    double size,
    FontWeight w,
    Color color, {
    double? ls,
    double? h,
  }) => TextStyle(
    fontSize: size,
    fontWeight: w,
    color: color,
    letterSpacing: ls,
    height: h,
  );

  final textTheme = TextTheme(
    displaySmall: t(rem(1.9), FontWeight.w800, c.text, h: 1),
    headlineMedium: t(
      rem(1.45),
      FontWeight.w700,
      c.text,
      ls: -0.02 * rem(1.45),
    ), // .view-title
    headlineSmall: t(
      rem(1.4),
      FontWeight.w800,
      c.text,
      ls: -0.02 * rem(1.4),
    ), // .pdh-title
    titleLarge: t(rem(1.05), FontWeight.w700, c.text), // .modal-header h2
    titleMedium: t(rem(0.9), FontWeight.w600, c.text), // .card-header h3
    titleSmall: t(rem(0.85), FontWeight.w700, c.text),
    bodyLarge: t(rem(0.9), FontWeight.w400, c.text, h: 1.5),
    bodyMedium: t(rem(0.85), FontWeight.w400, c.text, h: 1.5),
    bodySmall: t(rem(0.75), FontWeight.w400, c.text3, h: 1.5),
    labelLarge: t(rem(0.85), FontWeight.w500, c.text),
    labelMedium: t(rem(0.72), FontWeight.w700, c.text2, ls: 0.03 * rem(0.72)),
    labelSmall: t(rem(0.68), FontWeight.w600, c.text3),
  );

  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: Radii.smAll,
    borderSide: BorderSide(color: color),
  );

  final scheme =
      ColorScheme.fromSeed(
        seedColor: Brand.primary,
        brightness: brightness,
      ).copyWith(
        primary: Brand.primary,
        onPrimary: Colors.white,
        secondary: Brand.primary,
        error: Brand.danger,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.text,
        surfaceContainerHighest: c.surface2,
        outline: c.border2,
        outlineVariant: c.border,
      );

  final buttonShape = RoundedRectangleBorder(borderRadius: Radii.smAll);
  const buttonPad = EdgeInsets.symmetric(horizontal: 14, vertical: 9);
  final buttonText = t(rem(0.85), FontWeight.w500, c.text);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.surface,
    dividerColor: c.border,
    textTheme: textTheme,
    extensions: [c],
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 60,
      titleTextStyle: textTheme.titleMedium,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.lgAll,
        side: BorderSide(color: c.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Brand.primary.withValues(alpha: .5),
        disabledForegroundColor: Colors.white70,
        padding: buttonPad,
        shape: buttonShape,
        textStyle: buttonText,
        elevation: 0,
        minimumSize: const Size(0, 36),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: c.surface2,
        foregroundColor: c.text,
        side: BorderSide(color: c.border),
        padding: buttonPad,
        shape: buttonShape,
        textStyle: buttonText,
        minimumSize: const Size(0, 36),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.text2,
        padding: buttonPad,
        shape: buttonShape,
        textStyle: buttonText,
        minimumSize: const Size(0, 36),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.text2,
        shape: buttonShape,
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.bg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      hintStyle: t(rem(0.85), FontWeight.w400, c.text3),
      labelStyle: t(rem(0.85), FontWeight.w400, c.text3),
      errorStyle: t(rem(0.72), FontWeight.w400, Brand.danger),
      border: border(c.border),
      enabledBorder: border(c.border),
      disabledBorder: border(c.border),
      focusedBorder: border(Brand.primary),
      errorBorder: border(Brand.danger),
      focusedErrorBorder: border(Brand.danger),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: textTheme.bodyMedium,
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(color: c.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: c.surface,
      modalBarrierColor: const Color(0x80000000),
      showDragHandle: false,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.lg),
        ),
        side: BorderSide(color: c.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.lgAll,
        side: BorderSide(color: c.border),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.text2),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Brand.sidebarBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface2,
      side: BorderSide(color: c.border),
      shape: RoundedRectangleBorder(borderRadius: Radii.pillAll),
      labelStyle: t(rem(0.72), FontWeight.w600, c.text2),
    ),
    listTileTheme: ListTileThemeData(
      textColor: c.text,
      iconColor: c.text2,
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: textTheme.bodySmall,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Brand.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surface,
      contentTextStyle: textTheme.bodyMedium,
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.text, borderRadius: Radii.smAll),
      textStyle: t(rem(0.72), FontWeight.w500, c.bg),
    ),
  );
}

final ThemeData appLightTheme = _build(Brightness.light, AppColors.light);
final ThemeData appDarkTheme = _build(Brightness.dark, AppColors.dark);
