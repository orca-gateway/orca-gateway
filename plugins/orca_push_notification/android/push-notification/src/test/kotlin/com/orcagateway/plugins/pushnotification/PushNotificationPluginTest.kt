package com.orcagateway.plugins.pushnotification

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Process
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import com.google.firebase.messaging.RemoteMessage
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.plugins.PluginMerger
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.core.state.ElmStore
import com.orcagateway.core.state.StoreState
import com.orcagateway.sdk.toParts
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** One notification the plugin asked to show. */
private data class Shown(val id: Int, val title: String?, val body: String?, val payload: String?)

/** The OS's notifications as the plugin sees them: the permission, the channel and what was shown. */
private class FakeNotifications : Notifications {
    override var permissionAsked: Boolean = true
    var allowed = false
    var channels = 0
    val shown = ArrayList<Shown>()

    override fun allowed(): Boolean = allowed

    override fun createChannel() {
        channels++
    }

    override fun show(id: Int, title: String?, body: String?, payload: String?) {
        shown += Shown(id, title, body, payload)
    }
}

/** Firebase Cloud Messaging as the plugin sees it: a token, topics, and a failure to throw. */
private class FakeMessaging : PushMessaging {
    var token: String? = "fcm-token-1"
    var failure: Exception? = null
    val calls = ArrayList<String>()

    override suspend fun token(): String? {
        calls += "token"
        failure?.let { throw it }
        return token
    }

    override suspend fun subscribe(topic: String) {
        calls += "subscribe $topic"
        failure?.let { throw it }
    }

    override suspend fun unsubscribe(topic: String) {
        calls += "unsubscribe $topic"
        failure?.let { throw it }
    }
}

