import 'package:flutter/material.dart';

/// Event families supported by the visual system.
///
/// These are presentation-only categories. They must never be used to infer
/// ticket ownership, provider inventory, or swap eligibility.
enum SwappyEventTone { music, sports, arts, family, neutral }

@immutable
class SwappyEventPalette {
  const SwappyEventPalette({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );
}

/// Swappy's expressive visual layer.
///
/// Material's [ColorScheme] remains the source of truth for semantic states
/// such as errors and disabled controls. These tokens cover branded event
/// energy, elevated surfaces, glass and category accents.
@immutable
class SwappyVisualTokens extends ThemeExtension<SwappyVisualTokens> {
  const SwappyVisualTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.brandViolet,
    required this.neonCyan,
    required this.energyCoral,
    required this.celebrationGold,
    required this.glassFill,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassShadow,
    required this.eventHeroScrim,
    required this.eventHeroControl,
    required this.selectedIconStroke,
    required this.inactiveIcon,
    required this.onEnergy,
    required this.sportsPrimary,
    required this.sportsSecondary,
    required this.artsPrimary,
    required this.artsSecondary,
    required this.familyPrimary,
    required this.familySecondary,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color brandViolet;
  final Color neonCyan;
  final Color energyCoral;
  final Color celebrationGold;
  final Color glassFill;
  final Color glassBorder;
  final Color glassHighlight;
  final Color glassShadow;
  final Color eventHeroScrim;
  final Color eventHeroControl;
  final Color selectedIconStroke;
  final Color inactiveIcon;
  final Color onEnergy;
  final Color sportsPrimary;
  final Color sportsSecondary;
  final Color artsPrimary;
  final Color artsSecondary;
  final Color familyPrimary;
  final Color familySecondary;

  static const light = SwappyVisualTokens(
    canvas: Color(0xFFF8F6FF),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    brandViolet: Color(0xFF6D28D9),
    neonCyan: Color(0xFF00AFC8),
    energyCoral: Color(0xFFFF5C73),
    celebrationGold: Color(0xFFFFB648),
    glassFill: Color(0xD9FFFFFF),
    glassBorder: Color(0x8AFFFFFF),
    glassHighlight: Color(0xBFFFFFFF),
    glassShadow: Color(0x3307112A),
    eventHeroScrim: Color(0xF2070B18),
    eventHeroControl: Color(0xA6070B18),
    selectedIconStroke: Color(0xFF6D28D9),
    inactiveIcon: Color(0xFF667085),
    onEnergy: Color(0xFFFFFFFF),
    sportsPrimary: Color(0xFF2563EB),
    sportsSecondary: Color(0xFF65A30D),
    artsPrimary: Color(0xFFC026D3),
    artsSecondary: Color(0xFFFB7185),
    familyPrimary: Color(0xFFD97706),
    familySecondary: Color(0xFF0284C7),
  );

  static const dark = SwappyVisualTokens(
    canvas: Color(0xFF070B18),
    surface: Color(0xFF10162A),
    surfaceRaised: Color(0xFF171E38),
    brandViolet: Color(0xFFA970FF),
    neonCyan: Color(0xFF46DCEB),
    energyCoral: Color(0xFFFF667F),
    celebrationGold: Color(0xFFFFC857),
    glassFill: Color(0xB3121930),
    glassBorder: Color(0x667DD3FC),
    glassHighlight: Color(0x3DFFFFFF),
    glassShadow: Color(0xB3000000),
    eventHeroScrim: Color(0xF2070B18),
    eventHeroControl: Color(0xA6070B18),
    selectedIconStroke: Color(0xFFC7A2FF),
    inactiveIcon: Color(0xFF9AA4BD),
    onEnergy: Color(0xFFFFFFFF),
    sportsPrimary: Color(0xFF60A5FA),
    sportsSecondary: Color(0xFFA3E635),
    artsPrimary: Color(0xFFE879F9),
    artsSecondary: Color(0xFFFB7185),
    familyPrimary: Color(0xFFFBBF24),
    familySecondary: Color(0xFF38BDF8),
  );

