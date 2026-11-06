package com.orcagateway.core.models

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.json.SwiftText
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException

/**
 * A wire action (schema/action.schema.json, engine/src/types/action.ts): all
 * 28 kinds, plus `custom:*` and unknown kinds kept verbatim so a newer server
 * never breaks decoding of a whole page.
 *
 * Fields that the wire types as `string | Value` (or plain `Value`) are
 * [JsonValue]: the executor resolves them with `ValueResolver` at run time.
 * Optional fields mirror what the Dart executor reads, which is a superset of
 * the TS interfaces in a few places (`showToast.duration`, `share.text`,
 * `navigate.path`, `addComponent.components`). Wire integers are Long
 * (Swift's Int is 64-bit).
 */
@Serializable(with = ActionSerializer::class)
public sealed class Action {
    public data class Navigate(
        public val route: JsonValue? = null,
        /** Legacy alias the Dart executor falls back to when `route` is absent. */
        public val path: JsonValue? = null,
        public val params: Map<String, JsonValue>? = null,
        public val replace: Boolean? = null,
    ) : Action()

    public data object GoBack : Action()

    public data class SwitchTab(public val tabId: String) : Action()

    public data object OpenDrawer : Action()

    public data class OpenDialog(public val dialogId: String, public val heightFactor: Double? = null) : Action()

    public data object CloseDialog : Action()

    public data class SetState(
        public val key: String,
        /** Absent means `page`, as in the Dart executor. */
        public val scope: StateScope? = null,
        public val value: JsonValue,
    ) : Action()

    public data class ClearState(public val key: String, public val scope: StateScope? = null) : Action()

    public data class PersistState(
        public val key: String,
        public val scope: StateScope? = null,
        public val storage: String? = null,
    ) : Action()

    public data class ServerAction(public val id: String, public val params: Map<String, JsonValue>? = null) : Action()

    public data class ShowSnackbar(
        public val message: JsonValue? = null,
        public val duration: Long? = null,
        public val action: String? = null,
    ) : Action()

    public data class ShowToast(public val message: JsonValue? = null, public val duration: Long? = null) : Action()

    public data class UpdateComponent(public val id: String, public val props: Map<String, JsonValue>? = null) : Action()

    public data class DeleteComponent(public val id: String) : Action()

    public data class AddComponent(
        public val parentId: String,
        public val node: JsonValue? = null,
        public val components: JsonValue? = null,
        public val position: Long? = null,
    ) : Action()

    public data class CopyToClipboard(public val text: JsonValue? = null) : Action()

    public data class Share(
        public val title: JsonValue? = null,
        public val message: JsonValue? = null,
        public val text: JsonValue? = null,
        public val subject: JsonValue? = null,
        public val url: JsonValue? = null,
    ) : Action()

    public data class OpenUrl(public val url: JsonValue? = null) : Action()

    public data class ActionGroup(public val mode: String? = null, public val actions: List<Action>) : Action()

    /** `elseAction` is the wire's `else`. */
    public data class ConditionalAction(
        public val branches: List<Branch>,
        public val elseAction: Action? = null,
    ) : Action() {
        /** `condition` is the wire's `when`. */
        public data class Branch(public val condition: BoolExpr, public val then: Action)
    }

    public data class AnimateForward(public val animationId: String) : Action()

    public data class AnimateReverse(public val animationId: String) : Action()

    public data object RefetchPage : Action()

    public data class UpdateSubPage(
        public val subPageId: JsonValue,
        public val pageId: JsonValue,
        public val params: Map<String, JsonValue>? = null,
        public val mode: JsonValue? = null,
    ) : Action()

    public data class Lifecycle(
        public val action: Action,
        public val onLoading: ActionList? = null,
        public val onSuccess: ActionList? = null,
        public val onError: ActionList? = null,
        public val onComplete: ActionList? = null,
    ) : Action()

    public data class DebugLog(
        public val level: String? = null,
        public val message: JsonValue? = null,
        public val tag: String? = null,
        public val data: JsonValue? = null,
        public val includeState: Boolean? = null,
        public val includeEvent: Boolean? = null,
        public val includeRequest: Boolean? = null,
        public val includeStackTrace: Boolean? = null,
    ) : Action()

