package com.orcagateway.core.navigation

import com.orcagateway.core.animation.AnimationDuration
import com.orcagateway.core.animation.Curves
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.RouteTransitionDef

/**
 * How a route's page comes in (Flutter's `_transitionsBuilder`,
 * sdk/lib/src/navigation/navigation_handler.dart:303-325). [None] is the
 * platform's own page animation, not "no animation".
 */
public enum class TransitionKind { Fade, SlideUp, Scale, SlideRight, Slide, None }

/**
 * The entering page at one moment of its transition: [opacity] 0...1, its
 * offset as a fraction of the page's own width and height (+x is right, +y
 * is down), and its [scale] about the centre. In place: 1, 0, 0, 1.
 */
public data class PageMotion(
    val opacity: Double,
    val offsetXFraction: Double,
    val offsetYFraction: Double,
    val scale: Double,
) {
    public companion object {
        /** The page in place. */
        public val Identity: PageMotion = PageMotion(opacity = 1.0, offsetXFraction = 0.0, offsetYFraction = 0.0, scale = 1.0)
    }
}

/**
 * A route's transition, pure: the [kind], its length [durationMs] in whole
 * milliseconds (the same in and out), and the [curve] by name, evaluated
 * with the whole [Curves] table (a missing or unknown name is easeInOut).
 * Only the entering page moves; the page under it stands still, and a pop
 * plays the same run backwards.
 */
public data class TransitionSpec(
    val kind: TransitionKind,
    val durationMs: Double,
    val curve: String?,
) {
    /** The platforms that draw route transitions. */
    public enum class Platform { IOS, ANDROID }

    /**
     * Whether [platform] plays this transition itself. Android: every kind
     * ([TransitionKind.None] is its NavHost default). iOS: only
     * [TransitionKind.Fade] and [TransitionKind.SlideUp]; any other kind is
     * the system push.
     */
    public fun honoured(platform: Platform): Boolean = when (platform) {
        Platform.ANDROID -> true
        Platform.IOS -> kind == TransitionKind.Fade || kind == TransitionKind.SlideUp
    }

    /**
     * The entrance has nothing left to play at [elapsedMs]: the page is at
     * rest and needs no more frames. Always so for [TransitionKind.None],
     * with [reduceMotion] and for a duration of 0 or less.
     */
    public fun isOver(elapsedMs: Double, reduceMotion: Boolean): Boolean =
        kind == TransitionKind.None || reduceMotion || !(durationMs > 0.0) || elapsedMs >= durationMs

    /**
     * How long a run lasts: [durationMs], or 0 when there is nothing to
     * play ([TransitionKind.None], [reduceMotion], a duration of 0).
     */
    public fun runMs(reduceMotion: Boolean): Double = if (isOver(0.0, reduceMotion)) 0.0 else durationMs

    /**
     * The entering page [elapsedMs] after its push. With [reduceMotion], a
     * duration of 0 or [TransitionKind.None], and at or past the end, it is
     * in place; before the push is the start. A curve that leaves 0...1
     * (elastic, back) moves the page past its place; the opacity stays
     * within 0...1.
     */
    public fun entering(elapsedMs: Double, reduceMotion: Boolean): PageMotion {
        if (isOver(elapsedMs, reduceMotion)) return PageMotion.Identity
        val p = Curves.apply(curve, elapsedMs / durationMs)
        return when (kind) {
            TransitionKind.Fade -> PageMotion.Identity.copy(opacity = p.coerceIn(0.0, 1.0))
            TransitionKind.SlideUp -> PageMotion.Identity.copy(offsetYFraction = 1.0 - p)
            TransitionKind.Scale -> PageMotion.Identity.copy(scale = p)
            TransitionKind.SlideRight -> PageMotion.Identity.copy(offsetXFraction = 1.0 - p)
            TransitionKind.Slide -> PageMotion.Identity.copy(offsetXFraction = p - 1.0)
            TransitionKind.None -> PageMotion.Identity
        }
    }

    /**
     * The popped page [elapsedMs] after its pop: the entering run played
     * backwards, [entering] at `durationMs - elapsedMs`. With nothing to
     * play it is in place, and gone at once.
     */
    public fun leaving(elapsedMs: Double, reduceMotion: Boolean): PageMotion {
        val run = runMs(reduceMotion)
        if (run <= 0.0) return PageMotion.Identity
        return entering(run - maxOf(elapsedMs, 0.0), reduceMotion)
    }

    public companion object {
        /** No transition: what a route without one, or with `none`, gets. */
        public val None: TransitionSpec = TransitionSpec(TransitionKind.None, AnimationDuration.DEFAULT_MS, null)

        /**
         * The spec of a route's [transition] as Flutter reads it: no
         * transition and the type `none` are [None] whatever else they
         * carry; `fade`, `scale`, `slideUp`, `slideRight` and `slide` are
         * themselves, and any other type is [TransitionKind.Slide] (Dart's
         * `'slide' || _`, names compared as written). The duration is the
         * route's in whole milliseconds, below 0 is 0; the curve the route's.
         */
        public fun of(transition: RouteTransitionDef?): TransitionSpec {
            if (transition == null || transition.type == "none") return None
            val kind = when (transition.type) {
                "fade" -> TransitionKind.Fade
                "scale" -> TransitionKind.Scale
                "slideUp" -> TransitionKind.SlideUp
                "slideRight" -> TransitionKind.SlideRight
                else -> TransitionKind.Slide
            }
            val duration = AnimationDuration.milliseconds(JsonValue.Int(transition.duration.toLong()))
            return TransitionSpec(kind, duration, transition.curve)
        }
    }
}