  LinearGradient get ambientGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      brandViolet.withValues(alpha: 0.24),
      canvas,
      neonCyan.withValues(alpha: 0.12),
    ],
    stops: const [0, 0.52, 1],
  );

  LinearGradient get primaryActionGradient => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brandViolet, Color.lerp(brandViolet, neonCyan, 0.28)!],
  );

  LinearGradient get glassGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [glassHighlight, glassFill, glassFill.withValues(alpha: 0.76)],
    stops: const [0, 0.36, 1],
  );

  LinearGradient get dockRimGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      brandViolet.withValues(alpha: 0.82),
      glassBorder,
      neonCyan.withValues(alpha: 0.78),
    ],
  );

  LinearGradient get selectedIconGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [selectedIconStroke, neonCyan],
  );

  LinearGradient get eventHeroScrimGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, eventHeroScrim],
  );

  SwappyEventPalette eventPalette(SwappyEventTone tone) => switch (tone) {
    SwappyEventTone.music => SwappyEventPalette(
      primary: brandViolet,
      secondary: neonCyan,
    ),
    SwappyEventTone.sports => SwappyEventPalette(
      primary: sportsPrimary,
      secondary: sportsSecondary,
    ),
    SwappyEventTone.arts => SwappyEventPalette(
      primary: artsPrimary,
      secondary: artsSecondary,
    ),
    SwappyEventTone.family => SwappyEventPalette(
      primary: familyPrimary,
      secondary: familySecondary,
    ),
    SwappyEventTone.neutral => SwappyEventPalette(
      primary: brandViolet,
      secondary: energyCoral,
    ),
  };

  @override
  SwappyVisualTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? brandViolet,
    Color? neonCyan,
    Color? energyCoral,
    Color? celebrationGold,
    Color? glassFill,
    Color? glassBorder,
    Color? glassHighlight,
    Color? glassShadow,
    Color? eventHeroScrim,
    Color? eventHeroControl,
    Color? selectedIconStroke,
    Color? inactiveIcon,
    Color? onEnergy,
    Color? sportsPrimary,
    Color? sportsSecondary,
    Color? artsPrimary,
    Color? artsSecondary,
    Color? familyPrimary,
    Color? familySecondary,
  }) => SwappyVisualTokens(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    brandViolet: brandViolet ?? this.brandViolet,
    neonCyan: neonCyan ?? this.neonCyan,
    energyCoral: energyCoral ?? this.energyCoral,
    celebrationGold: celebrationGold ?? this.celebrationGold,
    glassFill: glassFill ?? this.glassFill,
    glassBorder: glassBorder ?? this.glassBorder,
    glassHighlight: glassHighlight ?? this.glassHighlight,
    glassShadow: glassShadow ?? this.glassShadow,
    eventHeroScrim: eventHeroScrim ?? this.eventHeroScrim,
    eventHeroControl: eventHeroControl ?? this.eventHeroControl,
    selectedIconStroke: selectedIconStroke ?? this.selectedIconStroke,
    inactiveIcon: inactiveIcon ?? this.inactiveIcon,
    onEnergy: onEnergy ?? this.onEnergy,
    sportsPrimary: sportsPrimary ?? this.sportsPrimary,
    sportsSecondary: sportsSecondary ?? this.sportsSecondary,
    artsPrimary: artsPrimary ?? this.artsPrimary,
    artsSecondary: artsSecondary ?? this.artsSecondary,
    familyPrimary: familyPrimary ?? this.familyPrimary,
    familySecondary: familySecondary ?? this.familySecondary,
  );

  @override
  SwappyVisualTokens lerp(covariant SwappyVisualTokens? other, double t) {
    if (other == null) return this;
    return SwappyVisualTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      brandViolet: Color.lerp(brandViolet, other.brandViolet, t)!,
      neonCyan: Color.lerp(neonCyan, other.neonCyan, t)!,
      energyCoral: Color.lerp(energyCoral, other.energyCoral, t)!,
      celebrationGold: Color.lerp(celebrationGold, other.celebrationGold, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      eventHeroScrim: Color.lerp(eventHeroScrim, other.eventHeroScrim, t)!,
      eventHeroControl: Color.lerp(
        eventHeroControl,
        other.eventHeroControl,
        t,
      )!,
      selectedIconStroke: Color.lerp(
        selectedIconStroke,
        other.selectedIconStroke,
        t,
      )!,
      inactiveIcon: Color.lerp(inactiveIcon, other.inactiveIcon, t)!,
      onEnergy: Color.lerp(onEnergy, other.onEnergy, t)!,
      sportsPrimary: Color.lerp(sportsPrimary, other.sportsPrimary, t)!,
      sportsSecondary: Color.lerp(sportsSecondary, other.sportsSecondary, t)!,
      artsPrimary: Color.lerp(artsPrimary, other.artsPrimary, t)!,
      artsSecondary: Color.lerp(artsSecondary, other.artsSecondary, t)!,
      familyPrimary: Color.lerp(familyPrimary, other.familyPrimary, t)!,
      familySecondary: Color.lerp(familySecondary, other.familySecondary, t)!,
    );
  }
}

abstract final class SwappySpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class SwappyRadii {
  static const double compact = 10;
  static const double control = 14;
  static const double card = 18;
  static const double sheet = 28;
  static const double dock = 32;
  static const double pill = 999;
}

abstract final class SwappyMotion {
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration emphasized = Duration(milliseconds: 420);
  static const Curve fluid = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve expressive = Cubic(0.16, 1, 0.3, 1);

  static Duration duration(BuildContext context, Duration preferred) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : preferred;
}

extension SwappyVisualThemeContext on BuildContext {
  SwappyVisualTokens get swappyVisual =>
      Theme.of(this).extension<SwappyVisualTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? SwappyVisualTokens.dark
          : SwappyVisualTokens.light);
}
