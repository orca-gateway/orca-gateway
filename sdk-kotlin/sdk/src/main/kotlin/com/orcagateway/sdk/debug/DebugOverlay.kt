package com.orcagateway.sdk.debug

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.absolutePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.debug.OrcaDebug
import com.orcagateway.core.json.DartFormat
import com.orcagateway.sdk.OrcaPageModel

/**
 * The UI layer's half of [OrcaDebugConfig]: whether pages draw the debug
 * overlay (Flutter `OrcaDebug.config.showOverlay`). [OrcaDebug.start] sets it
 * from the config, [OrcaDebug.stop] turns it off. Compose state, so a page on
 * screen follows a start or a stop.
 */
internal object DebugOverlaySwitch {
    var showOverlay: Boolean by mutableStateOf(false)
}

/**
 * Flutter's OrcaDebugOverlay over a page (orca_page.dart:396-403): drawn only
 * while DevTools is on and [DebugOverlaySwitch.showOverlay] is set, with the
 * page's load ([loadMs], request start to render complete) and its current
 * node count. Nothing is drawn or laid out otherwise.
 */
@Composable
internal fun PageDebugOverlay(model: OrcaPageModel, loadMs: Double?, modifier: Modifier = Modifier) {
    // The switch first: it is the Compose state a start or a stop changes.
    if (!DebugOverlaySwitch.showOverlay || !OrcaDebug.isEnabled) return
    // Flutter counts the store's nodes on every build: server actions change it.
    val count = remember(model, model.structureRevision) { model.renderer.nodes.size }
    DebugOverlayChip(loadMs, count, modifier)
}

/**
 * Flutter's chip (sdk/lib/src/debug/debug_overlay.dart): 8 dp in from the
 * right and bottom of where [modifier] places it, black 87% with radius 6;
 * `<load>ms` collapsed, and on a tap the right-aligned `Load: x.xms`,
 * `Components: n`, `Cache: -` (Flutter never passes a cache status). A
 * missing load or count shows `-`. Only the chip takes touches.
 */
@Composable
internal fun DebugOverlayChip(loadMs: Double?, componentCount: Int?, modifier: Modifier = Modifier) {
    var expanded by remember { mutableStateOf(false) }
    Box(
        modifier
            .absolutePadding(right = 8.dp, bottom = 8.dp)
            .testTag(DEBUG_OVERLAY_TAG)
            .background(BLACK_87, RoundedCornerShape(6.dp))
            .clickable(interactionSource = null, indication = null) { expanded = !expanded }
            .padding(horizontal = 8.dp, vertical = 4.dp),
    ) {
        if (expanded) {
            Column(horizontalAlignment = Alignment.End) {
                BasicText("Load: ${fixed(loadMs, 1)}ms", style = mono(GREEN_ACCENT, 11))
                BasicText("Components: ${componentCount ?: "-"}", style = mono(WHITE_70, 11))
                BasicText("Cache: -", style = mono(WHITE_70, 11))
            }
        } else {
            BasicText("${fixed(loadMs, 0)}ms", style = mono(GREEN_ACCENT, 12))
        }
    }
}

/** Dart `toStringAsFixed`, `-` for no value. */
private fun fixed(ms: Double?, digits: Long): String = ms?.let { DartFormat.fixed(it, digits) } ?: "-"

private fun mono(color: Color, size: Int) = TextStyle(color = color, fontSize = size.sp, fontFamily = FontFamily.Monospace)

/** Flutter `Colors.black87`, `Colors.greenAccent`, `Colors.white70`. */
private val BLACK_87 = Color(0xDD000000)
private val GREEN_ACCENT = Color(0xFF69F0AE)
private val WHITE_70 = Color(0xB3FFFFFF)

/** The test tag of the overlay's chip. */
internal const val DEBUG_OVERLAY_TAG: String = "orca-debug-overlay"