/**
 * C17.4/K: the push plugin on Android does what Flutter's
 * plugins/orca_push_notification/lib/src/push_notification_plugin.dart does
 * (on firebase_messaging 15.2.10 and flutter_local_notifications 18.0.1):
 * the five actions with Flutter's params, defaults, raw or resolved reads and
 * state writes (scope "app"), the permission as firebase_messaging_android
 * asks for it (POST_NOTIFICATIONS from API 33, the notification switch below),
 * the local notification on the "orca_default_channel" channel with a tap
 * that brings its payload to the host's onNotificationTap, and a foreground
 * FCM message shown as a local notification. The plugin's own checks drive it
 * with fakes for the OS and Firebase; Robolectric checks the real channel,
 * notification, permission path, new-intent listener, service and merged
 * manifest.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PushNotificationPluginTest {
    private val notifications = FakeNotifications()
    private val messaging = FakeMessaging()
    private val plugin = PushNotificationPlugin(notifications, messaging)

    /** How many times the plugin asked for the permission, answered with [answer]. */
    private var asks = 0
    private var answer = true

    private val five = listOf(
        "requestNotificationPermission",
        "getNotificationToken",
        "showLocalNotification",
        "subscribeToTopic",
        "unsubscribeFromTopic",
    )

    private val app get() = RuntimeEnvironment.getApplication()
    private val manager get() = app.getSystemService(NotificationManager::class.java)

    private fun executor(page: Map<String, JsonValue> = emptyMap(), app: Map<String, JsonValue> = emptyMap()) =
        ActionExecutor(ElmStore(page = page, app = app))

    /** The plugin answering a permission request as a launcher would, as initialize sets it up. */
    private fun initialized() {
        plugin.askPermission = {
            asks++
            plugin.permissionAnswered(answer)
        }
    }

    /** Run the action `custom:<name>` with [params] as a page does: through the executor the plugin's handlers are registered on. */
    private fun run(executor: ActionExecutor, name: String, vararg params: Pair<String, Any?>, on: PushNotificationPlugin = plugin) =
        runBlocking {
            for ((type, handler) in on.actions) executor.registerHandler(type, handler)
            executor.execute(Action.Custom(JsonValue.obj("type" to "custom:$name", *params)))
        }

    /** Start the action without waiting for it: it suspends where the plugin waits for the user. */
    private fun start(executor: ActionExecutor, name: String, vararg params: Pair<String, Any?>, on: PushNotificationPlugin = plugin): Job {
        for ((type, handler) in on.actions) executor.registerHandler(type, handler)
        return CoroutineScope(Dispatchers.Unconfined).launch {
            executor.execute(Action.Custom(JsonValue.obj("type" to "custom:$name", *params)))
        }
    }

    private fun appState(key: String) = mapOf("type" to "state", "key" to key, "scope" to "app")

    private fun pageState(key: String) = mapOf("type" to "state", "key" to key, "scope" to "page")

    private fun string(value: String) = JsonValue.String(value)

    /** The app's launch activity, for the PendingIntent a notification carries. */
    private fun launchActivity(): ComponentName {
        val launcher = ComponentName(app, ComponentActivity::class.java)
        val packages = shadowOf(app.packageManager)
        packages.addActivityIfNotPresent(launcher)
        packages.addIntentFilterForActivity(
            launcher,
            IntentFilter(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_LAUNCHER) },
        )
        return launcher
    }

    // MARK: The plugin

    @Test
    fun c17_4_thePluginHasFluttersNameNoWidgetFiveActionsInOrderAndNoTrigger() {
        assertEquals("PushNotificationPlugin", plugin.name)
        assertTrue(plugin.widgets.isEmpty())
        assertEquals(five, plugin.actions.keys.toList())
        assertTrue(plugin.triggers.isEmpty())

        val merged = PluginMerger.merge(builtInWidgets = WidgetRegistry.shared.types, plugins = listOf(plugin.toParts()))
        assertEquals(emptySet(), merged.pluginWidgetTypes)
        assertEquals(five.toSet(), merged.pluginActionTypes)
    }

    // MARK: requestNotificationPermission (Flutter :86-113)

    @Test
    fun c17_4_aHeldPermissionIsGrantedWithNothingAskedAndTheTokenWrittenInAppState() {
        initialized()
        notifications.allowed = true
        val executor = executor()
        run(executor, "requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to "pushToken")

        assertEquals(0, asks)
        assertEquals(StoreState(app = mapOf("pushStatus" to string("granted"), "pushToken" to string("fcm-token-1"))), executor.store.state)
        assertEquals(listOf("token"), messaging.calls)
    }

    @Test
    fun c17_4_fromApi33ThePermissionIsAskedAndTheAnswerWritten() {
        initialized()
        val granted = executor()
        run(granted, "requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to "pushToken", "scope" to "page")
        assertEquals(1, asks)
        assertEquals(StoreState(page = mapOf("pushStatus" to string("granted"), "pushToken" to string("fcm-token-1"))), granted.store.state)

        answer = false
        val denied = executor()
        run(denied, "requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to "pushToken")
        assertEquals(2, asks)
        assertEquals(StoreState(app = mapOf("pushStatus" to string("denied"))), denied.store.state)
        // Denied: no token asked for.
        assertEquals(listOf("token"), messaging.calls)
    }

    /** firebase_messaging_android's FlutterFirebasePermissionManager: one request at a time. */
    @Test
    fun c17_4_aSecondRequestWhileTheUserIsAskedFailsTheAction() {
        plugin.askPermission = { asks++ }
        val first = executor()
        val asking = start(first, "requestNotificationPermission", "statusKey" to "pushStatus")
        assertEquals(1, asks)
        assertFalse(asking.isCompleted)

        val second = executor()
        val failure = assertFailsWith<IllegalStateException> { run(second, "requestNotificationPermission", "statusKey" to "pushStatus") }
        assertTrue("already running" in failure.message.orEmpty(), failure.message)
        assertEquals(1, asks)

        plugin.permissionAnswered(true)
        assertTrue(asking.isCompleted)
        assertEquals(StoreState(app = mapOf("pushStatus" to string("granted"))), first.store.state)
        assertEquals(StoreState(), second.store.state)
    }

    /** A launch that throws (an unregistered launcher, any reason) asked nothing: the next request is free to ask. */
    @Test
    fun c17_4_aRequestWhoseLaunchFailsLeavesTheNextRequestFreeToAsk() {
        plugin.askPermission = {
            asks++
            error("Attempting to launch an unregistered ActivityResultLauncher")
        }
        val failed = executor()
        val failure = assertFailsWith<IllegalStateException> { run(failed, "requestNotificationPermission", "statusKey" to "pushStatus") }
        assertTrue("unregistered" in failure.message.orEmpty(), failure.message)
        assertEquals(StoreState(), failed.store.state)

        initialized()
        val next = executor()
        run(next, "requestNotificationPermission", "statusKey" to "pushStatus")
        assertEquals(2, asks)
        assertEquals(StoreState(app = mapOf("pushStatus" to string("granted"))), next.store.state)
    }

    /** firebase_messaging_android below 33: granted is the notification switch, nothing asked. */
    @Test
    fun c17_4_belowApi33TheSwitchDecidesAndNothingIsAsked() {
        initialized()
        notifications.permissionAsked = false
        val off = executor()
        run(off, "requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to "pushToken")
        assertEquals(StoreState(app = mapOf("pushStatus" to string("denied"))), off.store.state)

        notifications.allowed = true
        val on = executor()
        run(on, "requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to "pushToken")
        assertEquals(StoreState(app = mapOf("pushStatus" to string("granted"), "pushToken" to string("fcm-token-1"))), on.store.state)
        assertEquals(0, asks)
    }

    @Test
    fun c17_4_withoutKeysOrTokenThePermissionIsAskedAndLessIsWritten() {
        initialized()
        val none = executor()
        run(none, "requestNotificationPermission")
        assertEquals(1, asks)
        assertEquals(StoreState(), none.store.state)
        assertEquals(emptyList(), messaging.calls)

        // A null token writes nothing into tokenKey.
        messaging.token = null
        val noToken = executor()
        run(noToken, "requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to "pushToken")
        assertEquals(StoreState(app = mapOf("pushStatus" to string("granted"))), noToken.store.state)
        assertEquals(listOf("token"), messaging.calls)
    }

    /** Flutter always has its activity; here the host hands it over in initialize, so asking before it fails. */
    @Test
    fun c17_4_askingBeforeInitializeFailsTheActionNamingInitialize() {
        // Held, so only the missing initialize fails it.
        notifications.allowed = true
        val executor = executor()
        val failure = assertFailsWith<IllegalStateException> {
            run(executor, "requestNotificationPermission", "statusKey" to "pushStatus")
        }
        assertTrue("initialize" in failure.message.orEmpty(), failure.message)
        notifications.permissionAsked = false
        assertFailsWith<IllegalStateException> { run(executor, "requestNotificationPermission", "statusKey" to "pushStatus") }
        assertEquals(StoreState(), executor.store.state)
    }

    @Test
    fun c17_4_aTokenErrorFailsThePermissionActionAfterTheStatusIsWritten() {
        initialized()
        notifications.allowed = true
        messaging.failure = IllegalStateException("Default FirebaseApp is not initialized in this process")
        val executor = executor()
        assertFailsWith<IllegalStateException> {
            run(executor, "requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to "pushToken")
        }
        assertEquals(StoreState(app = mapOf("pushStatus" to string("granted"))), executor.store.state)
    }

    /** Flutter's `action['statusKey'] as String?` and its kin: raw reads, a non-string (a Value object too) fails the action. */
    @Test
    fun c17_4_aRawKeyOrScopeThatIsNotAStringFailsTheAction() {
        initialized()
        notifications.allowed = true
        val executor = executor()
        assertFailsWith<IllegalArgumentException> { run(executor, "requestNotificationPermission", "statusKey" to 1) }
        assertFailsWith<IllegalArgumentException> { run(executor, "requestNotificationPermission", "tokenKey" to true) }
        assertFailsWith<IllegalArgumentException> { run(executor, "requestNotificationPermission", "statusKey" to "s", "scope" to 2) }
        assertFailsWith<IllegalArgumentException> {
            run(executor, "requestNotificationPermission", "statusKey" to appState("key"))
        }
        assertFailsWith<IllegalArgumentException> { run(executor, "getNotificationToken", "tokenKey" to 5) }
        assertFailsWith<IllegalArgumentException> { run(executor, "getNotificationToken", "scope" to pageState("scope")) }
        assertEquals(StoreState(), executor.store.state)
        // getNotificationToken casts before it asks for the token, as Flutter.
        assertEquals(emptyList(), messaging.calls)
        // A JSON null reads as absent.
        run(executor, "requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to null, "scope" to null)
        assertEquals(StoreState(app = mapOf("pushStatus" to string("granted"))), executor.store.state)
    }

    // MARK: getNotificationToken (Flutter :115-127)

    @Test
    fun c17_4_getNotificationTokenWritesTheTokenOrNullIntoFcmTokenInAppState() {
        val defaults = executor()
        run(defaults, "getNotificationToken")
        assertEquals(StoreState(app = mapOf("fcmToken" to string("fcm-token-1"))), defaults.store.state)

        val page = executor()
        run(page, "getNotificationToken", "tokenKey" to "pushToken", "scope" to "page")
        assertEquals(StoreState(page = mapOf("pushToken" to string("fcm-token-1"))), page.store.state)

        messaging.token = null
        val none = executor(app = mapOf("fcmToken" to string("old")))
        run(none, "getNotificationToken")
        assertEquals(StoreState(app = mapOf("fcmToken" to JsonValue.Null)), none.store.state)
    }

    @Test
    fun c17_4_aMessagingErrorFailsTheTokenAndTopicActions() {
        messaging.failure = IllegalStateException("Default FirebaseApp is not initialized in this process")
        val executor = executor()
        assertFailsWith<IllegalStateException> { run(executor, "getNotificationToken") }
        assertFailsWith<IllegalStateException> { run(executor, "subscribeToTopic", "topic" to "news") }
        assertFailsWith<IllegalStateException> { run(executor, "unsubscribeFromTopic", "topic" to "news") }
        assertEquals(StoreState(), executor.store.state)
    }

    /** The plugin a host makes from its Context, with no Firebase app set up (no google-services.json): the token and topics fail. */
    @Test
    fun c17_4_withoutFirebaseTheDevicePluginsTokenAndTopicsFail() {
        val device = PushNotificationPlugin(app)
        val executor = executor()
        assertFailsWith<IllegalStateException> { run(executor, "getNotificationToken", on = device) }
        assertFailsWith<IllegalStateException> { run(executor, "subscribeToTopic", "topic" to "news", on = device) }
        assertFailsWith<IllegalStateException> { run(executor, "unsubscribeFromTopic", "topic" to "news", on = device) }
        assertEquals(StoreState(), executor.store.state)
    }

    // MARK: showLocalNotification (Flutter :129-152)

    @Test
    fun c17_4_showLocalNotificationShowsTheTitleBodyAndPayloadWithTheTimeInSecondsAsItsId() {
        val before = (System.currentTimeMillis() / 1000).toInt()
        run(executor(), "showLocalNotification", "title" to "Orca push", "body" to "Tap to open the map", "payload" to "orcacounter://open/map")
        val after = (System.currentTimeMillis() / 1000).toInt()

        val shown = notifications.shown.single()
        assertTrue(shown.id in before..after, "id ${shown.id} not in $before..$after")
        assertEquals(Shown(shown.id, "Orca push", "Tap to open the map", "orcacounter://open/map"), shown)
    }

    @Test
    fun c17_4_showLocalNotificationResolvesItsTextsAsValuesWithFluttersDefaults() {
        val executor = executor(
            page = mapOf("body" to string("from the page")),
            app = mapOf("title" to string("from the app"), "link" to string("orcacounter://open/push"), "count" to JsonValue.Int(3)),
        )
        run(executor, "showLocalNotification", "title" to appState("title"), "body" to pageState("body"), "payload" to appState("link"))
        // Absent title and body are "", an absent or null payload is none.
        run(executor, "showLocalNotification")
        run(executor, "showLocalNotification", "payload" to null)
        // A payload whose value resolves to null is "", as Flutter's resolveString; a number reads as Dart prints it.
        run(executor, "showLocalNotification", "title" to appState("count"), "body" to 42, "payload" to appState("missing"))

        assertEquals(
            listOf(
                Triple("from the app", "from the page", "orcacounter://open/push"),
                Triple("", "", null),
                Triple("", "", null),
                Triple("3", "42", ""),
            ),
            notifications.shown.map { Triple(it.title, it.body, it.payload) },
        )
    }

    // MARK: subscribeToTopic, unsubscribeFromTopic (Flutter :154-166)

    @Test
    fun c17_4_topicsAreResolvedAndAnEmptyTopicDoesNothing() {
        val executor = executor(app = mapOf("topic" to string("sports"), "blank" to string("")))
        run(executor, "subscribeToTopic", "topic" to "news")
        run(executor, "unsubscribeFromTopic", "topic" to "news")
        run(executor, "subscribeToTopic", "topic" to appState("topic"))
        run(executor, "unsubscribeFromTopic", "topic" to appState("topic"))
        run(executor, "subscribeToTopic", "topic" to "")
        run(executor, "unsubscribeFromTopic")
        run(executor, "subscribeToTopic", "topic" to appState("blank"))
        run(executor, "unsubscribeFromTopic", "topic" to appState("missing"))

        assertEquals(listOf("subscribe news", "unsubscribe news", "subscribe sports", "unsubscribe sports"), messaging.calls)
    }

    // MARK: Robolectric: the real channel, notification, permission, tap and service

    @Test
    fun c17_4_theMergedManifestDeclaresPostNotificationsAndTheMessagingService() {
        val packages = app.packageManager
        val info = packages.getPackageInfo(app.packageName, PackageManager.GET_PERMISSIONS or PackageManager.GET_SERVICES)
        assertTrue(Manifest.permission.POST_NOTIFICATIONS in info.requestedPermissions.orEmpty())

        val service = assertNotNull(info.services?.singleOrNull { it.name == PushMessagingService::class.java.name })
        assertFalse(service.exported)
        // Firebase's own service has the MESSAGING_EVENT filter at priority -500: the plugin's is the one FCM starts.
        val resolved = packages.resolveService(Intent("com.google.firebase.MESSAGING_EVENT").setPackage(app.packageName), 0)
        assertEquals(PushMessagingService::class.java.name, resolved?.serviceInfo?.name)
    }

    @Test
    fun c17_4_initializeMakesTheChannelNotificationsAtHighImportance() {
        val device = PushNotificationPlugin(DeviceNotifications(app), messaging)
        assertNull(manager.getNotificationChannel("orca_default_channel"))
        Robolectric.buildActivity(ComponentActivity::class.java).use { controller ->
            device.initialize(controller.create().get()) {}
        }
        val channel = assertNotNull(manager.getNotificationChannel("orca_default_channel"))
        assertEquals("Notifications", channel.name)
        assertEquals(NotificationManager.IMPORTANCE_HIGH, channel.importance)
    }

    @Test
    fun c17_4_theRealNotificationIsOnTheChannelWithTheLauncherIconAndATapToTheLaunchActivity() {
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        app.applicationInfo.icon = android.R.drawable.sym_def_app_icon
        val launcher = launchActivity()
        val device = PushNotificationPlugin(DeviceNotifications(app), messaging)

        run(
            executor(), "showLocalNotification",
            "title" to "Orca push", "body" to "Tap to open the map", "payload" to "orcacounter://open/map",
            on = device,
        )

        val posted = manager.activeNotifications.single()
        val notification = posted.notification
        assertEquals("orca_default_channel", notification.channelId)
        assertEquals("Orca push", notification.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString())
        assertEquals("Tap to open the map", notification.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString())
        assertEquals(android.R.drawable.sym_def_app_icon, notification.smallIcon.resId)
        assertTrue(notification.flags and Notification.FLAG_AUTO_CANCEL != 0)
        // Made on show too, as flutter_local_notifications does: no initialize here.
        assertEquals(NotificationManager.IMPORTANCE_HIGH, manager.getNotificationChannel("orca_default_channel")?.importance)

        val tap = shadowOf(notification.contentIntent)
        assertTrue(tap.isActivity)
        assertTrue(tap.isImmutable)
        assertEquals(posted.id, tap.requestCode)
        assertEquals(launcher, tap.savedIntent.component)
        assertEquals("orcacounter://open/map", tap.savedIntent.getStringExtra(EXTRA_PAYLOAD))
        assertEquals(ACTION_SELECT_NOTIFICATION, tap.savedIntent.action)
    }

    /** With no POST_NOTIFICATIONS on 33+ the system drops what the app posts; the plugin posts nothing. */
    @Test
    fun c17_4_withoutThePermissionTheRealNotificationIsNotPosted() {
        launchActivity()
        run(executor(), "showLocalNotification", "title" to "Orca push", on = PushNotificationPlugin(DeviceNotifications(app), messaging))
        assertEquals(0, manager.activeNotifications.size)
    }

    @Test
    fun c17_4_fromApi33TheRealPathAsksForPostNotificationsUnlessHeld() {
        val device = PushNotificationPlugin(DeviceNotifications(app), messaging)
        Robolectric.buildActivity(ComponentActivity::class.java).use { controller ->
            val activity = controller.create().get()
            device.initialize(activity) {}
            controller.start().resume()

            val granted = executor()
            val asking = start(granted, "requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to "pushToken", on = device)
            val request = assertNotNull(shadowOf(activity).lastRequestedPermission)
            assertEquals(listOf(Manifest.permission.POST_NOTIFICATIONS), request.requestedPermissions.toList())
            assertFalse(asking.isCompleted)
            answerPermission(activity, request.requestCode, PackageManager.PERMISSION_GRANTED)
            assertTrue(asking.isCompleted)
            assertEquals(StoreState(app = mapOf("pushStatus" to string("granted"), "pushToken" to string("fcm-token-1"))), granted.store.state)

            val denied = executor()
            val again = start(denied, "requestNotificationPermission", "statusKey" to "pushStatus", "tokenKey" to "pushToken", on = device)
            val second = assertNotNull(shadowOf(activity).lastRequestedPermission)
            answerPermission(activity, second.requestCode, PackageManager.PERMISSION_DENIED)
            assertTrue(again.isCompleted)
            assertEquals(StoreState(app = mapOf("pushStatus" to string("denied"))), denied.store.state)

            // Held: granted with nothing asked.
            shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
            val held = executor()
            run(held, "requestNotificationPermission", "statusKey" to "pushStatus", on = device)
            assertTrue(shadowOf(activity).lastRequestedPermission === second)
            assertEquals(StoreState(app = mapOf("pushStatus" to string("granted"))), held.store.state)
        }
    }

    /** The destroyed activity's launcher is let go: a request in the gap fails naming initialize, and the next initialize asks. */
    @Test
    fun c17_4_onceTheActivityIsDestroyedARequestFailsNamingInitializeUntilTheNextInitialize() {
        val device = PushNotificationPlugin(DeviceNotifications(app), messaging)
        Robolectric.buildActivity(ComponentActivity::class.java).use { controller ->
            val destroyed = controller.create().get()
            device.initialize(destroyed) {}
            controller.start().resume().pause().stop().destroy()

            val gap = executor()
            val failure = assertFailsWith<IllegalStateException> {
                run(gap, "requestNotificationPermission", "statusKey" to "pushStatus", on = device)
            }
            assertTrue("initialize" in failure.message.orEmpty(), failure.message)
            assertNull(shadowOf(destroyed).lastRequestedPermission)
            assertEquals(StoreState(), gap.store.state)
        }

        Robolectric.buildActivity(ComponentActivity::class.java).use { controller ->
            val activity = controller.create().get()
            device.initialize(activity) {}
            controller.start().resume()
            val next = executor()
            val asking = start(next, "requestNotificationPermission", "statusKey" to "pushStatus", on = device)
            val request = assertNotNull(shadowOf(activity).lastRequestedPermission)
            answerPermission(activity, request.requestCode, PackageManager.PERMISSION_GRANTED)
            assertTrue(asking.isCompleted)
            assertEquals(StoreState(app = mapOf("pushStatus" to string("granted"))), next.store.state)
        }
    }

    /** An older activity destroyed after the next initialize leaves the newer one's launcher in place. */
    @Test
    fun c17_4_anOlderActivityDestroyedAfterTheNextInitializeLeavesTheNewerOneAsking() {
        val device = PushNotificationPlugin(DeviceNotifications(app), messaging)
        Robolectric.buildActivity(ComponentActivity::class.java).use { older ->
            device.initialize(older.create().get()) {}
            older.start().resume()
            Robolectric.buildActivity(ComponentActivity::class.java).use { newer ->
                val activity = newer.create().get()
                device.initialize(activity) {}
                newer.start().resume()
                older.pause().stop().destroy()

                val executor = executor()
                val asking = start(executor, "requestNotificationPermission", "statusKey" to "pushStatus", on = device)
                val request = assertNotNull(shadowOf(activity).lastRequestedPermission)
                answerPermission(activity, request.requestCode, PackageManager.PERMISSION_DENIED)
                assertTrue(asking.isCompleted)
                assertEquals(StoreState(app = mapOf("pushStatus" to string("denied"))), executor.store.state)
            }
        }
    }

    /** What ComponentActivity's onRequestPermissionsResult hands its registry. */
    private fun answerPermission(activity: ComponentActivity, requestCode: Int, result: Int) {
        activity.activityResultRegistry.dispatchResult(
            requestCode,
            Activity.RESULT_OK,
            Intent()
                .putExtra(ActivityResultContracts.RequestMultiplePermissions.EXTRA_PERMISSIONS, arrayOf(Manifest.permission.POST_NOTIFICATIONS))
                .putExtra(ActivityResultContracts.RequestMultiplePermissions.EXTRA_PERMISSION_GRANT_RESULTS, intArrayOf(result)),
        )
    }

    @Test
    fun c17_4_belowApi33TheRealPathReadsTheNotificationSwitchAndAsksNothing() {
        val below = DeviceNotifications(app, sdkInt = 32)
        assertFalse(below.permissionAsked)
        shadowOf(manager).setNotificationsEnabled(false)
        assertFalse(below.allowed())
        shadowOf(manager).setNotificationsEnabled(true)
        // POST_NOTIFICATIONS is not held, and not read below 33.
        assertTrue(below.allowed())

        val at34 = DeviceNotifications(app)
        assertTrue(at34.permissionAsked)
        assertFalse(at34.allowed())
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        assertTrue(at34.allowed())

        shadowOf(manager).setNotificationsEnabled(false)
        val device = PushNotificationPlugin(below, messaging)
        Robolectric.buildActivity(ComponentActivity::class.java).use { controller ->
            val activity = controller.create().get()
            device.initialize(activity) {}
            controller.start().resume()
            val executor = executor()
            run(executor, "requestNotificationPermission", "statusKey" to "pushStatus", on = device)
            assertNull(shadowOf(activity).lastRequestedPermission)
            assertEquals(StoreState(app = mapOf("pushStatus" to string("denied"))), executor.store.state)
        }
    }

    @Test
    fun c17_4_aTapOnThePluginsNotificationBringsItsPayloadToOnNotificationTap() {
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        launchActivity()
        val device = PushNotificationPlugin(DeviceNotifications(app), messaging)
        val taps = ArrayList<String?>()
        // Started from a tap (a cold start): the launch intent is not read, as in Flutter.
        val coldStart = Intent(ACTION_SELECT_NOTIFICATION).putExtra(EXTRA_PAYLOAD, "orcacounter://open/cold")
        Robolectric.buildActivity(ComponentActivity::class.java, coldStart).use { controller ->
            device.initialize(controller.create().get()) { taps += it }
            controller.start().resume()
            assertEquals(emptyList(), taps)

            run(executor(), "showLocalNotification", "title" to "Orca push", "payload" to "orcacounter://open/map", on = device)
            controller.newIntent(shadowOf(manager.activeNotifications.single().notification.contentIntent).savedIntent)
            assertEquals(listOf<String?>("orcacounter://open/map"), taps)

            // An intent the plugin did not make reaches nothing.
            controller.newIntent(Intent(Intent.ACTION_VIEW, Uri.parse("orcacounter://open/map")))
            controller.newIntent(Intent(Intent.ACTION_MAIN).putExtra(EXTRA_PAYLOAD, "orcacounter://open/other"))
            assertEquals(listOf<String?>("orcacounter://open/map"), taps)

            // No payload: the tap reaches the host with "", as flutter_local_notifications 18.0.1 shows with
            // `'payload': payload ?? ''` (platform_flutter_local_notifications.dart :331).
            run(executor(), "showLocalNotification", "title" to "No payload", on = device)
            controller.newIntent(shadowOf(manager.activeNotifications.single().notification.contentIntent).savedIntent)
            assertEquals(listOf<String?>("orcacounter://open/map", ""), taps)
        }
    }

    /** Flutter's onMessage listener: a message with a notification, while the app is in the foreground. */
    @Test
    fun c17_4_aForegroundMessageWithANotificationIsShownWithItsDataAsAJsonPayload() {
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        launchActivity()
        val service = Robolectric.buildService(PushMessagingService::class.java).create().get()
        val message = RemoteMessage(
            Bundle().apply {
                putString("gcm.n.e", "1")
                putString("gcm.n.title", "Orca")
                putString("gcm.n.body", "Hello")
                putString("route", "/map")
                putString("id", "7")
            },
        )
        val dataOnly = RemoteMessage(Bundle().apply { putString("route", "/map") })

        processImportance(ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED)
        service.onMessageReceived(message)
        assertEquals(0, manager.activeNotifications.size)

        processImportance(ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND)
        shadowOf(app.getSystemService(KeyguardManager::class.java)).setKeyguardLocked(true)
        service.onMessageReceived(message)
        assertEquals(0, manager.activeNotifications.size)

        shadowOf(app.getSystemService(KeyguardManager::class.java)).setKeyguardLocked(false)
        service.onMessageReceived(dataOnly)
        assertEquals(0, manager.activeNotifications.size)

        service.onMessageReceived(message)
        val notification = manager.activeNotifications.single().notification
        assertEquals("orca_default_channel", notification.channelId)
        assertEquals("Orca", notification.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString())
        assertEquals("Hello", notification.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString())
        val payload = assertNotNull(shadowOf(notification.contentIntent).savedIntent.getStringExtra(EXTRA_PAYLOAD))
        assertEquals(JsonObject(mapOf("route" to JsonPrimitive("/map"), "id" to JsonPrimitive("7"))), Json.parseToJsonElement(payload).jsonObject)
    }

    private fun processImportance(importance: Int) {
        val process = ActivityManager.RunningAppProcessInfo(app.packageName, Process.myPid(), arrayOf(app.packageName))
        process.importance = importance
        shadowOf(app.getSystemService(ActivityManager::class.java)).setProcesses(listOf(process))
    }
}
