import 'package:flutter/material.dart';

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Brightness brightness;
  final Color background;
  final Color text;
  final Color cardBackground;
  final Color cardBorder;
  final Color iconBackground;
  final Color iconColor;
  final Color iconBorder;
  final Color inputBackground;
  final Color inputBorder;
  final Color buttonBackground;
  final Color buttonText;

  // NUEVOS COLORES SEMÁNTICOS
  final Color successColor;
  final Color errorColor;
  final Color warningColor;
  final Color infoColor;

  const AppThemeColors({
    required this.brightness,
    required this.background,
    required this.text,
    required this.cardBackground,
    required this.cardBorder,
    required this.iconBackground,
    required this.iconColor,
    required this.iconBorder,
    required this.inputBackground,
    required this.inputBorder,
    required this.buttonBackground,
    required this.buttonText,
    required this.successColor,
    required this.errorColor,
    required this.warningColor,
    required this.infoColor,
  });

  factory AppThemeColors.light() {
    return const AppThemeColors(
      brightness: Brightness.light,
      background: Color(0xFFF9F6EE),
      text: Colors.black,
      cardBackground: Colors.white,
      cardBorder: Colors.black,
      iconBackground: Colors.black,
      iconColor: Colors.white,
      iconBorder: Colors.black,
      inputBackground: Color(0xFFF3F3F3),
      inputBorder: Colors.black,
      buttonBackground: Color(0xFFE0E0E0),
      buttonText: Colors.black,
      successColor: Colors.green,
      errorColor: Colors.red,
      warningColor: Colors.orange,
      infoColor: Colors.blue,
    );
  }

  factory AppThemeColors.dark() {
    return const AppThemeColors(
      brightness: Brightness.dark,
      background: Color(0xFF121212),
      text: Colors.white,
      cardBackground: Color(0xFF1E1E1E),
      cardBorder: Colors.white,
      iconBackground: Colors.white,
      iconColor: Colors.grey,
      iconBorder: Colors.white,
      inputBackground: Color(0xFF1A1A1A),
      inputBorder: Colors.white,
      buttonBackground: Color(0xFF333333),
      buttonText: Colors.white,
      successColor: Colors.green,
      errorColor: Colors.redAccent, // Un rojo más suave para dark mode
      warningColor: Colors.orange,
      infoColor: Colors.blueAccent,
    );
  }

  factory AppThemeColors.custom(Map<String, dynamic>? colors) {
    final Color fallback = Colors.white;

    final bg = colors?['bg'] != null ? Color(colors!['bg']) : fallback;
    final txt = colors?['text'] != null ? Color(colors!['text']) : fallback;
    final cardBg = colors?['cardBg'] != null
        ? Color(colors!['cardBg'])
        : bg.withValues(alpha: 0.8);
    final cardBorder = colors?['cardBorder'] != null
        ? Color(colors!['cardBorder'])
        : txt.withValues(alpha: 0.5);
    final icnBg = colors?['iconBg'] != null
        ? Color(colors!['iconBg'])
        : fallback;
    final icn = colors?['icon'] != null ? Color(colors!['icon']) : fallback;
    final icnBorder = colors?['iconBorder'] != null
        ? Color(colors!['iconBorder'])
        : txt;
    final inp = colors?['input'] != null ? Color(colors!['input']) : fallback;
    final btnBg = colors?['btnBg'] != null ? Color(colors!['btnBg']) : fallback;

    // Semánticos customizables, con fallback a los universales
    final success = colors?['success'] != null
        ? Color(colors!['success'])
        : Colors.green;
    final error = colors?['error'] != null
        ? Color(colors!['error'])
        : Colors.red;
    final warning = colors?['warning'] != null
        ? Color(colors!['warning'])
        : Colors.orange;
    final info = colors?['info'] != null ? Color(colors!['info']) : Colors.blue;

    return AppThemeColors(
      brightness: bg.computeLuminance() > 0.5
          ? Brightness.light
          : Brightness.dark,
      background: bg,
      text: txt,
      cardBackground: cardBg,
      cardBorder: cardBorder,
      iconBackground: icnBg,
      iconColor: icn,
      iconBorder: icnBorder,
      inputBackground: txt.withValues(alpha: 0.05),
      inputBorder: inp,
      buttonBackground: btnBg,
      buttonText: txt,
      successColor: success,
      errorColor: error,
      warningColor: warning,
      infoColor: info,
    );
  }

  @override
  ThemeExtension<AppThemeColors> copyWith({
    Brightness? brightness,
    Color? background,
    Color? text,
    Color? cardBackground,
    Color? cardBorder,
    Color? iconBackground,
    Color? iconColor,
    Color? iconBorder,
    Color? inputBackground,
    Color? inputBorder,
    Color? buttonBackground,
    Color? buttonText,
    Color? successColor,
    Color? errorColor,
    Color? warningColor,
    Color? infoColor,
  }) {
    return AppThemeColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      text: text ?? this.text,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      iconBackground: iconBackground ?? this.iconBackground,
      iconColor: iconColor ?? this.iconColor,
      iconBorder: iconBorder ?? this.iconBorder,
      inputBackground: inputBackground ?? this.inputBackground,
      inputBorder: inputBorder ?? this.inputBorder,
      buttonBackground: buttonBackground ?? this.buttonBackground,
      buttonText: buttonText ?? this.buttonText,
      successColor: successColor ?? this.successColor,
      errorColor: errorColor ?? this.errorColor,
      warningColor: warningColor ?? this.warningColor,
      infoColor: infoColor ?? this.infoColor,
    );
  }

  @override
  ThemeExtension<AppThemeColors> lerp(
    covariant ThemeExtension<AppThemeColors>? other,
    double t,
  ) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      text: Color.lerp(text, other.text, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      iconBackground: Color.lerp(iconBackground, other.iconBackground, t)!,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      iconBorder: Color.lerp(iconBorder, other.iconBorder, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      buttonBackground: Color.lerp(
        buttonBackground,
        other.buttonBackground,
        t,
      )!,
      buttonText: Color.lerp(buttonText, other.buttonText, t)!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      errorColor: Color.lerp(errorColor, other.errorColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      infoColor: Color.lerp(infoColor, other.infoColor, t)!,
    );
  }
}
