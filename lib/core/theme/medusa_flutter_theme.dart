import 'package:flutter/material.dart';

import 'swappy_visual_theme.dart';

/// The Swappy application theme.
///
/// It preserves the original semantic token API for existing screens while
/// layering Swappy's event palette, glass, shape and motion foundations over
/// standard Material components. New code should use [SwappyVisualTokens].
abstract final class SwappyTheme {
  static const double radiusSmall = SwappyRadii.compact;
  static const double radiusMedium = SwappyRadii.control;
  static const double radiusLarge = SwappyRadii.card;

  static final ThemeData light = _build(
    brightness: Brightness.light,
    tokens: MedusaColors.light,
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    tokens: MedusaColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required MedusaColors tokens,
  }) {
    final isDark = brightness == Brightness.dark;
    final visual = isDark ? SwappyVisualTokens.dark : SwappyVisualTokens.light;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: visual.brandViolet,
          brightness: brightness,
        ).copyWith(
          primary: visual.brandViolet,
          onPrimary: tokens.onColor,
          secondary: visual.neonCyan,
          onSecondary: tokens.onColor,
          tertiary: visual.energyCoral,
          onTertiary: visual.onEnergy,
          surface: visual.surface,
          onSurface: tokens.fgBase,
          error: tokens.error,
          onError: tokens.onColor,
          outline: tokens.borderStrong,
          outlineVariant: tokens.borderBase,
          shadow: isDark ? const Color(0x7A000000) : const Color(0x1F000000),
          scrim: tokens.overlay,
          inverseSurface: isDark
              ? const Color(0xFFF4F4F5)
              : const Color(0xFF18181B),
          onInverseSurface: isDark
              ? const Color(0xFF18181B)
              : const Color(0xFFF4F4F5),
          inversePrimary: isDark
              ? const Color(0xFF6D28D9)
              : const Color(0xFFC7A2FF),
        );

    final textTheme = _textTheme(tokens);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: BorderSide(color: tokens.borderBase),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: BorderSide(color: tokens.interactive, width: 1.5),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: visual.canvas,
      canvasColor: visual.surface,
      fontFamily: 'Inter',
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[tokens, visual],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
      dividerColor: tokens.borderBase,
      disabledColor: tokens.fgDisabled,
      focusColor: tokens.focusRing,
      highlightColor: tokens.bgHighlight,
      hoverColor: tokens.bgComponentHover,
      splashColor: tokens.interactive.withValues(alpha: 0.10),
      appBarTheme: AppBarThemeData(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: visual.canvas,
        foregroundColor: tokens.fgBase,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: tokens.fgSubtle, size: 22),
        actionsIconTheme: IconThemeData(color: tokens.fgSubtle, size: 22),
        shape: const Border(),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        elevation: 0,
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        height: 64,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? visual.selectedIconStroke
                : visual.inactiveIcon,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? visual.selectedIconStroke
                : visual.inactiveIcon,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.transparent,
        selectedItemColor: visual.selectedIconStroke,
        unselectedItemColor: visual.inactiveIcon,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
        type: BottomNavigationBarType.fixed,
      ),
      drawerTheme: DrawerThemeData(
        elevation: 0,
        backgroundColor: tokens.bgBase,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: tokens.borderBase),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: visual.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: visual.glassShadow,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: tokens.borderBase),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        isDense: true,
        filled: true,
        fillColor: tokens.bgField,
        hoverColor: tokens.bgFieldHover,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: focusBorder,
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: tokens.error),
        ),
        focusedErrorBorder: focusBorder.copyWith(
          borderSide: BorderSide(color: tokens.error, width: 1.5),
        ),
        disabledBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: tokens.borderBase),
        ),
        labelStyle: textTheme.bodySmall?.copyWith(color: tokens.fgSubtle),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: tokens.interactive,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.fgMuted),
        helperStyle: textTheme.bodySmall?.copyWith(color: tokens.fgMuted),
        errorStyle: textTheme.bodySmall?.copyWith(color: tokens.error),
        prefixIconColor: tokens.fgMuted,
        suffixIconColor: tokens.fgMuted,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(tokens.bgField),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStatePropertyAll(BorderSide(color: tokens.borderBase)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwappyRadii.control),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: SwappySpacing.md),
        ),
        textStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
        hintStyle: WidgetStatePropertyAll(
          textTheme.bodyLarge?.copyWith(color: tokens.fgMuted),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? tokens.fgDisabled
                : tokens.contrastFg;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return tokens.bgDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return tokens.buttonPrimaryPressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return tokens.buttonPrimaryHover;
            }
            return tokens.buttonPrimary;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? tokens.fgDisabled
                : tokens.fgBase;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return tokens.bgDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return tokens.bgComponentPressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return tokens.bgComponentHover;
            }
            return tokens.bgBase;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(BorderSide(color: tokens.borderBase)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? tokens.fgDisabled
                : tokens.fgBase;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return tokens.bgComponentPressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return tokens.bgComponentHover;
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStateProperty.resolveWith((states) {
            return BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? tokens.borderBase
                  : tokens.borderStrong,
            );
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? tokens.fgDisabled
                : tokens.fgBase;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return tokens.bgComponentPressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return tokens.bgComponentHover;
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          iconColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? tokens.fgDisabled
                : tokens.fgSubtle;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return tokens.bgComponentPressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return tokens.bgComponentHover;
            }
            return Colors.transparent;
          }),
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.tagNeutralBg,
        selectedColor: tokens.bgHighlight,
        disabledColor: tokens.bgDisabled,
        labelStyle: textTheme.labelSmall?.copyWith(color: tokens.fgSubtle),
        secondaryLabelStyle: textTheme.labelSmall?.copyWith(
          color: tokens.interactive,
        ),
        side: BorderSide(color: tokens.borderBase),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwappyRadii.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        showCheckmark: false,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: tokens.error,
        textColor: tokens.onColor,
        textStyle: textTheme.labelSmall,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      checkboxTheme: CheckboxThemeData(
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: tokens.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.bgDisabled;
          if (states.contains(WidgetState.selected)) return tokens.interactive;
          return tokens.bgField;
        }),
        checkColor: WidgetStatePropertyAll(tokens.onColor),
      ),
      radioTheme: RadioThemeData(
        visualDensity: VisualDensity.compact,
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.fgDisabled;
          if (states.contains(WidgetState.selected)) return tokens.interactive;
          return tokens.borderStrong;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.fgDisabled;
          return tokens.onColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return tokens.bgDisabled;
          if (states.contains(WidgetState.selected)) return tokens.interactive;
          return tokens.switchOff;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        minTileHeight: 48,
        iconColor: tokens.fgMuted,
        textColor: tokens.fgBase,
        selectedColor: tokens.interactive,
        selectedTileColor: tokens.bgHighlight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        titleTextStyle: textTheme.bodyMedium?.copyWith(
          color: tokens.fgBase,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: tokens.fgSubtle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.borderBase,
        space: 1,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: tokens.bgBase,
        surfaceTintColor: Colors.transparent,
        barrierColor: tokens.overlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwappyRadii.sheet),
          side: BorderSide(color: tokens.borderBase),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: tokens.fgSubtle,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        modalElevation: 0,
        backgroundColor: tokens.bgBase,
        modalBackgroundColor: tokens.bgBase,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SwappyRadii.sheet),
          ),
          side: BorderSide(color: tokens.borderBase),
        ),
        showDragHandle: true,
        dragHandleColor: tokens.borderStrong,
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 0,
        color: tokens.bgBase,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: tokens.borderBase),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.contrastBg,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: tokens.contrastFg,
        ),
        actionTextColor: isDark
            ? const Color(0xFF93C5FD)
            : const Color(0xFFBFDBFE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.contrastBg,
          borderRadius: BorderRadius.circular(radiusSmall),
          border: Border.all(color: tokens.contrastBorder),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: tokens.contrastFg),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        waitDuration: const Duration(milliseconds: 450),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: tokens.borderBase,
        indicatorColor: tokens.interactive,
        labelColor: tokens.fgBase,
        unselectedLabelColor: tokens.fgMuted,
        labelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium,
        overlayColor: WidgetStatePropertyAll(tokens.bgComponentHover),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: visual.brandViolet,
        linearTrackColor: tokens.bgDisabled,
        circularTrackColor: tokens.bgDisabled,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tokens.interactive,
        selectionColor: tokens.interactive.withValues(alpha: 0.24),
        selectionHandleColor: tokens.interactive,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 4,
        backgroundColor: visual.brandViolet,
        foregroundColor: visual.onEnergy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwappyRadii.control),
        ),
      ),
    );
  }

  static TextTheme _textTheme(MedusaColors tokens) {
    TextStyle style(
      double size,
      double height, {
      FontWeight weight = FontWeight.w400,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        color: color ?? tokens.fgBase,
        letterSpacing: 0,
      );
    }

    return TextTheme(
      displayLarge: style(40, 44, weight: FontWeight.w500),
      displayMedium: style(32, 38, weight: FontWeight.w500),
      displaySmall: style(28, 34, weight: FontWeight.w500),
      headlineLarge: style(24, 30, weight: FontWeight.w500),
      headlineMedium: style(20, 28, weight: FontWeight.w500),
      headlineSmall: style(18, 28, weight: FontWeight.w500),
      titleLarge: style(18, 28, weight: FontWeight.w500),
      titleMedium: style(16, 24, weight: FontWeight.w500),
      titleSmall: style(14, 20, weight: FontWeight.w500),
      bodyLarge: style(16, 26),
      bodyMedium: style(14, 20),
      bodySmall: style(13, 18, color: tokens.fgSubtle),
      labelLarge: style(14, 20, weight: FontWeight.w500),
      labelMedium: style(13, 20, weight: FontWeight.w500),
      labelSmall: style(12, 18, weight: FontWeight.w500),
    );
  }
}

