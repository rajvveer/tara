import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class OnwardColors {
  // Neumorphic surfaces deliberately share the canvas tone so depth comes
  // from light, shadow, and state instead of stacked borders.
  static const canvas = Color(0xFFEDF1F4);
  static const surface = canvas;
  static const ink = Color(0xFF25272E);
  static const graphite = ink;
  static const muted = Color(0xFF5E6570);
  static const decorativeMuted = Color(0xFF777D92);
  static const primary = Color(0xFF6C2BFF);
  static const cobalt = primary;
  static const border = Color(0xFFD5DCE3);

  static const soft = Color(0xFFEEF1FF);
  static const cream = Color(0xFFFEF0CD);
  static const mint = Color(0xFFDDF2E2);
  static const pink = Color(0xFFF9E2ED);
  static const lilac = Color(0xFFEDE6FA);
  static const orange = Color(0xFFED934A);
  static const aqua = Color(0xFF69C9D8);
  static const green = Color(0xFF7DB36A);
  static const rose = Color(0xFFEFA7C8);
  static const purple = Color(0xFFC895EC);
  static const yellow = Color(0xFFF3C653);

  static const darkCanvas = Color(0xFF252831);
  static const darkSurface = darkCanvas;
  static const darkElevated = Color(0xFF2C303A);
  static const darkBorder = Color(0xFF414955);
}

/// Marker used by shared widgets to render the authenticated product in the
/// crisp, card-based visual language without changing the approved entry flow.
@immutable
class OnwardMainAppVisuals extends ThemeExtension<OnwardMainAppVisuals> {
  const OnwardMainAppVisuals();

  @override
  OnwardMainAppVisuals copyWith() => this;

  @override
  OnwardMainAppVisuals lerp(covariant OnwardMainAppVisuals? other, double t) =>
      this;
}

/// Native Flutter neumorphism shared by cards and controls.
///
/// Raised surfaces use opposing highlight/shadow pairs. Pressed surfaces
/// reverse that lighting and add a shallow concave gradient; no package is
/// needed for either state.
abstract final class OnwardNeumorphism {
  static const controlRadius = 16.0;
  static const surfaceRadius = 22.0;

  static BoxDecoration raised(
    BuildContext context, {
    Color? color,
    double radius = surfaceRadius,
    double depth = 1,
    BoxShape shape = BoxShape.rectangle,
  }) => _decoration(
    context,
    color: color,
    radius: radius,
    depth: depth,
    shape: shape,
    pressed: false,
  );

  static BoxDecoration pressed(
    BuildContext context, {
    Color? color,
    double radius = surfaceRadius,
    double depth = 1,
    BoxShape shape = BoxShape.rectangle,
  }) => _decoration(
    context,
    color: color,
    radius: radius,
    depth: depth,
    shape: shape,
    pressed: true,
  );

  static BoxDecoration _decoration(
    BuildContext context, {
    required Color? color,
    required double radius,
    required double depth,
    required BoxShape shape,
    required bool pressed,
  }) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final mainApp = theme.extension<OnwardMainAppVisuals>() != null;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final surface = color ?? theme.colorScheme.surface;
    final amount = depth.clamp(.35, 1.5);
    final compact = amount <= .7;
    final strong = amount >= 1.25;
    final lightDistance = compact ? 3.0 : (strong ? 7.0 : 5.0);
    final shadeDistance = compact ? 4.0 : (strong ? 8.0 : 6.0);
    final lightBlur = compact ? 9.0 : (strong ? 18.0 : 14.0);
    final shadeBlur = compact ? 10.0 : (strong ? 18.0 : 14.0);
    final highlight = dark ? const Color(0xFF3B404D) : Colors.white;
    final shade = dark ? Colors.black : const Color(0xFFB7C0CB);
    final highlightOpacity = dark
        ? (highContrast ? .92 : .8)
        : (highContrast ? 1.0 : .92);
    final shadeOpacity = dark
        ? (highContrast ? .8 : .68)
        : (highContrast ? .78 : .62);
    final radii = shape == BoxShape.circle
        ? null
        : BorderRadius.circular(radius);

