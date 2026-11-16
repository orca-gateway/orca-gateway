package com.orcagateway.sdk.widgets

import android.graphics.Picture
import android.os.Build
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlurEffect
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.draw
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Velocity
import androidx.compose.ui.unit.dp
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.sdk.ChildView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.style.Props
import kotlin.math.ceil

/**
 * Whether a backdrop is blurred at Android [apiLevel]: from Android 12
 * (API 31, `RenderEffect`). Below it a white scrim at 60% stands in for the
 * blur, under the overlay colour (q7).
 */
internal fun backdropBlurs(apiLevel: Int): Boolean = apiLevel >= Build.VERSION_CODES.S

/**
 * Flutter's blur [sigma] (a Gaussian sigma in logical pixels) as the radius
 * in pixels Android's blur takes. Android turns a radius r into the sigma
 * 0.57735 r + 0.5 (the relation Swift's shadows use), so r = (sigma in
 * pixels - 0.5) / 0.57735; a sigma of half a pixel or less is no blur.
 */
internal fun blurRadius(sigma: Double, density: Float): Float =
    ((sigma * density - 0.5) / 0.57735).coerceAtLeast(0.0).toFloat()

/**
 * What a page's backdrops draw behind themselves. Compose has no backdrop
 * API, so while a BackdropFilter or BlurView is on the page (q6) and the
 * device blurs, the page root records what it draws, every backdrop leaving
 * itself out (its copy, overlay and child), then draws as usual; each
 * backdrop gets the part of the recording behind it, as it was when
 * recorded, in its [Backdrop.layer]. With no backdrop the page draws in one
 * pass and nothing is recorded.
 *
 * The recording is a flat [Picture], not a layer of the page: a layer would
 * hold the page's own layers (a scroll view's clip, an opacity) by
 * reference, so a backdrop inside one would draw inside its own copy, and a
 * layer recorded while backdrops leave themselves out would keep them out
 * when drawn. Drawn flat, those layers are played into the Picture, and a
 * backdrop knows it is being recorded by the canvas it is drawn into.
 *
 * The copy is as fresh as the page root's last draw. A scroll view redraws
 * only its own layer, so every scroll a touch drives (and its fling)
 * reports to the page root, which then records again: a fixed backdrop
 * over a scrolling list follows it. What changes inside a layer of its own
 * without such a scroll (an animation, a scroll moved by code) is seen as
 * it was at the root's last draw.
 *
 * Only what the page draws is in it: a route's title bar, a drawer, a
 * snackbar or an embedded Android view does not show through a blur. What
 * is drawn above a backdrop (a later sibling) is in its copy too, and
 * another backdrop is not; Flutter's copy holds exactly what was painted
 * before it. The copy is placed by translation only, so a backdrop under a
 * RotatedBox or a zoomed InteractiveViewer is misaligned. The copy is the
 * box's size (TileMode.Clamp), so the blur's edges differ from Flutter's,
 * which samples past the clip.
 */
internal class BackdropRecorder(val blurs: Boolean) {
    /** The backdrops on the page; the page root records while there is one. */
    internal val backdrops = mutableStateListOf<Backdrop>()

    /** The page root, where the recording starts. */
    internal var root: LayoutCoordinates? = null

    /** The canvas the page is being recorded into, while it is. */
    private var recordingInto: android.graphics.Canvas? = null

    /** Counts the scrolls below the page root; the root's draw reads it, so a scroll records the page again. */
    private var scrolls by mutableIntStateOf(0)

    /** Hears the scrolls below the page root, taking nothing from them. */
    internal val scrollConnection: NestedScrollConnection = object : NestedScrollConnection {
        override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
            if (consumed != Offset.Zero) scrolled()
            return Offset.Zero
        }

        override suspend fun onPostFling(consumed: Velocity, available: Velocity): Velocity {
            scrolled()
            return Velocity.Zero
        }
    }

    private fun scrolled() {
        if (blurs && backdrops.isNotEmpty()) scrolls++
    }

    /** Whether the page root records: while the device blurs and a backdrop is on the page. */
    internal fun records(): Boolean {
        if (!blurs || backdrops.isEmpty()) return false
        return scrolls >= 0 // read, so that a scroll draws the root again
    }

    /** Whether [scope] draws into the recording (a backdrop then draws nothing). */
    internal fun isRecording(scope: DrawScope): Boolean {
        val recording = recordingInto ?: return false
        return scope.drawContext.canvas.nativeCanvas === recording
    }

    /** Records what the page root in [scope] draws and hands each backdrop its part. */
    internal fun record(scope: ContentDrawScope) {
        val root = root?.takeIf { it.isAttached } ?: return
        val width = ceil(scope.size.width).toInt()
        val height = ceil(scope.size.height).toInt()
        if (width <= 0 || height <= 0) return
        val page = Picture()
        val canvas = page.beginRecording(width, height)
        recordingInto = canvas
        try {
            scope.draw(scope, scope.layoutDirection, Canvas(canvas), scope.size) { scope.drawContent() }
        } finally {
            recordingInto = null
            page.endRecording()
        }
        for (backdrop in backdrops) {
            val box = backdrop.coordinates?.takeIf { it.isAttached } ?: continue
            val at = root.localPositionOf(box, Offset.Zero)
            backdrop.layer.record(scope, scope.layoutDirection, box.size) {
                translate(-at.x, -at.y) { drawIntoCanvas { it.nativeCanvas.drawPicture(page) } }
            }
        }
    }
}

