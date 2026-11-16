package com.orcagateway.plugins.pushnotification

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.Context
import com.google.android.gms.tasks.Task
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** What the plugin asks of Firebase Cloud Messaging. */
internal interface PushMessaging {
    /** The FCM registration token, null when there is none; throws when Firebase is not set up. */
    suspend fun token(): String?

    suspend fun subscribe(topic: String)

    suspend fun unsubscribe(topic: String)
}

/**
 * FirebaseMessaging's default instance, looked up on each call, so a plugin
 * made without Firebase set up (no google-services.json) fails only the
 * token and topic actions, as firebase_messaging throws without
 * Firebase.initializeApp.
 */
internal object FirebasePushMessaging : PushMessaging {
    override suspend fun token(): String? = FirebaseMessaging.getInstance().token.await()

    override suspend fun subscribe(topic: String) {
        FirebaseMessaging.getInstance().subscribeToTopic(topic).await()
    }

    override suspend fun unsubscribe(topic: String) {
        FirebaseMessaging.getInstance().unsubscribeFromTopic(topic).await()
    }
}

/** The task's result once it completes; its failure, or a cancelled task, throws. */
private suspend fun <T> Task<T>.await(): T? = suspendCancellableCoroutine { continuation ->
    addOnCompleteListener({ it.run() }) { task ->
        if (task.isSuccessful) {
            continuation.resume(task.result)
        } else {
            continuation.resumeWithException(task.exception ?: IllegalStateException("$task was cancelled"))
        }
    }
}

/**
 * Flutter's onMessage listener (PushNotificationPlugin.initialize): a
 * message with a notification that arrives while the app is in the
 * foreground is shown as a local notification on the plugin's channel, its
 * data as a JSON payload. In the background the system shows notification
 * messages itself, as in Flutter. Merged into the app by this library's
 * manifest; its MESSAGING_EVENT filter outranks Firebase's own service.
 */
internal class PushMessagingService : FirebaseMessagingService() {
    /**
     * A new token is not followed, as in Flutter (its plugin never listens to
     * onTokenRefresh): a page reads the current one with getNotificationToken.
     */
    override fun onNewToken(token: String) {}

    override fun onMessageReceived(message: RemoteMessage) {
        val notification = message.notification ?: return
        if (!isApplicationForeground(this)) return
        val data = JsonObject(message.data.mapValues { JsonPrimitive(it.value) })
        // Flutter's id is the notification's hashCode, as here.
        DeviceNotifications(this).show(notification.hashCode(), notification.title, notification.body, data.toString())
    }
}

/**
 * firebase_messaging's own test (FlutterFirebaseMessagingUtils.isApplicationForeground,
 * :174-199): not behind the lock screen, and the app's process at
 * foreground importance.
 */
internal fun isApplicationForeground(context: Context): Boolean {
    if (context.getSystemService(KeyguardManager::class.java)?.isKeyguardLocked == true) return false
    val processes = context.getSystemService(ActivityManager::class.java)?.runningAppProcesses ?: return false
    return processes.any {
        it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND && it.processName == context.packageName
    }
}
