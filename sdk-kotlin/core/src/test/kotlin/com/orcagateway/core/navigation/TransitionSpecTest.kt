package com.orcagateway.core.navigation

import com.orcagateway.core.animation.Curves
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.RouteTransitionDef
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFails
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A route's transition as the pure core reads it (B12.6-K, B12.7-K): the
 * kinds and defaults of Flutter's `RouteTransitionDef` and
 * `_transitionsBuilder` (sdk/lib/src/navigation/navigation_handler.dart:280-325),
 * which platform honours which kind, and the entering page at a time handed in.
 */
class TransitionSpecTest {
    private fun spec(type: String, duration: Int = 300, curve: String = "linear") =
        TransitionSpec.of(RouteTransitionDef(type, duration, curve))

    /** The transition a route decoded from the wire carries. */
    private fun decoded(json: String): TransitionSpec =
        TransitionSpec.of(NavRoute.fromTree(JsonValue.parse("""{"path":"p","transition":$json}""".encodeToByteArray())).transition)

    private val identity = PageMotion(opacity = 1.0, offsetXFraction = 0.0, offsetYFraction = 0.0, scale = 1.0)

    // MARK: Parsing

    @Test
    fun b12_6_everyKindIsReadByItsFlutterName() {
        assertEquals(TransitionKind.Fade, spec("fade").kind)
        assertEquals(TransitionKind.SlideUp, spec("slideUp").kind)
        assertEquals(TransitionKind.Scale, spec("scale").kind)
        assertEquals(TransitionKind.SlideRight, spec("slideRight").kind)
        assertEquals(TransitionKind.Slide, spec("slide").kind)
        assertEquals(TransitionKind.None, spec("none").kind)
    }

    @Test
    fun b12_6_noTransitionAndNoneAreThePlatformDefault() {
        assertEquals(TransitionSpec(TransitionKind.None, 300.0, null), TransitionSpec.None)
        assertEquals(TransitionSpec.None, TransitionSpec.of(null))
        // `none` is no transition at all, whatever else it carries.
        assertEquals(TransitionSpec.None, spec("none", duration = 900, curve = "linear"))
        assertEquals(TransitionSpec.None, decoded("""{"type":"none","duration":500}"""))
        assertEquals(identity, TransitionSpec.of(null).entering(0.0, reduceMotion = false))
        assertEquals(0.0, TransitionSpec.of(null).runMs(reduceMotion = false))
        assertEquals(0.0, spec("none").runMs(reduceMotion = false))
    }

    /** Dart's `'slide' || _`: any name it does not know comes in from the left. */
    @Test
    fun b12_6_anUnknownKindIsSlide() {
        assertEquals(TransitionKind.Slide, spec("zoom").kind)
        assertEquals(TransitionKind.Slide, spec("").kind)
        assertEquals(TransitionKind.Slide, spec("Fade").kind)
        assertEquals(TransitionKind.Slide, spec("slideup").kind)
    }

    @Test
    fun b12_6_durationIsWholeMillisecondsAndDefaultsTo300() {
        assertEquals(300.0, decoded("""{"type":"fade"}""").durationMs)
        assertEquals(450.0, decoded("""{"type":"fade","duration":450}""").durationMs)
        assertEquals(0.0, decoded("""{"type":"fade","duration":0}""").durationMs)
        assertEquals(0.0, decoded("""{"type":"fade","duration":-20}""").durationMs, "a negative duration jumps")
        // Dart's `json['duration'] as int?` refuses a fraction; so does the route model.
        assertFails { decoded("""{"type":"fade","duration":250.7}""") }
    }

    @Test
    fun b12_6_curveIsKeptByNameAndDefaultsToEaseInOut() {
        assertEquals("easeInOut", decoded("""{"type":"fade"}""").curve)
        assertEquals("bounceOut", decoded("""{"type":"fade","curve":"bounceOut"}""").curve)
        assertNull(TransitionSpec.of(null).curve)
        // A name outside the table is easeInOut, the full table of 41 names counts (not Flutter's 11 here).
        val unknown = spec("fade", curve = "wobble").entering(75.0, reduceMotion = false)
        assertEquals(Curves.apply("easeInOut", 0.25), unknown.opacity, 1e-12)
        assertEquals("easeOutCubic", spec("fade", curve = "easeOutCubic").curve)
        val cubic = spec("fade", curve = "easeOutCubic").entering(150.0, reduceMotion = false)
        assertEquals(Curves.apply("easeOutCubic", 0.5), cubic.opacity, 1e-12)
    }

    // MARK: Platforms

    @Test
    fun b12_7_iosHonoursFadeAndSlideUpOnlyAndAndroidEveryKind() {
        val table = listOf(
            "fade" to true, "slideUp" to true, "scale" to false, "slideRight" to false,
            "slide" to false, "zoom" to false, "none" to false,
        )
        for ((type, ios) in table) {
            assertEquals(ios, spec(type).honoured(TransitionSpec.Platform.IOS), "iOS $type")
            assertTrue(spec(type).honoured(TransitionSpec.Platform.ANDROID), "android $type")
        }
        assertFalse(TransitionSpec.of(null).honoured(TransitionSpec.Platform.IOS))
        assertTrue(TransitionSpec.of(null).honoured(TransitionSpec.Platform.ANDROID), "none is the NavHost default")
    }

