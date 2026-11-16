package com.orcagateway.plugins.pushnotification

import android.content.Context
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.sdk.OrcaPlugin
import kotlinx.coroutines.CompletableDeferred
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject

/** The key the permission launcher is registered under in the activity's ActivityResultRegistry. */
private const val PERMISSION_KEY = "com.orcagateway.plugins.pushnotification.POST_NOTIFICATIONS"

/**
 * Push notifications for Orca pages: Flutter's `PushNotificationPlugin`
 * (plugins/orca_push_notification/lib/src/push_notification_plugin.dart, on
 * firebase_messaging 15.2.10 and flutter_local_notifications 18.0.1) one to
 * one. It has no widget; its five actions ask for the notification
 * permission, read the FCM token into state, show a local notification and
 * subscribe to topics.
 *
 * Call [initialize] in the host activity's onCreate (Flutter's static
 * initialize in main()): it makes the notification channel, registers the
 * permission request and hands a tapped notification's payload to the host.
 * The token and topics need the app's Firebase project (google-services.json
 * and the google-services Gradle plugin); without it those actions fail and
 * local notifications still work. Make one plugin per app; its actions run
 * on the main thread.
 */
public class PushNotificationPlugin internal constructor(
    private val notifications: Notifications,
    private val messaging: PushMessaging,
) : OrcaPlugin {
    /** Shows notifications through [context]'s NotificationManagerCompat and reads the token from FirebaseMessaging. */
    public constructor(context: Context) : this(DeviceNotifications(context), FirebasePushMessaging)

    override val name: String = "PushNotificationPlugin"

    override val actions: Map<String, OrcaActionHandler> = mapOf(
        "requestNotificationPermission" to OrcaActionHandler { action, executor -> requestNotificationPermission(action, executor) },
        "getNotificationToken" to OrcaActionHandler { action, executor -> getNotificationToken(action, executor) },
        "showLocalNotification" to OrcaActionHandler { action, executor -> showLocalNotification(action, executor) },
        "subscribeToTopic" to OrcaActionHandler { action, executor -> subscribeToTopic(action, executor) },
        "unsubscribeFromTopic" to OrcaActionHandler { action, executor -> unsubscribeFromTopic(action, executor) },
    )

    /**
     * Sets the plugin up on the host's [activity]; call it in onCreate, before
     * the activity starts (an ActivityResult registration must be). It makes
     * the "Notifications" channel, registers the POST_NOTIFICATIONS request
     * that requestNotificationPermission makes from API 33, and calls
     * [onNotificationTap] with the payload of a notification this plugin
     * showed ("" when it had none, as in Flutter) when a tap brings the
     * activity back (singleTop) with it. The
     * intent the activity was launched with is not read: a tap that starts
     * the app reaches nothing, as in Flutter. Call it again on a new
     * activity: the last one asks and hears the taps. The plugin lets go of
     * the activity's launcher when the activity is destroyed; until the next
     * initialize a request fails naming it, and an answer pending over a
     * configuration change reaches the new activity's launcher.
     */
    public fun initialize(activity: ComponentActivity, onNotificationTap: (String?) -> Unit) {
        notifications.createChannel()
        val launcher = activity.activityResultRegistry.register(
            PERMISSION_KEY,
            activity,
            ActivityResultContracts.RequestPermission(),
        ) { granted -> permissionAnswered(granted) }
        val ask: () -> Unit = { launcher.launch(POST_NOTIFICATIONS) }
        askPermission = ask
        activity.lifecycle.addObserver(
            object : DefaultLifecycleObserver {
                override fun onDestroy(owner: LifecycleOwner) {
                    if (askPermission === ask) askPermission = null
                }
            },
        )
        activity.addOnNewIntentListener { intent ->
            if (intent.action == ACTION_SELECT_NOTIFICATION) onNotificationTap(intent.getStringExtra(EXTRA_PAYLOAD))
        }
    }

    // MARK: The notification permission

    /** Asks the user for POST_NOTIFICATIONS through the launcher [initialize] registered. */
    internal var askPermission: (() -> Unit)? = null

    private var permissionAnswer: CompletableDeferred<Boolean>? = null

    /** The user's answer to the request [askPermission] made. */
    internal fun permissionAnswered(granted: Boolean) {
        val answer = permissionAnswer ?: return
        permissionAnswer = null
        answer.complete(granted)
    }

    /**
     * firebase_messaging_android's requestPermission (FlutterFirebaseMessagingPlugin.java
     * :358-409): from API 33 granted when POST_NOTIFICATIONS is held, else
     * asked for; below, the notification switch, nothing asked. Flutter always
     * has its activity; here the host gives it in [initialize], so asking
     * before it fails.
     */
    private suspend fun notificationsGranted(): Boolean {
        val ask = checkNotNull(askPermission) {
            "PushNotificationPlugin.initialize(activity, onNotificationTap) must be called in the activity's " +
                "onCreate before requestNotificationPermission"
        }
        val allowed = notifications.allowed()
        if (allowed || !notifications.permissionAsked) return allowed
        check(permissionAnswer == null) {
            "A request for permissions is already running, please wait for it to finish before doing another request."
        }
        val answer = CompletableDeferred<Boolean>()
        permissionAnswer = answer
        try {
            ask()
        } catch (failure: Throwable) {
            // Nothing was asked, so no answer comes: the next request may ask.
            permissionAnswer = null
            throw failure
        }
        return answer.await()
    }

    // MARK: The actions (Flutter :86-166)

    private suspend fun requestNotificationPermission(action: JsonObject, executor: ActionExecutor) {
        val granted = notificationsGranted()
        val params = RequestNotificationPermissionParams(action)
        val statusKey = action.cast("statusKey", params.statusKey)
        val tokenKey = action.cast("tokenKey", params.tokenKey)
        val scope = action.cast("scope", params.scope) ?: "app"

        if (statusKey != null) executor.setState(statusKey, JsonValue.String(if (granted) "granted" else "denied"), scope)
        if (granted && tokenKey != null) {
            messaging.token()?.let { executor.setState(tokenKey, JsonValue.String(it), scope) }
        }
    }

    private suspend fun getNotificationToken(action: JsonObject, executor: ActionExecutor) {
        val params = GetNotificationTokenParams(action)
        val tokenKey = action.cast("tokenKey", params.tokenKey) ?: "fcmToken"
        val scope = action.cast("scope", params.scope) ?: "app"

        val token = messaging.token()
        executor.setState(tokenKey, token?.let { JsonValue.String(it) } ?: JsonValue.Null, scope)
    }

    private fun showLocalNotification(action: JsonObject, executor: ActionExecutor) {
        val title = executor.resolveString(action["title"])
        val body = executor.resolveString(action["body"])
        val rawPayload = action["payload"]
        val payload = if (rawPayload == null || rawPayload is JsonNull) null else executor.resolveString(rawPayload)
        notifications.show((System.currentTimeMillis() / 1000).toInt(), title, body, payload)
    }

    private suspend fun subscribeToTopic(action: JsonObject, executor: ActionExecutor) {
        val topic = executor.resolveString(action["topic"])
        if (topic.isEmpty()) return
        messaging.subscribe(topic)
    }

    private suspend fun unsubscribeFromTopic(action: JsonObject, executor: ActionExecutor) {
        val topic = executor.resolveString(action["topic"])
        if (topic.isEmpty()) return
        messaging.unsubscribe(topic)
    }
}

/**
 * Flutter's `action[key] as String?`: the generated param's [read] (null when
 * the param is absent, null or not a string); a param that is there and not
 * a string fails the action, as the cast throws.
 */
private fun JsonObject.cast(key: String, read: String?): String? {
    val raw = this[key]
    require(read != null || raw == null || raw is JsonNull) { "$key is not a String: $raw" }
    return read
}

/** Flutter's `executor.resolveString(raw ?? '')`: the value resolved, as Dart text; '' for null. */
private fun ActionExecutor.resolveString(raw: JsonElement?): String {
    val value = JsonValue.fromJsonElement(resolve(raw ?: JsonNull))
    return if (value.isNull) "" else DartFormat.string(value)
}

/** Flutter's `executor.execute({'type': 'setState', ...})`: scope `app` writes app state, anything else page state. */
private suspend fun ActionExecutor.setState(key: String, value: JsonValue, scope: String) {
    execute(Action.SetState(key = key, scope = if (scope == "app") StateScope.App else StateScope.Page, value = value))
}
