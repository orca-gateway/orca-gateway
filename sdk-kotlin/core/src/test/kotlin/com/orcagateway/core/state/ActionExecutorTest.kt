package com.orcagateway.core.state

import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ActionList
import com.orcagateway.core.render.ComponentMutation
import com.orcagateway.core.support.ActionStub
import com.orcagateway.core.support.arr
import com.orcagateway.core.support.assertJsonEqual
import com.orcagateway.core.support.j
import com.orcagateway.core.support.obj
import com.orcagateway.core.support.props
import com.orcagateway.core.support.runSuspend
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.fail

/**
 * T3.3 and the executor's own rules beyond the fixtures: the server action
 * request, how its failures surface, lifecycle order, and parallel groups.
 */
class ActionExecutorTest {
    private class Box {
        val effects = ArrayList<ActionEffect>()
        val mutations = ArrayList<ComponentMutation>()
        val types: List<String> get() = effects.map { it.type }
    }

    private fun executor(state: StoreState = StoreState(), stub: ActionStub? = null): Triple<ActionExecutor, ElmStore, Box> {
        val store = ElmStore(state)
        val executor = ActionExecutor(store, stub?.let { ActionStub.client(it) })
        val box = Box()
        executor.onEffect = { box.effects.add(it) }
        executor.onMutation = { box.mutations.add(it) }
        return Triple(executor, store, box)
    }

    // MARK: T3.3 server actions

    @Test
    fun serverActionPostsTheDartBody() = runSuspend {
        val stub = ActionStub(mapOf("save" to obj("actions" to arr())))
        val (executor, _, _) = executor(StoreState(page = props("n" to 1), app = props("user" to "amr")), stub)
        executor.execute(
            Action.ServerAction("save", props("n" to obj("type" to "state", "scope" to "page", "key" to "n"))),
        )

        val request = assertNotNull(stub.requests.firstOrNull())
        assertEquals(1, stub.requests.size, "no caps retry on actions")
        assertEquals("POST", request.method)
        assertEquals("http://stub.invalid/api/v1/app/fixture-app/action", request.url.toString())
        assertEquals("application/json", request.headers["Content-Type"])
        assertNotNull(request.headers["x-orca-caps-hash"])
        assertEquals("Android", request.headers["x-orca-platform"])
        assertJsonEqual(
            JsonValue.parse(request.body ?: ByteArray(0)),
            obj("action" to "save", "params" to obj("n" to 1), "pageState" to obj("n" to 1), "appState" to obj("user" to "amr")),
        )
    }

    @Test
    fun responseActionsRunAndSetStateDefaultsToPageScope() = runSuspend {
        val stub = ActionStub(
            mapOf(
                "add" to obj(
                    "actions" to arr(
                        obj("type" to "setState", "key" to "cart", "value" to 2),
                        obj("type" to "setState", "key" to "user", "scope" to "app", "value" to "x"),
                        obj("type" to "showToast", "message" to "Added"),
                    ),
                ),
            ),
        )
        val (executor, store, box) = executor(stub = stub)
        executor.execute(Action.ServerAction("add"))
        assertEquals(j(2), store.state.page["cart"])
        assertEquals(j("x"), store.state.app["user"])
        assertEquals(listOf("serverAction", "showToast"), box.types)
    }

    @Test
    fun refusedCallsShowTheServerMessageInASnackbar() = runSuspend {
        val stub = ActionStub(
            emptyMap(),
            raw = mapOf(
                "forbidden" to ActionStub.json(403, props("error" to "Forbidden")),
                "missing" to ActionStub.json(404, props("error" to "Unknown action: missing")),
                // A thrown handler: the engine adds a snackbar Flutter ignores.
                "boom" to ActionStub.json(
                    500,
                    props(
                        "error" to "Server action failed",
                        "actions" to arr(obj("type" to "showSnackbar", "message" to "TypeError: x")),
                    ),
                ),
                "silent" to ActionStub.json(400, emptyMap()),
            ),
        )
        val (executor, _, box) = executor(stub = stub)
        for (id in listOf("forbidden", "missing", "boom", "silent")) {
            executor.execute(Action.ServerAction(id))
        }
        val messages = box.effects.filter { it.type == "showSnackbar" }.map { it.payload["message"]?.stringValue ?: "" }
        assertEquals(
            listOf("Forbidden", "Unknown action: missing", "Server action failed", "Server action failed"),
            messages,
        )
    }

    @Test
    fun aBodyThatIsNotJsonThrowsToTheLifecycle() = runSuspend {
        val stub = ActionStub(emptyMap(), raw = mapOf("html" to HttpResponse(502, body = "<html>".encodeToByteArray())))
        val (executor, store, box) = executor(stub = stub)
        executor.execute(
            Action.Lifecycle(
                action = Action.ServerAction("html"),
                onLoading = ActionList.Single(Action.SetState("loading", value = j(true))),
                onError = ActionList.Single(Action.ShowToast(j("failed"))),
                onComplete = ActionList.Single(Action.SetState("loading", value = j(false))),
            ),
        )
        assertEquals(j(false), store.state.page["loading"])
        assertEquals(listOf("serverAction", "showToast"), box.types)
    }

