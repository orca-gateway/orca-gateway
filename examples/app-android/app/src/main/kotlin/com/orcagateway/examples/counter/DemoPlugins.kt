package com.orcagateway.examples.counter

import android.util.Log
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.sdk.OrcaPlugin
import com.orcagateway.sdk.WidgetBuilder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

// The two plugins the `custom` example app (examples/server/custom.ts) needs,
// as the Flutter example host has them (examples/app/lib/main.dart,
// `_BadgePlugin` and `_DeviceActionsPlugin`). Their widget and action names
// go into the client's capabilities, so the server sends the ColoredBadge
// instead of leaving it out.

private const val TAG = "OrcaDemoPlugins"

/** Draws the server's ColoredBadge: its `label` on a pill of its `color`; a tap fires its `onTap`. */
class BadgePlugin : OrcaPlugin {
    override val name: String = "BadgePlugin"
    override val widgets: Map<String, WidgetBuilder> = mapOf("ColoredBadge" to coloredBadge)
}

private val coloredBadge: WidgetBuilder = { node, model, modifier ->
    val tappable = "onTap" in node.actions
    Box(
        modifier
            .clip(RoundedCornerShape(20.dp))
            .background(badgeColor(node["color"]?.stringValue))
            .then(if (tappable) Modifier.clickable { model.fire("onTap", on = node) } else Modifier)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        Text(
            node["label"]?.stringValue ?: "",
            color = Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.2.sp,
        )
    }
}

/** `#RRGGBB` as a color; grey when absent or unreadable, as Flutter's example. */
private fun badgeColor(hex: String?): Color {
    val rgb = hex?.takeIf { it.length == 7 && it.startsWith("#") }?.drop(1)?.toLongOrNull(16)
    return Color(rgb?.or(0xFF000000) ?: 0xFF888888)
}

/**
 * The device actions of the `custom` app. `hapticFeedback` plays a haptic on
 * [view] (light, medium or heavy; no permission needed). The example has no
 * confetti or store SDK, so `showConfetti`, `rateApp` and `processPayment`
 * only log the action they got. Every action is logged under the tag
 * `OrcaDemoPlugins` (the emulator plays no haptics).
 */
class DeviceActionsPlugin(private val view: View) : OrcaPlugin {
    override val name: String = "DeviceActionsPlugin"
    override val actions: Map<String, OrcaActionHandler> = mapOf(
        "hapticFeedback" to OrcaActionHandler { action, _ ->
            val intensity = (action["intensity"] as? JsonPrimitive)?.contentOrNull ?: "medium"
            Log.i(TAG, "hapticFeedback $intensity")
            view.post { view.performHapticFeedback(hapticConstant(intensity)) }
        },
        "showConfetti" to logOnly("showConfetti"),
        "rateApp" to logOnly("rateApp"),
        "processPayment" to logOnly("processPayment"),
    )
}

private fun hapticConstant(intensity: String): Int = when (intensity) {
    "light" -> HapticFeedbackConstants.CLOCK_TICK
    "heavy" -> HapticFeedbackConstants.LONG_PRESS
    else -> HapticFeedbackConstants.KEYBOARD_TAP
}

private fun logOnly(name: String) = OrcaActionHandler { action, _ -> Log.i(TAG, "$name $action") }
