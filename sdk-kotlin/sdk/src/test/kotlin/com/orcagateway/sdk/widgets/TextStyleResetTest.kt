package com.orcagateway.sdk.widgets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.row
import com.orcagateway.sdk.support.text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

/**
 * A7.2: where a DefaultTextStyle stops. Every Material puts its child under
 * the theme's text style (MUI material.dart:470-474), so a DTS above a
 * Card (card.dart:279), an ElevatedButton, OutlinedButton or TextButton
 * (button_style_button.dart:628), a FloatingActionButton (its
 * RawMaterialButton), an InkWell (the builder's transparent Material,
 * layout_builders.dart:620), a Scaffold (scaffold.dart:3415) or an AppBar
 * (app_bar.dart:1162, :1233) never reaches a Text inside: that Text lays out
 * as the same Text in the same host with no DTS (style, colour included,
 * line limit, overflow, size). Under the same DTS a Text beside the host,
 * outside any Material, takes it (red, 30): the control. Flutter's
 * IconButton builder draws no Material (button_builders.dart:93-163), so the
 * DTS reaches a Text in it. The same cases as Swift's TextStyleResetTests.
 * Each page draws the host under the DTS and its twin without one, each in a
 * 300 x 180 box; DefaultTextStyle is registered only in K-caps (G7), so the
 * test registers its builder and widens the core's registry by it. Texts
 * are tagged with their node ids.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class TextStyleResetTest {
    @get:Rule
    val compose = createComposeRule()

    /** A7.2: a Card resets the DTS. */
    @Test
    fun a7_2_kt_aCardResetsTheDts() {
        assertResets("Card", "t") { p -> listOf(node("${p}card", "Card", "${p}t"), text("${p}t", "Hi")) }
    }

    /** A7.2: ElevatedButton, OutlinedButton and TextButton (Texts t0, t1, t2) reset the DTS for their label. */
    @Test
    fun a7_2_kt_theButtonsResetTheDts() {
        val types = listOf("ElevatedButton", "OutlinedButton", "TextButton")
        assertResets("the buttons", *Array(types.size) { "t$it" }) { p ->
            listOf(row("${p}buttons", *Array(types.size) { "${p}b$it" })) +
                types.mapIndexed { i, type -> node("${p}b$i", type, "${p}t$i", kind = ComponentNode.Kind.Button) } +
                types.indices.map { text("${p}t$it", "Hi") }
        }
    }

    /** A7.2: a FloatingActionButton resets the DTS. */
    @Test
    fun a7_2_kt_aFloatingActionButtonResetsTheDts() {
        assertResets("FloatingActionButton", "t") { p ->
            listOf(node("${p}fab", "FloatingActionButton", "${p}t", kind = ComponentNode.Kind.Button), text("${p}t", "Hi"))
        }
    }

    /** A7.2: an InkWell resets the DTS (the builder wraps it in a transparent Material, which still resets it). */
    @Test
    fun a7_2_kt_anInkWellResetsTheDts() {
        assertResets("InkWell", "t") { p -> listOf(node("${p}ink", "InkWell", "${p}t"), text("${p}t", "Hi")) }
    }

    /**
     * A7.2: an AppBar resets the DTS for its title and its actions (its
     * Material holds the whole toolbar; the title draws in the bar's own
     * style, as before).
     */
    @Test
    fun a7_2_kt_anAppBarResetsTheDtsForItsTitleAndActions() {
        assertResets("AppBar", "t", "a") { p ->
            listOf(
                structure("${p}bar", "AppBar", "title" to "${p}t", "action_0" to "${p}a"),
                text("${p}t", "Hi"),
                text("${p}a", "Go"),
            )
        }
    }

    /**
     * A7.2: a Scaffold resets the DTS for its body. The Scaffold fills what
     * it is given, so it stands in an 80 high SizedBox, the control below.
     */
    @Test
    fun a7_2_kt_theScaffoldBodyResetsTheDts() {
        assertResets("Scaffold", "t") { p ->
            listOf(
                ComponentNode(
                    "${p}box", "SizedBox", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                    props("width" to 300, "height" to 80), listOf("${p}s"),
                ),
                structure("${p}s", "Scaffold", "body" to "${p}body"),
                column("${p}body", "${p}t"),
                text("${p}t", "Hi"),
            )
        }
    }

    /**
     * A7.2: Flutter's IconButton builder puts no Material around its child
     * (a SizedBox, an Opacity and a GestureDetector), so a Text in it takes
     * the DTS.
     */
    @Test
    fun a7_2_kt_anIconButtonPassesTheDtsThrough() {
        val model = twins { p ->
            listOf(node("${p}ib", "IconButton", "${p}t", kind = ComponentNode.Kind.Button), text("${p}t", "Hi"))
        }
        show(model)
        val under = layout("ut").layoutInput.style
        assertEquals(Color.Red, under.color, "the Text in the IconButton did not take the DTS's colour")
        assertEquals(30.sp, under.fontSize, "the Text in the IconButton did not take the DTS's size")
        assertNotEquals(layout("nt").layoutInput.style, under)
        assertControl("IconButton")
    }

    // helpers

    /**
     * The host [host] makes (from its id prefix; its first node the root)
     * lays its Texts [texts] (ids without the prefix) out under the DTS as
     * its twin does with no DTS; the control beside it under the DTS takes
     * the DTS. [name] names the host in the failures.
     */
    private fun assertResets(name: String, vararg texts: String, host: (String) -> List<ComponentNode>) {
        show(twins(host))
        for (t in texts) {
            val under = layout("u$t")
            val alone = layout("n$t")
            assertEquals(alone.layoutInput.style, under.layoutInput.style, "$name: the DTS reached Text $t (style)")
            assertEquals(alone.layoutInput.maxLines, under.layoutInput.maxLines, "$name: the DTS reached Text $t (maxLines)")
            assertEquals(alone.layoutInput.overflow, under.layoutInput.overflow, "$name: the DTS reached Text $t (overflow)")
            assertEquals(alone.size, under.size, "$name: the DTS reached Text $t (size)")
        }
        assertControl(name)
    }

    /** The Text beside the host, under the same DTS, takes it: red, 30. */
    private fun assertControl(name: String) {
        val control = layout("control").layoutInput.style
        assertEquals(Color.Red, control.color, "$name: the Text beside did not take the DTS's colour")
        assertEquals(30.sp, control.fontSize, "$name: the Text beside did not take the DTS's size")
    }

    /**
     * The page: the DTS (red, 30) `d` over the Column `under` of the host
     * made with prefix `u` and the control Text `control`; the twin Column
     * `alone` of the host made with prefix `n` and a Text `aside`, under no
     * DTS. No host id may be one of these.
     */
    private fun twins(host: (String) -> List<ComponentNode>): OrcaPageModel {
        val under = host("u")
        val alone = host("n")
        val nodes = listOf(
            ComponentNode(
                "d", "DefaultTextStyle", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                mapOf("style" to JsonValue.obj("color" to "#FF0000", "fontSize" to 30)), listOf("under"),
            ),
            column("under", under.first().id, "control"),
            text("control", "Hi"),
            column("alone", alone.first().id, "aside"),
            text("aside", "Hi"),
        ) + under + alone
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + TYPES)
        return OrcaPageModel(page(*nodes.toTypedArray()), registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("DefaultTextStyle") { node, model, modifier -> DefaultTextStyleWidget(node, model, modifier) }
                register("Text") { node, _, modifier -> TextWidget(node, modifier.testTag(node.id)) }
            }
        }
    }

    /** The DTS page `d` above its twin `alone`, each at the top left of a 300 x 180 box. */
    private fun show(model: OrcaPageModel) {
        compose.setContent {
            Column {
                Box(Modifier.size(300.dp, 180.dp)) { NodeView("d", model) }
                Box(Modifier.size(300.dp, 180.dp)) { NodeView("alone", model) }
            }
        }
    }

    private fun layout(tag: String): TextLayoutResult {
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag(tag, useUnmergedTree = true).performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        return results.single()
    }

    private fun props(vararg props: Pair<String, Any?>): Map<String, JsonValue> =
        props.associate { (key, value) -> key to JsonValue.of(value) }

    private fun node(id: String, type: String, child: String, kind: ComponentNode.Kind = ComponentNode.Kind.Layout) =
        ComponentNode(id, type, kind, ComponentNode.ChildMode.Single, emptyMap(), listOf(child))

    /** A structure widget, its slot props holding the ids of nodes listed as its children. */
    private fun structure(id: String, type: String, vararg slots: Pair<String, String>) = ComponentNode(
        id, type, ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
        slots.associate { (slot, child) -> slot to JsonValue.String(child) }, slots.map { it.second },
    )

    private companion object {
        val TYPES = setOf(
            "DefaultTextStyle", "Card", "ElevatedButton", "OutlinedButton", "TextButton", "IconButton",
            "FloatingActionButton", "InkWell", "AppBar", "Scaffold", "Column", "Row", "SizedBox", "Text",
        )
    }
}