/** One BackdropFilter or BlurView: where it is and the part of the page behind it. */
internal class Backdrop(val layer: GraphicsLayer) {
    internal var coordinates: LayoutCoordinates? = null
}

/** The page's [BackdropRecorder]; null outside [BackdropRecording] (a NodeView hosted on its own). */
internal val LocalBackdropRecorder = staticCompositionLocalOf<BackdropRecorder?> { null }

/**
 * Gives the page in [content] a [BackdropRecorder] for Android [apiLevel];
 * [content] puts the modifier it is handed on the page root (OrcaPageView
 * hands it to the root's NodeView).
 */
@Composable
internal fun BackdropRecording(
    apiLevel: Int = Build.VERSION.SDK_INT,
    content: @Composable (root: Modifier) -> Unit,
) {
    val recorder = remember(apiLevel) { BackdropRecorder(backdropBlurs(apiLevel)) }
    val root = remember(recorder) {
        Modifier
            .nestedScroll(recorder.scrollConnection)
            .onPlaced { recorder.root = it }
            .drawWithContent {
                if (recorder.records()) recorder.record(this)
                drawContent()
            }
    }
    CompositionLocalProvider(LocalBackdropRecorder provides recorder) { content(root) }
}

/**
 * Flutter `BackdropFilter` (`_buildBackdropFilter`): its child, its size
 * (nothing without one), over what is behind it blurred by `blurX` and
 * `blurY` (sigmas, 10 by default). Flutter's blur reaches the nearest
 * ancestor clip; the natives clip it to the widget's box (design D9). Taps
 * reach the child. Like Flutter's proxy box it takes no tap itself and does
 * not clip its child: a tap where the child takes none reaches what is
 * behind.
 */
@Composable
internal fun BackdropFilterWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    BackdropBox(node, model, modifier, RectangleShape, blurView = false, overlay = null)
}

/**
 * The SDK's `BlurView` (Flutter `_buildBlurView`): ClipRRect(`borderRadius`,
 * 0 by default) > the blur behind (`blurX`, `blurY`, 10 by default) >
 * `overlayColor` (none by default) at the child's size > the child. Its size
 * is the child's (nothing without one). The corners cut what is drawn,
 * child included, not where it is touched: it takes every tap over its
 * whole rectangle, so nothing behind it gets one (the overlay is a Flutter
 * ColoredBox, always hit, and ClipRRect cuts hits only with a custom
 * clipper, proxy_box.dart:1736-1746), while its child still gets those it
 * takes.
 */
@Composable
internal fun BlurViewWidget(node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val shape = RoundedCornerShape(Props.length(node["borderRadius"]) ?: 0.dp)
    BackdropBox(node, model, modifier, shape, blurView = true, overlay = Props.color(node["overlayColor"]))
}

/**
 * A backdrop: inside [shape], the part of the page behind it blurred (or
 * the scrim), then [overlay], then the child. A [blurView] cuts its child's
 * drawing to [shape] too and takes every tap over its rectangle. Draws
 * nothing while the page records.
 */
@Composable
private fun BackdropBox(
    node: ResolvedNode,
    model: OrcaPageModel,
    modifier: Modifier,
    shape: Shape,
    blurView: Boolean,
    overlay: Color?,
) {
    val recorder = LocalBackdropRecorder.current
    val layer = rememberGraphicsLayer()
    val backdrop = remember(layer) { Backdrop(layer) }
    if (recorder != null) {
        DisposableEffect(recorder, backdrop) {
            recorder.backdrops += backdrop
            onDispose { recorder.backdrops -= backdrop }
        }
    }
    val sigmaX = Props.number(node["blurX"]) ?: DEFAULT_SIGMA
    val sigmaY = Props.number(node["blurY"]) ?: DEFAULT_SIGMA
    val density = LocalDensity.current.density
    val blur = remember(sigmaX, sigmaY, density) {
        val x = blurRadius(sigmaX, density)
        val y = blurRadius(sigmaY, density)
        if (x > 0f || y > 0f) BlurEffect(x, y, TileMode.Clamp) else null
    }
    val blurs = recorder?.blurs == true

    Box(
        modifier
            .onPlaced { backdrop.coordinates = it }
            .drawWithContent {
                if (recorder?.isRecording(this) == true) return@drawWithContent
                clipTo(shape) {
                    if (blurs) {
                        layer.renderEffect = blur
                        drawLayer(layer)
                    } else {
                        drawRect(SCRIM)
                    }
                    if (overlay != null) drawRect(overlay)
                    if (blurView) this@drawWithContent.drawContent()
                }
                if (!blurView) drawContent()
            }
            .then(if (blurView) Modifier.pointerInput(Unit) {} else Modifier),
        propagateMinConstraints = true,
    ) {
        ChildView(node, model)
    }
}

/** Draws [block] cut to [shape] at this scope's size. */
private inline fun DrawScope.clipTo(shape: Shape, block: DrawScope.() -> Unit) {
    when (val outline = shape.createOutline(size, layoutDirection, this)) {
        is Outline.Rectangle -> clipRect(
            outline.rect.left, outline.rect.top, outline.rect.right, outline.rect.bottom, block = block,
        )
        is Outline.Rounded -> clipPath(Path().apply { addRoundRect(outline.roundRect) }, block = block)
        is Outline.Generic -> clipPath(outline.path, block = block)
    }
}

/** Flutter's `blurX` and `blurY` when absent. */
private const val DEFAULT_SIGMA = 10.0

/** What stands in for the blur below Android 12: white at 60% (q7). */
private val SCRIM = Color(1f, 1f, 1f, 0.6f)