/// Backward-compatible name for screens that still consume the original
/// semantic token API. New application entry points should use [SwappyTheme].
abstract final class MedusaTheme {
  static const double radiusSmall = SwappyTheme.radiusSmall;
  static const double radiusMedium = SwappyTheme.radiusMedium;
  static const double radiusLarge = SwappyTheme.radiusLarge;

  static final ThemeData light = SwappyTheme.light;
  static final ThemeData dark = SwappyTheme.dark;
}

@immutable
class MedusaColors extends ThemeExtension<MedusaColors> {
  const MedusaColors({
    required this.bgBase,
    required this.bgSubtle,
    required this.bgComponent,
    required this.bgComponentHover,
    required this.bgComponentPressed,
    required this.bgField,
    required this.bgFieldHover,
    required this.bgDisabled,
    required this.bgHighlight,
    required this.fgBase,
    required this.fgSubtle,
    required this.fgMuted,
    required this.fgDisabled,
    required this.borderBase,
    required this.borderStrong,
    required this.interactive,
    required this.interactiveHover,
    required this.error,
    required this.onColor,
    required this.overlay,
    required this.contrastBg,
    required this.contrastFg,
    required this.contrastBorder,
    required this.buttonPrimary,
    required this.buttonPrimaryHover,
    required this.buttonPrimaryPressed,
    required this.switchOff,
    required this.tagNeutralBg,
    required this.tagBlueBg,
    required this.tagBlueText,
    required this.tagGreenBg,
    required this.tagGreenText,
    required this.tagOrangeBg,
    required this.tagOrangeText,
    required this.tagRedBg,
    required this.tagRedText,
    required this.tagPurpleBg,
    required this.tagPurpleText,
    required this.focusRing,
  });

