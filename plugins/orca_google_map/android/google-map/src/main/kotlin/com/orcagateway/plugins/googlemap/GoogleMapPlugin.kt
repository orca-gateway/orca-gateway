package com.orcagateway.plugins.googlemap

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.plugins.OrcaActionHandler
import com.orcagateway.core.plugins.TriggerDefinition
import com.orcagateway.core.render.ResolvedNode
import com.orcagateway.core.state.ActionExecutor
import com.orcagateway.sdk.OrcaPageModel
import com.orcagateway.sdk.OrcaPlugin
import com.orcagateway.sdk.WidgetBuilder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject

/**
 * Google Maps for Orca pages: Flutter's `GoogleMapPlugin`
 * (plugins/orca_google_map/lib/src/google_map_plugin.dart, on
 * google_maps_flutter 2.17.0) one to one. The `GoogleMap` widget draws a
 * map whose camera starts at the props' latitude, longitude and zoom
 * (read once, when the map is made), with their mapType, myLocationEnabled,
 * zoomControlsEnabled and markers (each update), and fires `onTap` and
 * `onLongPress` {latitude, longitude}, `onCameraMove` {latitude, longitude,
 * zoom} while the camera moves and `onMarkerTap` {markerId}. The
 * `moveCamera` action {targetId, latitude, longitude, zoom} animates the
 * map whose node id is targetId.
 *
 * Draws with Google's Maps Compose: the app gives the Maps API key
 * (com.google.android.geo.API_KEY in its manifest) and, for the location
 * layer, asks for location (this module's manifest declares it). Make one
 * plugin per app; its actions run on the main thread.
 */
public class GoogleMapPlugin internal constructor(
    /** What draws the maps. */
    internal val surface: MapSurface,
) : OrcaPlugin {
    /** Draws with Google's Maps Compose. */
    public constructor() : this(GoogleMapSurface)

    override val name: String = "GoogleMapPlugin"

    override val widgets: Map<String, WidgetBuilder> = mapOf("GoogleMap" to googleMapBuilder(this))

    override val actions: Map<String, OrcaActionHandler> = mapOf(
        "moveCamera" to OrcaActionHandler { action, executor -> moveCamera(action, executor) },
    )

    override val triggers: Map<String, List<TriggerDefinition>> = mapOf(
        "GoogleMap" to listOf(
            TriggerDefinition(
                GoogleMapProps.Triggers.onTap,
                dataType = "LatLng",
                description = "Fires when the map is tapped with {latitude, longitude}",
            ),
            TriggerDefinition(
                GoogleMapProps.Triggers.onLongPress,
                dataType = "LatLng",
                description = "Fires on long press with {latitude, longitude}",
            ),
            TriggerDefinition(
                GoogleMapProps.Triggers.onCameraMove,
                dataType = "CameraPosition",
                description = "Fires during camera movement with {latitude, longitude, zoom}",
            ),
            TriggerDefinition(
                GoogleMapProps.Triggers.onMarkerTap,
                dataType = "String",
                description = "Fires when a marker is tapped with {markerId}",
            ),
        ),
    )

    /**
     * The made maps by node id (Flutter's `_controllers`): a map adds its
     * camera once it is made and removes it when its view leaves.
     */
    internal val maps: MutableMap<String, MapCamera> = HashMap()

    /** Flutter's `_handleMoveCamera` (:153-171): every param resolved before the map is looked for. */
    private fun moveCamera(action: JsonObject, executor: ActionExecutor) {
        val targetId = executor.resolveString(action["targetId"])
        val latitude = executor.resolveNumber(action, "latitude")?.doubleValue
        val longitude = executor.resolveNumber(action, "longitude")?.doubleValue
        val zoom = executor.resolveNumber(action, "zoom")?.doubleValue
        if (latitude == null || longitude == null) return
        val camera = maps[targetId] ?: return
        camera.animateTo(MapCameraPosition(latitude, longitude, zoom ?: 14.0))
    }
}

