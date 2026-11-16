package com.orcagateway.sdk.widgets

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

/**
 * Flutter's `ThemeData()` colours: its Material 3 light scheme
 * (`_colorSchemeLightM3`, color_scheme_defaults.g.dart), the theme
 * Flutter's builders wrap a Scaffold and their Material controls in
 * (`Theme(data: ThemeData())`). Compose's `lightColorScheme()` is the same
 * baseline but for the four on-container roles, which Flutter takes from
 * tone 30 and Compose from tone 10: those four are set here, every other
 * role is Compose's default, equal to Flutter's.
 */
internal val FlutterLightScheme: ColorScheme = lightColorScheme(
    onPrimaryContainer = Color(0xFF4F378B),
    onSecondaryContainer = Color(0xFF4A4458),
    onTertiaryContainer = Color(0xFF633B48),
    onErrorContainer = Color(0xFF8C1D18),
)