  final Color bgBase;
  final Color bgSubtle;
  final Color bgComponent;
  final Color bgComponentHover;
  final Color bgComponentPressed;
  final Color bgField;
  final Color bgFieldHover;
  final Color bgDisabled;
  final Color bgHighlight;
  final Color fgBase;
  final Color fgSubtle;
  final Color fgMuted;
  final Color fgDisabled;
  final Color borderBase;
  final Color borderStrong;
  final Color interactive;
  final Color interactiveHover;
  final Color error;
  final Color onColor;
  final Color overlay;
  final Color contrastBg;
  final Color contrastFg;
  final Color contrastBorder;
  final Color buttonPrimary;
  final Color buttonPrimaryHover;
  final Color buttonPrimaryPressed;
  final Color switchOff;
  final Color tagNeutralBg;
  final Color tagBlueBg;
  final Color tagBlueText;
  final Color tagGreenBg;
  final Color tagGreenText;
  final Color tagOrangeBg;
  final Color tagOrangeText;
  final Color tagRedBg;
  final Color tagRedText;
  final Color tagPurpleBg;
  final Color tagPurpleText;
  final Color focusRing;

  static const light = MedusaColors(
    bgBase: Color(0xFFFFFFFF),
    bgSubtle: Color(0xFFF8F6FF),
    bgComponent: Color(0xFFFBFAFF),
    bgComponentHover: Color(0xFFF0EBFF),
    bgComponentPressed: Color(0xFFE4DAFF),
    bgField: Color(0xFFFBFAFF),
    bgFieldHover: Color(0xFFF4F0FF),
    bgDisabled: Color(0xFFF0EEF5),
    bgHighlight: Color(0xFFEDE7FF),
    fgBase: Color(0xFF151126),
    fgSubtle: Color(0xFF514A66),
    fgMuted: Color(0xFF746D85),
    fgDisabled: Color(0xFFA7A1B2),
    borderBase: Color(0xFFE6E0F0),
    borderStrong: Color(0xFFD3CAE3),
    interactive: Color(0xFF6D28D9),
    interactiveHover: Color(0xFF5B21B6),
    error: Color(0xFFE11D48),
    onColor: Color(0xFFFFFFFF),
    overlay: Color(0x73151126),
    contrastBg: Color(0xFF151126),
    contrastFg: Color(0xE0FFFFFF),
    contrastBorder: Color(0x26FFFFFF),
    buttonPrimary: Color(0xFF6D28D9),
    buttonPrimaryHover: Color(0xFF7C3AED),
    buttonPrimaryPressed: Color(0xFF5B21B6),
    switchOff: Color(0xFFD9D4E3),
    tagNeutralBg: Color(0xFFF0EEF5),
    tagBlueBg: Color(0xFFDDF8FC),
    tagBlueText: Color(0xFF075E6B),
    tagGreenBg: Color(0xFFD1FAE5),
    tagGreenText: Color(0xFF065F46),
    tagOrangeBg: Color(0xFFFFEDD5),
    tagOrangeText: Color(0xFF9A3412),
    tagRedBg: Color(0xFFFFE4E6),
    tagRedText: Color(0xFF9F1239),
    tagPurpleBg: Color(0xFFEDE7FF),
    tagPurpleText: Color(0xFF5B21B6),
    focusRing: Color(0x996D28D9),
  );

