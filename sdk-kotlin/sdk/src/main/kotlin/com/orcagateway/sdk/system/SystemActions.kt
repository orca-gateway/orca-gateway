package com.orcagateway.sdk.system

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import androidx.core.net.toUri
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.OrcaUrlPolicy
import java.net.URI

/**
 * What `openUrl`, `copyToClipboard` and `share` do on the device. [android]
 * uses the system (a view intent, the clipboard, the share chooser); tests
 * and hosts swap in their own. The Android side of Swift's `SystemActions`.
 */
public class SystemActions(
    public val open: (URI) -> Unit,
    public val copy: (String) -> Unit,
    /** The text to share and an optional subject (used by mail targets). */
    public val share: (String, String?) -> Unit,
    public val urlPolicy: OrcaUrlPolicy = OrcaUrlPolicy.standard,
) {
    /** Perform one of the three system effects; false for any other effect. */
    public fun perform(effect: ActionEffect): Boolean {
        when (effect.type) {
            // Flutter reports the effect, then launches only what the policy
            // allows; a blocked scheme is dropped silently.
            "openUrl" -> urlPolicy.url(effect.payload["url"]?.stringValue ?: "")?.let(open)
            "copyToClipboard" -> copy(effect.payload["text"]?.stringValue ?: "")
            "share" -> share(effect.payload["text"]?.stringValue ?: "", effect.payload["subject"]?.stringValue)
            else -> return false
        }
        return true
    }

    public companion object {
        /**
         * The device's own handlers: a view intent for the URL, the system
         * clipboard, and the share chooser over a plain-text send intent.
         * From a context that is not an activity the intents start a new
         * task. A URL nothing on the device can open is dropped.
         */
        public fun android(context: Context, urlPolicy: OrcaUrlPolicy = OrcaUrlPolicy.standard): SystemActions =
            SystemActions(
                open = { url -> context.startQuietly(Intent(Intent.ACTION_VIEW, url.toString().toUri())) },
                copy = { text ->
                    context.getSystemService(ClipboardManager::class.java)
                        ?.setPrimaryClip(ClipData.newPlainText("text", text))
                },
                share = { text, subject ->
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
                    if (subject != null) send.putExtra(Intent.EXTRA_SUBJECT, subject)
                    context.startQuietly(Intent.createChooser(send, null))
                },
                urlPolicy = urlPolicy,
            )

        private fun Context.startQuietly(intent: Intent) {
            if (this !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(intent)
            } catch (_: ActivityNotFoundException) {
                // Nothing installed handles it.
            }
        }
    }
}