    public data class Once(public val action: Action) : Action()

    public data class Always(public val action: Action) : Action()

    /** `custom:<name>`, handled by a plugin; the whole object is kept. */
    public data class Custom(public val raw: JsonValue) : Action()

    /** A kind this build does not know; the whole object is kept. */
    public data class Unknown(public val raw: JsonValue) : Action()

    public val kind: String
        get() = when (this) {
            is Navigate -> "navigate"
            GoBack -> "goBack"
            is SwitchTab -> "switchTab"
            OpenDrawer -> "openDrawer"
            is OpenDialog -> "openDialog"
            CloseDialog -> "closeDialog"
            is SetState -> "setState"
            is ClearState -> "clearState"
            is PersistState -> "persistState"
            is ServerAction -> "serverAction"
            is ShowSnackbar -> "showSnackbar"
            is ShowToast -> "showToast"
            is UpdateComponent -> "updateComponent"
            is DeleteComponent -> "deleteComponent"
            is AddComponent -> "addComponent"
            is CopyToClipboard -> "copyToClipboard"
            is Share -> "share"
            is OpenUrl -> "openUrl"
            is ActionGroup -> "actionGroup"
            is ConditionalAction -> "conditionalAction"
            is AnimateForward -> "animateForward"
            is AnimateReverse -> "animateReverse"
            RefetchPage -> "refetchPage"
            is UpdateSubPage -> "updateSubPage"
            is Lifecycle -> "lifecycle"
            is DebugLog -> "debugLog"
            is Once -> "once"
            is Always -> "always"
            is Custom -> raw["type"].stringValue ?: ""
            is Unknown -> raw["type"].stringValue ?: ""
        }

    /** This action as wire JSON ([JsonValue.Null] if it cannot be encoded). */
    public val json: JsonValue get() = bridge(ActionSerializer, this)

    public companion object {
        /** The 28 built-in kinds. */
        public val kinds: List<String> = listOf(
            "navigate", "goBack", "switchTab", "openDrawer", "openDialog", "closeDialog",
            "setState", "clearState", "persistState", "serverAction", "showSnackbar",
            "showToast", "updateComponent", "deleteComponent", "addComponent",
            "copyToClipboard", "share", "openUrl", "actionGroup", "conditionalAction",
            "animateForward", "animateReverse", "refetchPage", "updateSubPage",
            "lifecycle", "debugLog", "once", "always",
        )
    }
}

/** `Action | Action[]`, as lifecycle callbacks allow either. */
@Serializable(with = ActionListSerializer::class)
public sealed class ActionList {
    public data class Single(public val action: Action) : ActionList()

    public data class Many(public val list: List<Action>) : ActionList()

    public val actions: List<Action>
        get() = when (this) {
            is Single -> listOf(action)
            is Many -> list
        }
}

// MARK: - Serializers

internal object ActionListSerializer : JsonTreeSerializer<ActionList>("com.orcagateway.core.models.ActionList") {
    override fun fromTree(tree: JsonValue): ActionList {
        // Swift: `try? decode([Action])`, else one Action (whose error stands).
        val many = tree.arrayValue?.let { items ->
            try {
                items.map(ActionSerializer::fromTree)
            } catch (_: SerializationException) {
                null
            }
        }
        return if (many != null) ActionList.Many(many) else ActionList.Single(ActionSerializer.fromTree(tree))
    }

    override fun toTree(value: ActionList): JsonValue = when (value) {
        is ActionList.Single -> ActionSerializer.toTree(value.action)
        is ActionList.Many -> JsonValue.Array(value.list.map(ActionSerializer::toTree))
    }
}

internal object ActionSerializer : JsonTreeSerializer<Action>("com.orcagateway.core.models.Action") {
    private fun scope(f: Fields): StateScope? = f.decodeOrNull("scope", ::scopeFromTree)