  static const dark = MedusaColors(
    bgBase: Color(0xFF10162A),
    bgSubtle: Color(0xFF070B18),
    bgComponent: Color(0xFF171E38),
    bgComponentHover: Color(0x1AFFFFFF),
    bgComponentPressed: Color(0x29FFFFFF),
    bgField: Color(0x0AFFFFFF),
    bgFieldHover: Color(0x14FFFFFF),
    bgDisabled: Color(0xFF171E38),
    bgHighlight: Color(0xFF2B1B52),
    fgBase: Color(0xFFF7F5FF),
    fgSubtle: Color(0xFFB9B2CB),
    fgMuted: Color(0xFF9189A6),
    fgDisabled: Color(0xFF5F5872),
    borderBase: Color(0x14FFFFFF),
    borderStrong: Color(0x29FFFFFF),
    interactive: Color(0xFFC7A2FF),
    interactiveHover: Color(0xFFDDD0FF),
    error: Color(0xFFFB7185),
    onColor: Color(0xFFFFFFFF),
    overlay: Color(0xC2050812),
    contrastBg: Color(0xFF171E38),
    contrastFg: Color(0xE0FFFFFF),
    contrastBorder: Color(0x29FFFFFF),
    buttonPrimary: Color(0xFF7C3AED),
    buttonPrimaryHover: Color(0xFF8B5CF6),
    buttonPrimaryPressed: Color(0xFF6D28D9),
    switchOff: Color(0xFF353B52),
    tagNeutralBg: Color(0x14FFFFFF),
    tagBlueBg: Color(0xFF083344),
    tagBlueText: Color(0xFF67E8F9),
    tagGreenBg: Color(0xFF022C22),
    tagGreenText: Color(0xFF34D399),
    tagOrangeBg: Color(0xFF431407),
    tagOrangeText: Color(0xFFFDBA74),
    tagRedBg: Color(0xFF4C0519),
    tagRedText: Color(0xFFFDA4AF),
    tagPurpleBg: Color(0xFF2B1B52),
    tagPurpleText: Color(0xFFD8B4FE),
    focusRing: Color(0xCCC7A2FF),
  );

