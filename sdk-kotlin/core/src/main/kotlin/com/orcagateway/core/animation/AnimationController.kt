package com.orcagateway.core.animation

/** Flutter's `AnimationStatus`. */
public enum class AnimationStatus {
    /** At rest at 0. */
    Dismissed,

    /** Running towards 1. */
    Forward,

    /** Running towards 0. */
    Reverse,

    /** At rest at 1. */
    Completed,
}

/**
 * The clock of one AnimatedBuilder (Flutter's `AnimationController` plus
 * its `CurvedAnimation`), with no timer inside: every call takes the time
 * in milliseconds, so the UI passes its frame time and a test passes
 * numbers. It starts at rest at 0.
 *
 * With [reduceMotion], or a [durationMs] of 0 or less, a run ends the
 * moment it starts: the end state at once and one completion; a repeating
 * builder rests at 1 and, as a repeat, never completes.
 */
public class AnimationController(
    public val durationMs: Double = AnimationDuration.DEFAULT_MS,
    public val curve: String? = null,
    public val repeats: Boolean = false,
    public val reverses: Boolean = false,
    public val reduceMotion: Boolean = false,
) {
    private sealed interface Motion

    private class Rest(val value: Double) : Motion

    private class Run(val from: Double, val to: Double, val start: Double, val length: Double) : Motion {
        /** A run with no length (a jump) has ended whatever the time, also one before its [start]. */
        fun ended(now: Double): Boolean = !(length > 0) || now >= start + length
    }

    private class Repeat(val start: Double) : Motion

    private var motion: Motion = Rest(0.0)
    private var completions = 0

    private val jumps: Boolean get() = reduceMotion || !(durationMs > 0)

    /**
     * The builder's `autoStart` run: forever with [repeats] (back and forth
     * with [reverses]), else once as [forward].
     */
    public fun start(now: Double) {
        if (!repeats) return forward(now)
        settle(now)
        motion = if (jumps) Rest(1.0) else Repeat(now)
    }

    /** Flutter's `forward(from: 0)`: again from 0, once, also on a repeating builder. */
    public fun forward(now: Double) {
        settle(now)
        motion = Run(from = 0.0, to = 1.0, start = now, length = if (jumps) 0.0 else durationMs)
    }

    /**
     * Flutter's `reverse()`: from the value now down to 0, in that share of
     * the duration. At 0 there is nothing to do, and nothing completes.
     */
    public fun reverse(now: Double) {
        settle(now)
        val from = value(now)
        if (from <= 0.0) return
        motion = Run(from = from, to = 0.0, start = now, length = if (jumps) 0.0 else from * durationMs)
    }

    /** The linear value, 0...1. */
    public fun value(now: Double): Double = when (val m = motion) {
        is Rest -> m.value
        is Run -> if (m.ended(now)) m.to else m.from + (m.to - m.from) * maxOf(now - m.start, 0.0) / m.length
        is Repeat -> {
            val cycles = maxOf(now - m.start, 0.0) / durationMs
            val phase = cycles % 1.0
            if (reverses && cycles.toLong() % 2 == 1L) 1.0 - phase else phase
        }
    }

    /** The value after the [curve]: what a tween under the builder reads. */
    public fun progress(now: Double): Double = Curves.apply(curve, value(now))

    public fun status(now: Double): AnimationStatus = when (val m = motion) {
        is Rest -> resting(m.value)
        is Run -> when {
            m.ended(now) -> resting(m.to)
            m.to > m.from -> AnimationStatus.Forward
            else -> AnimationStatus.Reverse
        }
        is Repeat -> {
            val cycles = maxOf(now - m.start, 0.0) / durationMs
            if (reverses && cycles.toLong() % 2 == 1L) AnimationStatus.Reverse else AnimationStatus.Forward
        }
    }

    /** Whether the value still moves at [now]: the UI ticks only while true. */
    public fun isRunning(now: Double): Boolean = when (val m = motion) {
        is Rest -> false
        is Run -> !m.ended(now)
        is Repeat -> true
    }

    /**
     * True once for each run that has reached 1 or reached 0 by [now]: the
     * builder's `onComplete`. Never for a cycle of a repeat, nor for a
     * `reverse` at 0. Two runs that ended since the last call give true twice.
     */
    public fun takeCompletion(now: Double): Boolean {
        settle(now)
        if (completions == 0) return false
        completions -= 1
        return true
    }

    private fun resting(value: Double): AnimationStatus =
        if (value >= 1.0) AnimationStatus.Completed else AnimationStatus.Dismissed

    /** Turns a run that has ended into a rest and counts its completion. */
    private fun settle(now: Double) {
        val run = motion as? Run ?: return
        if (!run.ended(now)) return
        motion = Rest(run.to)
        completions += 1
    }
}

/**
 * The controllers a page's actions can reach by `animationId` (Flutter's
 * `AnimationRegistry`), one per page model. The last builder to register an
 * id owns it, and a builder that leaves removes the entry only if it is
 * still its own (Flutter removes whatever sits under the id). An unknown id
 * is not an error: nothing happens.
 */
public class AnimationRegistry {
    private class Entry(val owner: Any, val controller: AnimationController)

    private val entries = mutableMapOf<String, Entry>()

    /** Puts [controller] under [id] for [owner] (any object the builder keeps), replacing an earlier owner. */
    public fun register(id: String, owner: Any, controller: AnimationController) {
        entries[id] = Entry(owner, controller)
    }

    /** Removes [id] if [owner] still owns it. */
    public fun unregister(id: String, owner: Any) {
        if (owns(id, owner)) entries.remove(id)
    }

    /** Whether [id] is registered to this very [owner]. */
    public fun owns(id: String, owner: Any): Boolean = entries[id]?.owner === owner

    /** The controller under [id], null when no builder has it. */
    public fun controller(id: String): AnimationController? = entries[id]?.controller

    /** `animateForward`: false, and nothing happens, for an unknown id. */
    public fun forward(id: String, now: Double): Boolean {
        val controller = controller(id) ?: return false
        controller.forward(now)
        return true
    }

    /** `animateReverse`: false, and nothing happens, for an unknown id. */
    public fun reverse(id: String, now: Double): Boolean {
        val controller = controller(id) ?: return false
        controller.reverse(now)
        return true
    }

    /** The curved progress a tween naming [id] reads; 0 for an unknown id. */
    public fun progress(id: String, now: Double): Double = controller(id)?.progress(now) ?: 0.0
}
