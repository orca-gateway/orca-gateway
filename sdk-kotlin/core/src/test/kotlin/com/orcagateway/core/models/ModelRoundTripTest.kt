package com.orcagateway.core.models

import com.orcagateway.core.capabilities.GeneratedCapabilities
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.resolver.ValueResolver
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.StoreState
import com.orcagateway.core.support.Fixtures
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.decodeModel
import com.orcagateway.core.support.j
import com.orcagateway.core.support.jsonOf
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlin.test.fail

/**
 * T1.1: every render fixture's expected nodes decode into [ComponentNode]
 * and encode back JSON-equal; the action fixtures do the same for [Action].
 */
class ModelRoundTripTest {
    @Test
    fun allRenderFixturesRoundTrip() {
        val files = Fixtures.files("render")
        assertEquals(30, files.size, "render fixtures 01-30")
        var nodes = 0
        for ((name, fixture) in files) {
            val expected = fixture["expected"]
            val items = expected.arrayValue ?: fail("$name: expected is not an array")
            val decoded = decodeModel<List<ComponentNode>>(expected)
            assertEquals(items.size, decoded.size, name)
            assertJsonEqual(jsonOf(decoded), expected, name)
            nodes += decoded.size
        }
        assertTrue(nodes > 24)
    }

    @Test
    fun renderFixtureNodesDecodeTheirFields() {
        val fixture = Fixtures.json("schema/fixtures/render/06_nested_state.json")
        val nodes = decodeModel<List<ComponentNode>>(fixture["expected"])
        assertEquals(listOf("col", "lbl"), nodes.map { it.id })
        assertEquals(ComponentNode.Kind.Layout, nodes[0].kind)
        assertEquals(ComponentNode.ChildMode.Multi, nodes[0].childMode)
        assertEquals(listOf("lbl"), nodes[0].children)
        assertEquals(listOf("count", "theme.color"), nodes[1].watches)
        assertEquals(j("theme.color"), nodes[1].props["data"]?.get("key"))
    }

    @Test
    fun allActionFixturesRoundTrip() {
        val files = Fixtures.files("actions")
        assertEquals(15, files.size, "action fixtures 01-15")
        val kinds = HashSet<String>()
        for ((name, fixture) in files) {
            val lists = mutableListOf(fixture["actions"])
            fixture["serverResponses"].objectValue?.let { responses ->
                lists += responses.values.map { it["actions"] }.filter { !it.isNull }
            }
            for (list in lists) {
                val actions = decodeModel<List<Action>>(list)
                assertJsonEqual(jsonOf(actions), list, name)
                for (action in actions) {
                    assertFalse(action is Action.Unknown, "$name: ${action.kind} decoded as unknown")
                    collectKinds(action, kinds)
                }
            }
            // State snapshots and effects are data too.
            val state = decodeModel<StoreState>(fixture["expected"]["state"])
            assertJsonEqual(jsonOf(state), fixture["expected"]["state"], name)
            val effects = decodeModel<List<ActionEffect>>(fixture["expected"]["effects"])
            assertJsonEqual(JsonValue.Array(effects.map { it.json }), fixture["expected"]["effects"], name)
        }
        // Every advertised kind appears in the fixtures, except the three
        // component kinds: a fixture compares state and effects, not the node
        // tree, so ComponentMutationTest pins them against Dart's
        // ComponentStore instead.
        val structural = setOf("addComponent", "updateComponent", "deleteComponent")
        assertTrue(kinds.containsAll(GeneratedCapabilities.actionKinds.toSet() - structural), "$kinds")
    }