  @override
  MedusaColors copyWith({
    Color? bgBase,
    Color? bgSubtle,
    Color? bgComponent,
    Color? bgComponentHover,
    Color? bgComponentPressed,
    Color? bgField,
    Color? bgFieldHover,
    Color? bgDisabled,
    Color? bgHighlight,
    Color? fgBase,
    Color? fgSubtle,
    Color? fgMuted,
    Color? fgDisabled,
    Color? borderBase,
    Color? borderStrong,
    Color? interactive,
    Color? interactiveHover,
    Color? error,
    Color? onColor,
    Color? overlay,
    Color? contrastBg,
    Color? contrastFg,
    Color? contrastBorder,
    Color? buttonPrimary,
    Color? buttonPrimaryHover,
    Color? buttonPrimaryPressed,
    Color? switchOff,
    Color? tagNeutralBg,
    Color? tagBlueBg,
    Color? tagBlueText,
    Color? tagGreenBg,
    Color? tagGreenText,
    Color? tagOrangeBg,
    Color? tagOrangeText,
    Color? tagRedBg,
    Color? tagRedText,
    Color? tagPurpleBg,
    Color? tagPurpleText,
    Color? focusRing,
  }) {
    return MedusaColors(
      bgBase: bgBase ?? this.bgBase,
      bgSubtle: bgSubtle ?? this.bgSubtle,
      bgComponent: bgComponent ?? this.bgComponent,
      bgComponentHover: bgComponentHover ?? this.bgComponentHover,
      bgComponentPressed: bgComponentPressed ?? this.bgComponentPressed,
      bgField: bgField ?? this.bgField,
      bgFieldHover: bgFieldHover ?? this.bgFieldHover,
      bgDisabled: bgDisabled ?? this.bgDisabled,
      bgHighlight: bgHighlight ?? this.bgHighlight,
      fgBase: fgBase ?? this.fgBase,
      fgSubtle: fgSubtle ?? this.fgSubtle,
      fgMuted: fgMuted ?? this.fgMuted,
      fgDisabled: fgDisabled ?? this.fgDisabled,
      borderBase: borderBase ?? this.borderBase,
      borderStrong: borderStrong ?? this.borderStrong,
      interactive: interactive ?? this.interactive,
      interactiveHover: interactiveHover ?? this.interactiveHover,
      error: error ?? this.error,
      onColor: onColor ?? this.onColor,
      overlay: overlay ?? this.overlay,
      contrastBg: contrastBg ?? this.contrastBg,
      contrastFg: contrastFg ?? this.contrastFg,
      contrastBorder: contrastBorder ?? this.contrastBorder,
      buttonPrimary: buttonPrimary ?? this.buttonPrimary,
      buttonPrimaryHover: buttonPrimaryHover ?? this.buttonPrimaryHover,
      buttonPrimaryPressed: buttonPrimaryPressed ?? this.buttonPrimaryPressed,
      switchOff: switchOff ?? this.switchOff,
      tagNeutralBg: tagNeutralBg ?? this.tagNeutralBg,
      tagBlueBg: tagBlueBg ?? this.tagBlueBg,
      tagBlueText: tagBlueText ?? this.tagBlueText,
      tagGreenBg: tagGreenBg ?? this.tagGreenBg,
      tagGreenText: tagGreenText ?? this.tagGreenText,
      tagOrangeBg: tagOrangeBg ?? this.tagOrangeBg,
      tagOrangeText: tagOrangeText ?? this.tagOrangeText,
      tagRedBg: tagRedBg ?? this.tagRedBg,
      tagRedText: tagRedText ?? this.tagRedText,
      tagPurpleBg: tagPurpleBg ?? this.tagPurpleBg,
      tagPurpleText: tagPurpleText ?? this.tagPurpleText,
      focusRing: focusRing ?? this.focusRing,
    );
  }

