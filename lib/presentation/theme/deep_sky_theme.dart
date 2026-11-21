import 'package:deep_sky/scene/local_scene_view_state.dart';
import 'package:material_ui/material_ui.dart';

/// Design System semantic tokens for Deep Sky ("Intimate Sanctuary", `DS-3`, `V-06`, `V-08`, `V-09`).
@immutable
class DeepSkyTokens extends ThemeExtension<DeepSkyTokens> {
  const DeepSkyTokens({
    required this.skyBackdrop,
    required this.surfaceLowest,
    required this.surfaceLow,
    required this.cardSurface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.surfaceBright,
    required this.elevatedSurface,
    required this.cardBorder,
    required this.warmGlow,
    required this.amberGlow,
    required this.amberSoft,
    required this.calmAccent,
    required this.accentText,
    required this.blushPetal,
    required this.qrFrameSurface,
    required this.mutedInk,
    required this.offlineBannerSurface,
    required this.offlineBannerInk,
    required this.wallDayTop,
    required this.wallDayBottom,
    required this.wallTwilightTop,
    required this.wallTwilightBottom,
    required this.wallNightTop,
    required this.wallNightBottom,
    required this.floorParquetBase,
  });

  final Color skyBackdrop;
  final Color surfaceLowest;
  final Color surfaceLow;
  final Color cardSurface;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color surfaceBright;
  final Color elevatedSurface;
  final Color cardBorder;
  final Color warmGlow;
  final Color amberGlow;
  final Color amberSoft;
  final Color calmAccent;
  final Color accentText;
  final Color blushPetal;
  final Color qrFrameSurface;
  final Color mutedInk;
  final Color offlineBannerSurface;
  final Color offlineBannerInk;
  final Color wallDayTop;
  final Color wallDayBottom;
  final Color wallTwilightTop;
  final Color wallTwilightBottom;
  final Color wallNightTop;
  final Color wallNightBottom;
  final Color floorParquetBase;