    if (mainApp) {
      final selected = color == theme.colorScheme.primary;
      return BoxDecoration(
        color: pressed
            ? Color.alphaBlend(
                theme.colorScheme.primary.withValues(alpha: dark ? .12 : .07),
                surface,
              )
            : surface,
        shape: shape,
        borderRadius: radii,
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: .22)
              : theme.colorScheme.outline.withValues(alpha: dark ? .72 : .8),
        ),
        boxShadow: pressed || dark
            ? null
            : [
                BoxShadow(
                  color: const Color(
                    0xFF4B6A9B,
                  ).withValues(alpha: selected ? .13 : .075),
                  blurRadius: selected ? 18 : 14,
                  offset: const Offset(0, 5),
                ),
              ],
      );
    }

    return BoxDecoration(
      color: pressed ? null : surface,
      gradient: pressed
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  shade.withValues(alpha: dark ? .23 : .18),
                  surface,
                ),
                surface,
                Color.alphaBlend(
                  highlight.withValues(alpha: dark ? .1 : .54),
                  surface,
                ),
              ],
              stops: const [0, .5, 1],
            )
          : null,
      shape: shape,
      borderRadius: radii,
      border: dark || highContrast
          ? Border.all(
              color: theme.colorScheme.onSurface.withValues(
                alpha: highContrast ? .3 : .08,
              ),
            )
          : null,
      boxShadow: dark
          ? null
          : [
              BoxShadow(
                color: highlight.withValues(alpha: highlightOpacity),
                blurRadius: pressed ? 5.5 : lightBlur,
                offset: Offset(
                  pressed ? 2.2 : -lightDistance,
                  pressed ? 2.2 : -lightDistance,
                ),
              ),
              BoxShadow(
                color: shade.withValues(alpha: shadeOpacity),
                blurRadius: pressed ? 5.5 : shadeBlur,
                offset: Offset(
                  pressed ? -2.2 : shadeDistance,
                  pressed ? -2.2 : shadeDistance,
                ),
              ),
            ],
    );
  }
}

/// Authenticated-app theme based on the supplied Anova reference. The entry,
/// authentication, and onboarding routes continue using [onwardTheme].
ThemeData onwardMainAppTheme({required bool dark}) {
  final base = onwardTheme(dark: dark);
  final scheme = dark
      ? const ColorScheme.dark(
          primary: Color(0xFF84A5FF),
          onPrimary: Color(0xFF111725),
          secondary: Color(0xFF84A5FF),
          onSecondary: Color(0xFF111725),
          tertiary: Color(0xFFB9A0FF),
          onTertiary: Color(0xFF171222),
          surface: Color(0xFF202838),
          onSurface: Color(0xFFF5F7FC),
          error: Color(0xFFFFB4AB),
          outline: Color(0xFF39465A),
          surfaceContainerHighest: Color(0xFF293449),
        )
      : const ColorScheme.light(
          primary: Color(0xFF5F86F7),
          onPrimary: Colors.white,
          secondary: Color(0xFF5F86F7),
          onSecondary: Colors.white,
          tertiary: Color(0xFF8257EB),
          onTertiary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF171B25),
          error: Color(0xFFB42318),
          outline: Color(0xFFDDE5F1),
          surfaceContainerHighest: Color(0xFFEDF3FC),
        );
  final canvas = dark ? const Color(0xFF161D2A) : const Color(0xFFFDFCFB);
  final muted = dark ? const Color(0xFFB8C2D3) : const Color(0xFF697386);
  final text = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    textTheme: text,
    extensions: const [OnwardMainAppVisuals()],
    appBarTheme: base.appBarTheme.copyWith(
      foregroundColor: scheme.onSurface,
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outline,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: scheme.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      hintStyle: TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: controlShape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        side: BorderSide(color: scheme.outline),
        shape: controlShape,
        textStyle: text.labelLarge,
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      height: 74,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: .12),
      shadowColor: const Color(0xFF45618A).withValues(alpha: .08),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
    ),
    dialogTheme: base.dialogTheme.copyWith(backgroundColor: scheme.surface),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

Color onwardMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFBFC5D0)
    : OnwardColors.muted;

Color onwardCategoryColor(String category) => switch (category.toLowerCase()) {
  'health' || 'fitness' => OnwardColors.green,
  'learning' || 'study' => OnwardColors.aqua,
  'career' || 'productivity' => OnwardColors.primary,
  'finance' => OnwardColors.yellow,
  'relationships' => OnwardColors.rose,
  _ => OnwardColors.purple,
};