  @override
  MedusaColors lerp(covariant MedusaColors? other, double t) {
    if (other == null) return this;
    return MedusaColors(
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      bgSubtle: Color.lerp(bgSubtle, other.bgSubtle, t)!,
      bgComponent: Color.lerp(bgComponent, other.bgComponent, t)!,
      bgComponentHover: Color.lerp(
        bgComponentHover,
        other.bgComponentHover,
        t,
      )!,
      bgComponentPressed: Color.lerp(
        bgComponentPressed,
        other.bgComponentPressed,
        t,
      )!,
      bgField: Color.lerp(bgField, other.bgField, t)!,
      bgFieldHover: Color.lerp(bgFieldHover, other.bgFieldHover, t)!,
      bgDisabled: Color.lerp(bgDisabled, other.bgDisabled, t)!,
      bgHighlight: Color.lerp(bgHighlight, other.bgHighlight, t)!,
      fgBase: Color.lerp(fgBase, other.fgBase, t)!,
      fgSubtle: Color.lerp(fgSubtle, other.fgSubtle, t)!,
      fgMuted: Color.lerp(fgMuted, other.fgMuted, t)!,
      fgDisabled: Color.lerp(fgDisabled, other.fgDisabled, t)!,
      borderBase: Color.lerp(borderBase, other.borderBase, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      interactive: Color.lerp(interactive, other.interactive, t)!,
      interactiveHover: Color.lerp(
        interactiveHover,
        other.interactiveHover,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      onColor: Color.lerp(onColor, other.onColor, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      contrastBg: Color.lerp(contrastBg, other.contrastBg, t)!,
      contrastFg: Color.lerp(contrastFg, other.contrastFg, t)!,
      contrastBorder: Color.lerp(contrastBorder, other.contrastBorder, t)!,
      buttonPrimary: Color.lerp(buttonPrimary, other.buttonPrimary, t)!,
      buttonPrimaryHover: Color.lerp(
        buttonPrimaryHover,
        other.buttonPrimaryHover,
        t,
      )!,
      buttonPrimaryPressed: Color.lerp(
        buttonPrimaryPressed,
        other.buttonPrimaryPressed,
        t,
      )!,
      switchOff: Color.lerp(switchOff, other.switchOff, t)!,
      tagNeutralBg: Color.lerp(tagNeutralBg, other.tagNeutralBg, t)!,
      tagBlueBg: Color.lerp(tagBlueBg, other.tagBlueBg, t)!,
      tagBlueText: Color.lerp(tagBlueText, other.tagBlueText, t)!,
      tagGreenBg: Color.lerp(tagGreenBg, other.tagGreenBg, t)!,
      tagGreenText: Color.lerp(tagGreenText, other.tagGreenText, t)!,
      tagOrangeBg: Color.lerp(tagOrangeBg, other.tagOrangeBg, t)!,
      tagOrangeText: Color.lerp(tagOrangeText, other.tagOrangeText, t)!,
      tagRedBg: Color.lerp(tagRedBg, other.tagRedBg, t)!,
      tagRedText: Color.lerp(tagRedText, other.tagRedText, t)!,
      tagPurpleBg: Color.lerp(tagPurpleBg, other.tagPurpleBg, t)!,
      tagPurpleText: Color.lerp(tagPurpleText, other.tagPurpleText, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }
}

extension MedusaThemeContext on BuildContext {
  MedusaColors get medusa =>
      Theme.of(this).extension<MedusaColors>() ?? MedusaColors.light;
}
