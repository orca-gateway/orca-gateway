package com.orcagateway.sdk.system

import android.app.Application
import android.content.ClipboardManager
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.core.state.OrcaUrlPolicy
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import java.net.URI
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** The three effects as recording lambdas see them (Swift's SystemRecorder). */
private class SystemRecorder {
    val opened = mutableListOf<URI>()
    val copied = mutableListOf<String>()
    val shared = mutableListOf<List<String?>>()

    fun actions(policy: OrcaUrlPolicy = OrcaUrlPolicy.standard): SystemActions = SystemActions(
        open = { opened += it },
        copy = { copied += it },
        share = { text, subject -> shared.add(listOf(text, subject)) },
        urlPolicy = policy,
    )
}

private fun effect(type: String, vararg payload: Pair<String, String>): ActionEffect =
    ActionEffect(type, payload.associate { (key, value) -> key to JsonValue.String(value) })

/**
 * T6.4.2: openUrl through the URL policy, the clipboard and the share chooser,
 * first with recording lambdas, then the Android handlers under Robolectric
 * (the started intents, the clipboard text). Swift's RouterTests cases.
 */
@RunWith(RobolectricTestRunner::class)
class SystemActionsTest {
    private val application: Application get() = ApplicationProvider.getApplicationContext()

    @Test
    fun y1_openUrlFollowsThePolicy() {
        val recorder = SystemRecorder()
        val actions = recorder.actions()
        for (url in listOf(
            "https://orca.example/docs", "mailto:hi@orca.example", "javascript:alert(1)",
            "tel:123", "file:///etc/hosts", "not a url",
        )) {
            assertTrue(actions.perform(effect("openUrl", "url" to url)), "blocked URLs are still handled: $url")
        }
        assertEquals(listOf("https://orca.example/docs", "mailto:hi@orca.example"), recorder.opened.map { it.toString() })

        val tel = SystemRecorder()
        assertTrue(tel.actions(OrcaUrlPolicy(extraSchemes = setOf("TEL"))).perform(effect("openUrl", "url" to "tel:123")))
        assertEquals(listOf("tel:123"), tel.opened.map { it.toString() })
    }

    @Test
    fun y2_clipboardAndShare() {
        val recorder = SystemRecorder()
        val actions = recorder.actions()
        // The payloads ActionExecutor emits: share's title/message arrive as subject/text.
        assertTrue(actions.perform(effect("copyToClipboard", "text" to "ORCA-42")))
        assertTrue(actions.perform(effect("share", "text" to "Look", "subject" to "Orca")))
        assertTrue(actions.perform(effect("share", "text" to "Plain")))
        assertEquals(listOf("ORCA-42"), recorder.copied)
        assertEquals(listOf(listOf("Look", "Orca"), listOf("Plain", null)), recorder.shared)
        assertFalse(recorder.actions().perform(effect("navigate", "route" to "x")))
    }

    @Test
    fun y1_androidOpensAViewIntent() {
        val shadow = shadowOf(application)
        val actions = SystemActions.android(application)

        assertTrue(actions.perform(effect("openUrl", "url" to "https://orca.example/docs")))
        val view = assertNotNull(shadow.nextStartedActivity)
        assertEquals(Intent.ACTION_VIEW, view.action)
        assertEquals("https://orca.example/docs", view.dataString)
        assertTrue(view.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0, "an application context starts a new task")

        assertTrue(actions.perform(effect("openUrl", "url" to "javascript:alert(1)")))
        assertNull(shadow.nextStartedActivity, "a blocked scheme starts nothing")

        // Nothing installed to handle the scheme: dropped, not thrown.
        shadow.checkActivities(true)
        assertTrue(actions.perform(effect("openUrl", "url" to "mailto:hi@orca.example")))
        assertNull(shadow.nextStartedActivity)
    }

    @Test
    fun y2_androidClipboardAndChooser() {
        val shadow = shadowOf(application)
        val actions = SystemActions.android(application)

        assertTrue(actions.perform(effect("copyToClipboard", "text" to "ORCA-42")))
        val clipboard = application.getSystemService(ClipboardManager::class.java)
        assertEquals("ORCA-42", clipboard.primaryClip?.getItemAt(0)?.text?.toString())

        assertTrue(actions.perform(effect("share", "text" to "Look", "subject" to "Orca")))
        val chooser = assertNotNull(shadow.nextStartedActivity)
        assertEquals(Intent.ACTION_CHOOSER, chooser.action)
        assertTrue(chooser.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        val send = assertNotNull(chooser.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java))
        assertEquals(Intent.ACTION_SEND, send.action)
        assertEquals("text/plain", send.type)
        assertEquals("Look", send.getStringExtra(Intent.EXTRA_TEXT))
        assertEquals("Orca", send.getStringExtra(Intent.EXTRA_SUBJECT))

        assertTrue(actions.perform(effect("share", "text" to "Plain")))
        val plain = assertNotNull(assertNotNull(shadow.nextStartedActivity).getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java))
        assertEquals("Plain", plain.getStringExtra(Intent.EXTRA_TEXT))
        assertFalse(plain.hasExtra(Intent.EXTRA_SUBJECT))
    }
}
