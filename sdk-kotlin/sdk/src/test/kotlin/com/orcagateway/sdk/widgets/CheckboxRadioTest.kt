package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.StoreState
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.draw
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.row
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A6.1, A6.2 and A6.7 for Checkbox and Radio, as Flutter's `_buildCheckbox`
 * and `_buildRadio` (input_builders.dart) draw and bind them: a tap writes
 * the page-state key `stateKey` first, then fires `onChange` with
 * `{value}`; what is drawn comes from the store at `stateKey`, else the
 * `value` (or `groupValue`) prop, and a node redraws only through its
 * watches. At 1 dp per pixel, drawn in software for the colours.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class CheckboxRadioTest {
    @get:Rule
    val compose = createComposeRule()

    private lateinit var view: View

    /** `{type: state, key}`, the engine's `V.pageState`. */
    private fun state(key: String): JsonValue = JsonValue.obj("type" to "state", "key" to key)

    /** `{type: event, key: value}`, the change's value in an action. */
    private val eventValue: JsonValue = JsonValue.obj("type" to "event", "key" to "value")

    private fun def(key: String, initial: Any?) = StateDefinition(key, StateScope.Page, JsonValue.of(initial))

    private fun control(
        type: String,
        id: String,
        props: Array<out Pair<String, Any?>>,
        onChange: Action?,
        watches: List<String>,
    ) = ComponentNode(
        id, type, ComponentNode.Kind.Input, ComponentNode.ChildMode.None,
        props.associate { (key, value) -> key to JsonValue.of(value) },
        watches = watches,
        actions = onChange?.let { mapOf("onChange" to it) },
    )

    private fun checkbox(id: String, vararg props: Pair<String, Any?>, onChange: Action? = null, watches: List<String> = emptyList()) =
        control("Checkbox", id, props, onChange, watches)

    private fun radio(id: String, vararg props: Pair<String, Any?>, onChange: Action? = null, watches: List<String> = emptyList()) =
        control("Radio", id, props, onChange, watches)

    /** A Text showing the page-state key [key], redrawn when it changes. */
    private fun shows(id: String, key: String) = leaf(id, "Text", mapOf("data" to state(key))).copy(watches = listOf(key))

    /**
     * The page from [nodes], its root in a 300 x 400 box; Checkbox and
     * Radio known to the core and drawn here, they and Texts tagged with
     * their ids.
     */
    private fun show(vararg nodes: ComponentNode, state: List<StateDefinition> = emptyList()): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("Checkbox", "Radio"))
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("Checkbox") { node, model, modifier -> CheckboxWidget(node, model, modifier.testTag(node.id)) }
                register("Radio") { node, model, modifier -> RadioWidget(node, model, modifier.testTag(node.id)) }
                register("Text") { node, _, modifier -> TextWidget(node, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(300.dp, 400.dp)) { NodeView(nodes.first().id, model) }
        }
        compose.waitForIdle()
        return model
    }

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag).getUnclippedBoundsInRoot()

    /** The pixel [dx], [dy] into the node tagged [tag], in [picture]. */
    private fun assertPixel(expected: Color, picture: Bitmap, tag: String, dx: Int, dy: Int) {
        val box = bounds(tag)
        val x = box.left.value.toInt() + dx
        val y = box.top.value.toInt() + dy
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < 0.05f },
            "$tag ($dx, $dy) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }

    private fun picture(): Bitmap {
        compose.waitForIdle()
        return draw(view)
    }

    /** The colour the Text showing [data] is laid out in. */
    private fun textColor(data: String): Color = compose.onNodeWithText(data, useUnmergedTree = true).fetchSemanticsNode().let { node ->
        val results = ArrayList<TextLayoutResult>()
        requireNotNull(node.config[SemanticsActions.GetTextLayoutResult].action).invoke(results)
        results.first().layoutInput.style.color
    }

    private val noClick = SemanticsMatcher.keyNotDefined(SemanticsActions.OnClick)
    private val scheme = lightColorScheme()
    private val disabled = scheme.onSurface.copy(alpha = 0.38f).compositeOver(Color.White)

    // A bare Checkbox is Material's 48 x 48 target around a 24 dp node (its
    // tagged bounds), the 20 dp box drawn 2 into it: a pixel of the fill at
    // (5, 5), of the left border at (3, 12). The labelled row's box is at
    // (26, 18): 16 of padding, then the 40 dp leading box of a
    // shrink-wrapped Checkbox, in a row 56 high.

    /**
     * A6.1: a tap writes `true` to `stateKey` in page scope, then fires
     * onChange with `{value: true}`, a bool: onChange copies the key, and
     * reads `true` only if the write came first. The box and a Text watching
     * the key redraw.
     */
    @Test
    fun a6_1_kt_aTapWritesTheKeyInPageScopeThenFiresOnChangeWithABool() {
        val onChange = Action.ActionGroup(
            actions = listOf(
                Action.SetState(key = "seen", value = eventValue),
                Action.SetState(key = "copy", value = state("agree")),
            ),
        )
        val model = show(
            column("root", "c", "t"),
            checkbox("c", "stateKey" to "agree", onChange = onChange, watches = listOf("agree")),
            shows("t", "agree"),
            state = listOf(def("agree", false), def("seen", null), def("copy", null)),
        )
        val commits = ArrayList<StoreState>()
        model.store.onCommit = { commits.add(it) }
        compose.onNodeWithTag("c").assertIsOff()
        compose.onNodeWithTag("c").assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Checkbox))
        compose.onNodeWithText("false").assertExists()

        compose.onNodeWithTag("c").performClick()

        compose.runOnIdle {
            assertEquals(JsonValue.Bool(true), model.store.state.page["agree"])
            assertNull(model.store.state.app["agree"])
            assertEquals(JsonValue.Bool(true), commits.first().page["agree"])
            assertEquals(JsonValue.Null, commits.first().page["seen"])
            assertEquals(JsonValue.Bool(true), model.store.value("seen"))
            assertEquals(JsonValue.Bool(true), model.store.value("copy"))
        }
        compose.onNodeWithTag("c").assertIsOn()
        compose.onNodeWithText("true").assertExists()
    }

    /**
     * A6.1: no remembered state. Bound the engine's way (value
     * `V.pageState(k)`, onChange `SetState(k, event.value)`), the box follows
     * the state; bound by `stateKey` without watching it, the key is written
     * but the box keeps what it drew, as Flutter's builder is not rebuilt.
     */
    @Test
    fun a6_1_kt_theBoxIsTheStateAndRedrawsOnlyThroughItsWatches() {
        val model = show(
            column("root", "bound", "unwatched"),
            checkbox(
                "bound", "value" to state("k"),
                onChange = Action.SetState(key = "k", value = eventValue), watches = listOf("k"),
            ),
            checkbox("unwatched", "stateKey" to "u"),
            state = listOf(def("k", false), def("u", false)),
        )

        compose.onNodeWithTag("bound").performClick()
        compose.onNodeWithTag("bound").assertIsOn()
        compose.onNodeWithTag("bound").performClick()
        compose.onNodeWithTag("bound").assertIsOff()
        compose.runOnIdle { assertEquals(JsonValue.Bool(false), model.store.value("k")) }

        compose.onNodeWithTag("unwatched").performClick()
        compose.runOnIdle { assertEquals(JsonValue.Bool(true), model.store.value("u")) }
        compose.onNodeWithTag("unwatched").assertIsOff()

        model.store.dispatch(mapOf("k" to JsonValue.Bool(true)))
        compose.onNodeWithTag("bound").assertIsOn()
    }

    /**
     * A6.1: a tristate Checkbox cycles false, true, null, false (Toggleable),
     * each written and sent as is; a two-state one with no value draws it as
     * false, so its first tap writes true.
     */
    @Test
    fun a6_1_kt_tristateCyclesToNullAndAMissingValueIsFalse() {
        val model = show(
            column("root", "tri", "two"),
            checkbox(
                "tri", "stateKey" to "t", "tristate" to true,
                onChange = Action.SetState(key = "seen", value = eventValue), watches = listOf("t"),
            ),
            checkbox("two", "stateKey" to "missing", watches = listOf("missing")),
            state = listOf(def("t", false), def("seen", "none")),
        )
        val tri = compose.onNodeWithTag("tri")
        val states = ArrayList<Pair<JsonValue, JsonValue>>()
        val drawn = ArrayList<ToggleableState>()
        repeat(3) {
            tri.performClick()
            compose.runOnIdle { states.add(model.store.value("t") to model.store.value("seen")) }
            drawn.add(tri.fetchSemanticsNode().config[SemanticsProperties.ToggleableState])
        }

        val yes = JsonValue.Bool(true)
        val no = JsonValue.Bool(false)
        assertEquals(listOf(yes to yes, JsonValue.Null to JsonValue.Null, no to no), states)
        assertEquals(listOf(ToggleableState.On, ToggleableState.Indeterminate, ToggleableState.Off), drawn)

        compose.onNodeWithTag("two").assertIsOff()
        compose.onNodeWithTag("two").performClick()
        compose.runOnIdle { assertEquals(yes, model.store.value("missing")) }
        compose.onNodeWithTag("two").assertIsOn()
    }

    /**
     * A6.1: with a label it is Flutter's CheckboxListTile: a row as wide as
     * it is let be and 56 high, the box leading after 16, the label the
     * title, and a tap anywhere on it toggles (the label, the far end, the
     * box). One checkbox for accessibility, its label merged in.
     */
    @Test
    fun a6_1_kt_aLabelledCheckboxIsARowThatTogglesAnywhere() {
        val model = show(
            column("root", "c"),
            checkbox("c", "stateKey" to "agree", "label" to "Agree", watches = listOf("agree")),
            state = listOf(def("agree", false)),
        )
        val tile = compose.onNodeWithTag("c")
        assertEquals(300.dp, bounds("c").right - bounds("c").left)
        assertEquals(56.dp, bounds("c").bottom - bounds("c").top)
        tile.assertIsOff()
        tile.assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Checkbox))
        assertEquals(listOf("Agree"), tile.fetchSemanticsNode().config[SemanticsProperties.Text].map { it.text })
        assertEquals(scheme.onSurface, textColor("Agree"))
        assertPixel(scheme.onSurfaceVariant, picture(), "c", 27, 28)

        val values = ArrayList<JsonValue>()
        compose.onNodeWithText("Agree").performClick()
        compose.runOnIdle { values.add(model.store.value("agree")) }
        tile.performTouchInput { click(Offset(width - 4f, height / 2f)) }
        compose.runOnIdle { values.add(model.store.value("agree")) }
        tile.performTouchInput { click(Offset(36f, 28f)) }
        compose.runOnIdle { values.add(model.store.value("agree")) }

        assertEquals(listOf<JsonValue>(JsonValue.Bool(true), JsonValue.Bool(false), JsonValue.Bool(true)), values)
        tile.assertIsOn()
        assertPixel(scheme.primary, picture(), "c", 29, 21)
    }

    /**
     * A6.1 (D4): a state at `stateKey` that is not a bool, where Flutter's
     * builder throws, draws the `value` prop instead.
     */
    @Test
    fun a6_1_kt_aStateThatIsNotABoolDrawsTheValueProp() {
        show(
            column("root", "c"),
            checkbox("c", "stateKey" to "agree", "value" to true, watches = listOf("agree")),
            state = listOf(def("agree", "yes")),
        )

        compose.onNodeWithTag("c").assertIsOn()
    }

    /**
     * A6.2: three radios on one key select exactly the one whose value is
     * the key's; a tap on another writes its value to the key, then fires
     * onChange with `{value}`, a string, and only it is selected after.
     * Flutter's look: a 20 dp circle with a 2 dp ring, a 10 dp dot when
     * selected, #2196F3 selected and #757575 not.
     */
    @Test
    fun a6_2_kt_radiosSharingAKeySelectExactlyOne() {
        val pick = listOf("pick")
        val onChange = Action.SetState(key = "seen", value = eventValue)
        val model = show(
            row("root", "r1", "r2", "r3"),
            radio("r1", "value" to "a", "stateKey" to "pick", onChange = onChange, watches = pick),
            radio("r2", "value" to "b", "stateKey" to "pick", onChange = onChange, watches = pick),
            radio("r3", "value" to "c", "stateKey" to "pick", onChange = onChange, watches = pick),
            state = listOf(def("pick", "b"), def("seen", null)),
        )
        val blue = Props.hex("#2196F3")
        val grey = Props.hex("#757575")
        assertEquals(20.dp, bounds("r1").right - bounds("r1").left)
        assertEquals(20.dp, bounds("r1").bottom - bounds("r1").top)
        fun selected(vararg on: String) {
            val picture = picture()
            for (id in listOf("r1", "r2", "r3")) {
                val chosen = id in on
                assertPixel(if (chosen) blue else grey, picture, id, 1, 10)
                assertPixel(if (chosen) blue else Color.White, picture, id, 10, 10)
            }
        }
        selected("r2")

        val commits = ArrayList<StoreState>()
        model.store.onCommit = { commits.add(it) }
        compose.onNodeWithTag("r3").performClick()

        compose.runOnIdle {
            assertEquals(JsonValue.String("c"), commits.first().page["pick"])
            assertEquals(JsonValue.Null, commits.first().page["seen"])
            assertEquals(JsonValue.String("c"), model.store.value("seen"))
        }
        selected("r3")
    }

    /**
     * A6.2: a tap on the selected radio does nothing, and it offers no click;
     * without `stateKey` the group is the `groupValue` prop, compared as
     * strings, with `activeColor` and `inactiveColor`; a radio with neither
     * value nor group is selected ('' equals '').
     */
    @Test
    fun a6_2_kt_theSelectedRadioIgnoresTapsAndTheGroupPropSelects() {
        val model = show(
            row("root", "on", "off", "empty", "keyed"),
            radio("on", "value" to "1", "groupValue" to 1, "activeColor" to "#E53935"),
            radio("off", "value" to "2", "groupValue" to 1, "inactiveColor" to "#43A047"),
            radio("empty"),
            radio("keyed", "value" to "x", "stateKey" to "p", onChange = Action.SetState(key = "seen", value = eventValue)),
            state = listOf(def("p", "x"), def("seen", "none")),
        )
        val picture = picture()
        val red = Props.hex("#E53935")
        assertPixel(red, picture, "on", 1, 10)
        assertPixel(red, picture, "on", 10, 10)
        assertPixel(Props.hex("#43A047"), picture, "off", 1, 10)
        assertPixel(Color.White, picture, "off", 10, 10)
        assertPixel(Props.hex("#2196F3"), picture, "empty", 10, 10)
        compose.onNodeWithTag("keyed").assert(noClick)
        compose.onNodeWithTag("off").assert(SemanticsMatcher.keyIsDefined(SemanticsActions.OnClick))

        var commits = 0
        model.store.onCommit = { commits += 1 }
        compose.onNodeWithTag("keyed").performClick()

        compose.runOnIdle {
            assertEquals(0, commits)
            assertEquals(JsonValue.String("none"), model.store.value("seen"))
        }
    }

    /**
     * A6.7: `enabled` false makes a Checkbox inert and greys it as Material
     * does (onSurface at 0.38: the checked box's fill, the unchecked one's
     * border, and the label row's title in Flutter's disabled colour).
     */
    @Test
    fun a6_7_kt_aDisabledCheckboxIsInertAndGreyed() {
        val onChange = Action.SetState(key = "seen", value = eventValue)
        val model = show(
            column("root", "checked", "unchecked", "labelled", props = mapOf("crossAxisAlignment" to JsonValue.String("start"))),
            checkbox("checked", "stateKey" to "a", "enabled" to false, onChange = onChange, watches = listOf("a")),
            checkbox("unchecked", "value" to false, "enabled" to false, onChange = onChange),
            checkbox("labelled", "label" to "Off", "enabled" to false, onChange = onChange),
            state = listOf(def("a", true), def("seen", "none")),
        )
        val picture = picture()
        assertPixel(disabled, picture, "checked", 5, 5)
        assertPixel(disabled, picture, "unchecked", 3, 12)
        assertEquals(48.dp, bounds("unchecked").top - bounds("checked").top)
        assertEquals(Color(0x61000000), textColor("Off"))
        for (id in listOf("checked", "unchecked", "labelled")) compose.onNodeWithTag(id).assertIsNotEnabled()

        var commits = 0
        model.store.onCommit = { commits += 1 }
        for (id in listOf("checked", "unchecked", "labelled")) compose.onNodeWithTag(id).performClick()

        compose.runOnIdle {
            assertEquals(0, commits)
            assertEquals(JsonValue.String("none"), model.store.value("seen"))
        }
        compose.onNodeWithTag("checked").assertIsOn()
    }

    /**
     * A6.7: `enabled` false makes a Radio inert; an unselected one is drawn
     * #BDBDBD, a selected one as it would be enabled.
     */
    @Test
    fun a6_7_kt_aDisabledRadioIsInertAndOnlyAnUnselectedOneGreyed() {
        val model = show(
            row("root", "selected", "unselected", "live"),
            radio("selected", "value" to "a", "groupValue" to "a", "enabled" to false),
            radio("unselected", "value" to "b", "stateKey" to "p", "enabled" to false, watches = listOf("p")),
            radio("live", "value" to "c", "groupValue" to "a"),
            state = listOf(def("p", "a")),
        )
        val picture = picture()
        val blue = Props.hex("#2196F3")
        assertPixel(blue, picture, "selected", 1, 10)
        assertPixel(blue, picture, "selected", 10, 10)
        assertPixel(Props.hex("#BDBDBD"), picture, "unselected", 1, 10)
        assertPixel(Props.hex("#757575"), picture, "live", 1, 10)
        compose.onNodeWithTag("unselected").assert(noClick)

        var commits = 0
        model.store.onCommit = { commits += 1 }
        compose.onNodeWithTag("unselected").performClick()

        compose.runOnIdle {
            assertEquals(0, commits)
            assertEquals(JsonValue.String("a"), model.store.value("p"))
        }
    }

    /**
     * A6.7: with no onChange both still take touches, look enabled and
     * write their `stateKey`; nothing fires.
     */
    @Test
    fun a6_7_kt_withoutOnChangeBothStillTakeTouchesAndWriteTheirKey() {
        val model = show(
            row("root", "c", "r"),
            checkbox("c", "stateKey" to "a", watches = listOf("a")),
            radio("r", "value" to "x", "stateKey" to "p", watches = listOf("p")),
            state = listOf(def("a", false), def("p", "")),
        )
        val effects = ArrayList<ActionEffect>()
        model.onEffect = { effects.add(it) }
        val commits = ArrayList<StoreState>()
        model.store.onCommit = { commits.add(it) }
        compose.onNodeWithTag("c").assertIsEnabled()

        compose.onNodeWithTag("c").performClick()
        compose.onNodeWithTag("r").performClick()

        compose.runOnIdle {
            assertEquals(2, commits.size)
            assertEquals(JsonValue.Bool(true), model.store.value("a"))
            assertEquals(JsonValue.String("x"), model.store.value("p"))
            assertTrue(effects.isEmpty(), "$effects")
        }
        compose.onNodeWithTag("c").assertIsOn()
        assertPixel(Props.hex("#2196F3"), picture(), "r", 10, 10)
    }
}