    override fun fromTree(tree: JsonValue): Action {
        val f = Fields.of(tree, "Action")
        return when (val type = f.string("type")) {
            "navigate" -> Action.Navigate(
                f.jsonOrNull("route"), f.jsonOrNull("path"), f.objOrNull("params"), f.boolOrNull("replace"),
            )
            "goBack" -> Action.GoBack
            "switchTab" -> Action.SwitchTab(f.string("tabId"))
            "openDrawer" -> Action.OpenDrawer
            "openDialog" -> Action.OpenDialog(f.string("dialogId"), f.doubleOrNull("heightFactor"))
            "closeDialog" -> Action.CloseDialog
            "setState" -> Action.SetState(f.string("key"), scope(f), f.jsonOrNull("value") ?: JsonValue.Null)
            "clearState" -> Action.ClearState(f.string("key"), scope(f))
            "persistState" -> Action.PersistState(f.string("key"), scope(f), f.stringOrNull("storage"))
            "serverAction" -> Action.ServerAction(f.string("id"), f.objOrNull("params"))
            "showSnackbar" -> Action.ShowSnackbar(
                f.jsonOrNull("message"), f.longOrNull("duration"), f.stringOrNull("action"),
            )
            "showToast" -> Action.ShowToast(f.jsonOrNull("message"), f.longOrNull("duration"))
            "updateComponent" -> Action.UpdateComponent(f.string("id"), f.objOrNull("props"))
            "deleteComponent" -> Action.DeleteComponent(f.string("id"))
            "addComponent" -> Action.AddComponent(
                f.string("parentId"), f.jsonOrNull("node"), f.jsonOrNull("components"), f.longOrNull("position"),
            )
            "copyToClipboard" -> Action.CopyToClipboard(f.jsonOrNull("text"))
            "share" -> Action.Share(
                f.jsonOrNull("title"), f.jsonOrNull("message"), f.jsonOrNull("text"),
                f.jsonOrNull("subject"), f.jsonOrNull("url"),
            )
            "openUrl" -> Action.OpenUrl(f.jsonOrNull("url"))
            "actionGroup" -> Action.ActionGroup(f.stringOrNull("mode"), f.list("actions", ::fromTree))
            "conditionalAction" -> Action.ConditionalAction(
                f.list("branches") { branch ->
                    val b = Fields.of(branch, "ConditionalAction.Branch")
                    Action.ConditionalAction.Branch(b.decode("when", BoolExprSerializer::fromTree), b.decode("then", ::fromTree))
                },
                f.decodeOrNull("else", ::fromTree),
            )
            "animateForward" -> Action.AnimateForward(f.string("animationId"))
            "animateReverse" -> Action.AnimateReverse(f.string("animationId"))
            "refetchPage" -> Action.RefetchPage
            "updateSubPage" -> Action.UpdateSubPage(
                f.json("subPageId"), f.json("pageId"), f.objOrNull("params"), f.jsonOrNull("mode"),
            )
            "lifecycle" -> Action.Lifecycle(
                f.decode("action", ::fromTree),
                f.decodeOrNull("onLoading", ActionListSerializer::fromTree),
                f.decodeOrNull("onSuccess", ActionListSerializer::fromTree),
                f.decodeOrNull("onError", ActionListSerializer::fromTree),
                f.decodeOrNull("onComplete", ActionListSerializer::fromTree),
            )
            "debugLog" -> Action.DebugLog(
                f.stringOrNull("level"), f.jsonOrNull("message"), f.stringOrNull("tag"), f.jsonOrNull("data"),
                f.boolOrNull("includeState"), f.boolOrNull("includeEvent"), f.boolOrNull("includeRequest"),
                f.boolOrNull("includeStackTrace"),
            )
            "once" -> Action.Once(f.decode("action", ::fromTree))
            "always" -> Action.Always(f.decode("action", ::fromTree))
            else -> if (SwiftText.hasPrefix(type, "custom:")) Action.Custom(tree) else Action.Unknown(tree)
        }
    }