/** Flutter's `_buildGoogleMap`: a map per node id (another id, another map). */
private fun googleMapBuilder(plugin: GoogleMapPlugin): WidgetBuilder = { node, model, modifier ->
    key(node.id) { GoogleMapNode(plugin, node, model, modifier) }
}

/**
 * One node's map: its camera read when it is first drawn, its options on
 * each draw, registered under the node's id once made, removed when it
 * leaves. It fills the box it is given, as Flutter's platform view.
 */
@Composable
private fun GoogleMapNode(plugin: GoogleMapPlugin, node: ResolvedNode, model: OrcaPageModel, modifier: Modifier) {
    val props = GoogleMapProps(node)
    val camera = remember { initialCamera(props) }
    val currentNode = rememberUpdatedState(node)
    val currentModel = rememberUpdatedState(model)
    val events = remember { NodeMapEvents(plugin, node.id, currentNode, currentModel) }
    DisposableEffect(events) { onDispose { events.leave() } }
    val options = mapOptions(props, hasLocationPermission(LocalContext.current))
    plugin.surface.Draw(options, camera, events, modifier.fillMaxSize())
}

/** What a node's map tells the plugin: its camera once made, and the four triggers fired on the node drawn now. */
private class NodeMapEvents(
    private val plugin: GoogleMapPlugin,
    private val id: String,
    private val node: State<ResolvedNode>,
    private val model: State<OrcaPageModel>,
) : MapEvents {
    private var camera: MapCamera? = null
    private var left = false

    /** Flutter's onMapCreated: `_controllers[ctx.node.id] = controller`. A map made after its view left is not kept. */
    override fun created(camera: MapCamera) {
        if (left) return
        this.camera = camera
        plugin.maps[id] = camera
    }

    /** The view left: its camera goes, unless another map took the id since. */
    fun leave() {
        left = true
        val mine = camera ?: return
        camera = null
        if (plugin.maps[id] === mine) plugin.maps.remove(id)
    }

    override fun tap(latitude: Double, longitude: Double) {
        fire(GoogleMapProps.Triggers.onTap, latLng(latitude, longitude))
    }

    override fun longPress(latitude: Double, longitude: Double) {
        fire(GoogleMapProps.Triggers.onLongPress, latLng(latitude, longitude))
    }

    override fun cameraMove(latitude: Double, longitude: Double, zoom: Double) {
        fire(GoogleMapProps.Triggers.onCameraMove, latLng(latitude, longitude) + ("zoom" to JsonValue.Double(zoom)))
    }

    override fun markerTap(markerId: String) {
        fire(GoogleMapProps.Triggers.onMarkerTap, mapOf("markerId" to JsonValue.String(markerId)))
    }

    private fun latLng(latitude: Double, longitude: Double): Map<String, JsonValue> =
        mapOf("latitude" to JsonValue.Double(latitude), "longitude" to JsonValue.Double(longitude))

    private fun fire(trigger: String, eventData: Map<String, JsonValue>) {
        model.value.fire(trigger, on = node.value, eventData = eventData)
    }
}

/** Flutter's `executor.resolveString(raw ?? '')`: the value resolved, as Dart text; '' for null. */
private fun ActionExecutor.resolveString(raw: JsonElement?): String {
    val value = JsonValue.fromJsonElement(resolve(raw ?: JsonNull))
    return if (value.isNull) "" else DartFormat.string(value)
}

/**
 * Flutter's `executor.resolveValue(action[key]) as num?`: null when absent
 * or null, else a number; anything else fails the action, as the cast throws.
 */
private fun ActionExecutor.resolveNumber(action: JsonObject, key: String): JsonValue? {
    val value = JsonValue.fromJsonElement(resolve(action[key] ?: JsonNull))
    if (value.isNull) return null
    require(value.isNumber) { "$key is not a number: ${DartFormat.string(value)}" }
    return value
}
