package com.orcagateway.sdk.widgets

import android.graphics.Bitmap
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.draw
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * A6.4 and A6.7 for TextFormField and Form. Flutter's `_buildTextFormField`
 * is a copy of `_buildTextField` (input_builders.dart), so TextField's
 * builder draws it (registered under the name here, as standard() will);
 * `_buildForm` (layout_builders.dart) returns its one child.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FormFieldTest {
    @get:Rule
    val compose = createComposeRule()

    private lateinit var view: View

    /** `{type: state, key}`, the engine's `V.pageState`. */
    private fun state(key: String): JsonValue = JsonValue.obj("type" to "state", "key" to key)

    /** `{type: event, key: value}`, the edit's text in an action. */
    private val eventValue: JsonValue = JsonValue.obj("type" to "event", "key" to "value")

    private fun def(key: String, initial: Any?) = StateDefinition(key, StateScope.Page, JsonValue.of(initial))

    private fun field(id: String, vararg props: Pair<String, Any?>, onChange: Action? = null, watches: List<String> = emptyList()) =
        ComponentNode(
            id, "TextFormField", ComponentNode.Kind.Input, ComponentNode.ChildMode.None,
            props.associate { (key, value) -> key to JsonValue.of(value) },
            watches = watches,
            actions = onChange?.let { mapOf("onChange" to it) },
        )

    private fun form(id: String, vararg children: String) =
        ComponentNode(id, "Form", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, children = children.toList())

    /** A Text showing the page-state key [key], redrawn when it changes. */
    private fun shows(id: String, key: String) = leaf(id, "Text", mapOf("data" to state(key))).copy(watches = listOf(key))

    /**
     * The page from [nodes], its root in a 300 x 400 box (in [scheme] when
     * one is given); TextFormField and Form known to the core and drawn
     * here, Forms and Texts tagged with their ids (a field is found by its
     * editable text).
     */
    private fun show(
        vararg nodes: ComponentNode,
        state: List<StateDefinition> = emptyList(),
        scheme: ColorScheme? = null,
    ): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("TextFormField", "Form"))
        val model = OrcaPageModel(page(*nodes, state = state), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("TextFormField") { node, model, modifier -> TextFieldWidget(node, model, modifier) }
                register("Form") { node, model, modifier -> FormWidget(node, model, modifier.testTag(node.id)) }
                register("Text") { node, _, modifier -> TextWidget(node, modifier.testTag(node.id)) }
            }
        }
        compose.setContent {
            view = LocalView.current
            if (scheme == null) {
                Box(Modifier.size(300.dp, 400.dp)) { NodeView(nodes.first().id, model) }
            } else {
                MaterialTheme(colorScheme = scheme) { Box(Modifier.size(300.dp, 400.dp)) { NodeView(nodes.first().id, model) } }
            }
        }
        compose.waitForIdle()
        return model
    }

    private val editable = SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText)

    private fun type(text: String) = compose.onNode(hasSetTextAction()).performTextInput(text)

    private fun shown(): String = compose.onNode(editable).fetchSemanticsNode().config[SemanticsProperties.EditableText].text

    /**
     * A6.4: typing writes `stateKey` first, then fires onChange with
     * `{value}`: onChange copies the key, and reads "piz" only if the write
     * came first. A Text watching the key redraws.
     */
    @Test
    fun a6_4_kt_aTextFormFieldBindsLikeATextField() {
        val onChange = Action.ActionGroup(
            actions = listOf(
                Action.SetState(key = "query", value = eventValue),
                Action.SetState(key = "seen", value = state("name")),
            ),
        )
        val model = show(
            column("root", "f", "t"),
            field("f", "stateKey" to "name", "value" to state("query"), onChange = onChange, watches = listOf("query")),
            shows("t", "name"),
            state = listOf(def("name", ""), def("query", ""), def("seen", "")),
        )

        type("piz")

        compose.runOnIdle {
            assertEquals(JsonValue.String("piz"), model.store.state.page["name"])
            assertEquals(JsonValue.String("piz"), model.store.value("query"))
            assertEquals(JsonValue.String("piz"), model.store.value("seen"))
        }
        assertEquals("piz", shown())
        compose.onNodeWithTag("t").assertTextEquals("piz")
    }

    /**
     * A6.4: the field shows the store at `stateKey`, and takes a change to
     * it from elsewhere (a reset) without firing onChange.
     */
    @Test
    fun a6_4_kt_aTextFormFieldTakesItsKeyFromElsewhereWithoutFiring() {
        val model = show(
            column("root", "f"),
            field(
                "f", "stateKey" to "name",
                onChange = Action.SetState(key = "seen", value = eventValue), watches = listOf("name"),
            ),
            state = listOf(def("name", "pizza"), def("seen", "none")),
        )
        val effects = ArrayList<ActionEffect>()
        model.onEffect = { effects.add(it) }
        assertEquals("pizza", shown())

        model.store.dispatch(mapOf("name" to JsonValue.String("")))

        compose.waitForIdle()
        assertEquals("", shown())
        compose.runOnIdle {
            assertEquals(JsonValue.String("none"), model.store.value("seen"))
            assertTrue(effects.isEmpty(), "$effects")
        }
    }

    /**
     * A6.4: a Form draws its one child and nothing of its own: what its
     * parent hands it (here its test tag) lands on the field itself, which
     * sits where the Form is put and stays live; a Form with no child draws
     * nothing.
     */
    @Test
    fun a6_4_kt_aFormDrawsItsOneChild() {
        val model = show(
            column("root", "form", "empty"),
            form("form", "f"),
            field("f", "stateKey" to "name"),
            form("empty"),
            state = listOf(def("name", "")),
        )
        compose.onNodeWithTag("form").assert(editable)
        val drawn = compose.onNodeWithTag("form").getUnclippedBoundsInRoot()
        assertEquals(compose.onNode(editable).getUnclippedBoundsInRoot(), drawn)
        assertEquals(0.dp, drawn.top)
        assertEquals(300.dp, drawn.right - drawn.left)
        compose.onNodeWithTag("empty").assertDoesNotExist()

        type("x")

        compose.runOnIdle { assertEquals(JsonValue.String("x"), model.store.value("name")) }
    }

    /**
     * A6.7: `enabled` false on a bare TextFormField (no decoration) is
     * Flutter's EditableText with `readOnly: !enabled`: still enabled, a tap
     * focuses it, but it takes no edits (no set-text action, a key types
     * nothing), and the store keeps its text.
     */
    @Test
    fun a6_7_kt_aDisabledTextFormFieldTakesNoEdits() {
        val model = show(
            column("root", "f"),
            field(
                "f", "stateKey" to "name", "enabled" to false,
                onChange = Action.SetState(key = "seen", value = eventValue), watches = listOf("name"),
            ),
            state = listOf(def("name", "pizza"), def("seen", "none")),
        )
        var commits = 0
        model.store.onCommit = { commits += 1 }
        val node = compose.onNode(editable)

        node.assertIsEnabled()
        node.assert(hasSetTextAction().not())
        node.performClick()
        node.assertIsFocused()
        node.performKeyInput { pressKey(Key.A) }

        compose.runOnIdle {
            assertEquals(0, commits)
            assertEquals(JsonValue.String("pizza"), model.store.value("name"))
            assertEquals(JsonValue.String("none"), model.store.value("seen"))
        }
        assertEquals("pizza", shown())
    }

    /**
     * A6.7: with a decoration, `enabled` false is Material's disabled
     * TextField (Flutter's `TextField(enabled:)`): not enabled, no set-text
     * action, and a tap does not focus it.
     */
    @Test
    fun a6_7_kt_aDisabledDecoratedTextFormFieldTakesNoFocus() {
        val decoration = "decoration" to mapOf("labelText" to "Name")
        show(
            column("root", "on", "off"),
            field("on", decoration),
            field("off", decoration, "enabled" to false),
        )
        val on = compose.onAllNodes(editable)[0]
        val off = compose.onAllNodes(editable)[1]
        on.assertIsEnabled()
        off.assertIsNotEnabled()
        off.assert(hasSetTextAction().not())

        off.performClick()

        compose.onAllNodes(SemanticsMatcher.expectValue(SemanticsProperties.Focused, true)).assertCountEquals(0)
    }

    /**
     * A6.7: when no style is sent, a disabled decorated field keeps its text
     * in the builder's default style (16 black, the style Flutter's TextField
     * is given, which wins over the disabled colour) while
     * `_InputDecoratorDefaultsM3` greys the decoration's texts: label, hint,
     * helper, counter, and the prefix and suffix (the hint's style; shown
     * once there is text, as Flutter's) in onSurface at 0.38. The error text
     * keeps the error colour (its style has no disabled state). The scheme
     * tells the parts apart by hue.
     */
    @Test
    fun a6_7_kt_aDisabledDecoratedFieldGreysItsTextsNotItsValue() {
        val off = "enabled" to false
        show(
            column("root", "label", "hint", "affix", "value", "error"),
            field("label", off, "decoration" to mapOf("labelText" to "Name")),
            field("hint", off, "decoration" to mapOf("hintText" to "Hint")),
            field("affix", off, "value" to "x", "decoration" to mapOf("prefixText" to "P", "suffixText" to "S")),
            field(
                "value", off, "value" to "HHH", "maxLength" to 10,
                "decoration" to mapOf("helperText" to "Help"),
            ),
            field("error", off, "decoration" to mapOf("errorText" to "Err")),
            scheme = hues,
        )
        compose.waitForIdle()
        val picture = draw(view)

        for (part in listOf("Name", "Hint", "P", "S", "Help", "3/10")) {
            assertInk(Color.Red, 0.38f, inked(picture, textBounds(part)), part)
        }
        assertInk(hues.error, 1f, inked(picture, textBounds("Err")), "Err")
        val value = inked(picture, compose.onAllNodes(editable)[3].getUnclippedBoundsInRoot())
        assertTrue(
            value.any { p -> listOf(android.graphics.Color.red(p), android.graphics.Color.green(p), android.graphics.Color.blue(p)).all { it < 50 } },
            "no black text in the disabled field",
        )
    }

    /**
     * A6.7: a disabled decorated field's line and fill, Flutter's M3
     * defaults when no disabled border is set (the builder sets only
     * `border`, `enabledBorder` and `focusedBorder`): an unfilled field's
     * underline or outline is `outlineBorder`'s onSurface at 0.12, a filled
     * one's is `activeIndicatorBorder`'s onSurface at 0.38; a fill with no
     * `fillColor` is onSurface at 0.04, a `fillColor` sent stays.
     */
    @Test
    fun a6_7_kt_aDisabledDecoratedFieldGreysItsLinesAndFill() {
        val off = "enabled" to false
        show(
            column("root", "plain", "underline", "filled", "outline", "outlineFilled"),
            field("plain", off, "decoration" to mapOf("labelText" to "A")),
            field("underline", off, "decoration" to mapOf("border" to "underline")),
            field("filled", off, "decoration" to mapOf("filled" to true)),
            field("outline", off, "decoration" to mapOf("border" to "outline")),
            field("outlineFilled", off, "decoration" to mapOf("border" to "outline", "filled" to true, "fillColor" to "#FFFF00")),
            scheme = hues,
        )
        compose.waitForIdle()
        val picture = draw(view)
        val fields = compose.onAllNodes(editable)
        fun bottom(i: Int): Int {
            val b = fields[i].getUnclippedBoundsInRoot()
            return picture.getPixel(((b.left + b.right) / 2).value.toInt(), b.bottom.value.toInt() - 1)
        }
        fun inside(i: Int): Int {
            val b = fields[i].getUnclippedBoundsInRoot()
            return picture.getPixel(((b.left + b.right) / 2).value.toInt(), ((b.top + b.bottom) / 2).value.toInt())
        }
        val faint = Color.Red.copy(alpha = 0.12f).compositeOver(Color.White)
        val strong = Color.Red.copy(alpha = 0.38f)
        val fill = Color.Red.copy(alpha = 0.04f).compositeOver(Color.White)
        val yellow = Color(0xFFFFFF00)

        assertColour(faint, bottom(0), "unfilled underline")
        assertColour(faint, bottom(1), "underline border")
        assertColour(fill, inside(2), "fill without fillColor")
        assertColour(strong.compositeOver(fill), bottom(2), "filled underline")
        assertColour(faint, bottom(3), "unfilled outline")
        assertColour(yellow, inside(4), "fillColor")
        assertColour(strong.compositeOver(yellow), bottom(4), "filled outline")
    }

    /** Material's light scheme with onSurface red, onSurfaceVariant blue and error green, so each part shows whose colour it took. */
    private val hues = lightColorScheme(onSurface = Color.Red, onSurfaceVariant = Color.Blue, error = Color(0xFF00FF00))

    /** The bounds of the decoration text [text] (not the editable). */
    private fun textBounds(text: String): DpRect =
        compose.onNode(hasText(text) and editable.not(), useUnmergedTree = true).getUnclippedBoundsInRoot()

    /** The pixels of [picture] in [bounds] that are not white. */
    private fun inked(picture: Bitmap, bounds: DpRect): List<Int> {
        val out = ArrayList<Int>()
        val left = bounds.left.value.toInt().coerceAtLeast(0)
        val right = kotlin.math.ceil(bounds.right.value).toInt().coerceAtMost(picture.width)
        val top = bounds.top.value.toInt().coerceAtLeast(0)
        val bottom = kotlin.math.ceil(bounds.bottom.value).toInt().coerceAtMost(picture.height)
        for (y in top until bottom) {
            for (x in left until right) {
                val p = picture.getPixel(x, y)
                if (listOf(android.graphics.Color.red(p), android.graphics.Color.green(p), android.graphics.Color.blue(p)).any { it < 250 }) out.add(p)
            }
        }
        return out
    }

    /**
     * Every pixel in [pixels] is [ink] (a pure hue) over white at no more
     * than [alpha] of it, and some pixel at least 0.85 of [alpha]: text in
     * that colour, antialiased.
     */
    private fun assertInk(ink: Color, alpha: Float, pixels: List<Int>, what: String) {
        assertTrue(pixels.isNotEmpty(), "$what drew nothing")
        var strongest = 0f
        for (p in pixels) {
            val got = listOf(android.graphics.Color.red(p), android.graphics.Color.green(p), android.graphics.Color.blue(p))
            val want = listOf(ink.red, ink.green, ink.blue)
            val share = got.zip(want).filter { (_, w) -> w < 0.5f }.map { (g, _) -> (255 - g) / 255f }
            val kept = got.zip(want).filter { (_, w) -> w >= 0.5f }.all { (g, _) -> g >= 247 }
            assertTrue(kept && share.max() - share.min() < 0.06f, "$what has #${Integer.toHexString(p)}, not $ink over white")
            assertTrue(share.max() <= alpha + 0.03f, "$what has #${Integer.toHexString(p)}, darker than $ink at $alpha")
            strongest = maxOf(strongest, share.max())
        }
        assertTrue(strongest >= 0.85f * alpha, "$what at most $strongest, expected $ink at $alpha")
    }

    private fun assertColour(expected: Color, actual: Int, what: String) {
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(channels.all { (want, got) -> abs(want - got) < 0.05f }, "$what is #${Integer.toHexString(actual)}, expected $expected")
    }
}
