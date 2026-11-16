package com.orcagateway.sdk.widgets

import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.triStateToggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TriStateCheckbox
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.FormControls
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.WithColorScheme
import com.orcagateway.sdk.style.Props
import java.util.concurrent.ConcurrentHashMap

/*
 * Flutter's selection controls (`_buildCheckbox` and `_buildRadio`,
 * input_builders.dart). Neither remembers a value of its own: what is drawn
 * is the store at `stateKey`, else the `value` (or `groupValue`) prop, and
 * the node redraws only through its watches, as Flutter's builder is rebuilt
 * only by its WatchBuilder. A tap goes through [edit]: the stateKey write in
 * page scope, then `onChange` with `{value}`.
 */

/**
 * Flutter `Checkbox`: Material 3's `Checkbox` (a `TriStateCheckbox` when
 * `tristate`), its checked box in `activeColor` (Flutter's builder passes
 * no inactive colour), 48 x 48 with its touch target. The value is a bool,
 * or null under `tristate`; a two-state Checkbox draws a missing one as
 * false. A tap sends what Toggleable's cycle gives
 * ([FormControls.checkboxNext]: false, true, then null under `tristate` or
 * false). `enabled` false greys it as Material does and takes no taps;
 * without `onChange` it still takes them and writes its `stateKey`.
 *
 * With a non-empty `label` it is Flutter's `CheckboxListTile` in
 * `ThemeData()`'s light colours: a row as wide as it is let be, at least
 * 56 high, padded 16 at the start and 24 at the end, the shrink-wrapped
 * box (40 x 40) leading, 16 of gap, the label the title in body large,
 * Flutter's disabled colour (black at 0.38) when not enabled; a tap
 * anywhere on the row toggles, and it is one checkbox for accessibility.
 *
 * A state at `stateKey` that is not a bool (Flutter's builder throws) draws
 * the `value` prop, and is logged once per node.
 */
@Composable
internal fun CheckboxWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val enabled = node["enabled"]?.boolValue ?: true
    val tristate = node["tristate"]?.boolValue ?: false
    val value = checkboxValue(node, model)
    val drawn = if (tristate) value else value ?: false
    val state = when (drawn) {
        true -> ToggleableState.On
        false -> ToggleableState.Off
        null -> ToggleableState.Indeterminate
    }
    val toggle = {
        val next = FormControls.checkboxNext(drawn, tristate)
        edit(node, model, next?.let { JsonValue.Bool(it) } ?: JsonValue.Null)
    }
    val activeColor = Props.color(node["activeColor"])
    val label = Props.text(node["label"])
    if (label.isEmpty()) {
        MaterialCheckbox(state, tristate, toggle, modifier, enabled, activeColor)
        return
    }
    WithColorScheme(flutterLight) {
        Row(
            modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .triStateToggleable(state = state, enabled = enabled, role = Role.Checkbox, onClick = toggle)
                .padding(start = 16.dp, end = 24.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) {
                MaterialCheckbox(state, tristate, null, Modifier, enabled, activeColor)
            }
            Spacer(Modifier.width(16.dp))
            Text(
                label,
                Modifier.weight(1f),
                color = if (enabled) MaterialTheme.colorScheme.onSurface else FLUTTER_DISABLED,
                style = MaterialTheme.typography.bodyLarge,
            )
        }
    }
}

/** Material 3's checkbox in [state], its checked box in [activeColor] when set; [onClick] null leaves the taps to the row. */
@Composable
private fun MaterialCheckbox(
    state: ToggleableState,
    tristate: Boolean,
    onClick: (() -> Unit)?,
    modifier: Modifier,
    enabled: Boolean,
    activeColor: Color?,
) {
    val colors = CheckboxDefaults.colors(checkedColor = activeColor ?: Color.Unspecified)
    if (tristate) {
        TriStateCheckbox(state, onClick, modifier, enabled, colors)
    } else {
        val onCheckedChange: ((Boolean) -> Unit)? = onClick?.let { tap -> { _ -> tap() } }
        Checkbox(state == ToggleableState.On, onCheckedChange, modifier, enabled, colors)
    }
}

/** The Checkbox's value ([pageValue]): a bool, null when absent, the `value` prop for anything else. */
@Composable
private fun checkboxValue(node: ResolvedNode, model: OrcaPageModel): Boolean? {
    val value = pageValue(node, model)
    if (value == null || value.isNull) return null
    value.boolValue?.let { return it }
    SideEffect {
        if (notBool.add(node.id)) {
            Log.w(WidgetBuilders.LOG_TAG, "Checkbox \"${node.id}\": its value is not a bool ($value); drawing its value prop.")
        }
    }
    return node["value"]?.boolValue
}

/** Checkbox nodes already logged for a value that is not a bool. */
private val notBool: MutableSet<String> = ConcurrentHashMap.newKeySet()

/**
 * Flutter `Radio` as its builder draws it, not Material's: a 20 dp circle
 * with a 2 dp ring and, when selected, a 10 dp dot, in `activeColor`
 * (#2196F3 without one); unselected, the ring is `inactiveColor` (#757575),
 * or #BDBDBD when disabled. No ripple and no 48 dp target, as Flutter has
 * neither. It is selected when its `value` and the group (the store at
 * `stateKey` as a string, else `groupValue`) are the same string
 * ([FormControls.radioSelected]). Only an enabled, unselected Radio takes
 * a tap, within its circle, and it writes and sends its `value`.
 */
@Composable
internal fun RadioWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val enabled = node["enabled"]?.boolValue ?: true
    val value = Props.text(node["value"])
    val key = node["stateKey"]?.stringValue
    val group = Props.text(if (key != null) model.store.value(key) else node["groupValue"])
    val selected = FormControls.radioSelected(value, group)
    val active = Props.color(node["activeColor"]) ?: RADIO_ACTIVE
    val ring = when {
        selected -> active
        enabled -> Props.color(node["inactiveColor"]) ?: RADIO_INACTIVE
        else -> RADIO_DISABLED
    }
    val select = rememberUpdatedState<() -> Unit> { edit(node, model, JsonValue.String(value)) }
    val tap = if (enabled && !selected) {
        Modifier
            .pointerInput(Unit) { detectTapGestures(onTap = { select.value() }) }
            .semantics { onClick { select.value(); true } }
    } else {
        Modifier
    }
    Box(
        // Clipped first, so only the circle is hit, as Flutter's circle decoration is.
        modifier.size(20.dp).clip(CircleShape).then(tap).border(2.dp, ring, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        if (selected) Box(Modifier.size(10.dp).background(active, CircleShape))
    }
}

/** Flutter's `ThemeData()` colours, which CheckboxListTile is drawn in. */
private val flutterLight = lightColorScheme()

/** `ThemeData().disabledColor`, Colors.black38: a disabled list tile's title. */
private val FLUTTER_DISABLED = Color(0x61000000)

private val RADIO_ACTIVE = Color(0xFF2196F3)
private val RADIO_INACTIVE = Color(0xFF757575)
private val RADIO_DISABLED = Color(0xFFBDBDBD)