    @Test
    fun everyActionKindRoundTrips() {
        // One instance per kind, including the ones the alpha executor skips.
        val samples: List<Action> = listOf(
            Action.Navigate(route = j("/detail"), params = props("id" to obj("type" to "static", "value" to 7)), replace = true),
            Action.GoBack,
            Action.SwitchTab("home"),
            Action.OpenDrawer,
            Action.OpenDialog("confirm", heightFactor = 0.5),
            Action.CloseDialog,
            Action.SetState("count", StateScope.App, j(3)),
            Action.ClearState("count", StateScope.Page),
            Action.PersistState("token", StateScope.App, "local"),
            Action.ServerAction("save", props("a" to obj("type" to "state", "key" to "a", "scope" to "page"))),
            Action.ShowSnackbar(j("Saved"), 3000, "Undo"),
            Action.ShowToast(j("Hi"), 2000),
            Action.UpdateComponent("n1", props("data" to "x")),
            Action.DeleteComponent("n1"),
            Action.AddComponent("root", node = obj("type" to "Text"), position = 0),
            Action.CopyToClipboard(j("copied")),
            Action.Share(title = j("T"), message = j("M"), url = j("https://example.com")),
            Action.OpenUrl(j("https://example.com")),
            Action.ActionGroup("sequential", listOf(Action.GoBack, Action.RefetchPage)),
            Action.ConditionalAction(
                listOf(Action.ConditionalAction.Branch(BoolExpr.Eq(j(1), j(1)), Action.GoBack)),
                Action.CloseDialog,
            ),
            Action.AnimateForward("fade"),
            Action.AnimateReverse("fade"),
            Action.RefetchPage,
            Action.UpdateSubPage(j("tab"), j("feed"), params = null, mode = j("replace")),
            Action.Lifecycle(
                action = Action.GoBack,
                onLoading = ActionList.Single(Action.ShowToast(j("…"))),
                onSuccess = ActionList.Many(listOf(Action.GoBack, Action.RefetchPage)),
            ),
            Action.DebugLog(level = "info", message = j("hello"), tag = "t", includeState = true),
            Action.Once(Action.GoBack),
            Action.Always(Action.RefetchPage),
            Action.Custom(obj("type" to "custom:confetti", "count" to 3)),
            Action.Unknown(obj("type" to "teleport", "to" to "mars")),
        )
        assertEquals(28, samples.map { it.kind }.toSet().intersect(Action.kinds.toSet()).size, "all 28 kinds covered")
        for (action in samples) {
            val json = jsonOf(action)
            assertEquals(action.kind, json["type"].stringValue)
            assertEquals(action, decodeModel<Action>(json), action.kind)
        }
        assertEquals(
            Action.Custom(obj("type" to "custom:confetti", "count" to 3)),
            decodeModel<Action>(obj("type" to "custom:confetti", "count" to 3)),
        )
    }

    @Test
    fun pageResponseKeepsExtraMembers() {
        val render = Fixtures.json("schema/fixtures/render/07_scaffold_slots.json")
        val body = obj(
            "pageId" to "home",
            "title" to "Home",
            "state" to arr(
                obj("key" to "count", "scope" to "page", "initial" to 0),
                obj("key" to "user", "scope" to "app", "initial" to null),
            ),
            "components" to render["expected"],
            "capabilityWarnings" to obj("degraded" to arr("Checkbox")),
        )
        val page = decodeModel<PageResponse>(body)
        assertEquals("home", page.pageId)
        assertEquals(JsonValue.Null, page.state[1].initial)
        assertEquals(listOf("capabilityWarnings"), page.extra.keys.sorted())
        assertEquals(page.components.size, page.nodesById.size)
        assertJsonEqual(jsonOf(page), body)
    }

    @Test
    fun typedValueAndExpressionsDecodeFixtureProps() {
        // Every Value object found in fixture props decodes as a typed Value
        // and encodes back equal (modulo the default `scope: page`).
        var count = 0
        for ((name, fixture) in Fixtures.files("render")) {
            for (node in fixture["expected"].arrayValue.orEmpty()) {
                for (value in valueObjects(node["props"])) {
                    val typed = decodeModel<Value>(value)
                    assertEquals(typed, decodeModel<Value>(typed.json), name)
                    count += 1
                }
            }
        }
        assertTrue(count >= 9, "Value objects in fixtures 01-30")
    }

    // MARK: helpers

    private fun collectKinds(action: Action, kinds: MutableSet<String>) {
        kinds.add(action.kind)
        when (action) {
            is Action.ActionGroup -> action.actions.forEach { collectKinds(it, kinds) }
            is Action.ConditionalAction -> {
                action.branches.forEach { collectKinds(it.then, kinds) }
                action.elseAction?.let { collectKinds(it, kinds) }
            }
            is Action.Lifecycle -> {
                collectKinds(action.action, kinds)
                for (list in listOfNotNull(action.onLoading, action.onSuccess, action.onError, action.onComplete)) {
                    list.actions.forEach { collectKinds(it, kinds) }
                }
            }
            is Action.Once -> collectKinds(action.action, kinds)
            is Action.Always -> collectKinds(action.action, kinds)
            else -> Unit
        }
    }

    /** Top-most Value objects inside a props tree. */
    private fun valueObjects(json: JsonValue): List<JsonValue> = when (json) {
        is JsonValue.Object -> {
            val t = json.members["type"]?.stringValue
            if (t != null && t in ValueResolver.valueTypes) listOf(json) else json.members.values.flatMap(::valueObjects)
        }
        is JsonValue.Array -> json.items.flatMap(::valueObjects)
        else -> emptyList()
    }
}
