package com.orcagateway.sdk.widgets

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.performTextInput
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
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
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
}
