package com.orcagateway.sdk.style

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import com.orcagateway.core.render.ResolvedNode

/**
 * What the host app sets for the views an Orca page draws, the Kotlin side
 * of the `ThemeData` a Flutter host gives its MaterialApp (Swift
 * `OrcaTheme`). For now: a button style per button type, as
 * `elevatedButtonTheme`, `outlinedButtonTheme` and `textButtonTheme`. Set it
 * once above the pages through [LocalOrcaTheme]; it reaches every page of an
 * [OrcaApp][com.orcagateway.sdk.OrcaApp], pushed ones too.
 *
 *     CompositionLocalProvider(
 *         LocalOrcaTheme provides OrcaTheme(
 *             elevatedButton = OrcaButtonStyle(
 *                 shape = CircleShape,
 *                 containerColor = Color(0xFFFF9800),
 *                 contentColor = Color.White,
 *                 contentPadding = PaddingValues(horizontal = 20.dp, vertical = 12.dp),
 *             ),
 *         ),
 *     ) {
 *         OrcaApp(client)
 *     }
 *
 * A type without a style is drawn as before. The server wins: a button
 * whose node carries its own style props (ElevatedButton `backgroundColor`,
 * `foregroundColor`, `borderRadius`, `padding`; OutlinedButton `color`,
 * `borderColor`; TextButton `color`) is drawn with those, not with the host
 * style.
 */
public class OrcaTheme(
    public val elevatedButton: OrcaButtonStyle? = null,
    public val outlinedButton: OrcaButtonStyle? = null,
    public val textButton: OrcaButtonStyle? = null,
) {
    /**
     * The host style for a button node, or null when the host set none for
     * its type or the server styled the button itself.
     */
    internal fun buttonStyle(node: ResolvedNode): OrcaButtonStyle? {
        val serverStyled = SERVER_STYLE_PROPS[node.type].orEmpty().any { node[it] != null }
        if (serverStyled) return null
        return when (node.type) {
            "ElevatedButton" -> elevatedButton
            "OutlinedButton" -> outlinedButton
            "TextButton" -> textButton
            else -> null
        }
    }
}

/**
 * How the host draws one button type, for [OrcaTheme]. Each part it sets
 * replaces that button's Material 3 default (`ButtonDefaults`); each it
 * leaves out (null, or [Color.Unspecified]) keeps it. The disabled colours
 * and the elevation stay as they are.
 */
public class OrcaButtonStyle(
    public val shape: Shape? = null,
    public val containerColor: Color = Color.Unspecified,
    public val contentColor: Color = Color.Unspecified,
    public val border: BorderStroke? = null,
    public val contentPadding: PaddingValues? = null,
)

/** The host's [OrcaTheme] for the Orca pages below it; empty by default. */
public val LocalOrcaTheme: ProvidableCompositionLocal<OrcaTheme> = staticCompositionLocalOf { OrcaTheme() }

/** The server props that style each button type. */
private val SERVER_STYLE_PROPS: Map<String, List<String>> = mapOf(
    "ElevatedButton" to listOf("backgroundColor", "foregroundColor", "borderRadius", "padding"),
    "OutlinedButton" to listOf("color", "borderColor"),
    "TextButton" to listOf("color"),
)
