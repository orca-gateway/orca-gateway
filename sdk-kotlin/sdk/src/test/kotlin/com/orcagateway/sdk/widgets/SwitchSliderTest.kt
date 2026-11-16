package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.TouchInjectionScope
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.LayoutDirection
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
import com.orcagateway.sdk.support.sizedBox
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A6.3 and A6.7 for Switch and Slider, as Flutter's `_buildSwitch` and
 * `_buildSlider` (input_builders.dart) draw and bind them: a change writes
 * the page-state key `stateKey` first, then fires `onChange` with
 * `{value}` (a bool, a double); what is drawn comes from the store at
 * `stateKey`, else the `value` prop, and a node redraws only through its
 * watches. At 1 dp per pixel, drawn in software for the colours.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SwitchSliderTest {
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

    private fun switch(id: String, vararg props: Pair<String, Any?>, onChange: Action? = null, watches: List<String> = emptyList()) =
        control("Switch", id, props, onChange, watches)

    private fun slider(id: String, vararg props: Pair<String, Any?>, onChange: Action? = null, watches: List<String> = emptyList()) =
        control("Slider", id, props, onChange, watches)

    /** A Text showing the page-state key [key], redrawn when it changes. */
    private fun shows(id: String, key: String) = leaf(id, "Text", mapOf("data" to state(key))).copy(watches = listOf(key))

    /**
     * The page from [nodes], its root in a 300 x 400 box (right to left with
     * [rtl]); Switch and Slider known to the core and drawn here, they and
     * Texts tagged with their ids.
     */
    private fun show(vararg nodes: ComponentNode, state: List<StateDefinition> = emptyList(), rtl: Boolean = false): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("Switch", "Slider"))
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("Switch") { node, model, modifier -> SwitchWidget(node, model, modifier.testTag(node.id)) }
                register("Slider") { node, model, modifier -> SliderWidget(node, model, modifier.testTag(node.id)) }
                register("Text") { node, _, modifier -> TextWidget(node, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            view = LocalView.current
            CompositionLocalProvider(LocalLayoutDirection provides if (rtl) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                Box(Modifier.size(300.dp, 400.dp)) { NodeView(nodes.first().id, model) }
            }
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

    /** The Slider tagged [tag]'s progress: the value it draws, its range and steps. */
    private fun progress(tag: String): ProgressBarRangeInfo =
        compose.onNodeWithTag(tag).fetchSemanticsNode().config[SemanticsProperties.ProgressBarRangeInfo]

    /** An accessibility service setting the Slider tagged [tag] to [value]. */
    private fun setProgress(tag: String, value: Float) {
        compose.onNodeWithTag(tag).performSemanticsAction(SemanticsActions.SetProgress) { it(value) }
        compose.waitForIdle()
    }

    private val scheme = lightColorScheme()
    private val red = Props.hex("#E53935")
    private val green = Props.hex("#43A047")
    private val blue = Props.hex("#1E88E5")

    // A Switch's tagged bounds are Material's 52 x 32 track (in a 48 high
    // target): the unchecked thumb (16) centred at (16, 16), the checked one
    // (24) at (36, 16), the track's far side at (40, 16) or near side at
    // (10, 16) clear of either. A Slider is laid out as wide as it is let be
    // (300) and 48 high, Flutter's 2023 look: its track inset 24 on each side
    // (252 long), centred at y 24, the inactive part `trackHeight` (4) high
    // and the active part 2 more; a 20 dp round thumb. Its tagged bounds are
    // its semantics', 10 wider on each side (M3 widens them for TalkBack):
    // in them the thumb is centred at x 34 + 252 x the drawn fraction (at
    // 160 for a half; a discrete one moved by (0.5 - fraction) x trackHeight,
    // Flutter's inset), the 4 dp track's rows are 22-25 and the active
    // part's 21-26, and a finger lands only from x 10 to 310.

    /**
     * A6.3: a tap writes `true` to `stateKey` in page scope, then fires
     * onChange with `{value: true}`, a bool: onChange copies the key, and
     * reads `true` only if the write came first. The switch and a Text
     * watching the key redraw.
     */
    @Test
    fun a6_3_kt_aSwitchTapWritesTheKeyInPageScopeThenFiresOnChangeWithABool() {
        val onChange = Action.ActionGroup(
            actions = listOf(
                Action.SetState(key = "seen", value = eventValue),
                Action.SetState(key = "copy", value = state("on")),
            ),
        )
        val model = show(
            column("root", "s", "t"),
            switch("s", "stateKey" to "on", onChange = onChange, watches = listOf("on")),
            shows("t", "on"),
            state = listOf(def("on", false), def("seen", null), def("copy", null)),
        )
        val commits = ArrayList<StoreState>()
        model.store.onCommit = { commits.add(it) }
        compose.onNodeWithTag("s").assertIsOff()
        compose.onNodeWithTag("s").assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Switch))
        compose.onNodeWithTag("t").assertTextEquals("false")

        compose.onNodeWithTag("s").performClick()

        compose.runOnIdle {
            assertEquals(JsonValue.Bool(true), model.store.state.page["on"])
            assertNull(model.store.state.app["on"])
            assertEquals(JsonValue.Bool(true), commits.first().page["on"])
            assertEquals(JsonValue.Null, commits.first().page["seen"])
            assertEquals(JsonValue.Bool(true), model.store.value("seen"))
            assertEquals(JsonValue.Bool(true), model.store.value("copy"))
        }
        compose.onNodeWithTag("s").assertIsOn()
        compose.onNodeWithTag("t").assertTextEquals("true")
    }

    /**
     * A6.3: no remembered state. Bound the engine's way (value
     * `V.pageState(k)`, onChange `SetState(k, event.value)`), the switch
     * follows the state, from a tap or from elsewhere; bound by `stateKey`
     * without watching it, the key is written but the switch keeps what it
     * drew, as Flutter's builder is not rebuilt. No value draws off.
     */
    @Test
    fun a6_3_kt_theSwitchIsTheStateAndRedrawsOnlyThroughItsWatches() {
        val model = show(
            column("root", "bound", "unwatched", "bare"),
            switch(
                "bound", "value" to state("k"),
                onChange = Action.SetState(key = "k", value = eventValue), watches = listOf("k"),
            ),
            switch("unwatched", "stateKey" to "u"),
            switch("bare"),
            state = listOf(def("k", false), def("u", false)),
        )
        compose.onNodeWithTag("bare").assertIsOff()

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
     * A6.3: Flutter's colour mapping (`activeThumbColor`,
     * `inactiveTrackColor`): `activeColor` is the checked thumb, and the
     * checked track is that colour at alpha 0x80 (Switch's fallback when no
     * track colour is themed); without it the checked track is primary.
     * `inactiveColor` is the unchecked track.
     */
    @Test
    fun a6_3_kt_activeColorIsTheCheckedThumbAndInactiveColorTheUncheckedTrack() {
        show(
            column("root", "on", "off", "plain"),
            switch("on", "value" to true, "activeColor" to "#E53935", "inactiveColor" to "#43A047"),
            switch("off", "value" to false, "activeColor" to "#E53935", "inactiveColor" to "#43A047"),
            switch("plain", "value" to true),
        )
        assertEquals(52.dp, bounds("on").right - bounds("on").left)
        assertEquals(32.dp, bounds("on").bottom - bounds("on").top)
        val picture = picture()

        assertPixel(red, picture, "on", 36, 16)
        assertPixel(red.copy(alpha = 0x80 / 255f).compositeOver(Color.White), picture, "on", 10, 16)
        assertPixel(scheme.primary, picture, "plain", 10, 16)
        assertPixel(green, picture, "off", 40, 16)
        assertPixel(scheme.outline, picture, "off", 16, 16)
    }

    /**
     * A6.3: a swipe over a Slider 0-100 in 4 divisions writes each stop it
     * reaches, snapped (25.0, then 50.0) and as a double, before onChange
     * sends it; a stop the finger stays on is sent once, the start it left
     * from not at all. The slider and a Text watching the key redraw.
     */
    @Test
    fun a6_3_kt_aSwipeWritesEachSnappedStopOnceThenFiresOnChange() {
        val model = show(
            column("root", "s", "t"),
            slider(
                "s", "stateKey" to "vol", "max" to 100, "divisions" to 4,
                onChange = Action.SetState(key = "seen", value = eventValue), watches = listOf("vol"),
            ),
            shows("t", "vol"),
            state = listOf(def("vol", 0), def("seen", null)),
        )
        assertEquals(320.dp, bounds("s").right - bounds("s").left)
        val commits = ArrayList<StoreState>()
        model.store.onCommit = { commits.add(it) }

        compose.onNodeWithTag("s").performTouchInput {
            val y = height / 2f
            var x = 34f
            down(Offset(x, y))
            while (x < 186f) {
                x += 8f
                moveTo(Offset(x, y))
            }
            up()
        }

        compose.runOnIdle {
            assertEquals(4, commits.size, "${commits.map { it.page }}")
            assertEquals(JsonValue.Double(25.0), commits.first().page["vol"])
            assertEquals(JsonValue.Null, commits.first().page["seen"])
            assertEquals(
                listOf<JsonValue>(JsonValue.Double(25.0), JsonValue.Double(50.0)),
                commits.mapNotNull { it.page["seen"]?.takeUnless(JsonValue::isNull) }.distinct(),
            )
            assertIs<JsonValue.Double>(model.store.value("vol"))
            assertEquals(JsonValue.Double(50.0), model.store.value("vol"))
            assertEquals(JsonValue.Double(50.0), model.store.value("seen"))
        }
        compose.onNodeWithTag("t").assertTextEquals("50.0")
        assertEquals(50f, progress("s").current)
    }

    /**
     * A6.3: the Slider draws its value clamped to min..max without
     * correcting the state (150 on 0-100 draws 100); a setProgress snaps to
     * the nearest stop and is written and sent as a double; the same stop
     * again sends nothing. Without min and max the range is 0-1, and a
     * Slider with no value draws 0.
     */
    @Test
    fun a6_3_kt_theDrawnValueIsClampedAndSetProgressSnaps() {
        val model = show(
            column("root", "s", "t", "unit", "bare"),
            slider(
                "s", "value" to state("k"), "min" to 0, "max" to 100, "divisions" to 4,
                onChange = Action.SetState(key = "k", value = eventValue), watches = listOf("k"),
            ),
            shows("t", "k"),
            slider("unit", "value" to 0.3, onChange = Action.SetState(key = "u", value = eventValue)),
            slider("bare"),
            state = listOf(def("k", 150), def("u", null)),
        )
        assertEquals(100f, progress("s").current)
        assertEquals(0f..100f, progress("s").range)
        assertEquals(0.3f, progress("unit").current)
        assertEquals(0f..1f, progress("unit").range)
        assertEquals(0f, progress("bare").current)
        compose.runOnIdle { assertEquals(JsonValue.Int(150), model.store.value("k")) }
        var commits = 0
        model.store.onCommit = { commits += 1 }

        setProgress("s", 30f)
        compose.runOnIdle {
            assertEquals(1, commits)
            assertIs<JsonValue.Double>(model.store.value("k"))
            assertEquals(JsonValue.Double(25.0), model.store.value("k"))
        }
        compose.onNodeWithTag("t").assertTextEquals("25.0")
        assertEquals(25f, progress("s").current)

        setProgress("s", 30f)
        compose.runOnIdle { assertEquals(1, commits) }

        setProgress("s", 62f)
        compose.runOnIdle { assertEquals(JsonValue.Double(50.0), model.store.value("k")) }

        setProgress("unit", 0.7f)
        compose.runOnIdle {
            val u = model.store.value("u")
            assertIs<JsonValue.Double>(u)
            assertTrue(abs(u.value - 0.7) < 1e-6, "$u")
        }
    }

    /**
     * A6.3: Flutter's colours: `activeColor` the active track (and the
     * thumb, without `thumbColor`), `inactiveColor` the inactive track,
     * `thumbColor` the thumb; `trackHeight` the track's height.
     */
    @Test
    fun a6_3_kt_sliderColoursAndTrackHeight() {
        val colours = arrayOf("activeColor" to "#E53935", "inactiveColor" to "#43A047")
        show(
            column("root", "full", "active", "thick"),
            slider("full", "value" to 50, "max" to 100, *colours, "thumbColor" to "#1E88E5"),
            slider("active", "value" to 50, "max" to 100, "activeColor" to "#E53935"),
            slider("thick", "value" to 50, "max" to 100, *colours, "trackHeight" to 10),
        )
        val picture = picture()

        assertPixel(red, picture, "full", 70, 24)
        assertPixel(green, picture, "full", 240, 24)
        assertPixel(blue, picture, "full", 160, 24)
        assertPixel(Color.White, picture, "full", 240, 20)
        assertPixel(red, picture, "active", 160, 24)
        assertPixel(green, picture, "thick", 240, 24)
        assertPixel(green, picture, "thick", 240, 20)
    }

    /**
     * A6.3, Flutter's 2023 look (the default `year2023`): the inactive track
     * `trackHeight` (4) high in surfaceContainerHighest, the active part 2
     * higher in primary, both inset 24 (a 48 dp thumb slot); a 20 dp round
     * thumb in primary, not Material 3 Compose's 4 x 44 bar.
     */
    @Test
    fun a6_3_kt_theSliderHasFlutters2023TrackAndThumb() {
        show(
            column("root", "plain"),
            slider("plain", "value" to 50, "max" to 100),
        )
        val picture = picture()

        assertPixel(scheme.primary, picture, "plain", 70, 24)
        assertPixel(scheme.primary, picture, "plain", 70, 21)
        assertPixel(scheme.surfaceContainerHighest, picture, "plain", 240, 24)
        assertPixel(scheme.surfaceContainerHighest, picture, "plain", 240, 22)
        assertPixel(Color.White, picture, "plain", 240, 21)
        assertPixel(Color.White, picture, "plain", 240, 27)
        assertPixel(Color.White, picture, "plain", 30, 24)
        assertPixel(Color.White, picture, "plain", 290, 24)
        for (dx in listOf(152, 160, 168)) assertPixel(scheme.primary, picture, "plain", dx, 24)
        assertPixel(scheme.primary, picture, "plain", 160, 16)
        assertPixel(Color.White, picture, "plain", 160, 4)
    }

    /**
     * A6.3: a discrete Slider draws Flutter's tick marks, circles a quarter
     * of `trackHeight` in radius at min + i / d of the track less its
     * height: those left of the thumb in `inactiveColor`, those right of it
     * in `activeColor`. One division gives two, at either end.
     */
    @Test
    fun a6_3_kt_aDiscreteSliderDrawsFlutterTicks() {
        val colours = arrayOf("activeColor" to "#E53935", "inactiveColor" to "#43A047", "trackHeight" to 16, "max" to 100)
        show(
            column("root", "four", "one"),
            slider("four", "value" to 50, "divisions" to 4, *colours),
            slider("one", "value" to 0, "divisions" to 1, *colours),
        )
        val picture = picture()

        assertPixel(green, picture, "four", 101, 24)
        assertPixel(red, picture, "four", 130, 24)
        assertPixel(red, picture, "four", 219, 24)
        assertPixel(green, picture, "four", 240, 24)
        assertPixel(red, picture, "one", 278, 24)
        assertPixel(green, picture, "one", 250, 24)
    }

    /**
     * A6.3: while a finger is down the thumb grows Flutter's overlay, a
     * circle of radius 24 in `activeColor` at 0.12, else primary at 0.1 for
     * the whole press (Flutter's `_dragging` is set as any interaction
     * starts), gone again after.
     */
    @Test
    fun a6_3_kt_aPressGrowsTheOverlayInActiveColor() {
        show(
            column("root", "gap", "o", "p"),
            sizedBox("gap", 300, 60),
            slider("o", "value" to 50, "max" to 100, "activeColor" to "#E53935"),
            slider("p", "value" to 50, "max" to 100),
        )
        assertPixel(Color.White, picture(), "o", 175, 9)

        compose.onNodeWithTag("o").performTouchInput { down(Offset(160f, height / 2f)) }
        compose.waitForIdle()
        assertPixel(red.copy(alpha = 0.12f).compositeOver(Color.White), picture(), "o", 175, 9)

        compose.onNodeWithTag("o").performTouchInput { up() }
        compose.waitForIdle()
        assertPixel(Color.White, picture(), "o", 175, 9)

        compose.onNodeWithTag("p").performTouchInput { down(Offset(160f, height / 2f)) }
        compose.waitForIdle()
        assertPixel(scheme.primary.copy(alpha = 0.1f).compositeOver(Color.White), picture(), "p", 175, 9)
        compose.onNodeWithTag("p").performTouchInput { up() }
        compose.waitForIdle()
        assertPixel(Color.White, picture(), "p", 175, 9)
    }

    /**
     * A6.3: a press sends the value under the finger on the down, as
     * Flutter's `_startInteraction` does: written and sent before the finger
     * lifts, the thumb and a watching Text redrawn while it is held; the lift
     * sends nothing more. A drag from a down that sent goes on from the value
     * that down drew (25, then 50).
     */
    @Test
    fun a6_3_kt_aPressSendsItsValueOnTheDown() {
        val model = show(
            column("root", "s", "t"),
            slider(
                "s", "stateKey" to "vol", "max" to 100, "divisions" to 4,
                onChange = Action.SetState(key = "seen", value = eventValue), watches = listOf("vol"),
            ),
            shows("t", "vol"),
            state = listOf(def("vol", 0), def("seen", null)),
        )
        val commits = ArrayList<StoreState>()
        model.store.onCommit = { commits.add(it) }
        val slider = compose.onNodeWithTag("s")

        slider.performTouchInput { down(Offset(34f + 0.75f * 252f, height / 2f)) }
        compose.waitForIdle()
        compose.runOnIdle {
            assertEquals(2, commits.size, "${commits.map { it.page }}")
            assertEquals(JsonValue.Double(75.0), commits.first().page["vol"])
            assertEquals(JsonValue.Null, commits.first().page["seen"])
            assertEquals(JsonValue.Double(75.0), model.store.value("seen"))
        }
        compose.onNodeWithTag("t").assertTextEquals("75.0")
        assertEquals(75f, progress("s").current)
        slider.performTouchInput { up() }
        compose.runOnIdle { assertEquals(2, commits.size, "${commits.map { it.page }}") }

        slider.performTouchInput { down(Offset(34f + 0.25f * 252f, height / 2f)) }
        compose.waitForIdle()
        compose.runOnIdle { assertEquals(JsonValue.Double(25.0), model.store.value("vol")) }
        assertEquals(25f, progress("s").current)
        slider.performTouchInput {
            repeat(10) { moveBy(Offset(8f, 0f)) }
            up()
        }

        compose.runOnIdle {
            assertEquals(6, commits.size, "${commits.map { it.page }}")
            assertEquals(
                listOf<JsonValue>(JsonValue.Double(75.0), JsonValue.Double(25.0), JsonValue.Double(50.0)),
                commits.mapNotNull { it.page["seen"]?.takeUnless(JsonValue::isNull) }.distinct(),
            )
            assertEquals(JsonValue.Double(50.0), model.store.value("vol"))
        }
    }

    /**
     * A6.3: a discrete thumb sits where Flutter puts it, inset half the
     * track height at the end stops (left + v x (w - h) + h / 2): at 0 its
     * centre is 8 in from the track's start for a 16 dp track, at 1 8 in
     * from its end, the track's rounded ends running to the track's ends.
     */
    @Test
    fun a6_3_kt_aDiscreteThumbSitsWhereFlutterPutsItAtTheEndStops() {
        val look = arrayOf(
            "max" to 100, "divisions" to 4, "trackHeight" to 16,
            "activeColor" to "#E53935", "inactiveColor" to "#43A047", "thumbColor" to "#1E88E5",
        )
        show(
            column("root", "lo", "hi"),
            slider("lo", "value" to 0, *look),
            slider("hi", "value" to 100, *look),
        )
        val picture = picture()

        assertPixel(blue, picture, "lo", 50, 24)
        assertPixel(Color.White, picture, "lo", 30, 24)
        assertPixel(blue, picture, "hi", 270, 24)
        assertPixel(Color.White, picture, "hi", 292, 24)
    }

    /**
     * A6.3: a discrete tap maps through Flutter's padded track (x - left -
     * h / 2) / (width - h), as its ticks sit: on a 16 dp track in 4
     * divisions, 119.5 from the slider's start is just short of the midpoint
     * between the 25 and 50 ticks (120.5), so it sends 25 (the unpadded
     * track would give 50); the lift sends nothing more.
     */
    @Test
    fun a6_3_kt_aDiscreteTapMapsThroughFluttersPaddedTrack() {
        val model = show(
            column("root", "s"),
            slider("s", "stateKey" to "v", "max" to 100, "divisions" to 4, "trackHeight" to 16, watches = listOf("v")),
            state = listOf(def("v", 100)),
        )
        val commits = ArrayList<StoreState>()
        model.store.onCommit = { commits.add(it) }

        compose.onNodeWithTag("s").performTouchInput { down(Offset(10f + 119.5f, height / 2f)) }
        compose.waitForIdle()
        compose.runOnIdle { assertEquals(JsonValue.Double(25.0), model.store.value("v")) }
        compose.onNodeWithTag("s").performTouchInput { up() }

        compose.runOnIdle {
            assertEquals(1, commits.size, "${commits.map { it.page }}")
            assertEquals(JsonValue.Double(25.0), model.store.value("v"))
        }
    }

    /**
     * A6.3: a continuous thumb on a track higher than its radius (10) stays
     * half the track height inside the track's ends, as Flutter's
     * `_calcThumbCenter` clamps it; on a thinner track it reaches the ends.
     */
    @Test
    fun a6_3_kt_aContinuousThumbStaysInsideAThickTrack() {
        val look = arrayOf("max" to 100, "activeColor" to "#E53935", "inactiveColor" to "#43A047", "thumbColor" to "#1E88E5")
        show(
            column("root", "lo", "hi", "thin"),
            slider("lo", "value" to 0, "trackHeight" to 16, *look),
            slider("hi", "value" to 100, "trackHeight" to 16, *look),
            slider("thin", "value" to 0, *look),
        )
        val picture = picture()

        assertPixel(blue, picture, "lo", 50, 24)
        assertPixel(Color.White, picture, "lo", 30, 24)
        assertPixel(blue, picture, "hi", 270, 24)
        assertPixel(Color.White, picture, "hi", 292, 24)
        assertPixel(blue, picture, "thin", 26, 24)
    }

    /**
     * A6.3: right to left, the track is mirrored (the active part from the
     * right) and a down sends the value mirrored: three quarters of the way
     * from the left is 25.
     */
    @Test
    fun a6_3_kt_rightToLeftTheTrackAndADownAreMirrored() {
        val model = show(
            column("root", "r"),
            slider(
                "r", "stateKey" to "v", "max" to 100, "divisions" to 4,
                "activeColor" to "#E53935", "inactiveColor" to "#43A047", watches = listOf("v"),
            ),
            state = listOf(def("v", 0)),
            rtl = true,
        )
        compose.onNodeWithTag("r").performTouchInput { down(Offset(34f + 0.75f * 252f, height / 2f)) }
        compose.waitForIdle()
        compose.runOnIdle { assertEquals(JsonValue.Double(25.0), model.store.value("v")) }
        compose.onNodeWithTag("r").performTouchInput { up() }
        val picture = picture()

        assertPixel(red, picture, "r", 270, 24)
        assertPixel(green, picture, "r", 70, 24)
    }

    /**
     * A6.3: with `label` a discrete Slider shows it over its thumb while a
     * finger is down (Flutter's value indicator, only for discrete sliders
     * with a range): Flutter's drop, a pill 28 high spanning 22 to 50 above
     * the thumb's centre, the label centred in it, and a triangle whose tip
     * is 16 above the centre, in primary. A continuous Slider never shows
     * it, nor one whose max is its min.
     */
    @Test
    fun a6_3_kt_aDiscreteSliderShowsItsLabelOverTheThumbWhilePressed() {
        show(
            column("root", "gap", "d", "c", "flat"),
            sizedBox("gap", 300, 60),
            slider("d", "value" to 50, "max" to 100, "divisions" to 4, "label" to "Volume"),
            slider("c", "value" to 50, "max" to 100, "label" to "Level"),
            slider("flat", "value" to 5, "min" to 5, "max" to 5, "divisions" to 4, "label" to "Flat"),
        )
        compose.onNodeWithText("Volume", useUnmergedTree = true).assertDoesNotExist()

        compose.onNodeWithTag("d").performTouchInput { down(Offset(160f, height / 2f)) }
        compose.waitForIdle()
        val label = compose.onNodeWithText("Volume", useUnmergedTree = true).getUnclippedBoundsInRoot()
        val slider = bounds("d")
        assertTrue(label.bottom < slider.top, "$label over $slider")
        assertTrue(abs(((label.left + label.right) / 2 - slider.left).value - 160f) < 1f, "$label over $slider")
        assertTrue(abs(((label.top + label.bottom) / 2 - slider.top).value + 12f) < 1.5f, "$label over $slider")
        val picture = picture()
        assertPixel(scheme.primary, picture, "d", (label.left - slider.left).value.toInt() - 2, -12)
        assertPixel(scheme.primary, picture, "d", 160, 5)
        // Beside the triangle, under the press overlay (primary at 0.1).
        assertPixel(scheme.primary.copy(alpha = 0.1f).compositeOver(Color.White), picture, "d", 172, 5)
        compose.onNodeWithTag("d").performTouchInput { up() }
        compose.mainClock.advanceTimeBy(700)
        compose.waitForIdle()
        compose.onNodeWithText("Volume", useUnmergedTree = true).assertDoesNotExist()

        for ((tag, text) in listOf("c" to "Level", "flat" to "Flat")) {
            compose.onNodeWithTag(tag).performTouchInput { down(Offset(160f, height / 2f)) }
            compose.waitForIdle()
            compose.onNodeWithText(text, useUnmergedTree = true).assertDoesNotExist()
            compose.onNodeWithTag(tag).performTouchInput { up() }
        }
    }

    /**
     * A6.3: the label stays at least 500 ms from the press, as Flutter's
     * `_minimumInteractionTime`, then shrinks away in 100 ms; held longer,
     * it goes 100 ms after the finger lifts.
     */
    @Test
    fun a6_3_kt_theLabelStaysAtLeast500msThenShrinksIn100ms() {
        show(
            column("root", "gap", "d"),
            sizedBox("gap", 300, 60),
            slider("d", "value" to 50, "max" to 100, "divisions" to 4, "label" to "Volume"),
        )
        val label = compose.onNodeWithText("Volume", useUnmergedTree = true)
        val slider = compose.onNodeWithTag("d")
        // With the clock held, a press reaches the page only once the test
        // idles (which runs the main looper, and does not move the clock).
        fun touch(block: TouchInjectionScope.() -> Unit) {
            slider.performTouchInput(block)
            compose.waitForIdle()
        }
        var from = 0L
        // The clock [ms] after [from] (rounded up to a frame, as the clock moves).
        fun at(ms: Long) = compose.mainClock.advanceTimeBy(from + ms - compose.mainClock.currentTime)
        compose.mainClock.autoAdvance = false

        from = compose.mainClock.currentTime
        touch { down(Offset(160f, height / 2f)) }
        at(150)
        label.assertExists()
        touch { up() }
        at(495)
        label.assertExists()
        at(605)
        compose.mainClock.advanceTimeByFrame()
        label.assertDoesNotExist()

        from = compose.mainClock.currentTime
        touch { down(Offset(160f, height / 2f)) }
        at(900)
        label.assertExists()
        from = compose.mainClock.currentTime
        touch { up() }
        at(95)
        label.assertExists()
        at(105)
        compose.mainClock.advanceTimeByFrame()
        label.assertDoesNotExist()
    }

    /**
     * A6.3: a second press while the label still shows (within the 500 ms
     * hold) keeps it, rising from where it is, as Flutter's `forward()` from
     * 1; it then goes 100 ms after the later of that press's 500 ms and its
     * lift.
     */
    @Test
    fun a6_3_kt_aSecondPressWhileTheLabelShowsKeepsIt() {
        show(
            column("root", "gap", "d"),
            sizedBox("gap", 300, 60),
            slider("d", "value" to 50, "max" to 100, "divisions" to 4, "label" to "Volume"),
        )
        val label = compose.onNodeWithText("Volume", useUnmergedTree = true)
        val slider = compose.onNodeWithTag("d")
        fun touch(block: TouchInjectionScope.() -> Unit) {
            slider.performTouchInput(block)
            compose.waitForIdle()
        }
        var from = 0L
        fun at(ms: Long) = compose.mainClock.advanceTimeBy(from + ms - compose.mainClock.currentTime)
        compose.mainClock.autoAdvance = false

        from = compose.mainClock.currentTime
        touch { down(Offset(160f, height / 2f)) }
        at(150)
        touch { up() }
        at(300)
        label.assertExists()
        from = compose.mainClock.currentTime
        touch { down(Offset(160f, height / 2f)) }
        repeat(4) {
            compose.mainClock.advanceTimeByFrame()
            label.assertExists()
        }
        touch { up() }
        at(495)
        label.assertExists()
        at(605)
        compose.mainClock.advanceTimeByFrame()
        label.assertDoesNotExist()
    }

    /**
     * A6.7: `enabled` false makes a Switch inert and greys it as Material
     * does (the checked track onSurface at 0.12); an unchecked one keeps its
     * `inactiveColor` track (Flutter's widget track colour ignores the
     * disabled state, and Material's disabled opacity is 1).
     */
    @Test
    fun a6_7_kt_aDisabledSwitchIsInertAndGreyed() {
        val onChange = Action.SetState(key = "seen", value = eventValue)
        val model = show(
            column("root", "on", "off", "tinted"),
            switch("on", "stateKey" to "a", "enabled" to false, onChange = onChange, watches = listOf("a")),
            switch("off", "value" to false, "enabled" to false, onChange = onChange),
            switch("tinted", "value" to false, "enabled" to false, "inactiveColor" to "#43A047"),
            state = listOf(def("a", true), def("seen", "none")),
        )
        val picture = picture()
        assertPixel(scheme.onSurface.copy(alpha = 0.12f).compositeOver(Color.White), picture, "on", 10, 16)
        assertPixel(green, picture, "tinted", 40, 16)
        for (id in listOf("on", "off")) compose.onNodeWithTag(id).assertIsNotEnabled()

        var commits = 0
        model.store.onCommit = { commits += 1 }
        for (id in listOf("on", "off")) compose.onNodeWithTag(id).performClick()

        compose.runOnIdle {
            assertEquals(0, commits)
            assertEquals(JsonValue.String("none"), model.store.value("seen"))
        }
        compose.onNodeWithTag("on").assertIsOn()
        compose.onNodeWithTag("off").assertIsOff()
    }

    /**
     * A6.7: `enabled` false makes a Slider inert, to a swipe and to
     * setProgress, and greys it as Material does (the active track onSurface
     * at 0.38).
     */
    @Test
    fun a6_7_kt_aDisabledSliderIsInertAndGreyed() {
        val model = show(
            column("root", "s"),
            slider(
                "s", "stateKey" to "v", "max" to 100, "enabled" to false,
                onChange = Action.SetState(key = "seen", value = eventValue), watches = listOf("v"),
            ),
            state = listOf(def("v", 50), def("seen", "none")),
        )
        assertPixel(scheme.onSurface.copy(alpha = 0.38f).compositeOver(Color.White), picture(), "s", 70, 24)
        compose.onNodeWithTag("s").assertIsNotEnabled()

        var commits = 0
        model.store.onCommit = { commits += 1 }
        compose.onNodeWithTag("s").performTouchInput {
            down(Offset(160f, height / 2f))
            moveTo(Offset(290f, height / 2f))
            up()
        }
        compose.onNodeWithTag("s").performTouchInput { click(Offset(40f, height / 2f)) }
        setProgress("s", 10f)

        compose.runOnIdle {
            assertEquals(0, commits)
            assertEquals(JsonValue.Int(50), model.store.value("v"))
            assertEquals(JsonValue.String("none"), model.store.value("seen"))
        }
        assertEquals(50f, progress("s").current)
    }

    /**
     * A6.7: with no onChange both still take touches, look enabled and
     * write their `stateKey`; nothing fires.
     */
    @Test
    fun a6_7_kt_withoutOnChangeBothStillTakeTouchesAndWriteTheirKey() {
        val model = show(
            column("root", "sw", "sl"),
            switch("sw", "stateKey" to "a", watches = listOf("a")),
            slider("sl", "stateKey" to "v", "max" to 100, "divisions" to 4, watches = listOf("v")),
            state = listOf(def("a", false), def("v", 0)),
        )
        val effects = ArrayList<ActionEffect>()
        model.onEffect = { effects.add(it) }
        val commits = ArrayList<StoreState>()
        model.store.onCommit = { commits.add(it) }
        compose.onNodeWithTag("sw").assertIsEnabled()
        compose.onNodeWithTag("sl").assertIsEnabled()

        compose.onNodeWithTag("sw").performClick()
        setProgress("sl", 80f)

        compose.runOnIdle {
            assertEquals(2, commits.size)
            assertEquals(JsonValue.Bool(true), model.store.value("a"))
            assertEquals(JsonValue.Double(75.0), model.store.value("v"))
            assertTrue(effects.isEmpty(), "$effects")
        }
        compose.onNodeWithTag("sw").assertIsOn()
        assertEquals(75f, progress("sl").current)
    }
}