Color onwardCategorySurface(BuildContext context, String category) {
  final color = onwardCategoryColor(category);
  if (Theme.of(context).brightness == Brightness.dark) {
    return Color.alphaBlend(
      color.withValues(alpha: .23),
      OnwardColors.darkElevated,
    );
  }
  return Color.alphaBlend(color.withValues(alpha: .22), Colors.white);
}

SystemUiOverlayStyle onwardSystemUiOverlayStyle({required bool dark}) {
  final background = dark ? OnwardColors.darkCanvas : OnwardColors.canvas;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: background,
    systemNavigationBarDividerColor: background,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}

ThemeData onwardTheme({required bool dark}) {
  final muted = dark ? const Color(0xFFBFC5D0) : OnwardColors.muted;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: Color(0xFFA899FF),
          onPrimary: Color(0xFF181A20),
          secondary: Color(0xFFA899FF),
          onSecondary: Color(0xFF181A20),
          tertiary: Color(0xFFFFB4C9),
          onTertiary: Color(0xFF3A1020),
          surface: OnwardColors.darkSurface,
          onSurface: Color(0xFFF7F8FB),
          error: Color(0xFFFFB4AB),
          outline: OnwardColors.darkBorder,
          surfaceContainerHighest: OnwardColors.darkElevated,
        )
      : const ColorScheme.light(
          primary: OnwardColors.primary,
          onPrimary: Colors.white,
          secondary: OnwardColors.primary,
          onSecondary: Colors.white,
          tertiary: Color(0xFFB54B70),
          onTertiary: Colors.white,
          surface: OnwardColors.surface,
          onSurface: OnwardColors.ink,
          error: Color(0xFFB42318),
          outline: OnwardColors.border,
          surfaceContainerHighest: Color(0xFFF0EEFF),
        );
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: dark
        ? OnwardColors.darkCanvas
        : OnwardColors.canvas,
  );
  final text = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(
      fontSize: 32,
      height: 1.05,
      fontWeight: FontWeight.w800,
      letterSpacing: -.8,
    ),
    displayMedium: base.textTheme.displayMedium?.copyWith(
      fontSize: 28,
      height: 1.08,
      fontWeight: FontWeight.w800,
      letterSpacing: -.6,
    ),
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontSize: 24,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -.4,
    ),
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontSize: 22,
      height: 1.18,
      fontWeight: FontWeight.w800,
      letterSpacing: -.3,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -.2,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontSize: 18,
      height: 1.22,
      fontWeight: FontWeight.w700,
      letterSpacing: -.1,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: 18,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -.1,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w700,
      letterSpacing: .05,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      fontSize: 16,
      height: 1.5,
      letterSpacing: .05,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.5,
      letterSpacing: .1,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      height: 1.45,
      letterSpacing: .15,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: .1,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: .25,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: .3,
    ),
  );
  final rowRadius = BorderRadius.circular(16);
  final cardRadius = BorderRadius.circular(20);
  final shadow = dark ? Colors.black : OnwardColors.primary;

  return base.copyWith(
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    shadowColor: shadow.withValues(alpha: dark ? .3 : .14),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      systemOverlayStyle: onwardSystemUiOverlayStyle(dark: dark),
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: cardRadius),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outline.withValues(alpha: .82),
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: .66)),
      hintStyle: TextStyle(color: muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: rowRadius,
        borderSide: BorderSide(
          color: dark
              ? scheme.onSurface.withValues(alpha: .08)
              : Colors.transparent,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: rowRadius,
        borderSide: BorderSide(color: scheme.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: rowRadius,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: rowRadius,
        borderSide: BorderSide(color: scheme.error, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: rowRadius),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: rowRadius),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: rowRadius),
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary.withValues(alpha: dark ? .22 : .2),
      side: BorderSide(color: scheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelStyle: text.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: dark ? 0 : 2,
      shadowColor: shadow.withValues(alpha: dark ? .28 : .12),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: dark ? .24 : .18),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : muted,
          size: 22,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 8,
      modalElevation: 12,
      shadowColor: shadow.withValues(alpha: dark ? .32 : .18),
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 10,
      shadowColor: shadow.withValues(alpha: dark ? .32 : .18),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.onSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 4,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
