package com.orcagateway.sdk.widgets

import android.content.Context
import android.graphics.Bitmap
import android.view.View
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.test.core.app.ApplicationProvider
import com.orcagateway.core.client.DeviceInfo
import com.orcagateway.core.client.HttpRequest
import com.orcagateway.core.client.HttpResponse
import com.orcagateway.core.client.HttpTransport
import com.orcagateway.core.client.OrcaClient
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.NavConfig
import com.orcagateway.core.models.NavFlow
import com.orcagateway.core.models.NavRoute
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.models.TabDef
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.core.state.ActionEffect
import com.orcagateway.sdk.ORCA_ROUTE_TITLE_TAG
import com.orcagateway.sdk.OrcaApp
import com.orcagateway.sdk.OrcaPageLoader
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPageView
import com.orcagateway.sdk.OrcaPluginHost
import com.orcagateway.sdk.OrcaToast
import com.orcagateway.sdk.WidgetBuilders
import com.orcagateway.sdk.draw
import com.orcagateway.sdk.navigation.OrcaRouter
import com.orcagateway.sdk.navigation.ShellTree
import com.orcagateway.sdk.navigation.tabTag
import com.orcagateway.sdk.style.Props
import com.orcagateway.sdk.support.button
import com.orcagateway.sdk.support.column
import com.orcagateway.sdk.support.leaf
import com.orcagateway.sdk.support.page
import com.orcagateway.sdk.support.sizedBox
import com.orcagateway.sdk.support.text
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.net.URI
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * A8.1, the sheet: openDialog shows the keyed Dialog's children as Flutter's
 * OrcaPage shows them, `showModalBottomSheet` on the page's Navigator
 * (sdk/lib/src/widgets/orca_page.dart:323-374): a white panel with top
 * corners of 24, the heightFactor (0.5 when absent) of the height, at most
 * 640 wide and centred, from the bottom edge over a black54 barrier, in
 * 250 ms and out 200 on legacyDecelerate (MUI bottom_sheet.dart:29-31). A
 * barrier tap, a drag down, Back and closeDialog close the top sheet
 * (action_executor.dart:894-919), never a page; openDialog returns when its
 * sheet closes. What Android adds (D5): the page out of reach of
 * accessibility, the pane named as Flutter's route on Android, the scrim one
 * node, the focus taken and given back, the panel above the keyboard.
 * Robolectric, 1 dp per pixel, drawn in software for the colours, on the
 * test clock.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w300dp-h400dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class DialogTest {
    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private lateinit var view: View

    /** Whether the page's TextField has the focus (its builder reports it). */
    private var fieldFocused = false

    /** The runs a test started outside a page's scope (they may wait on a sheet): cancelled after it. */
    private val runs = MainScope()

    @After
    fun cancelRuns() {
        runs.coroutineContext[Job]?.cancel()
    }

    private val blue = Props.hex("#0000FF")

    /** Flutter's black54 barrier (0x8A000000, colors.dart) over blue: 117 of 255 left. */
    private val barrierOverBlue = Color(0f, 0f, 1f - 0x8A / 255f)

    // The sheet.

    /**
     * A8.1: the Dialog's child as a white panel half the height of the page
     * (FractionallySizedBox(heightFactor ?? 0.5), orca_page.dart:326,
     * :358-369) from its bottom edge, as wide as the child and centred (only
     * the sheet's Align gets the whole width, bottom_sheet.dart:417-421,
     * :618-621; the ConstrainedBox, the FractionallySizedBox and the
     * Container leave it loose), its top corners cut round at 24 (antiAlias),
     * over the barrier: black54 on the page around it (:1123, :1364).
     */
    @Test
    fun a8_1_openDialogShowsTheDialogsChildAsAWhitePanelOfHalfTheHeightOverABlack54Barrier() {
        val model = show()
        assertEquals(0, panels())

        compose.onNodeWithText("Open").performClick()
        compose.waitForIdle()

        // The child is a Column whose widest child is the "Change" button: the panel is that wide.
        val panel = bounds(DIALOG_PANEL_TAG)
        val change = compose.onNodeWithText("Change").getUnclippedBoundsInRoot()
        assertEquals(DpRect(change.left, 200.dp, change.right, 400.dp), panel)
        assertTrue(panel.right - panel.left < 150.dp, "narrower than the page: $panel")
        assertTrue(abs((300.dp - panel.right - panel.left).value) <= 1f, "centred: $panel")
        val note = compose.onNodeWithText("first").getUnclippedBoundsInRoot()
        assertTrue(note.top >= 200.dp && note.bottom <= 400.dp, "the Dialog's child is in the panel: $note")
        val picture = picture()
        val left = panel.left.value.toInt()
        val right = panel.right.value.toInt()
        for ((x, y) in listOf(5 to 190, left + 1 to 201, right - 2 to 201, 2 to 395, 297 to 395, left - 3 to 300)) {
            assertPixel(barrierOverBlue, picture, x, y)
        }
        for ((x, y) in listOf(150 to 395, left + 1 to 395, right - 2 to 395, left + 24 to 205)) assertPixel(Color.White, picture, x, y)
        assertEquals(1, model.dialogs.sheets.size)
    }

    /** A8.1: openDialog's heightFactor sizes the panel: 0.4 of 400 is 160. */
    @Test
    fun a8_1_aHeightFactorOf0_4MakesThePanel0_4OfTheHeight() {
        show()
        compose.onNodeWithText("Open 0.4").performClick()
        compose.waitForIdle()

        assertEquals(240.dp, bounds(DIALOG_PANEL_TAG).top)
        assertEquals(400.dp, bounds(DIALOG_PANEL_TAG).bottom)
    }

    /**
     * A8.1: on a screen wider than 640 a child wider still makes the panel
     * 640 wide, centred (M3's sheet constraints, bottom_sheet_defaults_m3
     * .g.dart:18, under the Align, bottom_sheet.dart:417-421).
     */
    @Test
    @Config(qualifiers = "w1000dp-h800dp-mdpi")
    fun a8_1_onAWideScreenThePanelIsAtMost640WideAndCentred() {
        show(width = 1000.dp, height = 800.dp, wide = true)
        compose.onNodeWithText("Open").performClick()
        compose.waitForIdle()

        assertEquals(DpRect(180.dp, 400.dp, 820.dp, 800.dp), bounds(DIALOG_PANEL_TAG))
    }

    /**
     * A8.1: the panel comes up in 250 ms and goes down in 200, the route's
     * time run through legacyDecelerate both ways (bottom_sheet.dart:29-31,
     * :695-699, :617-627): half way in time it is already more than three
     * quarters up (0.84; linear would be half), on the way in and out.
     */
    @Test
    fun a8_1_theSheetSlidesIn250AndOut200OnLegacyDecelerate() {
        show()
        compose.mainClock.autoAdvance = false
        compose.onNodeWithText("Open").performClick()
        compose.mainClock.advanceTimeBy(128)
        val coming = bounds(DIALOG_PANEL_TAG).top
        assertTrue(coming > 216.dp && coming < 256.dp, "about 0.84 up half way in: $coming")
        compose.mainClock.advanceTimeBy(200)
        assertEquals(200.dp, bounds(DIALOG_PANEL_TAG).top)

        compose.onNodeWithText("Close").performClick()
        compose.mainClock.advanceTimeBy(100)
        val going = bounds(DIALOG_PANEL_TAG).top
        assertTrue(going > 216.dp && going < 256.dp, "still about 0.84 up half way out: $going")
        compose.mainClock.advanceTimeBy(150)
        assertEquals(0, panels())
    }

    /** A8.1: a tap on the barrier closes the sheet (ModalBarrier, bottom_sheet.dart:1117), whatever `dismissible` says. */
    @Test
    fun a8_1_aBarrierTapClosesTheSheet() {
        val model = show()
        compose.onNodeWithText("Open").performClick()
        compose.waitForIdle()
        assertEquals(1, panels())

        compose.onRoot().performTouchInput { click(Offset(150f, 100f)) }
        compose.waitForIdle()
        assertEquals(0, panels())
        assertEquals(0, model.dialogs.sheets.size)
        compose.onNodeWithText("Page").assertExists()
    }

    /**
     * A8.1: OrcaPage awaits the sheet (orca_page.dart:346), so in a
     * sequential group the action after openDialog runs only once it closes.
     */
    @Test
    fun a8_1_inASequentialGroupTheNextActionRunsOnlyOnceTheSheetCloses() {
        val model = show()
        compose.onNodeWithText("Then").performClick()
        compose.waitForIdle()
        assertEquals(1, panels())
        assertEquals(JsonValue.Bool(false), model.store.state.page["after"])

        compose.onNodeWithText("Close").performClick()
        compose.waitForIdle()
        assertEquals(JsonValue.Bool(true), model.store.state.page["after"])
    }

    /**
     * A8.1: closeDialog closes the top sheet only, one per call, and with
     * none open does nothing (action_executor.dart:896-919); neither kind
     * emits an effect.
     */
    @Test
    fun a8_1_closeDialogClosesTheTopSheetOnePerCallAndWithNoneOpenNothing() {
        val model = show()
        val effects = mutableListOf<ActionEffect>()
        model.onEffect = { effects += it }
        open(model)
        open(model, 0.4)
        compose.waitForIdle()
        assertEquals(2, panels())
        assertEquals(listOf(0.5, 0.4), model.dialogs.sheets.map { it.sheet.heightFactor })

        run(model, Action.CloseDialog)
        compose.waitForIdle()
        assertEquals(1, panels())
        assertEquals(200.dp, bounds(DIALOG_PANEL_TAG).top)

        run(model, Action.CloseDialog)
        compose.waitForIdle()
        assertEquals(0, panels())
        run(model, Action.CloseDialog)
        compose.waitForIdle()
        compose.onNodeWithText("Page").assertExists()
        assertEquals(emptyList<ActionEffect>(), effects)
    }

    /** A8.1: closeDialog with no sheet open never pops the page under it (action_executor.dart:903-912). */
    @Test
    fun a8_1_closeDialogWithNoSheetOpenNeverPopsAPage() {
        val router = OrcaRouter(Pages().client, stackConfig)
        showApp(router)
        compose.runOnUiThread { router.navigate("/next") }
        compose.waitUntil(5_000) { count("next page") == 1 }

        run(model(router), Action.CloseDialog)
        compose.waitForIdle()
        assertEquals(1, router.stack.size)
        assertEquals(1, count("next page"))
    }

    /** A8.1: the sheet is drawn with the page's stores and executor: a state change from inside it redraws it there. */
    @Test
    fun a8_1_aStateChangeRedrawsInsideTheSheet() {
        val model = show()
        compose.onNodeWithText("Open").performClick()
        compose.waitForIdle()

        compose.onNodeWithText("Change").performClick()
        compose.waitForIdle()
        assertEquals(JsonValue.String("changed"), model.store.state.page["note"])
        compose.onNodeWithText("changed").assertExists()
    }

    /**
     * A8.1: a drag moves the panel with the finger; let go above half its
     * height it goes back up, below half, or flung down at 700 or more, it
     * closes (bottom_sheet.dart:32-33, :280-324). The touch slop is 16 here.
     */
    @Test
    fun a8_1_aDragMovesThePanelPastHalfOrFlungItClosesElseItGoesBack() {
        val model = show()
        compose.onNodeWithText("Then").performClick()
        compose.waitForIdle()

        compose.onNodeWithTag(DIALOG_PANEL_TAG).performTouchInput {
            down(Offset(10f, 150f))
            moveBy(Offset(0f, 17f))
            repeat(3) { moveBy(Offset(0f, 10f), delayMillis = 100) }
        }
        compose.waitForIdle()
        // With the finger, 1:1 past the slop: 1 over it, then 30 (on the curve it would be within 2 of the top).
        assertEquals(231f, bounds(DIALOG_PANEL_TAG).top.value, 0.5f)
        compose.onNodeWithTag(DIALOG_PANEL_TAG).performTouchInput { up() }
        compose.waitForIdle()
        assertEquals(200.dp, bounds(DIALOG_PANEL_TAG).top)
        assertEquals(1, panels())

        compose.onNodeWithTag(DIALOG_PANEL_TAG).performTouchInput {
            // Clear of the panel's buttons, and on screen all the way.
            down(Offset(10f, 30f))
            moveBy(Offset(0f, 17f))
            repeat(12) { moveBy(Offset(0f, 10f), delayMillis = 100) }
            up()
        }
        compose.waitForIdle()
        assertEquals(0, panels())
        assertEquals(JsonValue.Bool(true), model.store.state.page["after"])

        compose.onNodeWithText("Open").performClick()
        compose.waitForIdle()
        compose.onNodeWithTag(DIALOG_PANEL_TAG).performTouchInput {
            down(Offset(10f, 150f))
            moveBy(Offset(0f, 17f))
            repeat(3) { moveBy(Offset(0f, 10f), delayMillis = 5) }
            up()
        }
        compose.waitForIdle()
        assertEquals(0, panels())
    }

    /** A8.1: Back closes the top sheet, one per press, before it pops the page (a popup route pops first). */
    @Test
    fun a8_1_backClosesTheTopSheetOnePerPressBeforeThePage() {
        val router = OrcaRouter(Pages().client, stackConfig)
        showApp(router)
        compose.runOnUiThread { router.navigate("/next") }
        compose.waitUntil(5_000) { count("next page") == 1 }
        val model = model(router)
        open(model)
        open(model)
        compose.waitForIdle()
        assertEquals(2, panels())

        back()
        assertEquals(1, panels())
        back()
        assertEquals(0, panels())
        assertEquals(1, router.stack.size)
        back()
        assertEquals(0, router.stack.size)
    }

    // Accessibility, focus and the keyboard (D5).

    /**
     * A8.1: while a sheet is open the page under it is out of reach of
     * accessibility (ModalBarrier's BlockSemantics, modal_barrier.dart:260),
     * and the panel is a pane named as Flutter names the sheet's route on
     * Android, "Dialog" (bottom_sheet.dart:726-732, :777, :801-805;
     * material_localizations.dart:1122). The page is back once it closes.
     */
    @Test
    fun a8_1_whileOpenThePageIsOutOfReachAndThePanelIsAPaneNamedDialog() {
        show()
        compose.onNodeWithText("Page").assertExists()
        compose.onNodeWithText("Open").performClick()
        compose.waitForIdle()

        assertEquals(0, count("Page"))
        assertEquals(0, count("Open"))
        val pane = SemanticsMatcher.expectValue(SemanticsProperties.PaneTitle, "Dialog")
        compose.onNode(pane).assertExists()
        compose.onNode(hasText("first") and hasAnyAncestor(pane)).assertExists()

        compose.onNodeWithText("Close").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Page").assertExists()
        assertEquals(0, compose.onAllNodes(pane).fetchSemanticsNodes().size)
    }

    /**
     * A8.1: the barrier is one accessibility node, "Scrim", over the part
     * of the page above the panel (the clip of bottom_sheet.dart:734-736,
     * :806-811), whose click, "Close Bottom Sheet", and dismiss close the
     * sheet (modal_barrier.dart:233-238; bottom_sheet.dart:1356-1357;
     * material_localizations.dart:1137-1143).
     */
    @Test
    fun a8_1_theScrimIsOneNodeWhoseClickClosesTheSheet() {
        show()
        compose.onNodeWithText("Open").performClick()
        compose.waitForIdle()

        val scrims = compose.onAllNodes(hasContentDescription("Scrim")).fetchSemanticsNodes()
        assertEquals(1, scrims.size)
        val scrim = compose.onNode(hasContentDescription("Scrim"))
        assertEquals(DpRect(0.dp, 0.dp, 300.dp, 200.dp), scrim.getUnclippedBoundsInRoot())
        val config = scrim.fetchSemanticsNode().config
        assertEquals("Close Bottom Sheet", config.getOrNull(SemanticsActions.OnClick)?.label)
        assertTrue(config.getOrNull(SemanticsActions.Dismiss) != null, "a dismiss action")

        scrim.performSemanticsAction(SemanticsActions.OnClick)
        compose.waitForIdle()
        assertEquals(0, panels())
    }

    /**
     * A8.1: the sheet takes the focus from the page as Flutter's route does
     * (its FocusScope, routes.dart:1095-1160, :1201), so a field of the page
     * loses it and its keyboard; once the sheet closes, the field has it
     * again.
     */
    @Test
    fun a8_1_theSheetTakesTheFocusAndGivesItBackToTheFieldThatHadIt() {
        val model = show(field = true)
        val field = SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText)
        compose.onNode(field).performClick()
        compose.onNode(field).assertIsFocused()
        assertTrue(fieldFocused)

        open(model)
        compose.waitForIdle()
        assertFalse(fieldFocused, "the field lost the focus to the sheet")
        assertEquals(0, compose.onAllNodes(field).fetchSemanticsNodes().size)

        compose.onNode(hasContentDescription("Scrim")).performSemanticsAction(SemanticsActions.OnClick)
        compose.waitForIdle()
        assertTrue(fieldFocused, "the field has it again")
        compose.onNode(field).assertIsFocused()
    }

    /**
     * A8.1: with the keyboard up the panel stands on it, lifted by its
     * height, the barrier still the whole page (beyond Flutter, whose sheet
     * the keyboard covers: a known difference, the user's call).
     */
    @Test
    fun a8_1_thePanelStandsOnTheKeyboard() {
        val model = show()
        open(model)
        compose.waitForIdle()
        keyboard(120)

        assertEquals(80.dp, bounds(DIALOG_PANEL_TAG).top)
        assertEquals(280.dp, bounds(DIALOG_PANEL_TAG).bottom)
        assertPixel(barrierOverBlue, picture(), 5, 300)
    }

    /** A8.1: a page torn down with sheets open lets every openDialog waiting on them return (risk 7). */
    @Test
    fun a8_1_aPageTornDownWithSheetsOpenResumesEveryWaiter() {
        val model = show()
        val first = open(model)
        val second = open(model)
        compose.waitForIdle()
        assertEquals(2, panels())
        assertTrue(first.isActive && second.isActive, "both wait on their sheet")

        compose.runOnUiThread { model.close() }
        compose.waitForIdle()
        assertTrue(first.isCompleted && second.isCompleted, "both returned")
        assertEquals(0, model.dialogs.sheets.size)
    }

    /**
     * A8.1: the tab shell's own trees (tab bar, drawer) are no page:
     * Flutter's shell executor has no onOpenDialog (orca_shell.dart), so
     * openDialog there opens no sheet and does not wait (action_executor.dart
     * :862-871). The twin of Swift's testA8_1_AShellTreeOpensNoSheetAndDoesNotWait.
     */
    @Test
    fun a8_1_aShellTreeOpensNoSheetAndDoesNotWait() {
        val router = OrcaRouter(Pages().client, tabConfig)
        lateinit var tree: ShellTree
        compose.runOnUiThread { tree = ShellTree(router, listOf(column("c", "t", "d"), text("t", "tab bar")) + dialog()) }
        val run = open(tree.model)
        compose.waitForIdle()

        assertTrue(run.isCompleted, "openDialog in a shell tree waits")
        assertEquals(0, tree.model.dialogs.sheets.size)
        compose.runOnUiThread { tree.close() }
    }

    // Where the sheet is drawn.

    /**
     * A8.1: the sheet's route is above the page's: it covers the page's
     * AppBar and the snackbar bar its Scaffold draws for the root
     * ScaffoldMessenger (the page route under the popup route in the
     * Navigator's overlay; the bar inside the page's Scaffold,
     * scaffold.dart:3276).
     */
    @Test
    fun a8_1_theSheetCoversThePagesAppBarAndTheBarItsScaffoldDraws() {
        val model = show(scaffold = true)
        compose.mainClock.autoAdvance = false
        compose.runOnUiThread { model.snackbars.show(OrcaToast.Style.Snackbar, "Saved", null) }
        compose.mainClock.advanceTimeBy(400)
        assertEquals(DpRect(0.dp, 352.dp, 300.dp, 400.dp), bounds(SNACKBAR_BAR_TAG))
        val bar = Props.hex("#322F35")
        val before = picture()
        assertPixel(bar, before, 150, 390)
        val appBar = Color(before.getPixel(150, 10))

        open(model)
        compose.mainClock.advanceTimeBy(400)
        val after = picture()
        assertPixel(Color.White, after, 150, 390)
        assertPixel(Color(appBar.red * (1f - 0x8A / 255f), appBar.green * (1f - 0x8A / 255f), appBar.blue * (1f - 0x8A / 255f)), after, 150, 10)
        assertEquals(0, count("Saved"))
        assertEquals(0, count("Title"))
    }

    /**
     * A8.1: under tabs the sheet is on the tab's Navigator, in the shell's
     * body (orca_shell.dart:117-129): the tab bar stays uncovered and in
     * reach, and the shell's snackbar bar, painted after its body
     * (scaffold.dart:3197, :3276), is over the sheet. Back does not close a
     * sheet on a tab no longer shown.
     */
    @Test
    fun a8_1_underTabsTheSheetLeavesTheTabBarAndTheShellsBarOverIt() {
        val router = OrcaRouter(Pages().client, tabConfig)
        showApp(router)
        compose.waitUntil(5_000) { count("home page") == 1 }
        val tabTop = bounds(tabTag(0)).top
        open(model(router))
        compose.waitForIdle()

        assertEquals(tabTop, bounds(DIALOG_PANEL_TAG).bottom)
        assertEquals(1, compose.onAllNodes(hasTestTag(tabTag(1))).fetchSemanticsNodes().size)
        // The clock moves only when told from here: a queue holding a bar asks for every frame.
        compose.mainClock.autoAdvance = false
        compose.runOnUiThread { router.snackbars.show(OrcaToast.Style.Snackbar, "Saved", null) }
        compose.mainClock.advanceTimeBy(400)
        assertEquals(tabTop, bounds(SNACKBAR_BAR_TAG).bottom)
        assertEquals(1, count("Saved"))
        assertPixel(Props.hex("#322F35"), picture(), 150, (tabTop.value - 5).toInt())

        compose.onNodeWithTag(tabTag(1)).performClick()
        compose.mainClock.advanceTimeBy(500)
        compose.waitUntil(5_000) { count("plain page") == 1 }
        assertFalse(backIsHandled(), "the hidden tab's sheet takes no Back")
    }

    /**
     * A8.1: a route with a title is wrapped in Flutter's title-bar Scaffold
     * inside its route (navigation_handler.dart:111-147): the sheet covers
     * that bar too, the whole route's height.
     */
    @Test
    fun a8_1_aTitledRoutesSheetCoversItsTitleBar() {
        val router = OrcaRouter(Pages().client, tabConfig.copy(initialRoute = "/settings"))
        showApp(router)
        compose.waitUntil(5_000) { count("settings page") == 1 }
        compose.onNodeWithTag(ORCA_ROUTE_TITLE_TAG).assertExists()
        val screen = compose.onRoot().getUnclippedBoundsInRoot()
        open(model(router))
        compose.waitForIdle()

        assertEquals(screen.bottom / 2, bounds(DIALOG_PANEL_TAG).top)
        assertEquals(screen.bottom, bounds(DIALOG_PANEL_TAG).bottom)
        assertEquals(0, compose.onAllNodes(hasTestTag(ORCA_ROUTE_TITLE_TAG)).fetchSemanticsNodes().size)
    }

    /**
     * A8.1 (risk 5): Flutter's OrcaPage registers its openDialog after the
     * host's custom actions (orca_page.dart:318-323), so it beats a custom
     * one; closeDialog is a built-in a custom one replaces
     * (action_executor.dart:155-156, :896).
     */
    @Test
    fun a8_1_thePagesOpenDialogBeatsACustomOneAndACustomCloseDialogReplacesTheSdks() {
        val calls = mutableListOf<String>()
        val pages = Pages()
        val router = OrcaRouter(pages.client, stackConfig)
        router.plugins = OrcaPluginHost.merge(
            pages.client,
            emptyList(),
            mapOf(
                "openDialog" to OrcaActionHandler { _, _ -> calls += "custom openDialog" },
                "closeDialog" to OrcaActionHandler { _, _ -> calls += "custom closeDialog" },
            ),
            dialogWidgets(),
        )
        val loader = router.loader(router.root)
        runBlocking { loader.reload(ApplicationProvider.getApplicationContext<Context>()) }
        val model = (loader.phase as OrcaPageLoader.Phase.Loaded).model

        runBlocking {
            val waiting = launch(start = CoroutineStart.UNDISPATCHED) { model.run(Action.OpenDialog("d")) }
            assertEquals(1, model.dialogs.sheets.size)
            model.run(Action.CloseDialog)
            assertEquals(listOf("custom closeDialog"), calls)
            assertEquals(1, model.dialogs.sheets.size)
            assertTrue(waiting.isActive)
            model.close()
            waiting.join()
        }
    }

    // Helpers.

    /**
     * Page `p` in a [width] x [height] box under OrcaPageView: a blue
     * Container 300 x 400 holding a Column of "Page", the buttons "Open",
     * "Open 0.4" and "Then" (openDialog then `after` = true), with [field]
     * a TextField, and the Dialog `d`, whose child is a Column of the page
     * state `note` ("first"), "Change" (`note` = "changed") and "Close"
     * (closeDialog); with [wide] its child is a SizedBox 2000 wide instead.
     * With [scaffold] the Container is the body of a Scaffold with an AppBar
     * titled "Title".
     */
    private fun show(
        width: Dp = 300.dp,
        height: Dp = 400.dp,
        field: Boolean = false,
        scaffold: Boolean = false,
        wide: Boolean = false,
    ): OrcaPageModel {
        val nodes = buildList {
            if (scaffold) {
                add(structure("s", "Scaffold", mapOf("appBar" to "bar", "body" to "bg")))
                add(structure("bar", "AppBar", mapOf("title" to "bt")))
                add(text("bt", "Title"))
            }
            add(
                ComponentNode(
                    "bg", "Container", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single,
                    mapOf("color" to JsonValue.String("#0000FF"), "width" to JsonValue.Int(300), "height" to JsonValue.Int(400)),
                    listOf("c"),
                ),
            )
            val children = listOfNotNull("t", "open", "open4", "then", if (field) "f" else null, "d")
            add(column("c", *children.toTypedArray()))
            add(text("t", "Page"))
            add(button("open", "ElevatedButton", "ot", mapOf("onTap" to Action.OpenDialog("d"))))
            add(text("ot", "Open"))
            add(button("open4", "ElevatedButton", "o4", mapOf("onTap" to Action.OpenDialog("d", 0.4))))
            add(text("o4", "Open 0.4"))
            add(button("then", "ElevatedButton", "tt", mapOf("onTap" to openThenAfter)))
            add(text("tt", "Then"))
            if (field) add(leaf("f", "TextField"))
            if (wide) {
                add(ComponentNode("d", "Dialog", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, children = listOf("dc")))
                add(sizedBox("dc", width = 2000, height = 10))
            } else {
                addAll(dialog())
            }
        }
        val state = listOf(
            StateDefinition("note", StateScope.Page, JsonValue.String("first")),
            StateDefinition("after", StateScope.Page, JsonValue.Bool(false)),
        )
        val model = OrcaPageModel(page(*nodes.toTypedArray(), state = state), registry = dialogRegistry)
        model.builders = dialogWidgets().apply {
            register("TextField") { node, page, modifier ->
                TextFieldWidget(node, page, modifier.onFocusChanged { fieldFocused = it.hasFocus })
            }
        }
        model.registerCloseDialog()
        model.registerOpenDialog()
        compose.setContent {
            view = LocalView.current
            Box(Modifier.size(width, height)) { OrcaPageView(model) }
        }
        compose.waitForIdle()
        return model
    }

    /** The router's app under OrcaApp, Dialog known to its pages. */
    private fun showApp(router: OrcaRouter) {
        compose.setContent {
            view = LocalView.current
            OrcaApp(router, widgets = dialogWidgets())
        }
        compose.waitForIdle()
    }

    /** The loaded model of the router's page on top. */
    private fun model(router: OrcaRouter): OrcaPageModel {
        var model: OrcaPageModel? = null
        compose.waitUntil(5_000) {
            model = (router.loader(router.top).phase as? OrcaPageLoader.Phase.Loaded)?.model
            model != null
        }
        return model!!
    }

    /** openDialog `d` run on [model] from outside its scope; the job ends when the sheet closes. */
    private fun open(model: OrcaPageModel, heightFactor: Double? = null): Job = run(model, Action.OpenDialog("d", heightFactor))

    private fun run(model: OrcaPageModel, action: Action): Job {
        lateinit var job: Job
        compose.runOnUiThread { job = runs.launch(start = CoroutineStart.UNDISPATCHED) { model.run(action) } }
        return job
    }

    private fun back() {
        compose.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        compose.waitForIdle()
    }

    private fun backIsHandled(): Boolean {
        compose.waitForIdle()
        var handled = false
        compose.activityRule.scenario.onActivity { handled = it.onBackPressedDispatcher.hasEnabledCallbacks() }
        return handled
    }

    /** The keyboard up, [height] pixels (dp at mdpi), delivered as the platform does (SnackbarBarTest's harness). */
    private fun keyboard(height: Int) {
        val insets = WindowInsetsCompat.Builder()
            .setInsets(WindowInsetsCompat.Type.ime(), Insets.of(0, 0, 0, height))
            .setVisible(WindowInsetsCompat.Type.ime(), true)
            .build()
        compose.runOnIdle { ViewCompat.dispatchApplyWindowInsets(view, insets) }
        compose.waitForIdle()
    }

    /** The panels on screen: a kept page under the one on top is composed and not placed. */
    private fun panels(): Int =
        compose.onAllNodes(hasTestTag(DIALOG_PANEL_TAG)).fetchSemanticsNodes().count { it.layoutInfo.isPlaced }

    private fun bounds(tag: String): DpRect = compose.onNodeWithTag(tag, useUnmergedTree = true).getUnclippedBoundsInRoot()

    private fun count(text: String): Int =
        compose.onAllNodes(hasText(text)).fetchSemanticsNodes().count { it.layoutInfo.isPlaced }

    private fun picture(): Bitmap {
        compose.waitForIdle()
        return draw(view)
    }

    private fun assertPixel(expected: Color, picture: Bitmap, x: Int, y: Int, tolerance: Float = 0.03f) {
        val actual = picture.getPixel(x, y)
        val channels = listOf(
            expected.red to android.graphics.Color.red(actual) / 255f,
            expected.green to android.graphics.Color.green(actual) / 255f,
            expected.blue to android.graphics.Color.blue(actual) / 255f,
        )
        assertTrue(
            channels.all { (want, got) -> abs(want - got) < tolerance },
            "($x, $y) is #${Integer.toHexString(actual)}, expected $expected",
        )
    }

    private companion object {
        /** The core knows Dialog and TextField (standard() takes Dialog in K-caps). */
        val dialogRegistry = WidgetRegistry(types = WidgetRegistry.shared.types + setOf("Dialog", "TextField"))

        /** The standard builders and the Dialog, drawn in place as Flutter's `SizedBox.shrink()`. */
        fun dialogWidgets() = WidgetBuilders.standard().apply {
            register("Dialog") { node, _, modifier -> DialogWidget(modifier.testTag(node.id)) }
        }

        /** openDialog `d`, then `after` = true: a sequential group. */
        val openThenAfter = Action.ActionGroup(
            mode = "sequential",
            actions = listOf(Action.OpenDialog("d"), Action.SetState(key = "after", value = JsonValue.Bool(true))),
        )

        /** The Dialog `d` and its child, a Column of the state `note`, "Change" and "Close". */
        fun dialog(): List<ComponentNode> = listOf(
            ComponentNode("d", "Dialog", ComponentNode.Kind.Layout, ComponentNode.ChildMode.Single, children = listOf("dc")),
            column("dc", "dt", "change", "close"),
            ComponentNode(
                "dt", "Text", ComponentNode.Kind.Primitive, ComponentNode.ChildMode.None,
                mapOf("data" to JsonValue.obj("type" to "state", "key" to "note")), watches = listOf("note"),
            ),
            button("change", "ElevatedButton", "ct", mapOf("onTap" to Action.SetState(key = "note", value = JsonValue.String("changed")))),
            text("ct", "Change"),
            button("close", "ElevatedButton", "cl", mapOf("onTap" to Action.CloseDialog)),
            text("cl", "Close"),
        )

        /** A structure node, its slot props holding the ids of nodes listed as its children. */
        fun structure(id: String, type: String, slots: Map<String, String>) = ComponentNode(
            id, type, ComponentNode.Kind.Structure, ComponentNode.ChildMode.None,
            slots.mapValues { JsonValue.String(it.value) }, slots.values.toList(),
        )

        /** `/home` and `/next`, no tabs. */
        val stackConfig = NavConfig(
            initialRoute = "/home",
            flows = listOf(NavFlow(name = "main", routes = listOf(NavRoute("home"), NavRoute("next")))),
        )

        /** Tabs `/home` and `/plain`, and `/settings` beside them (a titled route). */
        val tabConfig = NavConfig(
            initialRoute = "/home",
            tabs = listOf(TabDef("home", "Home", "home", "/home"), TabDef("plain", "Plain", "search", "/plain")),
            flows = listOf(NavFlow(name = "main", routes = listOf(NavRoute("home"), NavRoute("plain"), NavRoute("settings")))),
        )
    }

    /** Each page a Column of "<name> page" and the Dialog `d`; `plain` the text alone. */
    private class Pages : HttpTransport {
        override suspend fun send(request: HttpRequest): HttpResponse {
            val name = request.url.path.substringAfterLast("/page/")
            val nodes = if (name == "plain") {
                listOf(column("c", "t"), text("t", "plain page"))
            } else {
                listOf(column("c", "t", "d"), text("t", "$name page")) + dialog()
            }
            val state = listOf(StateDefinition("note", StateScope.Page, JsonValue.String("first")))
            val page = PageResponse(pageId = name, title = name, state = state, components = nodes)
            return HttpResponse(200, body = Json.encodeToString(PageResponse.serializer(), page).encodeToByteArray())
        }

        val client: OrcaClient
            get() = OrcaClient(URI("http://stub.invalid"), appId = "app", device = DeviceInfo(osVersion = "test"), transport = this)
    }
}
