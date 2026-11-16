package com.orcagateway.core.state

import com.orcagateway.core.state.SnackbarQueue.Kind
import com.orcagateway.core.state.SnackbarQueue.Phase
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertSame

/**
 * A8.4, the core half of showSnackbar and showToast (design D4, D8): the
 * app's one ScaffoldMessenger queue (MUI scaffold.dart:356-392, :438-449),
 * shared by both kinds (action_executor.dart:393-423), driven by the time
 * the caller passes in. A bar comes in over 250 ms (snack_bar.dart:30),
 * its duration (`?? 4000`, a toast's `?? 2000`) starts once it is fully in
 * (scaffold.dart:661-674), it goes out over 250 ms, and only then the next
 * comes in; a new one never replaces the showing one. A swipe removes the
 * bar at once and the next comes in. The same cases as Swift's
 * SnackbarQueueTests.
 */
class SnackbarQueueTest {
    /** The head and its phase after each [step]-ms advance from 0 to [untilMs], one line per change. */
    private fun timeline(queue: SnackbarQueue, untilMs: Long, step: Long = 1): List<String> {
        val out = ArrayList<String>()
        var last: String? = null
        var t = 0L
        while (t <= untilMs) {
            if (t > 0) queue.advance(step)
            val now = "${queue.current?.message}:${queue.phase}"
            if (now != last) out += "$t $now"
            last = now
            t += step
        }
        return out
    }

    /** A8.4: snackbars and toasts share one queue and show in the order they came. */
    @Test
    fun a8_4_itemsShowInArrivalOrder() {
        val queue = SnackbarQueue()
        val a = queue.show(Kind.Snackbar, "a", 1000)
        val b = queue.show(Kind.Toast, "b", 500)
        val c = queue.show(Kind.Snackbar, "c", 1000)
        assertEquals(listOf(a, b, c), queue.items)
        assertSame(a, queue.current)
        assertEquals(
            listOf(
                "0 a:Entering", "250 a:Showing", "1250 a:Leaving",
                "1500 b:Entering", "1750 b:Showing", "2250 b:Leaving",
                "2500 c:Entering", "2750 c:Showing", "3750 c:Leaving",
                "4000 null:null",
            ),
            timeline(queue, 5000),
        )
        assertEquals(emptyList(), queue.items)
    }

    /** A8.4: no duration is 4000 ms for a snackbar and 2000 ms for a toast; a given one is kept, 0 too. */
    @Test
    fun a8_4_durationsDefaultTo4000ForASnackbarAnd2000ForAToast() {
        assertEquals(4000L, SnackbarQueue.SNACKBAR_DURATION_MS)
        assertEquals(2000L, SnackbarQueue.TOAST_DURATION_MS)
        assertEquals(250L, SnackbarQueue.TRANSITION_MS)
        val queue = SnackbarQueue()
        val snackbar = queue.show(Kind.Snackbar, "s")
        val toast = queue.show(Kind.Toast, "t")
        assertEquals(4000L, snackbar.durationMs)
        assertEquals(Kind.Snackbar, snackbar.kind)
        assertEquals("s", snackbar.message)
        assertEquals(2000L, toast.durationMs)
        assertEquals(Kind.Toast, toast.kind)
        assertEquals(1500L, queue.show(Kind.Snackbar, "x", 1500).durationMs)
        assertEquals(3000L, queue.show(Kind.Toast, "y", 3000).durationMs)
        assertEquals(0L, queue.show(Kind.Snackbar, "z", 0).durationMs)
        assertEquals(
            listOf("0 s:Entering", "250 s:Showing", "4250 s:Leaving", "4500 t:Entering", "4750 t:Showing", "6750 t:Leaving", "7000 x:Entering"),
            timeline(queue, 7000),
        )
    }

    /** A8.4: in over 250 ms (reveal 0 → 1), its duration fully in, out over 250 ms (1 → 0), then nothing. */
    @Test
    fun a8_4_aBarEnters250ThenShowsItsDurationThenLeaves250() {
        val queue = SnackbarQueue()
        assertNull(queue.phase)
        assertEquals(0.0, queue.reveal)
        assertNull(queue.untilNextChangeMs)
        queue.show(Kind.Snackbar, "a", 1000)
        assertEquals(Phase.Entering, queue.phase)
        assertEquals(0.0, queue.reveal)
        assertEquals(250L, queue.untilNextChangeMs)
        queue.advance(125)
        assertEquals(Phase.Entering, queue.phase)
        assertEquals(0.5, queue.reveal)
        assertEquals(125L, queue.untilNextChangeMs)
        queue.advance(124)
        assertEquals(Phase.Entering, queue.phase)
        queue.advance(1)
        assertEquals(Phase.Showing, queue.phase)
        assertEquals(1.0, queue.reveal)
        assertEquals(1000L, queue.untilNextChangeMs)
        queue.advance(999)
        assertEquals(Phase.Showing, queue.phase)
        assertEquals(1.0, queue.reveal)
        assertEquals(1L, queue.untilNextChangeMs)
        queue.advance(1)
        assertEquals(Phase.Leaving, queue.phase)
        assertEquals(1.0, queue.reveal)
        assertEquals(250L, queue.untilNextChangeMs)
        queue.advance(50)
        assertEquals(Phase.Leaving, queue.phase)
        assertEquals(0.8, queue.reveal)
        assertEquals(200L, queue.untilNextChangeMs)
        queue.advance(199)
        assertEquals(Phase.Leaving, queue.phase)
        assertEquals("a", queue.current?.message)
        queue.advance(1)
        assertNull(queue.phase)
        assertNull(queue.current)
        assertEquals(0.0, queue.reveal)
        assertNull(queue.untilNextChangeMs)
    }