    override fun toTree(value: Action): JsonValue {
        when (value) {
            is Action.Custom -> return value.raw
            is Action.Unknown -> return value.raw
            else -> Unit
        }
        return tree {
            when (value) {
                is Action.Navigate -> {
                    putIfPresent("route", value.route)
                    putIfPresent("path", value.path)
                    putIfPresent("params", value.params)
                    putIfPresent("replace", value.replace)
                }
                is Action.SwitchTab -> put("tabId", value.tabId)
                is Action.OpenDialog -> {
                    put("dialogId", value.dialogId)
                    putIfPresent("heightFactor", value.heightFactor)
                }
                is Action.SetState -> {
                    put("key", value.key)
                    putIfPresent("scope", value.scope?.wire)
                    put("value", value.value)
                }
                is Action.ClearState -> {
                    put("key", value.key)
                    putIfPresent("scope", value.scope?.wire)
                }
                is Action.PersistState -> {
                    put("key", value.key)
                    putIfPresent("scope", value.scope?.wire)
                    putIfPresent("storage", value.storage)
                }
                is Action.ServerAction -> {
                    put("id", value.id)
                    putIfPresent("params", value.params)
                }
                is Action.ShowSnackbar -> {
                    putIfPresent("message", value.message)
                    putIfPresent("duration", value.duration)
                    putIfPresent("action", value.action)
                }
                is Action.ShowToast -> {
                    putIfPresent("message", value.message)
                    putIfPresent("duration", value.duration)
                }
                is Action.UpdateComponent -> {
                    put("id", value.id)
                    putIfPresent("props", value.props)
                }
                is Action.DeleteComponent -> put("id", value.id)
                is Action.AddComponent -> {
                    put("parentId", value.parentId)
                    putIfPresent("node", value.node)
                    putIfPresent("components", value.components)
                    putIfPresent("position", value.position)
                }
                is Action.CopyToClipboard -> putIfPresent("text", value.text)
                is Action.Share -> {
                    putIfPresent("title", value.title)
                    putIfPresent("message", value.message)
                    putIfPresent("text", value.text)
                    putIfPresent("subject", value.subject)
                    putIfPresent("url", value.url)
                }
                is Action.OpenUrl -> putIfPresent("url", value.url)
                is Action.ActionGroup -> {
                    putIfPresent("mode", value.mode)
                    put("actions", JsonValue.Array(value.actions.map(::toTree)))
                }
                is Action.ConditionalAction -> {
                    put(
                        "branches",
                        JsonValue.Array(
                            value.branches.map { b ->
                                tree {
                                    put("when", BoolExprSerializer.toTree(b.condition))
                                    put("then", toTree(b.then))
                                }
                            },
                        ),
                    )
                    putIfPresent("else", value.elseAction?.let(::toTree))
                }
                is Action.AnimateForward -> put("animationId", value.animationId)
                is Action.AnimateReverse -> put("animationId", value.animationId)
                is Action.UpdateSubPage -> {
                    put("subPageId", value.subPageId)
                    put("pageId", value.pageId)
                    putIfPresent("params", value.params)
                    putIfPresent("mode", value.mode)
                }
                is Action.Lifecycle -> {
                    put("action", toTree(value.action))
                    putIfPresent("onLoading", value.onLoading?.let(ActionListSerializer::toTree))
                    putIfPresent("onSuccess", value.onSuccess?.let(ActionListSerializer::toTree))
                    putIfPresent("onError", value.onError?.let(ActionListSerializer::toTree))
                    putIfPresent("onComplete", value.onComplete?.let(ActionListSerializer::toTree))
                }
                is Action.DebugLog -> {
                    putIfPresent("level", value.level)
                    putIfPresent("message", value.message)
                    putIfPresent("tag", value.tag)
                    putIfPresent("data", value.data)
                    putIfPresent("includeState", value.includeState)
                    putIfPresent("includeEvent", value.includeEvent)
                    putIfPresent("includeRequest", value.includeRequest)
                    putIfPresent("includeStackTrace", value.includeStackTrace)
                }
                is Action.Once -> put("action", toTree(value.action))
                is Action.Always -> put("action", toTree(value.action))
                else -> Unit // goBack, openDrawer, closeDialog, refetchPage: no payload
            }
            put("type", value.kind)
        }
    }
}
