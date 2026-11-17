package com.orcagateway.core.state

/**
 * The app's one queue of snackbars and toasts, the Kotlin side of Flutter's
 * root ScaffoldMessenger as showSnackbar and showToast use it
 * (sdk/lib/src/state/action_executor.dart:393-423; material scaffold.dart
 * :371-392, :438-449, :661-674; snack_bar.dart:30, :323). Pure: no clock;
 * the UI passes time in with [advance], in whole milliseconds (Compose's
 * frame clock).
 *
 * First in, first shown, nothing dropped or replaced. The head enters in
 * 250 ms, shows its duration counted from when it is fully in, leaves in
 * 250 ms, and the next enters as it goes. A swipe removes the head at
 * once, with no leave of its own, and the next enters. The same cases as
 * Swift's SnackbarQueue.
 */
public class SnackbarQueue {
    public enum class Kind { Snackbar, Toast }

    /** Where the head is. */
    public enum class Phase {
        /** Coming in, for [TRANSITION_MS]. */
        Entering,

        /** Fully in, for its duration. */
        Showing,

        /** Going, for [TRANSITION_MS] from fully in. */
        Leaving,
    }

    /** One show. The same message twice is two items (identity, as Swift's `Item.id`). */
    public class Item internal constructor(
        public val kind: Kind,
        public val message: String,
        /** Its time fully in, ms; 0 or less leaves as soon as it is in. */
        public val durationMs: Long,
    ) {
        override fun toString(): String = "SnackbarQueue.Item($kind, \"$message\", ${durationMs}ms)"
    }

    private val queue = ArrayDeque<Item>()

    /** How far the head is in, ms, 0 .. [TRANSITION_MS]. */
    private var inMs = 0L

    /** How long the head has been fully in, ms. */
    private var shownMs = 0L

    /** Everything waiting, the head (on screen) first. */
    public val items: List<Item> get() = queue.toList()

    /** The head's phase; null when the queue is idle. */
    public var phase: Phase? = null
        private set

    /** The item on screen, null when idle. */
    public val current: Item? get() = queue.firstOrNull()

    /** How far the head is in, 0 (out) .. 1 (fully in): what the bar is revealed by. */
    public val reveal: Double get() = inMs.toDouble() / TRANSITION_MS

    /** The ms until the head's phase next changes; null when idle. */
    public val untilNextChangeMs: Long?
        get() = when (phase) {
            null -> null
            Phase.Entering -> TRANSITION_MS - inMs
            Phase.Showing -> maxOf(0L, queue.first().durationMs - shownMs)
            Phase.Leaving -> inMs
        }

    /**
     * showSnackbar or showToast: the item, at the back of the queue; it
     * starts entering at once when the queue is idle. No duration is 4000 ms
     * for a snackbar, 2000 for a toast (action_executor.dart:395, :410).
     */
    public fun show(kind: Kind, message: String, durationMs: Long? = null): Item {
        val item = Item(kind, message, durationMs ?: if (kind == Kind.Snackbar) SNACKBAR_DURATION_MS else TOAST_DURATION_MS)
        queue.addLast(item)
        // An idle queue's times are 0 already (the last head left with them).
        if (phase == null) phase = Phase.Entering
        return item
    }

    /**
     * A swipe on the bar: the head is removed at once, whatever its phase,
     * with no leave animation, and the next (if any) starts entering. The UI
     * slides the bar off with the drag first: Flutter's Dismissible, whose
     * onDismissed calls removeCurrentSnackBar (snack_bar.dart:859-871;
     * scaffold.dart:466-478). An idle queue is left as it is.
     */
    public fun swipe() {
        if (phase != null) dropHead()
    }

    /** The head is gone: the next, if any, starts entering from 0. */
    private fun dropHead() {
        inMs = 0
        shownMs = 0
        queue.removeFirst()
        phase = if (queue.isEmpty()) null else Phase.Entering
    }

    /**
     * [byMs] of time passes: phases end in turn, the time left over going to
     * the next, and a head that has left gives way to the next item, which
     * starts entering. A phase ends when the time reaches its end, so a
     * duration of 0 or less leaves the moment the bar is in. Zero or
     * negative changes nothing.
     */
    public fun advance(byMs: Long) {
        if (byMs <= 0) return
        var left = byMs
        while (true) {
            when (phase ?: return) {
                Phase.Entering -> {
                    val need = TRANSITION_MS - inMs
                    if (left < need) {
                        inMs += left
                        return
                    }
                    left -= need
                    inMs = TRANSITION_MS
                    shownMs = 0
                    phase = Phase.Showing
                }
                Phase.Showing -> {
                    val need = maxOf(0L, queue.first().durationMs - shownMs)
                    if (left < need) {
                        shownMs += left
                        return
                    }
                    left -= need
                    phase = Phase.Leaving
                }
                Phase.Leaving -> {
                    if (left < inMs) {
                        inMs -= left
                        return
                    }
                    left -= inMs
                    dropHead()
                }
            }
        }
    }

    public companion object {
        /** How long a bar takes to come in, and to go (snack_bar.dart:30). */
        public const val TRANSITION_MS: Long = 250

        /** A snackbar's time on screen when its action names none (action_executor.dart:395). */
        public const val SNACKBAR_DURATION_MS: Long = 4000

        /** A toast's (action_executor.dart:410). */
        public const val TOAST_DURATION_MS: Long = 2000
    }
}
