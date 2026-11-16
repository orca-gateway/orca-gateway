package com.orcagateway.plugins.googlemap

import android.Manifest
import android.content.pm.PackageManager
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertHeightIsEqualTo
import androidx.compose.ui.test.assertWidthIsEqualTo
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.unit.dp
import com.google.maps.android.compose.MapType
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.Action
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.models.PageResponse
import com.orcagateway.core.models.StateDefinition
import com.orcagateway.core.models.StateScope
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.plugins.PluginMerger
import com.orcagateway.core.plugins.TriggerDefinition
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.render.WidgetRegistry
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.toParts
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.w3c.dom.Element
import java.io.File
import java.util.Properties
import javax.xml.parsers.DocumentBuilderFactory
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

/** The test tag of the fake map's box. */
private const val MAP_TAG = "googleMap.fake"

/** The node id /map gives its map, moveCamera's targetId. */
private const val ID = "main-map"

/** The android: attributes' namespace in a manifest. */
private const val ANDROID = "http://schemas.android.com/apk/res/android"

private val TRIGGERS = listOf("onTap", "onLongPress", "onCameraMove", "onMarkerTap")

/** A drawn map's camera that moves nowhere: the test reads where the plugin sent it. */
private class FakeCamera : MapCamera {
    val moves = ArrayList<MapCameraPosition>()

    override fun animateTo(position: MapCameraPosition) {
        moves += position
    }
}

/**
 * A map that draws an empty box: it writes down what each draw was given,
 * keeps the events to tell the plugin what the user did, and is made (Flutter's
 * onMapCreated) only when the test says so.
 */
private class FakeSurface : MapSurface {
    val drawn = ArrayList<MapOptions>()
    val cameras = ArrayList<MapCameraPosition>()
    var events: MapEvents? = null

    /** Each map's events, in the order the maps were first drawn. */
    val maps = ArrayList<MapEvents>()

    @Composable
    override fun Draw(options: MapOptions, camera: MapCameraPosition, events: MapEvents, modifier: Modifier) {
        drawn += options
        cameras += camera
        this.events = events
        if (maps.none { it === events }) maps += events
        Box(modifier.testTag(MAP_TAG))
    }

    /** The map is there: the plugin gets [camera] to move. */
    fun create(camera: FakeCamera = FakeCamera()): FakeCamera {
        assertNotNull(events, "a map is drawn").created(camera)
        return camera
    }
}

