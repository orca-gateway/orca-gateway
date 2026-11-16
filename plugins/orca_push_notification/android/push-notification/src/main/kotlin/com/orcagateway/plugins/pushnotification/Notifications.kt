package com.orcagateway.plugins.pushnotification

import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * The channel every notification goes to: Flutter's
 * `AndroidNotificationDetails('orca_default_channel', 'Notifications',
 * importance: Importance.high, priority: Priority.high)`.
 */
internal const val CHANNEL_ID = "orca_default_channel"
internal const val CHANNEL_NAME = "Notifications"

/**
 * The action of the intent a tap on the plugin's notification starts
 * (flutter_local_notifications' SELECT_NOTIFICATION), so the new-intent
 * listener knows it, and the extra its payload rides in. A tap intent is not
 * the launcher's: one equal to the task's root intent would only bring the
 * task forward, with no new intent.
 */
internal const val ACTION_SELECT_NOTIFICATION = "com.orcagateway.plugins.pushnotification.SELECT_NOTIFICATION"
internal const val EXTRA_PAYLOAD = "com.orcagateway.plugins.pushnotification.PAYLOAD"

/** Manifest.permission.POST_NOTIFICATIONS, a runtime permission from API 33 (TIRAMISU). */
internal const val POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"

/** What the plugin asks of the system's notifications. */
internal interface Notifications {
    /** From API 33, POST_NOTIFICATIONS is a runtime permission the app asks the user for; below, nothing is asked. */
    val permissionAsked: Boolean

    /**
     * Whether the app may post notifications, as firebase_messaging_android
     * reads it: POST_NOTIFICATIONS held from API 33, the app's notification
     * switch (NotificationManagerCompat.areNotificationsEnabled()) below.
     */
    fun allowed(): Boolean

    /** Makes the plugin's channel (a no-op below API 26, where channels do not exist). */
    fun createChannel()

    /**
     * Posts notification [id] with [title] and [body] on the plugin's channel; a
     * tap opens the app's launch activity with [payload] ("" for none).
     */
    fun show(id: Int, title: String?, body: String?, payload: String?)
}

/**
 * The system's notifications through NotificationManagerCompat, as
 * flutter_local_notifications 18.0.1 posts them: high importance (priority
 * high below API 26), the app's launcher icon as the small icon, cancelled
 * when tapped, and a tap that opens the app's launch activity (a
 * PendingIntent, FLAG_IMMUTABLE) carrying the payload. [sdkInt] is the
 * device's API level.
 */
internal class DeviceNotifications(
    context: Context,
    private val sdkInt: Int = Build.VERSION.SDK_INT,
) : Notifications {
    private val context = context.applicationContext
    private val manager = NotificationManagerCompat.from(this.context)

    override val permissionAsked: Boolean get() = sdkInt >= Build.VERSION_CODES.TIRAMISU

    override fun allowed(): Boolean =
        if (permissionAsked) {
            ContextCompat.checkSelfPermission(context, POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            manager.areNotificationsEnabled()
        }

    override fun createChannel() {
        manager.createNotificationChannel(
            NotificationChannelCompat.Builder(CHANNEL_ID, NotificationManagerCompat.IMPORTANCE_HIGH)
                .setName(CHANNEL_NAME)
                .build(),
        )
    }

    override fun show(id: Int, title: String?, body: String?, payload: String?) {
        // From API 33 the system drops a notification the app may not post: nothing to post. The
        // check sits here, next to notify, where lint's MissingPermission looks for it.
        if (permissionAsked && ContextCompat.checkSelfPermission(context, POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        // flutter_local_notifications makes the channel on show when it is missing, initialize or not.
        createChannel()
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
        tapIntent(id, payload)?.let { notification.setContentIntent(it) }
        manager.notify(id, notification.build())
    }

    /**
     * The app's launch activity with the tap's action and [payload] ("" for
     * none: flutter_local_notifications 18.0.1 shows with `'payload': payload
     * ?? ''`, platform_flutter_local_notifications.dart :331), as a
     * PendingIntent whose request code is the notification's id; none when
     * the app has no launch activity (the notification then opens nothing).
     */
    private fun tapIntent(id: Int, payload: String?): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        launch.action = ACTION_SELECT_NOTIFICATION
        launch.putExtra(EXTRA_PAYLOAD, payload ?: "")
        return PendingIntent.getActivity(context, id, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}
