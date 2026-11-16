package com.orcagateway.plugins.pushnotification

import com.orcagateway.core.json.JsonValue
import kotlinx.serialization.json.JsonObject
import org.junit.Test
import java.lang.reflect.Modifier
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * C17.5/K: the action params the plugin reads come from
 * OrcaPushNotificationTypes.kt, what `orca plugin generate --lang kotlin
 * --types-only` writes for plugins/orca_push_notification/orca_plugin.yaml
 * (committed as generated, kept in sync by
 * cli/test/push_notification_kotlin_props_test.dart). They read what the
 * Flutter plugin reads (lib/src/push_notification_plugin.dart :24-30,
 * :91-93, :119-120, :133-137, :158, :165), with the same names; the plugin has
 * no widget, so no props and no triggers. Flutter's defaults (scope "app",
 * tokenKey "fcmToken", title and body "") are the plugin's to apply, so an
 * absent param reads null.
 */
class PushNotificationParamsTest {
    /** The raw object of a `custom:<name>` action with [params], as a handler receives it. */
    private fun action(name: String, vararg params: Pair<String, Any?>): JsonObject =
        JsonValue.obj("type" to "custom:$name", *params).toJsonElement() as JsonObject

    /** The public properties a generated type declares, less the action it reads. */
    private fun properties(type: Class<*>): Set<String> = type.declaredMethods
        .filter { Modifier.isPublic(it.modifiers) && it.parameterCount == 0 && it.name.startsWith("get") }
        .map { it.name.removePrefix("get").replaceFirstChar { c -> c.lowercaseChar() } }
        .toSet() - setOf("action")

    private companion object {
        const val PACKAGE = "com.orcagateway.plugins.pushnotification"
    }

    /**
     * Flutter's five action names, in its order, each the root of its params
     * type's name. The Kotlin types carry no list of names: that the yaml has
     * exactly these five, in this order, is push_notification_schema_test.dart's,
     * and that this file is the generator's output for it, the drift test's.
     */
    @Test
    fun c17_5_theActionsAreFluttersFive() {
        val names = listOf(
            "requestNotificationPermission",
            "getNotificationToken",
            "showLocalNotification",
            "subscribeToTopic",
            "unsubscribeFromTopic",
        )
        assertEquals(
            listOf(
                RequestNotificationPermissionParams::class.java,
                GetNotificationTokenParams::class.java,
                ShowLocalNotificationParams::class.java,
                SubscribeToTopicParams::class.java,
                UnsubscribeFromTopicParams::class.java,
            ),
            names.map { Class.forName("$PACKAGE.${it.replaceFirstChar(Char::uppercaseChar)}Params") },
        )
    }

    @Test
    fun c17_5_eachOfTheFiveActionsHasFluttersParams() {
        assertEquals(
            mapOf(
                "requestNotificationPermission" to setOf("statusKey", "tokenKey", "scope"),
                "getNotificationToken" to setOf("tokenKey", "scope"),
                "showLocalNotification" to setOf("title", "body", "payload"),
                "subscribeToTopic" to setOf("topic"),
                "unsubscribeFromTopic" to setOf("topic"),
            ),
            mapOf(
                "requestNotificationPermission" to properties(RequestNotificationPermissionParams::class.java),
                "getNotificationToken" to properties(GetNotificationTokenParams::class.java),
                "showLocalNotification" to properties(ShowLocalNotificationParams::class.java),
                "subscribeToTopic" to properties(SubscribeToTopicParams::class.java),
                "unsubscribeFromTopic" to properties(UnsubscribeFromTopicParams::class.java),
            ),
        )
    }

