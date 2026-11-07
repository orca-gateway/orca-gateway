package com.orcagateway.sdk

import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.sdk.support.recordedPage
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

/**
 * The native-widgets demo page (`examples/server`, `native-widgets home`),
 * recorded through the Kotlin caps handshake. K4 ports Swift's
 * `testTheFavouriteGestureTogglesItsIcon` (StackTests): the heart's
 * GestureDetector flips the page-state flag its Icon follows. G3 ports
 * Swift's `testNativeWidgetsPage` (GoldenTests): the whole page as a golden,
 * at the size and density of [GoldenTest]. R1 (gate 10) checks that each
 * card's photo spans its card.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class NativeWidgetsPageTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun k4_theHeartGestureTogglesItsIcon(): Unit = runBlocking {
        val model = OrcaPageModel(recordedPage("native-widgets-home"))
        val heart = assertNotNull(
            model.page.components.firstOrNull { node ->
                val tap = node.actions?.get("onTap")
                node.type == "GestureDetector" && tap is Action.SetState && tap.key == "fav_pizza"
            },
            "a GestureDetector whose onTap sets fav_pizza",
        )
        val iconId = assertNotNull(
            model.page.components.firstOrNull { it.type == "Icon" && it.watches == listOf("fav_pizza") }?.id,
            "an Icon that watches fav_pizza",
        )
        assertEquals(JsonValue.String("favorite_border"), model.resolve(iconId)?.get("name"))

        model.fire("onTap", on = assertNotNull(model.resolve(heart.id)))?.join()
        assertEquals(JsonValue.Bool(true), model.store.value("fav_pizza"))
        assertEquals(JsonValue.String("favorite"), model.resolve(iconId)?.get("name"))

        model.fire("onTap", on = assertNotNull(model.resolve(heart.id)))?.join()
        assertEquals(JsonValue.Bool(false), model.store.value("fav_pizza"))
    }

    /**
     * Network images would make the picture depend on the network, so each
     * Image's `src` is emptied and the Image draws its placeholder; layout,
     * colours and icons stay.
     */
    @Test
    fun g3_theNativeWidgetsPageGolden() {
        val recorded = recordedPage("native-widgets-home")
        val page = recorded.copy(
            components = recorded.components.map { node ->
                if (node.type == "Image") node.copy(props = node.props + ("src" to JsonValue.String(""))) else node
            },
        )
        compose.assertPageGolden(OrcaPageModel(page), "native-widgets-home")
    }

    /**
     * R1, the gate-10 report "images in cards not stretched": by Flutter's
     * rules each card's photo spans its card and is 160 dp high. The photo
     * is found by its `alt`, the card as the innermost layout holding both
     * the photo and the dish's name. Images are emptied as in G3.
     */
    @Test
    fun r1_theCardPhotoSpansTheCard() {
        val recorded = recordedPage("native-widgets-home")
        val page = recorded.copy(
            components = recorded.components.map { node ->
                if (node.type == "Image") node.copy(props = node.props + ("src" to JsonValue.String(""))) else node
            },
        )
        compose.setContent { OrcaPageView(OrcaPageModel(page)) }
        compose.waitForIdle()
        val height = with(compose.density) { 160.dp.roundToPx() }
        for (dish in listOf("Margherita Pizza", "Salmon Poke Bowl")) {
            val photo = compose.onNodeWithContentDescription(dish).fetchSemanticsNode().layoutInfo
            val name = compose.onNodeWithText(dish).fetchSemanticsNode().layoutInfo
            val holdsName = generateSequence(name) { it.parentInfo }.toList()
            val card = assertNotNull(
                generateSequence(photo.parentInfo) { it.parentInfo }.firstOrNull { a -> holdsName.any { it === a } },
                "$dish: a layout holding both the photo and the name",
            )
            assertEquals(card.width, photo.width, "$dish: the photo's width in px, against its card's")
            assertEquals(height, photo.height, "$dish: the photo's height in px")
        }
    }
}