  /// Returns the dynamic room wall colors for the active local [SkyPeriod] (`S2-D01`, `S2-APP-01`).
  LinearGradient wallGradientFor(SkyPeriod period) {
    final (Color top, Color bottom) = switch (period) {
      SkyPeriod.day => (wallDayTop, wallDayBottom),
      SkyPeriod.twilight => (wallTwilightTop, wallTwilightBottom),
      SkyPeriod.night => (wallNightTop, wallNightBottom),
    };
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[top, bottom],
    );
  }

  Color wallHeaderColorFor(SkyPeriod period) {
    return switch (period) {
      SkyPeriod.day => wallDayTop,
      SkyPeriod.twilight => wallTwilightTop,
      SkyPeriod.night => wallNightTop,
    };
  }

  static const DeepSkyTokens light = DeepSkyTokens(
    skyBackdrop: Color(0xFFFFF7FA),
    surfaceLowest: Color(0xFFFFFFFF),
    surfaceLow: Color(0xFFFCEEF4),
    cardSurface: Color(0xFFFFFDFD),
    surfaceHigh: Color(0xFFF8E5EE),
    surfaceHighest: Color(0xFFF1D6E3),
    surfaceBright: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFF5DCE8),
    cardBorder: Color(0xFFDFC4D2),
    warmGlow: Color(0xFFC47B09),
    amberGlow: Color(0xFFD9843B),
    amberSoft: Color(0xFF5C3D00),
    calmAccent: Color(0xFFA43073),
    accentText: Color(0xFF6B1D4E),
    blushPetal: Color(0xFF9E3556),
    qrFrameSurface: Color(0xFFFFFFFF),
    mutedInk: Color(0xFF624758),
    offlineBannerSurface: Color(0xFFF5E5D6),
    offlineBannerInk: Color(0xFF5F4428),
    wallDayTop: Color(0xFFFAF2EC),
    wallDayBottom: Color(0xFFF2E2D9),
    wallTwilightTop: Color(0xFFF3DDE7),
    wallTwilightBottom: Color(0xFFE7C9D8),
    wallNightTop: Color(0xFFE5DFEE),
    wallNightBottom: Color(0xFFD6CEE3),
    floorParquetBase: Color(0xFFA95E38),
  );

  static const DeepSkyTokens dark = DeepSkyTokens(
    skyBackdrop: Color(0xFF190F24),
    surfaceLowest: Color(0xFF13091E),
    surfaceLow: Color(0xFF21172C),
    cardSurface: Color(0xFF251B31),
    surfaceHigh: Color(0xFF30253C),
    surfaceHighest: Color(0xFF3B3047),
    surfaceBright: Color(0xFF40344C),
    elevatedSurface: Color(0xFF2F2242),
    cardBorder: Color(0xFF544249),
    warmGlow: Color(0xFFF9BD22),
    amberGlow: Color(0xFFFBBF24),
    amberSoft: Color(0xFFFEF3C7),
    calmAccent: Color(0xFFFFAFD3),
    accentText: Color(0xFFFBCFE8),
    blushPetal: Color(0xFFFDA4AF),
    qrFrameSurface: Color(0xFFFFF1F2),
    mutedInk: Color(0xFFDAC0C9),
    offlineBannerSurface: Color(0xFF2F2242),
    offlineBannerInk: Color(0xFFFEF3C7),
    wallDayTop: Color(0xFF2D3652),
    wallDayBottom: Color(0xFF232942),
    wallTwilightTop: Color(0xFF311F3E),
    wallTwilightBottom: Color(0xFF231630),
    wallNightTop: Color(0xFF1C2337),
    wallNightBottom: Color(0xFF190F24),
    floorParquetBase: Color(0xFF8C4C2C),
  );

  @override
  DeepSkyTokens copyWith({
    Color? skyBackdrop,
    Color? surfaceLowest,
    Color? surfaceLow,
    Color? cardSurface,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? surfaceBright,
    Color? elevatedSurface,
    Color? cardBorder,
    Color? warmGlow,
    Color? amberGlow,
    Color? amberSoft,
    Color? calmAccent,
    Color? accentText,
    Color? blushPetal,
    Color? qrFrameSurface,
    Color? mutedInk,
    Color? offlineBannerSurface,
    Color? offlineBannerInk,
    Color? wallDayTop,
    Color? wallDayBottom,
    Color? wallTwilightTop,
    Color? wallTwilightBottom,
    Color? wallNightTop,
    Color? wallNightBottom,
    Color? floorParquetBase,
  }) {
    return DeepSkyTokens(
      skyBackdrop: skyBackdrop ?? this.skyBackdrop,
      surfaceLowest: surfaceLowest ?? this.surfaceLowest,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      cardSurface: cardSurface ?? this.cardSurface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHighest: surfaceHighest ?? this.surfaceHighest,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      cardBorder: cardBorder ?? this.cardBorder,
      warmGlow: warmGlow ?? this.warmGlow,
      amberGlow: amberGlow ?? this.amberGlow,
      amberSoft: amberSoft ?? this.amberSoft,
      calmAccent: calmAccent ?? this.calmAccent,
      accentText: accentText ?? this.accentText,
      blushPetal: blushPetal ?? this.blushPetal,
      qrFrameSurface: qrFrameSurface ?? this.qrFrameSurface,
      mutedInk: mutedInk ?? this.mutedInk,
      offlineBannerSurface: offlineBannerSurface ?? this.offlineBannerSurface,
      offlineBannerInk: offlineBannerInk ?? this.offlineBannerInk,
      wallDayTop: wallDayTop ?? this.wallDayTop,
      wallDayBottom: wallDayBottom ?? this.wallDayBottom,
      wallTwilightTop: wallTwilightTop ?? this.wallTwilightTop,
      wallTwilightBottom: wallTwilightBottom ?? this.wallTwilightBottom,
      wallNightTop: wallNightTop ?? this.wallNightTop,
      wallNightBottom: wallNightBottom ?? this.wallNightBottom,
      floorParquetBase: floorParquetBase ?? this.floorParquetBase,
    );
  }

  @override
  DeepSkyTokens lerp(ThemeExtension<DeepSkyTokens>? other, double t) {
    if (other is! DeepSkyTokens) {
      return this;
    }
    return DeepSkyTokens(
      skyBackdrop: Color.lerp(skyBackdrop, other.skyBackdrop, t)!,
      surfaceLowest: Color.lerp(surfaceLowest, other.surfaceLowest, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHighest: Color.lerp(surfaceHighest, other.surfaceHighest, t)!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      warmGlow: Color.lerp(warmGlow, other.warmGlow, t)!,
      amberGlow: Color.lerp(amberGlow, other.amberGlow, t)!,
      amberSoft: Color.lerp(amberSoft, other.amberSoft, t)!,
      calmAccent: Color.lerp(calmAccent, other.calmAccent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      blushPetal: Color.lerp(blushPetal, other.blushPetal, t)!,
      qrFrameSurface: Color.lerp(qrFrameSurface, other.qrFrameSurface, t)!,
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
      wallDayTop: Color.lerp(wallDayTop, other.wallDayTop, t)!,
      wallDayBottom: Color.lerp(wallDayBottom, other.wallDayBottom, t)!,
      wallTwilightTop: Color.lerp(wallTwilightTop, other.wallTwilightTop, t)!,
      wallTwilightBottom: Color.lerp(
        wallTwilightBottom,
        other.wallTwilightBottom,
        t,
      )!,
      wallNightTop: Color.lerp(wallNightTop, other.wallNightTop, t)!,
      wallNightBottom: Color.lerp(wallNightBottom, other.wallNightBottom, t)!,
      floorParquetBase: Color.lerp(
        floorParquetBase,
        other.floorParquetBase,
        t,
      )!,
    );
  }
}

/// Intimate Sanctuary theme builder enforcing calm twilight & warm rose palettes (`DS-3`, `V-01`..`V-10`).
class DeepSkyTheme {
  const DeepSkyTheme._();

  static const String displayFontFamily = 'Plus Jakarta Sans';
  static const String bodyFontFamily = 'Nunito Sans';

  static const double radiusDefault = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 9999.0;

  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double pageMargin = 20.0;

  static ThemeData light() {
    const DeepSkyTokens tokens = DeepSkyTokens.light;
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFA43073),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFF472B6),
      onPrimaryContainer: Color(0xFF3D0026),
      secondary: Color(0xFFB83B5E),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFFDADC),
      onSecondaryContainer: Color(0xFF67001F),
      tertiary: Color(0xFFC47B09),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFDF9F),
      onTertiaryContainer: Color(0xFF473300),
      error: Color(0xFF9E2A3B),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF690005),
      surface: Color(0xFFFFF7FA),
      onSurface: Color(0xFF27142C),
      onSurfaceVariant: Color(0xFF624758),
      outline: Color(0xFF876A7B),
      outlineVariant: Color(0xFFDFC4D2),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFCEEF4),
      surfaceContainer: Color(0xFFFFFDFD),
      surfaceContainerHigh: Color(0xFFF8E5EE),
      surfaceContainerHighest: Color(0xFFF1D6E3),
    );
    return _buildTheme(scheme: scheme, tokens: tokens);
  }

  static ThemeData dark() {
    const DeepSkyTokens tokens = DeepSkyTokens.dark;
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFAFD3),
      onPrimary: Color(0xFF620040),
      primaryContainer: Color(0xFFF472B6),
      onPrimaryContainer: Color(0xFF6D0047),
      secondary: Color(0xFFFFB2B9),
      onSecondary: Color(0xFF67001F),
      secondaryContainer: Color(0xFF891933),
      onSecondaryContainer: Color(0xFFFF97A3),
      tertiary: Color(0xFFF9BD22),
      onTertiary: Color(0xFF402D00),
      tertiaryContainer: Color(0xFFCA9700),
      onTertiaryContainer: Color(0xFF473300),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF190F24),
      onSurface: Color(0xFFEEDCFA),
      onSurfaceVariant: Color(0xFFDAC0C9),
      outline: Color(0xFFA28A93),
      outlineVariant: Color(0xFF544249),
      surfaceContainerLowest: Color(0xFF13091E),
      surfaceContainerLow: Color(0xFF21172C),
      surfaceContainer: Color(0xFF251B31),
      surfaceContainerHigh: Color(0xFF30253C),
      surfaceContainerHighest: Color(0xFF3B3047),
    );
    return _buildTheme(scheme: scheme, tokens: tokens);
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required DeepSkyTokens tokens,
  }) {
    final TextTheme textTheme = TextTheme(
      headlineLarge: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        letterSpacing: -0.28,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        letterSpacing: -0.24,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        letterSpacing: 0.14,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 26 / 17,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 22 / 15,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        letterSpacing: 0.14,
        color: scheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.24,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontFamily: displayFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 14 / 11,
        letterSpacing: 0.22,
        color: scheme.onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: bodyFontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.skyBackdrop,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.skyBackdrop,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: tokens.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: BorderSide(color: tokens.cardBorder.withValues(alpha: 0.28)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          foregroundColor: tokens.accentText,
          side: BorderSide(color: tokens.cardBorder.withValues(alpha: 0.45)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: BorderSide(
            color: tokens.cardBorder.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: BorderSide(
            color: tokens.cardBorder.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          borderSide: BorderSide(color: scheme.primaryContainer, width: 1.5),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }

  static DeepSkyTokens tokensOf(BuildContext context) {
    return Theme.of(context).extension<DeepSkyTokens>() ?? DeepSkyTokens.dark;
  }
}
