import 'package:flutter/material.dart';

/// HealthMate visual language: warm off-white surfaces, a refined clinical
/// green, deep ink text and a restrained mint accent. The system is deliberately
/// calm: generous spacing, 20px cards, hairline borders and one soft shadow.
class AppColors {
  AppColors._();

  /// Signature HealthMate green. Kept close to the original identity while
  /// deepening it slightly for better contrast on white.
  static const teal = Color(0xFF0E8C7F);
  static const tealDark = Color(0xFF086A60);
  static const tealDeep = Color(0xFF064B45);
  static const tealSoft = Color(0xFFE8F6F1);
  static const mint = Color(0xFFDDF3EC);
  static const mintBackground = Color(0xFFF5FAF7);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF2F7F5);

  static const navy = Color(0xFF0D2733);
  static const slate = Color(0xFF5E7280);

  /// Captions and metadata use the same slate token so text never drifts below
  /// a readable contrast ratio.
  static const muted = slate;
  static const border = Color(0xFFDCEAE4);
  static const borderStrong = Color(0xFFC8DCD4);
  static const neutralSoft = Color(0xFFF0F5F2);

  static const danger = Color(0xFFC33C3C);
  static const dangerSoft = Color(0xFFFCEDEC);
  static const warning = Color(0xFF9A5B10);
  static const warningSoft = Color(0xFFFCF2E4);
  static const success = Color(0xFF167A52);
  static const successSoft = Color(0xFFE8F5EE);
  static const info = Color(0xFF2563A8);
  static const infoSoft = Color(0xFFEDF4FC);

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF08766B), Color(0xFF11A391)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const softGradient = LinearGradient(
    colors: [Color(0xFFF0FAF6), Color(0xFFE4F4EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppRadii {
  AppRadii._();
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 26.0;
  static const pill = 999.0;
}

class AppSpacing {
  AppSpacing._();
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
}

class AppMotion {
  AppMotion._();
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const gentle = Duration(milliseconds: 320);
}

class AppShadows {
  AppShadows._();
  static const card = [
    BoxShadow(
      color: Color(0x0C0D2733),
      blurRadius: 18,
      offset: Offset(0, 4),
    ),
  ];

  static const raised = [
    BoxShadow(
      color: Color(0x140D2733),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  static const brand = [
    BoxShadow(
      color: Color(0x2E0E8C7F),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static const _fontFamily = 'PlusJakartaSans';

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.teal,
      onPrimary: Colors.white,
      primaryContainer: AppColors.tealSoft,
      onPrimaryContainer: AppColors.tealDeep,
      secondary: AppColors.tealDark,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.mint,
      onSecondaryContainer: AppColors.tealDeep,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.infoSoft,
      onTertiaryContainer: AppColors.info,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerSoft,
      onErrorContainer: AppColors.danger,
      surface: AppColors.surface,
      onSurface: AppColors.navy,
      surfaceContainerHighest: AppColors.neutralSoft,
      onSurfaceVariant: AppColors.slate,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      shadow: Color(0x1A0D2733),
      scrim: Color(0x660D2733),
      inverseSurface: AppColors.navy,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFF6ED8C9),
    );

    final baseText = ThemeData.light().textTheme.apply(
          fontFamily: _fontFamily,
          bodyColor: AppColors.navy,
          displayColor: AppColors.navy,
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.mintBackground,
      hoverColor: AppColors.teal.withValues(alpha: 0.05),
      focusColor: AppColors.teal.withValues(alpha: 0.30),
      splashColor: AppColors.teal.withValues(alpha: 0.09),
      highlightColor: AppColors.teal.withValues(alpha: 0.04),
      textTheme: baseText.copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          height: 1.12,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
          height: 1.16,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
          height: 1.22,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        titleSmall: baseText.titleSmall?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          color: AppColors.navy,
          height: 1.55,
          fontSize: 15.5,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: AppColors.slate,
          height: 1.55,
          fontSize: 14,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          color: AppColors.muted,
          height: 1.48,
          fontSize: 12.5,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelMedium: baseText.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.mintBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        titleTextStyle: baseText.titleLarge?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColors.slate, fontSize: 14),
        floatingLabelStyle: const TextStyle(
          color: AppColors.tealDark,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13.5),
        prefixIconColor: AppColors.slate,
        suffixIconColor: AppColors.slate,
        helperStyle: const TextStyle(color: AppColors.slate, fontSize: 12),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF0E8C7F).withValues(alpha: 0.32),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.borderStrong, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.tealDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.navy,
          highlightColor: AppColors.tealSoft,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.teal,
        disabledColor: const Color(0xFFF0F5F2),
        labelStyle: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w600,
          fontFamily: _fontFamily,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontFamily: _fontFamily,
        ),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.tealSoft,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.tealDark
                : AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? AppColors.teal
                : AppColors.muted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: _fontFamily,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        titleTextStyle: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.teal,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.slate,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        headerBackgroundColor: AppColors.teal,
        headerForegroundColor: Colors.white,
        weekdayStyle: const TextStyle(
          color: AppColors.slate,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        dayStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: AppColors.navy,
        ),
        todayForegroundColor: const WidgetStatePropertyAll(AppColors.tealDark),
        todayBorder: const BorderSide(color: AppColors.teal),
        rangeSelectionBackgroundColor: AppColors.tealSoft,
        yearForegroundColor: const WidgetStatePropertyAll(AppColors.navy),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        dialBackgroundColor: AppColors.surfaceMuted,
        hourMinuteColor: AppColors.tealSoft,
        hourMinuteTextColor: AppColors.tealDark,
        dialHandColor: AppColors.teal,
        entryModeIconColor: AppColors.tealDark,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.teal
              : const Color(0xFFD7E4DF),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.teal,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.tealDark,
        overlayColor: Color(0x1A0E8C7F),
      ),
    );
  }
}

/// A readable content column for desktop/tablet. Keeps the browser experience
/// app-like instead of stretching cards across the whole monitor.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