    /** Flutter's `action['statusKey'] as String?` and its kin: the keys and scope, read raw. */
    @Test
    fun c17_5_theStateKeysAndScopeReadRawStrings() {
        val request = RequestNotificationPermissionParams(
            action("requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to "pushToken", "scope" to "app"),
        )
        assertEquals<String?>("pushStatus", request.statusKey)
        assertEquals<String?>("pushToken", request.tokenKey)
        assertEquals<String?>("app", request.scope)

        val get = GetNotificationTokenParams(action("getNotificationToken", "tokenKey" to "pushToken", "scope" to "page"))
        assertEquals<String?>("pushToken", get.tokenKey)
        assertEquals<String?>("page", get.scope)

        // Flutter's cast fails the action on a non-string; the param reads null
        // and the plugin fails it from the raw action.
        val number = RequestNotificationPermissionParams(
            action("requestNotificationPermission", "statusKey" to 1, "tokenKey" to true, "scope" to 2),
        )
        assertNull(number.statusKey)
        assertNull(number.tokenKey)
        assertNull(number.scope)
        assertEquals(JsonValue.of(1).toJsonElement(), number.action["statusKey"])
    }

    /** Flutter's `executor.resolveString(...)` on title, body, payload and topic: a plain string reads as is. */
    @Test
    fun c17_5_theTextParamsReadStrings() {
        val show = ShowLocalNotificationParams(
            action(
                "showLocalNotification",
                "title" to "Orca push", "body" to "Tap to open the map", "payload" to "orcacounter://open/map",
            ),
        )
        assertEquals<String?>("Orca push", show.title)
        assertEquals<String?>("Tap to open the map", show.body)
        assertEquals<String?>("orcacounter://open/map", show.payload)

        assertEquals<String?>("news", SubscribeToTopicParams(action("subscribeToTopic", "topic" to "news")).topic)
        assertEquals<String?>("news", UnsubscribeFromTopicParams(action("unsubscribeFromTopic", "topic" to "news")).topic)
        // An empty topic reads as sent: doing nothing on it is the plugin's.
        assertEquals<String?>("", SubscribeToTopicParams(action("subscribeToTopic", "topic" to "")).topic)
    }

    /** Where Flutter applies a default (scope "app", tokenKey "fcmToken", title and body "") or skips a write, the param reads null. */
    @Test
    fun c17_5_absentParamsReadNull() {
        val request = RequestNotificationPermissionParams(action("requestNotificationPermission"))
        assertNull(request.statusKey)
        assertNull(request.tokenKey)
        assertNull(request.scope)

        val get = GetNotificationTokenParams(action("getNotificationToken"))
        assertNull(get.tokenKey)
        assertNull(get.scope)

        val show = ShowLocalNotificationParams(action("showLocalNotification"))
        assertNull(show.title)
        assertNull(show.body)
        assertNull(show.payload)

        assertNull(SubscribeToTopicParams(action("subscribeToTopic")).topic)
        assertNull(UnsubscribeFromTopicParams(action("unsubscribeFromTopic")).topic)

        val nulls = RequestNotificationPermissionParams(
            action("requestNotificationPermission", "statusKey" to null, "tokenKey" to null, "scope" to null),
        )
        assertNull(nulls.statusKey)
        assertNull(nulls.tokenKey)
        assertNull(nulls.scope)
        val nullTexts = ShowLocalNotificationParams(
            action("showLocalNotification", "title" to null, "body" to null, "payload" to null),
        )
        assertNull(nullTexts.title)
        assertNull(nullTexts.body)
        assertNull(nullTexts.payload)
        assertNull(SubscribeToTopicParams(action("subscribeToTopic", "topic" to null)).topic)
        assertNull(GetNotificationTokenParams(action("getNotificationToken", "tokenKey" to null, "scope" to null)).tokenKey)
    }

    /**
     * Flutter resolves title, body, payload and topic as values: one sent as a
     * Value, or as a non-string, reads null here and stays in the raw action
     * for the plugin to resolve.
     */
    @Test
    fun c17_5_aTextParamSentAsAValueReadsNull() {
        val name = mapOf("type" to "state", "key" to "name", "scope" to "app")
        val show = ShowLocalNotificationParams(
            action("showLocalNotification", "title" to name, "body" to name, "payload" to name),
        )
        assertNull(show.title)
        assertNull(show.body)
        assertNull(show.payload)
        assertEquals(JsonValue.of(name).toJsonElement(), show.action["title"])

        val topic = SubscribeToTopicParams(action("subscribeToTopic", "topic" to name))
        assertNull(topic.topic)
        assertEquals(JsonValue.of(name).toJsonElement(), topic.action["topic"])
        assertNull(UnsubscribeFromTopicParams(action("unsubscribeFromTopic", "topic" to name)).topic)

        val number = ShowLocalNotificationParams(action("showLocalNotification", "title" to 42))
        assertNull(number.title)
        assertEquals(JsonValue.of(42).toJsonElement(), number.action["title"])
    }
}