    @Test
    fun withoutAClientOnlyTheRequestIsEmitted() = runSuspend {
        val (executor, _, box) = executor()
        executor.execute(Action.ServerAction("x", props("a" to 1)))
        assertEquals(listOf(ActionEffect("serverAction", props("id" to "x", "params" to obj("a" to 1)))), box.effects)
    }

    // MARK: lifecycle and groups

    @Test
    fun lifecycleOrderOnSuccess() = runSuspend {
        val (executor, _, box) = executor()
        executor.execute(
            Action.Lifecycle(
                action = Action.ShowToast(j("action")),
                onLoading = ActionList.Single(Action.ShowToast(j("loading"))),
                onSuccess = ActionList.Many(listOf(Action.ShowToast(j("success")))),
                onError = ActionList.Single(Action.ShowToast(j("error"))),
                onComplete = ActionList.Single(Action.ShowToast(j("complete"))),
            ),
        )
        assertEquals(
            listOf("loading", "action", "success", "complete"),
            box.effects.map { it.payload["message"]?.stringValue },
        )
    }

    @Test
    fun lifecycleWithoutOnErrorRethrowsAfterOnComplete() = runSuspend {
        val stub = ActionStub(emptyMap(), raw = mapOf("bad" to HttpResponse(500, body = "oops".encodeToByteArray())))
        val (executor, _, box) = executor(stub = stub)
        try {
            executor.execute(
                Action.Lifecycle(
                    action = Action.ServerAction("bad"),
                    onComplete = ActionList.Single(Action.ShowToast(j("complete"))),
                ),
            )
            fail("expected the decoding error to go on up")
        } catch (_: Exception) {
        }
        assertEquals(listOf("serverAction", "showToast"), box.types)
    }

    @Test
    fun parallelGroupRunsEveryAction() = runSuspend {
        val (executor, store, box) = executor()
        executor.execute(
            Action.ActionGroup(
                "parallel",
                listOf(
                    Action.SetState("a", value = j(1)),
                    Action.SetState("b", value = j(2)),
                    Action.ShowToast(j("t")),
                ),
            ),
        )
        assertEquals(props("a" to 1, "b" to 2), store.state.page)
        assertEquals(listOf("showToast"), box.types)
    }

    @Test
    fun navigateWithAnEmptyRouteDoesNothing() = runSuspend {
        val (executor, _, box) = executor()
        executor.execute(Action.Navigate(route = j("")))
        executor.execute(Action.Navigate(path = j("about")))
        assertEquals(listOf(ActionEffect("navigate", props("route" to "about", "replace" to false))), box.effects)
    }

    @Test
    fun effectsReachThePerformerAfterTheSink() = runSuspend {
        val (executor, _, box) = executor()
        val performed = ArrayList<String>()
        executor.perform = { performed.add(it.type) }
        executor.execute(
            Action.ActionGroup(
                actions = listOf(
                    Action.GoBack, Action.OpenUrl(j("https://orcagateway.com")),
                    Action.CopyToClipboard(j("hi")), Action.Share(title = j(""), message = j("m")),
                    Action.ServerAction("x"),
                ),
            ),
        )
        assertEquals(listOf("goBack", "openUrl", "copyToClipboard", "share", "serverAction"), box.types)
        assertEquals(listOf("goBack", "openUrl", "copyToClipboard", "share"), performed, "serverAction is not performed")
    }

    // MARK: component mutations

    @Test
    fun componentKindsBecomeMutations() = runSuspend {
        val node = obj(
            "id" to "c-1", "type" to "Text", "kind" to "primitive", "childMode" to "none",
            "props" to obj("data" to "x"), "children" to arr(), "watches" to arr(),
        )
        val (executor, _, box) = executor()
        executor.execute(Action.UpdateComponent("t", props("data" to "y")))
        executor.execute(Action.DeleteComponent("t"))
        executor.execute(Action.AddComponent("list", components = arr(node), position = 0))
        executor.execute(Action.Unknown(obj("type" to "replaceComponent", "targetId" to "list", "components" to arr(node))))
        assertEquals(4, box.mutations.size)
        assertEquals(ComponentMutation.Update("t", props("data" to "y")), box.mutations[0])
        assertEquals(ComponentMutation.Delete("t"), box.mutations[1])
        val add = box.mutations[2] as? ComponentMutation.Add
        val replace = box.mutations[3] as? ComponentMutation.Replace
        if (add == null || replace == null) fail("add and replace expected")
        assertEquals("list", add.parentId)
        assertEquals(0L, add.position)
        assertEquals(listOf("c-1"), add.components.map { it.id })
        assertEquals("list", replace.targetId)
        assertEquals(listOf("Text"), replace.components.map { it.type })
        assertEquals(emptyList(), box.effects, "mutations emit no effects, as in Dart")
    }
}
