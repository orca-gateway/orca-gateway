package com.orcagateway.sdk.widgets

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel

/**
 * The app lifecycle the background and foreground triggers follow: the
 * process's (ProcessLifecycleOwner, as SessionLifecycle.kt), so a rotation
 * is neither. Tests provide their own.
 */
internal val LocalOrcaAppLifecycle = staticCompositionLocalOf<Lifecycle> { ProcessLifecycleOwner.get().lifecycle }

/** True when [node] sets a trigger [LifecycleTriggers] fires; NodeView adds it only then, so other nodes keep their tree. */
internal fun hasLifecycleTriggers(node: ResolvedNode): Boolean = node.actions.keys.any { it in LIFECYCLE_TRIGGERS }

private val LIFECYCLE_TRIGGERS = setOf(
    "onInit", "onVisible", "onAppBackground", "onBackground", "onAppForeground", "onForeground",
)

/**
 * The lifecycle triggers of any node, Flutter's OrcaLifecycleWrapper
 * (sdk/lib/src/widgets/lifecycle_wrapper.dart, wrapped in
 * component_renderer.dart:230-255). It draws nothing. Each rule:
 *
 * - onInit, then onVisible, run once per mount, after the composition that first shows the node (LaunchedEffect).
 * - A redraw is not a mount, nor is a covered page coming back on top: the guard is on the page model ([OrcaPageModel.firstMount]).
 * - onVisible is onInit's twin, as in Flutter (no viewport test): "fires once on mount" (action.ts).
 * - onAppBackground (else onBackground) runs on the app's ON_STOP; the trigger fired is the name that is set.
 * - onAppForeground (else onForeground) runs on an ON_START after an ON_STOP: never on the first start, as Flutter's observer comes after resume.
 * - ON_STOP comes about 700 ms after the last activity stops (ProcessLifecycleOwner's delay, so a rotation is no stop); not worked around.
 * - A page under a pushed one hears them too, as Flutter's covered route, though the NavHost took it out of the
 *   composition: its observers are held on the page model meanwhile ([OrcaPageModel.isCovered]).
 * - With several nodes, ON_START reaches them in the order they began observing and ON_STOP the other way round
 *   (LifecycleRegistry), so the pushed page's onAppBackground runs before the covered one's; Flutter runs both in order.
 */
@Composable
internal fun LifecycleTriggers(node: ResolvedNode, model: OrcaPageModel) {
    val current = rememberUpdatedState(node)
    if ("onInit" in node.actions || "onVisible" in node.actions) {
        LaunchedEffect(model, node.id) {
            for (trigger in MOUNT_TRIGGERS) {
                val now = current.value
                if (trigger in now.actions && model.firstMount(now.id, trigger)) model.fire(trigger, now)
            }
        }
    }
    val background = appTrigger(node, "onAppBackground", "onBackground")
    val foreground = appTrigger(node, "onAppForeground", "onForeground")
    if (background == null && foreground == null) return
    val lifecycle = LocalOrcaAppLifecycle.current
    DisposableEffect(lifecycle, model, background, foreground) {
        // A new observer is brought up to the current state, so its first
        // ON_START is a replay or the first start: only one after an ON_STOP counts.
        var stopped = false
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_STOP -> {
                    stopped = true
                    background?.let { model.fire(it, current.value) }
                }
                Lifecycle.Event.ON_START -> if (stopped) {
                    stopped = false
                    foreground?.let { model.fire(it, current.value) }
                }
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose { model.appObserverLeft { lifecycle.removeObserver(observer) } }
    }
}

private val MOUNT_TRIGGERS = listOf("onInit", "onVisible")

/** [long] when the node sets it, else [short] when it sets that, else null: the `onApp*` name wins. */
private fun appTrigger(node: ResolvedNode, long: String, short: String): String? = when {
    long in node.actions -> long
    short in node.actions -> short
    else -> null
}
