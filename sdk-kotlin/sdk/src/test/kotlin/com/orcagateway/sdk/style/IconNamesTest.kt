package com.orcagateway.sdk.style

import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.dp
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPageView
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.kotlinRoot
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.text
import com.orcagateway.sdk.widgets.IconWidget
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The Kotlin icon table covers every Material name the Flutter SDK knows,
 * with the icon Flutter draws for it, so a page draws the same icons on
 * both (Swift's IconNamesTests). Reads Dart's `_materialIconMap` from
 * sdk/lib/src/builders/builder_helpers.dart in the monorepo at test time,
 * so the two tables cannot drift.
 */
@RunWith(RobolectricTestRunner::class)
class IconNamesTest {
    @get:Rule
    val compose = createComposeRule()

    /** Dart's map as (name, Flutter `Icons` constant), in its order. */
    private fun dartIcons(): List<Pair<String, String>> {
        val source = File(kotlinRoot.parentFile, "sdk/lib/src/builders/builder_helpers.dart").readText()
        val start = source.indexOf("const _materialIconMap")
        assertTrue(start >= 0, "no _materialIconMap in builder_helpers.dart")
        val body = source.substring(start, source.indexOf("};", start))
        return Regex("""'([a-z0-9_]+)':\s*Icons\.([a-z0-9_]+)""").findAll(body)
            .map { it.groupValues[1] to it.groupValues[2] }
            .toList()
    }

    /**
     * The Compose names for a Flutter `Icons` constant: `shopping_cart` is
     * `Filled.ShoppingCart`, `home_outlined` is `Outlined.Home` (`_rounded`
     * and `_sharp` likewise), and Compose's right-to-left aware copy,
     * `AutoMirrored.Filled.ArrowBack`, stands for its plain one.
     */
    private fun composeNames(flutterIcon: String): Set<String> {
        var base = flutterIcon
        var style = "Filled"
        for ((suffix, name) in listOf("_outlined" to "Outlined", "_rounded" to "Rounded", "_sharp" to "Sharp")) {
            if (base.endsWith(suffix)) {
                base = base.removeSuffix(suffix)
                style = name
            }
        }
        // Flutter's aliases: the same glyph under Material's own name.
        base = mapOf("copy" to "content_copy")[base] ?: base
        val camel = base.split('_').joinToString("") { part -> part.replaceFirstChar { it.uppercase() } }
        return setOf("$style.$camel", "AutoMirrored.$style.$camel")
    }

    @Test
    fun w10_everyFlutterIconNameHasTheSameMaterialIcon() {
        val dart = dartIcons()
        assertEquals(156, dart.size, "names read from _materialIconMap")
        val missing = dart.map { it.first }.filter { it !in IconNames.table }
        assertEquals(emptyList(), missing, "Flutter icon names with no Kotlin entry")
        val extra = IconNames.table.keys - dart.map { it.first }.toSet()
        assertEquals(emptySet(), extra, "Kotlin icon names Flutter does not know")
        val wrong = dart.mapNotNull { (name, flutterIcon) ->
            val drawn = IconNames.table.getValue(name).name
            "$name: Icons.$flutterIcon drawn as $drawn".takeIf { drawn !in composeNames(flutterIcon) }
        }
        assertEquals(emptyList(), wrong, "names drawn with another icon than Flutter's")
    }

    @Test
    fun w11_unknownAndMissingNamesDrawAFilledCircleLikeFlutter() {
        assertEquals("Filled.Circle", IconNames.vector(null).name)
        assertEquals("Filled.Circle", IconNames.vector("no_such_icon").name)
        assertEquals("Filled.Search", IconNames.vector("search").name)
        assertEquals("Filled.FavoriteBorder", IconNames.vector("favorite_border").name)
        assertEquals("Outlined.Home", IconNames.vector("home_outlined").name)
    }

    /** The widget: a known name, no `size`, is a 24 dp square, as Flutter's default icon size. */
    @Test
    fun anIconDrawsATwentyFourDpSquareByDefault() {
        val iconPage = page(
            column("0", "1", "2", "3"),
            text("1", "before"),
            leaf("2", "Icon", mapOf("name" to JsonValue.String("home"))),
            text("3", "after"),
        )
        val registry = WidgetRegistry(types = WidgetRegistry.shared.types + "Icon")
        val model = OrcaPageModel(iconPage, registry = registry).apply {
            builders = WidgetBuilders.standard().apply {
                register("Icon") { node, model, modifier -> IconWidget(node, model, modifier) }
            }
        }
        compose.setContent { OrcaPageView(model) }

        val before = compose.onNodeWithText("before").getUnclippedBoundsInRoot()
        val after = compose.onNodeWithText("after").getUnclippedBoundsInRoot()
        assertEquals(24.dp, after.top - before.bottom)
        assertTrue(model.builders.reportedMissing.isEmpty())
    }
}
