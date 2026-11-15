package com.orcagateway.sdk.widgets

import android.app.Activity
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material.ripple.RippleAlpha
import androidx.compose.material3.LocalRippleConfiguration
import androidx.compose.material3.RippleConfiguration
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.isFocused
import androidx.compose.ui.test.isNotFocused
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performMouseInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.sdk.NodeView
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.roundToInt
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * A1.5, the button half of A1.11 and D11 against Flutter's Material 3
 * buttons (button_builders.dart `_buildElevatedButton`, `_buildTextButton`,
 * `_buildOutlinedButton`, `_applyOverlay`), at 1 dp per pixel. Buttons and
 * SizedBoxes are tagged with their node ids.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class ButtonTest {
    @get:Rule
    val compose = createComposeRule()

    private var view: View? = null

    /** The ripple configuration each SizedBox (here a button's label) last saw, by node id. */
    private val ripples = mutableMapOf<String, RippleConfiguration?>()

    /** A page drawn from its root inside a loose box, its buttons and SizedBoxes tagged. */
    private fun buttonPage(width: Dp, height: Dp, vararg nodes: ComponentNode) {
        val model = OrcaPageModel(page(*nodes)).apply {
            builders = WidgetBuilders.standard().apply {
                for (type in listOf("ElevatedButton", "OutlinedButton", "TextButton")) {
                    register(type) { node, model, modifier -> ButtonWidget(node, model, modifier.testTag(node.id)) }
                }
                register("SizedBox") { node, model, modifier ->
                    ripples[node.id] = LocalRippleConfiguration.current
                    SizedBoxWidget(node, model, modifier.testTag(node.id))
                }
            }
        }
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(width, height)) { NodeView(nodes.first().id, model) }
        }
    }

    private fun button(id: String, type: String, child: String, vararg props: Pair<String, Any?>) =
        button(id, type, child, emptyMap(), props.associate { (key, value) -> key to JsonValue.of(value) })

    private fun all(side: Int) = mapOf("top" to side, "right" to side, "bottom" to side, "left" to side)

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    /**
     * A1.5: `padding` is the button's content padding, as Flutter's
     * `styleFrom(padding:)`: a 50x30 label with 20 on each side makes a
     * 90x70 button with the label 20 in from every edge.
     */
    @Test
    fun a1_5_paddingIsInsideTheButton() {
        buttonPage(
            300.dp, 300.dp,
            column("0", "b"),
            button("b", "ElevatedButton", "label", "padding" to all(20)),
            sizedBox("label", 50, 30),
        )

        val button = bounds("b")
        val label = bounds("label")
        assertEquals(90.dp to 70.dp, button.width to button.height)
        assertEquals(20.dp, label.left - button.left, "left")
        assertEquals(20.dp, label.top - button.top, "top")
        assertEquals(20.dp, button.right - label.right, "right")
        assertEquals(20.dp, button.bottom - label.bottom, "bottom")
    }

    /**
     * A1.5: `elevation` 6 casts a shadow below the button, drawn by the
     * hardware renderer (a software canvas draws none); elevation 0 casts
     * none, as Flutter's.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun a1_5_elevationCastsAShadowBelowTheButton() {
        buttonPage(
            300.dp, 300.dp,
            column("0", "raised", "gap", "flat"),
            button("raised", "ElevatedButton", "l1", "elevation" to 6, "backgroundColor" to "#FFFFFF"),
            sizedBox("gap", 10, 60),
            button("flat", "ElevatedButton", "l2", "elevation" to 0, "backgroundColor" to "#FFFFFF"),
            sizedBox("l1", 80, 40),
            sizedBox("l2", 80, 40),
        )
        compose.waitForIdle()
        val picture = capture()

        val raised = bounds("raised")
        val flat = bounds("flat")
        val below = { box: DpRect -> picture.at((box.left + box.width / 2).value, box.bottom.value + 2) }
        val background = picture.at(290f, 290f)
        val shadow = below(raised)
        assertTrue(
            darkness(shadow) - darkness(background) >= 8,
            "below the raised button is #${Integer.toHexString(shadow)} on #${Integer.toHexString(background)}",
        )
        assertEquals(Integer.toHexString(background), Integer.toHexString(below(flat)), "below the flat button")
    }

    /**
     * A1.11: `autofocus: true` focuses the button once it is composed, as
     * Flutter's `autofocus`; false or absent leaves it unfocused. Robolectric's
     * window is not in touch mode, where Compose lets a button take focus.
     */
    @Test
    fun a1_11_autofocusFocusesTheButton() {
        buttonPage(
            300.dp, 400.dp,
            column("0", "on", "off", "plain"),
            button("on", "ElevatedButton", "l1", "autofocus" to true),
            button("off", "OutlinedButton", "l2", "autofocus" to false),
            button("plain", "TextButton", "l3"),
            sizedBox("l1", 40, 20),
            sizedBox("l2", 40, 20),
            sizedBox("l3", 40, 20),
        )
        compose.waitForIdle()

        compose.onNodeWithTag("on").assert(isFocused())
        compose.onNodeWithTag("off").assert(isNotFocused())
        compose.onNodeWithTag("plain").assert(isNotFocused())
    }

    /**
     * D11: `splashColor` is the pressed overlay and `highlightColor` the
     * hovered one, each at its own alpha, as Flutter's `_applyOverlay`. The
     * press ripple is Android's RippleDrawable, which Robolectric does not
     * draw, so the press is read from the [RippleConfiguration] the
     * button's ripple reads (its label sees the same one); the hover layer
     * is Compose's and is drawn. A button with neither keeps the theme's
     * ripple.
     */
    @Test
    @GraphicsMode(GraphicsMode.Mode.NATIVE)
    fun d11_splashTintsThePressAndHighlightTheHover() {
        val overlays = arrayOf("backgroundColor" to "#FFFFFF", "splashColor" to "#FF0000", "highlightColor" to "#00FF00")
        buttonPage(
            300.dp, 300.dp,
            column("0", "pressed", "hovered", "plain"),
            button("pressed", "ElevatedButton", "l1", *overlays),
            button("hovered", "ElevatedButton", "l2", *overlays),
            button("plain", "ElevatedButton", "l3"),
            sizedBox("l1", 80, 40),
            sizedBox("l2", 80, 40),
            sizedBox("l3", 80, 40),
        )
        compose.waitForIdle()
        val alpha = RippleAlpha(draggedAlpha = 1f, focusedAlpha = 1f, hoveredAlpha = 1f, pressedAlpha = 1f)
        assertEquals(RippleConfiguration(Color.Green, alpha), ripples["l1"], "at rest")
        assertEquals(RippleConfiguration(), ripples["l3"], "no overlay colours")

        compose.onNodeWithTag("pressed").performTouchInput { down(center) }
        compose.waitForIdle()
        assertEquals(RippleConfiguration(Color.Red, alpha), ripples["l1"], "pressed")

        compose.onNodeWithTag("hovered").performMouseInput { enter(center) }
        compose.mainClock.advanceTimeBy(1_000)
        val hovered = bounds("hovered")
        val pixel = draw(requireNotNull(view)).at((hovered.left + hovered.width / 2).value, (hovered.top + 6.dp).value)
        assertEquals("ff00ff00", Integer.toHexString(pixel), "hovered")
    }

    /** The window as Robolectric's hardware renderer draws it (elevation shadows included), through PixelCopy. */
    private fun capture(): Bitmap {
        val view = requireNotNull(view)
        val activity = generateSequence(view.context) { (it as? ContextWrapper)?.baseContext }
            .filterIsInstance<Activity>().first()
        val decor = activity.window.decorView
        val bitmap = Bitmap.createBitmap(decor.width, decor.height, Bitmap.Config.ARGB_8888)
        PixelCopy.request(activity.window, bitmap, {}, Handler(Looper.getMainLooper()))
        val at = IntArray(2).also { view.getLocationInWindow(it) }
        return Bitmap.createBitmap(bitmap, at[0], at[1], view.width, view.height)
    }

    /** The view drawn in software on white, as GoldenTest draws it (no elevation shadows). */
    private fun draw(view: View): Bitmap {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(android.graphics.Color.WHITE)
        view.draw(Canvas(bitmap))
        return bitmap
    }

    private fun Bitmap.at(x: Float, y: Float): Int = getPixel(x.roundToInt(), y.roundToInt())

    /** How far below white the darkest channel of [pixel] is, 0 to 255. */
    private fun darkness(pixel: Int): Int = 255 - minOf(
        android.graphics.Color.red(pixel), android.graphics.Color.green(pixel), android.graphics.Color.blue(pixel),
    )
}