    /** A8.4: the duration runs from the moment the bar is fully in, also for one shorter than the entrance, and 0. */
    @Test
    fun a8_4_theDurationCountsOnlyOnceTheBarIsFullyIn() {
        val short = SnackbarQueue()
        short.show(Kind.Snackbar, "a", 100)
        assertEquals(listOf("0 a:Entering", "250 a:Showing", "350 a:Leaving", "600 null:null"), timeline(short, 700))

        val zero = SnackbarQueue()
        zero.show(Kind.Toast, "z", 0)
        assertEquals(listOf("0 z:Entering", "250 z:Leaving", "500 null:null"), timeline(zero, 600))

        val oneStep = SnackbarQueue()
        oneStep.show(Kind.Snackbar, "a", 1000)
        oneStep.advance(1249)
        assertEquals(Phase.Showing, oneStep.phase)
        oneStep.advance(1)
        assertEquals(Phase.Leaving, oneStep.phase)
        assertEquals(1.0, oneStep.reveal)
    }

    /**
     * A8.4: a swipe removes the head at once, whatever its phase, with no
     * leave of its own: Flutter's Dismissible slides it off with the drag
     * (the UI's part), then removeCurrentSnackBar drops it (snack_bar.dart
     * :859-871, scaffold.dart:466-478), and the next comes in at once with
     * its whole time. A swipe on an idle queue changes nothing.
     */
    @Test
    fun a8_4_aSwipeRemovesTheBarAtOnce() {
        val queue = SnackbarQueue()
        queue.swipe()
        assertNull(queue.phase)
        assertNull(queue.current)

        val a = queue.show(Kind.Snackbar, "a")
        val b = queue.show(Kind.Snackbar, "b", 1000)
        val c = queue.show(Kind.Toast, "c", 1000)
        queue.advance(1250)
        assertEquals(Phase.Showing, queue.phase)
        assertSame(a, queue.current)
        queue.swipe()
        assertSame(b, queue.current)
        assertEquals(Phase.Entering, queue.phase)
        assertEquals(0.0, queue.reveal)
        assertEquals(250L, queue.untilNextChangeMs)
        assertEquals(listOf(b, c), queue.items)

        queue.advance(100)
        assertEquals(0.4, queue.reveal)
        queue.swipe()
        assertSame(c, queue.current)
        assertEquals(Phase.Entering, queue.phase)
        assertEquals(0.0, queue.reveal)
        assertEquals(
            listOf("0 c:Entering", "250 c:Showing", "1250 c:Leaving", "1500 null:null"),
            timeline(queue, 1600),
        )

        val leaving = SnackbarQueue()
        leaving.show(Kind.Snackbar, "x", 1000)
        val y = leaving.show(Kind.Snackbar, "y", 1000)
        leaving.advance(1300)
        assertEquals(Phase.Leaving, leaving.phase)
        leaving.swipe()
        assertSame(y, leaving.current)
        assertEquals(Phase.Entering, leaving.phase)
        assertEquals(0.0, leaving.reveal)

        leaving.swipe()
        assertNull(leaving.current)
        assertNull(leaving.phase)
        assertEquals(0.0, leaving.reveal)
        assertNull(leaving.untilNextChangeMs)
        leaving.swipe()
        assertNull(leaving.phase)
    }

    /** A8.4: what comes while a bar shows waits behind it; the showing one keeps its time; the same text twice shows twice. */
    @Test
    fun a8_4_nothingIsDroppedOrReplaced() {
        val queue = SnackbarQueue()
        val a = queue.show(Kind.Snackbar, "a", 1000)
        queue.advance(300)
        val b = queue.show(Kind.Snackbar, "b", 1000)
        val again = queue.show(Kind.Snackbar, "b", 1000)
        val toast = queue.show(Kind.Toast, "t", 500)
        assertSame(a, queue.current)
        assertEquals(Phase.Showing, queue.phase)
        assertEquals(listOf(a, b, again, toast), queue.items)
        val shown = ArrayList<SnackbarQueue.Item>()
        repeat(6000) {
            queue.advance(1)
            val head = queue.current
            if (head != null && shown.lastOrNull() !== head) shown += head
        }
        assertEquals(listOf(a, b, again, toast), shown)
        assertNull(queue.current)
    }

    /**
     * A8.4: the next is not the head while the previous leaves; it comes in
     * the moment the leave ends, also when it arrived during the leave and
     * when one advance crosses the boundary.
     */
    @Test
    fun a8_4_theNextEntersOnlyAfterThePreviousHasLeft() {
        val queue = SnackbarQueue()
        queue.show(Kind.Snackbar, "a", 1000)
        queue.advance(1300)
        assertEquals(Phase.Leaving, queue.phase)
        queue.show(Kind.Toast, "b", 1000)
        assertEquals("a", queue.current?.message)
        queue.advance(199)
        assertEquals("a", queue.current?.message)
        assertEquals(Phase.Leaving, queue.phase)
        queue.advance(1)
        assertEquals("b", queue.current?.message)
        assertEquals(Phase.Entering, queue.phase)
        assertEquals(0.0, queue.reveal)

        val jump = SnackbarQueue()
        jump.show(Kind.Snackbar, "a", 1000)
        jump.show(Kind.Snackbar, "b", 1000)
        jump.advance(1600)
        assertEquals("b", jump.current?.message)
        assertEquals(Phase.Entering, jump.phase)
        assertEquals(0.4, jump.reveal)
        jump.advance(10_000)
        assertNull(jump.current)
        assertNull(jump.phase)

        val idle = SnackbarQueue()
        idle.advance(5000)
        idle.show(Kind.Snackbar, "late", 1000)
        assertEquals(Phase.Entering, idle.phase)
        assertEquals(0.0, idle.reveal)
    }
}
