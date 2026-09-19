import 'package:flutter/material.dart';

/// Design tokens mirrored 1:1 from the web app's `style.css` (`:root` and
/// `[data-theme="dark"]`). The web app is the source of truth: change a value
/// there and change it here.

/// The web app sets `html{font-size:14px}` and sizes text in rem.
double rem(double v) => v * 14;

class Brand {
  Brand._();
  static const primary = Color(0xFF2563EB);
  static const primaryHover = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFFDBEAFE);
  static const success = Color(0xFF059669);
  static const successLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFD97706);
  static const warningLight = Color(0xFFFEF3C7);
  static const danger = Color(0xFFDC2626);
  static const dangerLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF7C3AED);
  static const infoLight = Color(0xFFEDE9FE);

  // Sidebar (same in light + dark)
  static const sidebarBg = Color(0xFF0F172A);
  static const sidebarText = Color(0xFF94A3B8);
  static const sidebarHover = Color(0x0FFFFFFF); // rgba(255,255,255,.06)
  static const sidebarActive = Color(0x2E2563EB); // rgba(37,99,235,.18)
  static const sidebarActiveText = Color(0xFF60A5FA);

  static const projectColors = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
    Color(0xFF65A30D),
  ];
}

/// Theme-dependent surface/text colors (`--bg`, `--surface`, `--text-3` ...).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color border2;
  final Color text;
  final Color text2;
  final Color text3;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadow;
  final List<BoxShadow> shadowLg;
  final List<BoxShadow> shadowModal;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.border2,
    required this.text,
    required this.text2,
    required this.text3,
    required this.shadowSm,
    required this.shadow,
    required this.shadowLg,
    required this.shadowModal,
  });

  static const light = AppColors(
    bg: Color(0xFFF1F5F9),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF8FAFC),
    border: Color(0xFFE2E8F0),
    border2: Color(0xFFCBD5E1),
    text: Color(0xFF0F172A),
    text2: Color(0xFF475569),
    text3: Color(0xFF94A3B8),
    shadowSm: [
      BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
    ],
    shadow: [
      BoxShadow(
        color: Color(0x12000000),
        offset: Offset(0, 4),
        blurRadius: 6,
        spreadRadius: -1,
      ),
      BoxShadow(
        color: Color(0x0A000000),
        offset: Offset(0, 2),
        blurRadius: 4,
        spreadRadius: -1,
      ),
    ],
    shadowLg: [
      BoxShadow(
        color: Color(0x1A000000),
        offset: Offset(0, 10),
        blurRadius: 25,
        spreadRadius: -5,
      ),
      BoxShadow(
        color: Color(0x0D000000),
        offset: Offset(0, 4),
        blurRadius: 6,
        spreadRadius: -2,
      ),
    ],
    shadowModal: [
      BoxShadow(
        color: Color(0x38000000),
        offset: Offset(0, 25),
        blurRadius: 50,
        spreadRadius: -12,
      ),
    ],
  );

  static const dark = AppColors(
    bg: Color(0xFF0B1120),
    surface: Color(0xFF1A2236),
    surface2: Color(0xFF131D30),
    border: Color(0xFF253048),
    border2: Color(0xFF334155),
    text: Color(0xFFE2E8F0),
    text2: Color(0xFF94A3B8),
    text3: Color(0xFF64748B),
    shadowSm: [
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
    ],
    shadow: [
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 4), blurRadius: 6),
    ],
    shadowLg: [
      BoxShadow(
        color: Color(0x80000000),
        offset: Offset(0, 10),
        blurRadius: 25,
      ),
    ],
    shadowModal: [
      BoxShadow(
        color: Color(0x99000000),
        offset: Offset(0, 25),
        blurRadius: 50,
      ),
    ],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      t < 0.5 ? this : (other as AppColors? ?? this);
}

class Radii {
  Radii._();
  static const double sm = 6; // --radius-sm
  static const double md = 10; // --radius
  static const double lg = 16; // --radius-lg
  static const double pill = 20;

  static final BorderRadius smAll = BorderRadius.circular(sm);
  static final BorderRadius mdAll = BorderRadius.circular(md);
  static final BorderRadius lgAll = BorderRadius.circular(lg);
  static final BorderRadius pillAll = BorderRadius.circular(pill);
}

extension AppThemeContext on BuildContext {
  AppColors get c =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}