/**
 * C17.1/K: the map on Android does what Flutter's
 * plugins/orca_google_map/lib/src/google_map_plugin.dart does on
 * google_maps_flutter 2.17.0 (google_maps_flutter_android 2.19.5): the
 * widget's props and defaults (:89-123), the camera read once as
 * initialCameraPosition (:126-129), mapType, myLocationEnabled (only while
 * the app holds a location permission, as GoogleMapController checks),
 * zoomControlsEnabled and the markers following the props (:130-133), a map
 * per node id registered when it is made (:134-136), the four triggers with
 * Flutter's payloads (:137-150), and moveCamera's resolution (:153-171).
 * Robolectric cannot draw Google Maps: Maps Compose is behind MapSurface,
 * a fake here; the real GoogleMap composable is the hand check's.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class GoogleMapPluginTest {
    @get:Rule
    val compose = createComposeRule()

    private val surface = FakeSurface()
    private val plugin = GoogleMapPlugin(surface)

    /** What the node's triggers ran, in order: the trigger and the event data its action read. */
    private val fired = ArrayList<Pair<String, Map<String, JsonValue>>>()

    private val model = OrcaPageModel(
        PageResponse(
            pageId = "p",
            title = "P",
            state = listOf(
                StateDefinition("target", StateScope.Page, JsonValue.String(ID)),
                StateDefinition("lat", StateScope.Page, JsonValue.Double(48.8566)),
                StateDefinition("lng", StateScope.Page, JsonValue.Double(2.3522)),
                StateDefinition("z", StateScope.Page, JsonValue.Int(11)),
            ),
        ),
    ).also { model ->
        for ((type, handler) in plugin.actions) model.executor.registerHandler(type, handler)
        model.executor.registerHandler(
            "fired",
            OrcaActionHandler { action, executor ->
                val trigger = assertNotNull(JsonValue.fromJsonElement(assertNotNull(action["trigger"])).stringValue)
                val data = LinkedHashMap<String, JsonValue>()
                for (key in listOf("latitude", "longitude", "zoom", "markerId")) {
                    val value = JsonValue.fromJsonElement(executor.resolve(event(key).toJsonElement()))
                    if (!value.isNull) data[key] = value
                }
                fired += trigger to data
            },
        )
    }

    private var shown: ResolvedNode? by mutableStateOf(null)

    /** A second map drawn over the first, when a test wants two. */
    private var second: ResolvedNode? by mutableStateOf(null)
    private var box: Modifier by mutableStateOf(Modifier.width(320.dp))

    private fun event(key: String) = JsonValue.obj("type" to "event", "key" to key)

    private fun pageState(key: String) = JsonValue.obj("type" to "state", "key" to key, "scope" to "page")

    /** A resolved GoogleMap node with [props]; with [triggers], each of its four triggers runs `custom:fired`. */
    private fun node(vararg props: Pair<String, JsonValue>, id: String = ID, triggers: Boolean = true) = ResolvedNode(
        id = id,
        type = "GoogleMap",
        kind = ComponentNode.Kind.Primitive,
        props = mapOf(*props),
        childIds = emptyList(),
        slots = emptyMap(),
        actions = if (triggers) {
            TRIGGERS.associateWith { Action.Custom(JsonValue.obj("type" to "custom:fired", "trigger" to it)) }
        } else {
            emptyMap()
        },
        watches = emptyList(),
    )

    /** Draw [node] through the plugin's builder in [box] (320 dp wide unless the test says otherwise). */
    private fun show(node: ResolvedNode) {
        shown = node
        val builder = plugin.widgets.getValue("GoogleMap")
        compose.setContent {
            Box(box) {
                shown?.let { builder(it, model, Modifier) }
                second?.let { builder(it, model, Modifier) }
            }
        }
        compose.waitForIdle()
    }

    /** Draw [node] in place of the one shown (null takes the map away). */
    private fun reshow(node: ResolvedNode?) {
        shown = node
        compose.waitForIdle()
    }

    /** Run the action `custom:<name>` with [params] as a page does: through the page's executor. */
    private fun run(name: String, vararg params: Pair<String, Any?>) = runBlocking {
        model.executor.execute(Action.Custom(JsonValue.obj("type" to "custom:$name", *params)))
    }

    private fun at(latitude: Double, longitude: Double, zoom: Double) = MapCameraPosition(latitude, longitude, zoom)

    private fun options(
        mapType: MapType = MapType.NORMAL,
        myLocationEnabled: Boolean = false,
        zoomControlsEnabled: Boolean = true,
        markers: List<MapMarker> = emptyList(),
    ) = MapOptions(mapType, myLocationEnabled, zoomControlsEnabled, markers)

    private fun latLng(latitude: Double, longitude: Double) =
        mapOf<String, JsonValue>("latitude" to JsonValue.Double(latitude), "longitude" to JsonValue.Double(longitude))

    @Test
    fun c17_1_thePluginHasFluttersNameWidgetActionAndFourTriggers() {
        assertEquals("GoogleMapPlugin", plugin.name)
        assertEquals(setOf("GoogleMap"), plugin.widgets.keys)
        assertEquals(setOf("moveCamera"), plugin.actions.keys)
        assertEquals(
            mapOf(
                "GoogleMap" to listOf(
                    TriggerDefinition("onTap", "LatLng", "Fires when the map is tapped with {latitude, longitude}"),
                    TriggerDefinition("onLongPress", "LatLng", "Fires on long press with {latitude, longitude}"),
                    TriggerDefinition(
                        "onCameraMove",
                        "CameraPosition",
                        "Fires during camera movement with {latitude, longitude, zoom}",
                    ),
                    TriggerDefinition("onMarkerTap", "String", "Fires when a marker is tapped with {markerId}"),
                ),
            ),
            plugin.triggers,
        )

        val merged = PluginMerger.merge(builtInWidgets = WidgetRegistry.shared.types, plugins = listOf(plugin.toParts()))
        assertEquals(setOf("GoogleMap"), merged.pluginWidgetTypes)
        assertEquals(setOf("moveCamera"), merged.pluginActionTypes)

        // What a host makes: Flutter's GoogleMapPlugin() takes nothing, nor does this one; it draws with Maps Compose.
        val device = GoogleMapPlugin()
        assertEquals("GoogleMapPlugin", device.name)
        assertEquals(setOf("GoogleMap"), device.widgets.keys)
        assertEquals(setOf("moveCamera"), device.actions.keys)
        assertSame(GoogleMapSurface, device.surface)
    }

    /** The yaml's two permissions, merged into the app; the plugin never asks for them, as google_maps_flutter does not. */
    @Test
    fun c17_1_theModuleManifestDeclaresBothLocationPermissions() {
        val context = RuntimeEnvironment.getApplication()
        val info = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
        val requested = info.requestedPermissions.orEmpty().toSet()
        assertTrue(Manifest.permission.ACCESS_FINE_LOCATION in requested)
        assertTrue(Manifest.permission.ACCESS_COARSE_LOCATION in requested)
    }

    /**
     * Apache's HTTP client, gone from apps targeting API 28+ unless their manifest asks for it: the
     * Maps renderer in Google Play services can need it, so the library declares it, not required, as
     * google_maps_flutter_android 2.19.5 does, and the merger hands it to the app. Robolectric's
     * PackageInfo carries no uses-library: this reads the merged manifest Robolectric itself reads,
     * the one AGP names in test_config.properties.
     */
    @Test
    fun c17_1_theModuleManifestDeclaresApacheHttpLegacyNotRequired() {
        val config = Properties()
        assertNotNull(javaClass.classLoader?.getResourceAsStream("com/android/tools/test_config.properties")).use { config.load(it) }
        val merged = File(assertNotNull(config.getProperty("android_merged_manifest")))
        val factory = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
        val libraries = factory.newDocumentBuilder().parse(merged).getElementsByTagName("uses-library")
        val legacy = assertNotNull(
            (0 until libraries.length).map { libraries.item(it) as Element }
                .singleOrNull { it.getAttributeNS(ANDROID, "name") == "org.apache.http.legacy" },
            "the merged manifest declares org.apache.http.legacy",
        )
        assertEquals("application", legacy.parentNode.nodeName)
        assertEquals("false", legacy.getAttributeNS(ANDROID, "required"))
    }

    /** Flutter's defaults: 0, 0, zoom 14, normal, no my-location, zoom controls, no markers. */
    @Test
    fun c17_1_withNoPropsTheMapTakesFluttersDefaultsAndIsNotRegisteredBeforeItIsMade() {
        show(node())
        assertEquals(at(0.0, 0.0, 14.0), surface.cameras.last())
        assertEquals(options(), surface.drawn.last())

        assertTrue(plugin.maps.isEmpty(), "registered only once the map is made")
        run("moveCamera", "targetId" to ID, "latitude" to 1, "longitude" to 2)
        assertEquals(emptyList(), fired)
    }

    /**
     * Flutter's `prop<T>` cast throws, so its build fails; here, as the video
     * player's Kotlin props, a prop of the wrong type reads as absent: its default.
     */
    @Test
    fun c17_1_aPropOfTheWrongTypeTakesItsDefault() {
        show(
            node(
                "latitude" to JsonValue.String("north"),
                "longitude" to JsonValue.Bool(true),
                "zoom" to JsonValue.String("near"),
                "mapType" to JsonValue.Int(1),
                "myLocationEnabled" to JsonValue.String("yes"),
                "zoomControlsEnabled" to JsonValue.Int(0),
                "markers" to JsonValue.obj("id" to "sf", "latitude" to 1, "longitude" to 2),
            ),
        )
        assertEquals(at(0.0, 0.0, 14.0), surface.cameras.last())
        assertEquals(options(), surface.drawn.last())

        // In a marker: a non-number coordinate skips it, a non-string title is "", a non-string snippet none.
        reshow(
            node(
                "markers" to JsonValue.arr(
                    mapOf("id" to "w", "latitude" to "north", "longitude" to 2),
                    mapOf("id" to "t", "latitude" to 1, "longitude" to 2, "title" to 5, "snippet" to false),
                ),
            ),
        )
        assertEquals(listOf(MapMarker("t", 1.0, 2.0, "", null)), surface.drawn.last().markers)
    }

    /** Flutter's initialCameraPosition: later props do not move the camera; only moveCamera does. */
    @Test
    fun c17_1_theCameraPropsAreReadOnceWhenTheMapIsMade() {
        show(
            node(
                "latitude" to JsonValue.Double(37.7749),
                "longitude" to JsonValue.Double(-122.4194),
                "zoom" to JsonValue.Double(12.5),
            ),
        )
        assertEquals(at(37.7749, -122.4194, 12.5), surface.cameras.last())

        reshow(
            node(
                "latitude" to JsonValue.Int(40),
                "longitude" to JsonValue.Int(-74),
                "zoom" to JsonValue.Int(3),
                "mapType" to JsonValue.String("hybrid"),
            ),
        )
        assertEquals(MapType.HYBRID, surface.drawn.last().mapType, "the other props follow")
        assertEquals(at(37.7749, -122.4194, 12.5), surface.cameras.last(), "the camera stays where the map was made")

        // A map made anew reads them anew; whole numbers read as doubles.
        reshow(null)
        reshow(node("latitude" to JsonValue.Int(40), "longitude" to JsonValue.Int(-74), "zoom" to JsonValue.Int(3)))
        assertEquals(at(40.0, -74.0, 3.0), surface.cameras.last())
    }

    @Test
    fun c17_1_mapTypeIsFluttersFourAndAnythingElseIsNormal() {
        show(node())
        val names = listOf(
            "satellite" to MapType.SATELLITE,
            "normal" to MapType.NORMAL,
            "terrain" to MapType.TERRAIN,
            "hybrid" to MapType.HYBRID,
            "Satellite" to MapType.NORMAL,
            "none" to MapType.NORMAL,
            "" to MapType.NORMAL,
        )
        for ((name, type) in names) {
            reshow(node("mapType" to JsonValue.String(name)))
            assertEquals(options(mapType = type), surface.drawn.last(), "mapType '$name'")
        }
    }

    /**
     * google_maps_flutter_android's GoogleMapController sets the my-location
     * layer only while the app holds ACCESS_FINE_LOCATION or
     * ACCESS_COARSE_LOCATION (else it logs and leaves it off); the Maps SDK
     * would throw without one. zoomControlsEnabled is the map's + and - buttons.
     */
    @Test
    fun c17_1_zoomControlsFollowThePropAndMyLocationNeedsALocationPermission() {
        val app = RuntimeEnvironment.getApplication()
        val permissions = shadowOf(app)
        show(node("myLocationEnabled" to JsonValue.Bool(true), "zoomControlsEnabled" to JsonValue.Bool(false)))
        assertFalse(hasLocationPermission(app))
        assertEquals(options(zoomControlsEnabled = false), surface.drawn.last(), "no permission: no my-location layer")

        permissions.grantPermissions(Manifest.permission.ACCESS_COARSE_LOCATION)
        assertTrue(hasLocationPermission(app))
        reshow(node("myLocationEnabled" to JsonValue.Bool(true)))
        assertEquals(options(myLocationEnabled = true), surface.drawn.last())

        permissions.denyPermissions(Manifest.permission.ACCESS_COARSE_LOCATION)
        permissions.grantPermissions(Manifest.permission.ACCESS_FINE_LOCATION)
        assertTrue(hasLocationPermission(app))
        reshow(node("myLocationEnabled" to JsonValue.Bool(true), "zoomControlsEnabled" to JsonValue.Bool(true)))
        assertEquals(options(myLocationEnabled = true), surface.drawn.last())

        // Held, but not asked for.
        reshow(node("myLocationEnabled" to JsonValue.Bool(false)))
        assertEquals(options(), surface.drawn.last())

        permissions.denyPermissions(Manifest.permission.ACCESS_FINE_LOCATION)
        assertFalse(hasLocationPermission(app))
        reshow(node("myLocationEnabled" to JsonValue.Bool(true), "mapType" to JsonValue.String("terrain")))
        assertEquals(options(mapType = MapType.TERRAIN), surface.drawn.last())
    }

    /** Flutter's marker loop: id's text or "", both coordinates or skipped, title or "", snippet or none. */
    @Test
    fun c17_1_theMarkersAreReadAsFlutterReadsThemAndFollowTheProps() {
        show(
            node(
                "markers" to JsonValue.arr(
                    mapOf(
                        "id" to "sf", "latitude" to 37.7749, "longitude" to -122.4194,
                        "title" to "San Francisco", "snippet" to "The Golden City",
                    ),
                    mapOf("id" to "nyc", "latitude" to 40, "longitude" to -74),
                    mapOf("id" to "no-lat", "longitude" to -74),
                    mapOf("id" to "no-lng", "latitude" to 40),
                    mapOf("id" to "null-lat", "latitude" to null, "longitude" to 1),
                    "not an object",
                    listOf(1, 2),
                    mapOf("latitude" to 1, "longitude" to 2),
                    mapOf("id" to 7, "latitude" to 3.5, "longitude" to 4.5, "title" to "Seven"),
                ),
            ),
        )
        assertEquals(
            listOf(
                MapMarker("sf", 37.7749, -122.4194, "San Francisco", "The Golden City"),
                MapMarker("nyc", 40.0, -74.0, "", null),
                MapMarker("", 1.0, 2.0, "", null),
                MapMarker("7", 3.5, 4.5, "Seven", null),
            ),
            surface.drawn.last().markers,
        )

        reshow(node("markers" to JsonValue.arr(mapOf("id" to "paris", "latitude" to 48.8566, "longitude" to 2.3522))))
        assertEquals(listOf(MapMarker("paris", 48.8566, 2.3522, "", null)), surface.drawn.last().markers)
        reshow(node("markers" to JsonValue.arr()))
        assertEquals(emptyList(), surface.drawn.last().markers)
    }

    /** Flutter's `_controllers[ctx.node.id] = controller` in onMapCreated; gone when the view leaves (video-player-dispose-on-leave). */
    @Test
    fun c17_1_theMapRegistersUnderTheNodeIdWhenMadeAndIsRemovedWhenItLeaves() {
        show(node())
        assertTrue(plugin.maps.isEmpty())
        val camera = surface.create()
        assertEquals(setOf(ID), plugin.maps.keys)
        assertSame(camera, plugin.maps[ID])
        run("moveCamera", "targetId" to ID, "latitude" to 1.5, "longitude" to 2.5, "zoom" to 9)
        assertEquals(listOf(at(1.5, 2.5, 9.0)), camera.moves)

        // Other props keep the map.
        reshow(node("mapType" to JsonValue.String("satellite")))
        assertSame(camera, plugin.maps[ID])

        reshow(null)
        assertTrue(plugin.maps.isEmpty(), "removed when the view leaves")
        run("moveCamera", "targetId" to ID, "latitude" to 3, "longitude" to 4)
        assertEquals(1, camera.moves.size)

        // A map that leaves before it is made never registers.
        reshow(node())
        val events = assertNotNull(surface.events)
        reshow(null)
        events.created(FakeCamera())
        assertTrue(plugin.maps.isEmpty())

        // Another id is another map: made anew, with its camera read anew, under its own id.
        reshow(node("latitude" to JsonValue.Int(1)))
        surface.create()
        reshow(node("latitude" to JsonValue.Int(5), id = "other-map"))
        assertEquals(at(5.0, 0.0, 14.0), surface.cameras.last())
        assertTrue(plugin.maps.isEmpty(), "the first map left")
        val other = surface.create()
        assertEquals(setOf("other-map"), plugin.maps.keys)
        run("moveCamera", "targetId" to "other-map", "latitude" to 6, "longitude" to 7, "zoom" to 8.5)
        assertEquals(listOf(at(6.0, 7.0, 8.5)), other.moves)
    }

    /** Two maps under one id: the one made last is moved (Flutter's map assignment), and stays when the other leaves. */
    @Test
    fun c17_1_aMapLeavingKeepsAnotherMapMadeLaterUnderItsId() {
        show(node())
        val first = surface.create()
        second = node("mapType" to JsonValue.String("satellite"))
        compose.waitForIdle()
        assertEquals(2, surface.maps.size)
        val later = FakeCamera()
        surface.maps[1].created(later)
        assertSame(later, plugin.maps[ID])

        reshow(null)
        assertSame(later, plugin.maps[ID], "the first map's leaving leaves the second's")
        run("moveCamera", "targetId" to ID, "latitude" to 1, "longitude" to 2)
        assertEquals(listOf(at(1.0, 2.0, 14.0)), later.moves)
        assertEquals(emptyList(), first.moves)

        second = null
        compose.waitForIdle()
        assertTrue(plugin.maps.isEmpty())
    }

    /** google_maps_flutter's onTap, onLongPress, onCameraMove and a marker's onTap, as the plugin fires them. */
    @Test
    fun c17_1_eachTriggerFiresWithFluttersPayload() {
        show(node())
        val events = assertNotNull(surface.events)
        events.tap(37.7749, -122.4194)
        events.longPress(40.0, -74.0)
        events.cameraMove(48.8566, 2.3522, 12.5)
        events.markerTap("sf")
        events.markerTap("")
        assertEquals(
            listOf(
                "onTap" to latLng(37.7749, -122.4194),
                "onLongPress" to latLng(40.0, -74.0),
                "onCameraMove" to latLng(48.8566, 2.3522) + ("zoom" to JsonValue.Double(12.5)),
                "onMarkerTap" to mapOf<String, JsonValue>("markerId" to JsonValue.String("sf")),
                "onMarkerTap" to mapOf<String, JsonValue>("markerId" to JsonValue.String("")),
            ),
            fired,
        )

        // The node drawn now is the one that fires: without triggers, nothing runs.
        reshow(node(triggers = false))
        events.tap(1.0, 2.0)
        events.longPress(1.0, 2.0)
        events.cameraMove(1.0, 2.0, 3.0)
        events.markerTap("sf")
        assertEquals(5, fired.size)
    }

    /** Flutter's `animateCamera(newCameraPosition(CameraPosition(target, zoom ?? 14)))`. */
    @Test
    fun c17_1_moveCameraAnimatesTheTargetMapToTheCentreAndZoom() {
        show(node())
        val camera = surface.create()
        run("moveCamera", "targetId" to ID, "latitude" to 40.7128, "longitude" to -74.006, "zoom" to 12.5)
        run("moveCamera", "targetId" to ID, "latitude" to 40, "longitude" to -74)
        run("moveCamera", "targetId" to ID, "latitude" to 1, "longitude" to 2, "zoom" to null)
        assertEquals(listOf(at(40.7128, -74.006, 12.5), at(40.0, -74.0, 14.0), at(1.0, 2.0, 14.0)), camera.moves)
        assertEquals(emptyList(), fired, "the action fires nothing itself")
    }

    /** Flutter resolves targetId with `resolveString` and the numbers with `resolveValue`. */
    @Test
    fun c17_1_moveCameraResolvesItsParamsAsFlutterDoes() {
        show(node())
        val camera = surface.create()
        run(
            "moveCamera",
            "targetId" to pageState("target"),
            "latitude" to pageState("lat"),
            "longitude" to pageState("lng"),
            "zoom" to pageState("z"),
        )
        assertEquals(listOf(at(48.8566, 2.3522, 11.0)), camera.moves)

        // A number targetId is its Dart text.
        reshow(node(id = "7"))
        val seven = surface.create()
        run("moveCamera", "targetId" to 7, "latitude" to 1, "longitude" to 2)
        assertEquals(listOf(at(1.0, 2.0, 14.0)), seven.moves)
    }

    @Test
    fun c17_1_anUnknownOrMissingTargetOrCoordinateDoesNothing() {
        show(node())
        val camera = surface.create()
        run("moveCamera", "targetId" to "nobody", "latitude" to 1, "longitude" to 2)
        run("moveCamera", "targetId" to "", "latitude" to 1, "longitude" to 2)
        run("moveCamera", "latitude" to 1, "longitude" to 2)
        run("moveCamera", "targetId" to ID, "longitude" to 2)
        run("moveCamera", "targetId" to ID, "latitude" to 1)
        run("moveCamera", "targetId" to ID, "latitude" to null, "longitude" to 2, "zoom" to 3)
        run("moveCamera", "targetId" to ID)
        assertEquals(emptyList(), camera.moves)
    }

    /** Flutter's `resolveValue(...) as num?` throws for anything else, before it looks for the map. */
    @Test
    fun c17_1_aNonNumberParamFailsTheAction() {
        show(node())
        val camera = surface.create()
        assertFailsWith<IllegalArgumentException> { run("moveCamera", "targetId" to ID, "latitude" to "north", "longitude" to 2) }
        assertFailsWith<IllegalArgumentException> { run("moveCamera", "targetId" to ID, "latitude" to 1, "longitude" to true) }
        assertFailsWith<IllegalArgumentException> {
            run("moveCamera", "targetId" to ID, "latitude" to 1, "longitude" to 2, "zoom" to "far")
        }
        assertFailsWith<IllegalArgumentException> {
            run("moveCamera", "targetId" to "nobody", "latitude" to 1, "longitude" to 2, "zoom" to "far")
        }
        assertFailsWith<IllegalArgumentException> { run("moveCamera", "targetId" to ID, "zoom" to listOf(1)) }
        assertEquals(emptyList(), camera.moves)
    }

    /**
     * Flutter's map fills the box it is given (/map's Container 300 high). A
     * Column gives a child no height bound, in Flutter as in the SDK's
     * Column: the map takes none of it.
     */
    @Test
    fun c17_1_theMapFillsTheBoxItIsGivenAndTakesNoUnboundedHeight() {
        box = Modifier.size(320.dp, 300.dp)
        show(node())
        compose.onNodeWithTag(MAP_TAG).assertWidthIsEqualTo(320.dp).assertHeightIsEqualTo(300.dp)

        box = Modifier.width(320.dp).wrapContentHeight(unbounded = true)
        compose.waitForIdle()
        compose.onNodeWithTag(MAP_TAG).assertWidthIsEqualTo(320.dp).assertHeightIsEqualTo(0.dp)
    }
}
