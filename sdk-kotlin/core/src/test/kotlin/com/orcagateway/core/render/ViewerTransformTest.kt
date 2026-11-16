package com.orcagateway.core.render

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * A4.5, the core half of InteractiveViewer: Flutter's
 * `_InteractiveViewerState` (widgets/interactive_viewer.dart) as the
 * Flutter builder makes it (layout_builders.dart:636-644: minScale 0.8,
 * maxScale 2.5, pan and scale on; the framework's boundaryMargin zero, so
 * the bound is the child's rect). The scale is clamped after a floor of
 * viewport / child (`_matrixScale` :646-660), a translation is kept inside
 * the bound (`_matrixTranslate` :547-640), and one scale gesture pans or
 * pinches about its focal point (`_onScaleStart`, `_onScaleUpdate`
 * :700-805). The same cases as Swift's ViewerTransformTests.
 */
class ViewerTransformTest {
    /** A 200x200 child filling a 200x200 viewer, Flutter's defaults. */
    private val square = ViewerLimits(viewport = ViewerSize(200.0, 200.0), child = ViewerSize(200.0, 200.0))
    private val centre = ViewerPoint(100.0, 100.0)

    /** Zoomed in to 2 about the centre. */
    private val zoomed = ViewerTransform(scale = 2.0, x = -100.0, y = -100.0)

    /**
     * A4.5: at rest the transform is the identity, whose scene point is
     * the point itself; a transform draws scene point p at scale·p + (x, y).
     */
    @Test
    fun a4_5_atRestTheTransformIsTheIdentity() {
        assertEquals(ViewerTransform(scale = 1.0, x = 0.0, y = 0.0), ViewerTransform.identity)
        assertEquals(ViewerPoint(30.0, 70.0), ViewerTransform.identity.toScene(ViewerPoint(30.0, 70.0)))
        assertEquals(ViewerPoint(100.0, 75.0), ViewerTransform(scale = 2.0, x = -100.0, y = -50.0).toScene(ViewerPoint(100.0, 100.0)))
    }

    /** A4.5: the limits default to the Flutter builder's: 0.8 and 2.5, pan and scale on. */
    @Test
    fun a4_5_limitsDefaultToTheFlutterBuilders() {
        assertEquals(0.8, square.minScale)
        assertEquals(2.5, square.maxScale)
        assertTrue(square.panEnabled)
        assertTrue(square.scaleEnabled)
    }

    /** A4.5: a pinch x2 about the centre zooms to 2 and keeps the centre where it was: translation (-100, -100). */
    @Test
    fun a4_5_aPinchTimesTwoAboutTheCentreZoomsAboutIt() {
        assertTransform(zoomed, pinch(listOf(2.0), at = centre))
    }

    /** A4.5: a pinch x10 stops at maxScale 2.5, still about the centre. */
    @Test
    fun a4_5_aPinchStopsAtMaxScale() {
        assertTransform(ViewerTransform(scale = 2.5, x = -150.0, y = -150.0), pinch(listOf(10.0), at = centre))
    }

    /**
     * A4.5: a pinch x0.5 at rest stays at 1: the child would no longer
     * cover the viewer, whatever minScale (0.8 by default) allows.
     */
    @Test
    fun a4_5_aPinchOutAtRestStaysAtOneWhateverMinScale() {
        assertTransform(ViewerTransform.identity, pinch(listOf(0.5), at = centre))
        assertTransform(ViewerTransform.identity, pinch(listOf(0.5), at = centre, limits = square.copy(minScale = 0.1)))
    }

    /** A4.5: with minScale 1.5 a pinch x1.01 jumps to 1.5 (Flutter clamps the total), about the centre. */
    @Test
    fun a4_5_aMinScaleAboveOneIsReachedByAnyPinch() {
        assertTransform(
            ViewerTransform(scale = 1.5, x = -50.0, y = -50.0),
            pinch(listOf(1.01), at = centre, limits = square.copy(minScale = 1.5)),
        )
    }

    /**
     * A4.5: with maxScale 0.9 (below 1, above the default minScale) the
     * clamp wins over the floor of 1: any pinch goes to 0.9, and since the
     * child then covers neither axis of the viewer no translation is kept
     * (Flutter's result).
     */
    @Test
    fun a4_5_aMaxScaleBelowOneIsWhatTheClampGives() {
        val limits = square.copy(maxScale = 0.9)
        for (scale in listOf(2.0, 0.5)) {
            assertTransform(ViewerTransform(scale = 0.9, x = 0.0, y = 0.0), pinch(listOf(scale), at = centre, limits = limits))
        }
    }

    /** A4.5: at scale 1 a drag moves nothing (the child is exactly the viewport, so the bound leaves no room). */
    @Test
    fun a4_5_aDragAtScaleOneMovesNothing() {
        for (by in listOf(ViewerPoint(50.0, 30.0), ViewerPoint(-80.0, 0.0), ViewerPoint(0.0, -500.0))) {
            assertTransform(ViewerTransform.identity, drag(by, from = ViewerTransform.identity))
        }
    }

    /**
     * A4.5: zoomed in to 2 at (-100, -100), a drag by (-50, -30) pans to
     * (-150, -130); by (+500, 0) x stops at 0; by (-500, 0) x stops at
     * -200 (the child's right edge on the viewer's); within one drag the
     * edge keeps no overshoot: +500 then back 50 is at once at -50.
     */
    @Test
    fun a4_5_zoomedInADragPansWithinTheChild() {
        assertTransform(ViewerTransform(scale = 2.0, x = -150.0, y = -130.0), drag(ViewerPoint(-50.0, -30.0), from = zoomed))
        assertTransform(ViewerTransform(scale = 2.0, x = 0.0, y = -100.0), drag(ViewerPoint(500.0, 0.0), from = zoomed))
        assertTransform(ViewerTransform(scale = 2.0, x = -200.0, y = -100.0), drag(ViewerPoint(-500.0, 0.0), from = zoomed))
        assertTransform(
            ViewerTransform(scale = 2.0, x = -50.0, y = -100.0),
            drag(listOf(ViewerPoint(500.0, 0.0), ViewerPoint(450.0, 0.0)), from = zoomed),
        )
    }

    /** A4.5: a 200x100 child zoomed to 2 in a 200x100 viewport pans within [-200, 0] x [-100, 0]. */
    @Test
    fun a4_5_aWideChildPansWithinItsOwnBounds() {
        val limits = ViewerLimits(viewport = ViewerSize(200.0, 100.0), child = ViewerSize(200.0, 100.0))
        val from = ViewerTransform(scale = 2.0, x = -100.0, y = -50.0)
        assertTransform(ViewerTransform(scale = 2.0, x = 0.0, y = 0.0), drag(ViewerPoint(900.0, 900.0), from = from, limits = limits))
        assertTransform(
            ViewerTransform(scale = 2.0, x = -200.0, y = -100.0),
            drag(ViewerPoint(-900.0, -900.0), from = from, limits = limits),
        )
        assertTransform(
            ViewerTransform(scale = 2.0, x = -160.0, y = -20.0),
            drag(ViewerPoint(-60.0, 30.0), from = from, limits = limits),
        )
    }

    /** A4.5: a pinch x2 about the top-left corner keeps the corner there: translation (0, 0). */
    @Test
    fun a4_5_aPinchAboutTheTopLeftCornerKeepsItThere() {
        assertTransform(ViewerTransform(scale = 2.0, x = 0.0, y = 0.0), pinch(listOf(2.0), at = ViewerPoint(0.0, 0.0)))
    }

    /**
     * A4.5: from 2 at (0, 0), a pinch x0.75 about the centre would keep
     * the scene point (50, 50) under it only by moving the child right of
     * the viewer's edge, so the translation stops at (0, 0) and the point
     * under the focal point, (66.7, 66.7), becomes the reference: back to
     * x1, the pinch keeps that point there, (-33.3, -33.3), not (0, 0).
     */
    @Test
    fun a4_5_aPinchStoppedByTheBoundMovesItsReference() {
        val gesture = ViewerGesture()
        val from = ViewerTransform(scale = 2.0, x = 0.0, y = 0.0)
        gesture.start(focal = centre, transform = from)
        val out = gesture.update(scale = 0.75, focal = centre, transform = from, limits = square)
        assertTransform(ViewerTransform(scale = 1.5, x = 0.0, y = 0.0), out)
        assertEquals(200.0 / 3, gesture.reference.x, 1e-9)
        assertEquals(200.0 / 3, gesture.reference.y, 1e-9)
        val back = gesture.update(scale = 1.0, focal = centre, transform = out, limits = square)
        assertTransform(ViewerTransform(scale = 2.0, x = -100.0 / 3, y = -100.0 / 3), back)
    }

    /** A4.5: with scaleEnabled false a pinch changes nothing (Flutter counts it as a pan whose scale is not 1, and drops it). */
    @Test
    fun a4_5_scaleDisabledAPinchChangesNothing() {
        val limits = square.copy(scaleEnabled = false)
        assertTransform(ViewerTransform.identity, pinch(listOf(2.0, 3.0), at = centre, limits = limits))
        assertTransform(zoomed, pinch(listOf(0.5), at = centre, from = zoomed, limits = limits))
    }

    /**
     * A4.5: with panEnabled false a drag changes nothing, and a pinch
     * still zooms about its focal point (the pinch's own translation is
     * not a pan).
     */
    @Test
    fun a4_5_panDisabledADragChangesNothingButAPinchScalesAboutItsFocalPoint() {
        val limits = square.copy(panEnabled = false)
        assertTransform(zoomed, drag(ViewerPoint(-50.0, -30.0), from = zoomed, limits = limits))
        assertTransform(zoomed, pinch(listOf(2.0), at = centre, limits = limits))
    }

    /** A4.5: a gesture whose first update has scale 1 is a pan, and a later one with scale 1.5 makes it a scale, about its focal point. */
    @Test
    fun a4_5_aGestureThatStartsAsAPanBecomesAScale() {
        val gesture = ViewerGesture()
        gesture.start(focal = centre, transform = ViewerTransform.identity)
        val first = gesture.update(scale = 1.0, focal = centre, transform = ViewerTransform.identity, limits = square)
        assertEquals(ViewerGesture.Kind.Pan, gesture.kind)
        assertTransform(ViewerTransform.identity, first)
        val second = gesture.update(scale = 1.5, focal = centre, transform = first, limits = square)
        assertEquals(ViewerGesture.Kind.Scale, gesture.kind)
        assertTransform(ViewerTransform(scale = 1.5, x = -50.0, y = -50.0), second)
    }

    // Helpers.

    /** One gesture from [from]: a pinch whose updates have [scales] about a focal point that stays [at]. */
    private fun pinch(
        scales: List<Double>,
        at: ViewerPoint,
        from: ViewerTransform = ViewerTransform.identity,
        limits: ViewerLimits = square,
    ): ViewerTransform {
        val gesture = ViewerGesture()
        gesture.start(focal = at, transform = from)
        var transform = from
        for (scale in scales) transform = gesture.update(scale = scale, focal = at, transform = transform, limits = limits)
        return transform
    }

    /** One gesture from [from]: a finger down at the centre, then moved by each of [moves] from there in turn (scale 1). */
    private fun drag(moves: List<ViewerPoint>, from: ViewerTransform, limits: ViewerLimits = square): ViewerTransform {
        val gesture = ViewerGesture()
        gesture.start(focal = centre, transform = from)
        var transform = from
        for (move in moves) {
            val focal = ViewerPoint(centre.x + move.x, centre.y + move.y)
            transform = gesture.update(scale = 1.0, focal = focal, transform = transform, limits = limits)
        }
        return transform
    }

    private fun drag(move: ViewerPoint, from: ViewerTransform, limits: ViewerLimits = square): ViewerTransform =
        drag(listOf(move), from, limits)

    private fun assertTransform(expected: ViewerTransform, actual: ViewerTransform) {
        for ((want, got) in listOf(expected.scale to actual.scale, expected.x to actual.x, expected.y to actual.y)) {
            assertEquals(want, got, 1e-9, "$actual vs $expected")
        }
    }
}
