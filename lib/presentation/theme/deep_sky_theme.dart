import 'package:material_ui/material_ui.dart';

/// Design System DS-2 semantic color and surface tokens (V-06, V-08, V-09).
@immutable
class DeepSkyTokens extends ThemeExtension<DeepSkyTokens> {
  const DeepSkyTokens({
    required this.skyBackdrop,
    required this.cardSurface,
    required this.cardBorder,
    required this.warmGlow,
    required this.calmAccent,
    required this.mutedInk,
    required this.offlineBannerSurface,
    required this.offlineBannerInk,
  });

  final Color skyBackdrop;
  final Color cardSurface;
  final Color cardBorder;
  final Color warmGlow;
  final Color calmAccent;
  final Color mutedInk;
  final Color offlineBannerSurface;
  final Color offlineBannerInk;

  static const DeepSkyTokens light = DeepSkyTokens(
    skyBackdrop: Color(0xFFF6F1E7),
    cardSurface: Color(0xFFFFFCF7),
    cardBorder: Color(0xFFE4DACB),
    warmGlow: Color(0xFFD9843B),
    calmAccent: Color(0xFF3E5879),
    mutedInk: Color(0xFF5D574F),
    offlineBannerSurface: Color(0xFFF2E6D8),
    offlineBannerInk: Color(0xFF5F4428),
  );

  static const DeepSkyTokens dark = DeepSkyTokens(
    skyBackdrop: Color(0xFF141A29),
    cardSurface: Color(0xFF1E263A),
    cardBorder: Color(0xFF313B55),
    warmGlow: Color(0xFFE8A45D),
    calmAccent: Color(0xFF9DB7DF),
    mutedInk: Color(0xFFB8C0D2),
    offlineBannerSurface: Color(0xFF2B2620),
    offlineBannerInk: Color(0xFFE7C7A3),
  );

  @override
  DeepSkyTokens copyWith({
    Color? skyBackdrop,
    Color? cardSurface,
    Color? cardBorder,
    Color? warmGlow,
    Color? calmAccent,
    Color? mutedInk,
    Color? offlineBannerSurface,
    Color? offlineBannerInk,
  }) {
    return DeepSkyTokens(
      skyBackdrop: skyBackdrop ?? this.skyBackdrop,
      cardSurface: cardSurface ?? this.cardSurface,
      cardBorder: cardBorder ?? this.cardBorder,
      warmGlow: warmGlow ?? this.warmGlow,
      calmAccent: calmAccent ?? this.calmAccent,
      mutedInk: mutedInk ?? this.mutedInk,
      offlineBannerSurface: offlineBannerSurface ?? this.offlineBannerSurface,
      offlineBannerInk: offlineBannerInk ?? this.offlineBannerInk,
    );
  }

  @override
  DeepSkyTokens lerp(ThemeExtension<DeepSkyTokens>? other, double t) {
    if (other is! DeepSkyTokens) {
      return this;
    }
    return DeepSkyTokens(
      skyBackdrop: Color.lerp(skyBackdrop, other.skyBackdrop, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      warmGlow: Color.lerp(warmGlow, other.warmGlow, t)!,
      calmAccent: Color.lerp(calmAccent, other.calmAccent, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
      offlineBannerSurface: Color.lerp(
        offlineBannerSurface,
        other.offlineBannerSurface,
        t,
      )!,
      offlineBannerInk: Color.lerp(
        offlineBannerInk,
        other.offlineBannerInk,
        t,
      )!,
    );
  }
}

/// DS-2 theme builder enforcing non-alarming twilight & warm paper palettes (V-01..V-10).
class DeepSkyTheme {
  const DeepSkyTheme._();

  static ThemeData light() {
    const DeepSkyTokens tokens = DeepSkyTokens.light;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: tokens.calmAccent,
      brightness: Brightness.light,
      surface: tokens.cardSurface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.skyBackdrop,
      cardTheme: CardThemeData(
        color: tokens.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: tokens.cardBorder),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[tokens],
    );
  }

  static ThemeData dark() {
    const DeepSkyTokens tokens = DeepSkyTokens.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: tokens.calmAccent,
      brightness: Brightness.dark,
      surface: tokens.cardSurface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.skyBackdrop,
      cardTheme: CardThemeData(
        color: tokens.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: tokens.cardBorder),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[tokens],
    );
  }

  static DeepSkyTokens tokensOf(BuildContext context) {
    return Theme.of(context).extension<DeepSkyTokens>() ?? DeepSkyTokens.light;
  }
}
