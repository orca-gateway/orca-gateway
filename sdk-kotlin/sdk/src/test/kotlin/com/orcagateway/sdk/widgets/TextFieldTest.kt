package com.orcagateway.sdk.widgets

import androidx.compose.ui.input.key.Key
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextInputSelection
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPageView
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * TextField edits typed through Compose: the setState on `stateKey`, then
 * `onChange` with `{value}`, keystroke by keystroke (Swift's
 * NativeWidgetTests, the three TextField cases).
 */
@RunWith(RobolectricTestRunner::class)
class TextFieldTest {
    @get:Rule
    val compose = createComposeRule()

    /** `{type: state, key}`, the engine's `V.pageState`. */
    private fun state(key: String): JsonValue = JsonValue.obj("type" to "state", "key" to key)

    /** `{type: event, key: value}`, the edit's text in an action. */
    private val eventValue: JsonValue = JsonValue.obj("type" to "event", "key" to "value")

    private fun field(
        props: Map<String, JsonValue>,
        actions: Map<String, Action>? = null,
        watches: List<String> = emptyList(),
    ): ComponentNode = leaf("f", "TextField", props).copy(actions = actions, watches = watches)

    /** The field in a Column, drawn with a builder set that knows TextField. */
    private fun show(field: ComponentNode): OrcaPageModel {
        val keys = listOf("query", "name", "seen")
        val state = keys.map { StateDefinition(it, StateScope.Page, JsonValue.String("")) }
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "TextField")
        val model = OrcaPageModel(page(column("0", "f"), field, state = state), registry = registry)
        model.builders = WidgetBuilders.standard().apply {
            register("TextField") { node, page, modifier -> TextFieldWidget(node, page, modifier) }
        }
        compose.setContent { OrcaPageView(model) }
        return model
    }

    private fun type(text: String) = compose.onNode(hasSetTextAction()).performTextInput(text)

    private fun shown(): String =
        compose.onNode(hasSetTextAction()).fetchSemanticsNode().config[SemanticsProperties.EditableText].text

    private fun stored(model: OrcaPageModel, key: String): String? = model.store.value(key).stringValue

    /**
     * onChange copies `name` into `seen`: it reads "piz" only if the setState
     * on `stateKey` ran before it.
     */
    @Test
    fun w12_anEditSetsStateThenFiresOnChangeWithTheValue() {
        val onChange = Action.ActionGroup(
            actions = listOf(
                Action.SetState(key = "query", value = eventValue),
                Action.SetState(key = "seen", value = state("name")),
            ),
        )
        val model = show(
            field(
                props = mapOf("stateKey" to JsonValue.String("name"), "value" to state("query")),
                actions = mapOf("onChange" to onChange),
                watches = listOf("query"),
            ),
        )

        type("piz")

        compose.runOnIdle {
            assertEquals("piz", stored(model, "name"))
            assertEquals("piz", stored(model, "query"))
            assertEquals("piz", stored(model, "seen"))
            assertEquals(JsonValue.String("piz"), model.resolve("f")?.get("value"))
        }
        assertEquals("piz", shown())
    }

    /**
     * Fast typing, one keystroke at a time: each one's setState on `stateKey`
     * then its onChange, in typing order, and the page ends on the last.
     */
    @Test
    fun w13_editsRunInTypingOrder() {
        val model = show(
            field(
                props = mapOf("stateKey" to JsonValue.String("name"), "value" to state("query")),
                actions = mapOf("onChange" to Action.SetState(key = "query", value = eventValue)),
                watches = listOf("query"),
            ),
        )
        val commits = ArrayList<String>()
        model.store.onCommit = { commits.add("${it.value("name").stringValue}|${it.value("query").stringValue}") }
        val word = "margherita pizza"

        for (ch in word) type(ch.toString())

        val expected = ArrayList<String>()
        for (end in 1..word.length) {
            val typed = word.substring(0, end)
            expected.add("$typed|${word.substring(0, end - 1)}")
            expected.add("$typed|$typed")
        }
        compose.runOnIdle {
            assertEquals(expected, commits)
            assertEquals(word, stored(model, "query"))
        }
        assertEquals(word, shown())
    }

    /** No `stateKey`, no `onChange`: the text changes in the field and nowhere else. */
    @Test
    fun w14_aFieldWithNoBindingFiresNothing() {
        val model = show(field(props = mapOf("placeholder" to JsonValue.String("Search"))))
        val before = model.store.state
        var commits = 0
        val effects = ArrayList<ActionEffect>()
        model.store.onCommit = { commits += 1 }
        model.onEffect = { effects.add(it) }

        type("x")

        assertEquals("x", shown())
        compose.runOnIdle {
            assertEquals(0, commits)
            assertTrue(effects.isEmpty(), "$effects")
            assertEquals(before, model.store.state)
        }
    }

    /** Several fields in one Column, in order, drawn as [show] draws one. */
    private fun showAll(vararg fields: ComponentNode): OrcaPageModel {
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "TextField")
        val ids = fields.map { it.id }.toTypedArray()
        val model = OrcaPageModel(page(column("0", *ids), *fields), registry = registry)
        model.builders = WidgetBuilders.standard().apply {
            register("TextField") { node, page, modifier -> TextFieldWidget(node, page, modifier) }
        }
        compose.setContent { OrcaPageView(model) }
        return model
    }

    private val editable = SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText)

    /** The [index]th field on the page, by its editable text. */
    private fun fieldAt(index: Int): SemanticsNodeInteraction = compose.onAllNodes(editable)[index]

    private fun heightOf(index: Int): Dp = fieldAt(index).getUnclippedBoundsInRoot().let { it.bottom - it.top }

    /** The laid-out style of the Text that shows [data] (the field's own semantics merge it away). */
    private fun styleOf(data: String) = compose.onNodeWithText(data, useUnmergedTree = true).fetchSemanticsNode().let { node ->
        val results = ArrayList<TextLayoutResult>()
        requireNotNull(node.config[SemanticsActions.GetTextLayoutResult].action).invoke(results)
        results.first().layoutInput.style
    }

    private fun decorated(id: String, vararg decoration: Pair<String, Any?>, props: Map<String, Any?> = emptyMap()) =
        leaf(id, "TextField", (props + ("decoration" to mapOf(*decoration))).mapValues { JsonValue.of(it.value) })

    /**
     * A1.8: a read-only field (Flutter's TextField with a decoration) takes
     * focus and lets its text be selected, and typing changes nothing: no
     * set-text action for an IME, and a hardware key types nothing.
     */
    @Test
    fun a1_8_aReadOnlyFieldFocusesAndSelectsButTakesNoTyping() {
        showAll(
            decorated(
                "f", "border" to "outline",
                props = mapOf("value" to "pizza", "readOnly" to true),
            ),
        )
        val field = fieldAt(0)

        field.performClick()
        field.assertIsFocused()
        field.performTextInputSelection(TextRange(0, 5))
        field.assert(SemanticsMatcher.expectValue(SemanticsProperties.TextSelectionRange, TextRange(0, 5)))
        field.assert(hasSetTextAction().not())
        field.performKeyInput { pressKey(Key.A) }

        compose.runOnIdle {
            val node = fieldAt(0).fetchSemanticsNode()
            assertEquals("pizza", node.config[SemanticsProperties.EditableText].text)
        }
    }

    /**
     * A1.8: `hintStyle`, `helperStyle` and `errorStyle` (Flutter
     * `parseInputDecoration`) are merged over Material's own: their colour
     * and size reach the hint, the helper and the error text.
     */
    @Test
    fun a1_8_hintHelperAndErrorStylesApply() {
        showAll(
            decorated("f1", "hintText" to "hint", "hintStyle" to mapOf("color" to "#E53935", "fontSize" to 20)),
            decorated("f2", "helperText" to "helper", "helperStyle" to mapOf("color" to "#1E88E5", "fontSize" to 14)),
            decorated("f3", "errorText" to "error", "errorStyle" to mapOf("color" to "#43A047", "fontSize" to 18)),
        )

        val hint = styleOf("hint")
        assertEquals(Props.hex("#E53935"), hint.color)
        assertEquals(20.sp, hint.fontSize)
        val helper = styleOf("helper")
        assertEquals(Props.hex("#1E88E5"), helper.color)
        assertEquals(14.sp, helper.fontSize)
        val error = styleOf("error")
        assertEquals(Props.hex("#43A047"), error.color)
        assertEquals(18.sp, error.fontSize)
    }

    /**
     * A1.8: `isDense` takes 4 off the default content padding's top and
     * bottom, as Flutter's InputDecorator does for every border (M3: 20/12
     * to 16/8 outlined, 8/8 to 4/4 underlined), so the field is 8 shorter;
     * a `contentPadding` the author sends wins over it.
     */
    @Test
    fun a1_8_aDenseFieldIsShorter() {
        val dense = "isDense" to true
        showAll(
            decorated("f1", "border" to "outline"),
            decorated("f2", "border" to "outline", dense),
            decorated("f3", "border" to "underline"),
            decorated("f4", "border" to "underline", dense),
            decorated("f5", "contentPadding" to mapOf("top" to 10, "bottom" to 10)),
            decorated("f6", "contentPadding" to mapOf("top" to 10, "bottom" to 10), dense),
        )

        assertEquals(heightOf(0) - 8.dp, heightOf(1))
        assertEquals(heightOf(2) - 8.dp, heightOf(3))
        assertEquals(heightOf(4), heightOf(5))
    }

    /**
     * Gap 6: `maxLines` N with no `minLines` is a fixed N-line field, as
     * Flutter's EditableText sizes it, three lines tall while still empty.
     */
    @Test
    fun a1_8_maxLinesWithoutMinLinesIsThatManyLinesTall() {
        showAll(
            leaf("f1", "TextField"),
            leaf("f2", "TextField", mapOf("maxLines" to JsonValue.Int(3))),
        )

        val one = heightOf(0)
        val three = heightOf(1)
        assertTrue(abs((three - one * 3).value) <= 1f, "one line $one, three lines $three")
    }
}