    @Test
    fun b12_7_isOverTellsWhenTheEntranceNeedsNoMoreFrames() {
        assertFalse(spec("fade").isOver(0.0, reduceMotion = false))
        assertFalse(spec("fade").isOver(299.0, reduceMotion = false))
        assertTrue(spec("fade").isOver(300.0, reduceMotion = false))
        assertTrue(spec("fade").isOver(0.0, reduceMotion = true))
        assertTrue(spec("fade", duration = 0).isOver(0.0, reduceMotion = false))
        assertTrue(spec("none").isOver(0.0, reduceMotion = false))
    }

    // MARK: The entering page

    @Test
    fun b12_6_theEnteringPageStartsWhereItsKindSays() {
        assertEquals(identity.copy(opacity = 0.0), spec("fade").entering(0.0, false))
        assertEquals(identity.copy(offsetYFraction = 1.0), spec("slideUp").entering(0.0, false))
        assertEquals(identity.copy(scale = 0.0), spec("scale").entering(0.0, false))
        assertEquals(identity.copy(offsetXFraction = 1.0), spec("slideRight").entering(0.0, false), "from the right")
        assertEquals(identity.copy(offsetXFraction = -1.0), spec("slide").entering(0.0, false), "from the left")
        assertEquals(identity.copy(offsetXFraction = -1.0), spec("zoom").entering(0.0, false))
        assertEquals(identity, spec("none").entering(0.0, false))
        // Before the start is the start.
        assertEquals(identity.copy(opacity = 0.0), spec("fade").entering(-40.0, false))
    }

    @Test
    fun b12_6_midRunFollowsTheCurve() {
        // Linear: half way at half time.
        assertEquals(identity.copy(opacity = 0.5), spec("fade").entering(150.0, false))
        assertEquals(identity.copy(offsetYFraction = 0.5), spec("slideUp").entering(150.0, false))
        assertEquals(identity.copy(scale = 0.25), spec("scale", duration = 400).entering(100.0, false))
        assertEquals(identity.copy(offsetXFraction = 0.75), spec("slideRight").entering(75.0, false))
        assertEquals(identity.copy(offsetXFraction = -0.75), spec("slide").entering(75.0, false))

        // easeInOut, Flutter's number at t = 0.25.
        val eased = 0.12868531048297882
        assertEquals(eased, spec("fade", curve = "easeInOut").entering(75.0, false).opacity, 1e-9)
        assertEquals(1 - eased, spec("slideUp", curve = "easeInOut").entering(75.0, false).offsetYFraction, 1e-9)
        assertEquals(eased, spec("scale", curve = "easeInOut").entering(75.0, false).scale, 1e-9)
        assertEquals(-(1 - eased), spec("slide", curve = "easeInOut").entering(75.0, false).offsetXFraction, 1e-9)
        assertEquals(0.5, spec("fade", curve = "easeInOut").entering(150.0, false).opacity, 1e-9)
        // The duration is the route's.
        assertEquals(identity.copy(opacity = 0.25), spec("fade", duration = 1000).entering(250.0, false))
    }

    @Test
    fun b12_6_aCurveThatOvershootsMovesThePageButNotItsOpacity() {
        // elasticOut is 1.125 at a quarter: an opacity cannot be, an offset and a scale can.
        assertEquals(1.0, spec("fade", curve = "elasticOut").entering(75.0, false).opacity)
        assertEquals(-0.125, spec("slideUp", curve = "elasticOut").entering(75.0, false).offsetYFraction, 1e-9)
        assertEquals(1.125, spec("scale", curve = "elasticOut").entering(75.0, false).scale, 1e-9)
    }

    @Test
    fun b12_6_atTheEndAndPastItThePageIsInPlace() {
        for (type in listOf("fade", "slideUp", "scale", "slideRight", "slide", "none", "zoom")) {
            assertEquals(identity, spec(type).entering(300.0, false), type)
            assertEquals(identity, spec(type).entering(5_000.0, false), type)
        }
    }

    @Test
    fun b12_6_reducedMotionOrNoDurationLandsAtOnce() {
        for (type in listOf("fade", "slideUp", "scale", "slideRight", "slide")) {
            assertEquals(identity, spec(type).entering(0.0, reduceMotion = true), type)
            assertEquals(identity, spec(type).entering(150.0, reduceMotion = true), type)
            assertEquals(identity, spec(type, duration = 0).entering(0.0, reduceMotion = false), type)
            assertEquals(identity, spec(type, duration = -5).entering(0.0, reduceMotion = false), type)
            assertEquals(identity, spec(type).leaving(0.0, reduceMotion = true), type)
            assertEquals(0.0, spec(type).runMs(reduceMotion = true), type)
            assertEquals(0.0, spec(type, duration = 0).runMs(reduceMotion = false), type)
            assertEquals(300.0, spec(type).runMs(reduceMotion = false), type)
        }
    }

    /** Dart's reverse runs the same curve over the value going back: the entering page at `duration - t`. */
    @Test
    fun b12_6_aPopPlaysTheEnteringPageBackwards() {
        val fade = spec("fade", curve = "easeIn")
        assertEquals(identity, fade.leaving(0.0, false))
        assertEquals(fade.entering(225.0, false), fade.leaving(75.0, false))
        assertEquals(identity.copy(opacity = 0.0), fade.leaving(300.0, false))
        assertEquals(identity.copy(opacity = 0.0), fade.leaving(900.0, false))
        assertEquals(identity.copy(offsetYFraction = 0.25), spec("slideUp").leaving(75.0, false))
        assertTrue(spec("slide").leaving(150.0, false).offsetXFraction < 0)
        assertEquals(identity, spec("none").leaving(0.0, false))
    }
}
