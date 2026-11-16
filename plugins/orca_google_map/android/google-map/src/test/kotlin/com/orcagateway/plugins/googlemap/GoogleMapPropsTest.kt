package com.orcagateway.plugins.googlemap

import com.orcagateway.core.json.JsonValue
import com.orcagateway.core.models.ComponentNode
import com.orcagateway.core.render.ResolvedNode
import kotlinx.serialization.json.JsonObject
import org.junit.Test
import java.lang.reflect.Modifier
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * C17.5/K: the props, trigger names and action params the plugin reads come
 * from OrcaGoogleMapTypes.kt, what `orca plugin generate --lang kotlin
 * --types-only` writes for plugins/orca_google_map/orca_plugin.yaml
 * (committed as generated, kept in sync by
 * cli/test/google_map_kotlin_props_test.dart). They read what the Flutter
 * plugin reads (lib/src/google_map_plugin.dart :93-117, :37-61, :154-160),
 * with the same names and types; Flutter's defaults are the plugin's to apply,
 * so an absent prop or param reads null. The generator types `markers` as the
 * raw JSON array, each marker an object the plugin reads by key.
 */
class GoogleMapPropsTest {
    /** A resolved `GoogleMap` node with [props]. */
    private fun node(vararg props: Pair<String, JsonValue>) = ResolvedNode(
        id = "main-map",
        type = "GoogleMap",
        kind = ComponentNode.Kind.Primitive,
        props = mapOf(*props),
        childIds = emptyList(),
        slots = emptyMap(),
        actions = emptyMap(),
        watches = emptyList(),
    )

    /** The raw object of a `custom:<name>` action with [params], as a handler receives it. */
    private fun action(name: String, vararg params: Pair<String, Any?>): JsonObject =
        JsonValue.obj("type" to "custom:$name", *params).toJsonElement() as JsonObject

    /** The public properties a generated type declares, less the node or action it reads. */
    private fun properties(type: Class<*>): Set<String> = type.declaredMethods
        .filter { Modifier.isPublic(it.modifiers) && it.parameterCount == 0 && it.name.startsWith("get") }
        .map { it.name.removePrefix("get").replaceFirstChar { c -> c.lowercaseChar() } }
        .toSet() - setOf("node", "action")

    /** The string constants of an object, by name. */
    private fun constants(type: Class<*>): Map<String, Any?> = type.declaredFields
        .filter { Modifier.isStatic(it.modifiers) && it.type == String::class.java }
        .associate { it.name to it.get(null) }

    @Test
    fun c17_5_theWidgetPropsAreFluttersSeven() {
        assertEquals(
            setOf("latitude", "longitude", "zoom", "mapType", "myLocationEnabled", "zoomControlsEnabled", "markers"),
            properties(GoogleMapProps::class.java),
        )

        val props = GoogleMapProps(
            node(
                "latitude" to JsonValue.Double(37.7749),
                "longitude" to JsonValue.Double(-122.4194),
                "zoom" to JsonValue.Double(12.5),
                "mapType" to JsonValue.String("satellite"),
                "myLocationEnabled" to JsonValue.Bool(true),
                "zoomControlsEnabled" to JsonValue.Bool(false),
            ),
        )
        assertEquals<Double?>(37.7749, props.latitude)
        assertEquals<Double?>(-122.4194, props.longitude)
        assertEquals<Double?>(12.5, props.zoom)
        assertEquals<String?>("satellite", props.mapType)
        assertEquals<Boolean?>(true, props.myLocationEnabled)
        assertEquals<Boolean?>(false, props.zoomControlsEnabled)

        // Flutter's `prop<num>(...)?.toDouble()`: an integer or a double.
        val whole = GoogleMapProps(
            node("latitude" to JsonValue.Int(40), "longitude" to JsonValue.Int(-74), "zoom" to JsonValue.Int(14)),
        )
        assertEquals<Double?>(40.0, whole.latitude)
        assertEquals<Double?>(-74.0, whole.longitude)
        assertEquals<Double?>(14.0, whole.zoom)
    }

    /** Flutter's `prop<List>('markers')`, each entry a map read for id, latitude, longitude, title and snippet. */
    @Test
    fun c17_5_theMarkersReadFluttersFiveKeys() {
        val markers = GoogleMapProps(
            node(
                "markers" to JsonValue.arr(
                    mapOf(
                        "id" to "sf", "latitude" to 37.7749, "longitude" to -122.4194,
                        "title" to "San Francisco", "snippet" to "The Golden City",
                    ),
                    mapOf("id" to "nyc", "latitude" to 40, "longitude" to -74),
                ),
            ),
        ).markers?.arrayValue

        assertEquals(2, markers?.size)
        val sf = markers!![0]
        assertEquals<String?>("sf", sf["id"].stringValue)
        assertEquals<Double?>(37.7749, sf["latitude"].doubleValue)
        assertEquals<Double?>(-122.4194, sf["longitude"].doubleValue)
        assertEquals<String?>("San Francisco", sf["title"].stringValue)
        assertEquals<String?>("The Golden City", sf["snippet"].stringValue)

        // An integer coordinate reads as a double; an absent title or snippet reads null.
        val nyc = markers[1]
        assertEquals<String?>("nyc", nyc["id"].stringValue)
        assertEquals<Double?>(40.0, nyc["latitude"].doubleValue)
        assertEquals<Double?>(-74.0, nyc["longitude"].doubleValue)
        assertNull(nyc["title"].stringValue)
        assertNull(nyc["snippet"].stringValue)
    }

    /** Flutter falls back to 0, 0, 14, normal, false, true and no markers: the plugin does, the props do not. */
    @Test
    fun c17_5_absentPropsReadNull() {
        val absent = GoogleMapProps(node())
        assertNull(absent.latitude)
        assertNull(absent.longitude)
        assertNull(absent.zoom)
        assertNull(absent.mapType)
        assertNull(absent.myLocationEnabled)
        assertNull(absent.zoomControlsEnabled)
        assertNull(absent.markers)

        val nulls = GoogleMapProps(
            node(
                "latitude" to JsonValue.Null, "longitude" to JsonValue.Null, "zoom" to JsonValue.Null,
                "mapType" to JsonValue.Null, "myLocationEnabled" to JsonValue.Null,
                "zoomControlsEnabled" to JsonValue.Null, "markers" to JsonValue.Null,
            ),
        )
        assertNull(nulls.latitude)
        assertNull(nulls.longitude)
        assertNull(nulls.zoom)
        assertNull(nulls.mapType)
        assertNull(nulls.myLocationEnabled)
        assertNull(nulls.zoomControlsEnabled)
        assertNull(nulls.markers)
    }

    @Test
    fun c17_5_theTriggersAreExactlyFluttersFour() {
        val names = listOf("onTap", "onLongPress", "onCameraMove", "onMarkerTap")
        assertEquals(names.associateWith { it }, constants(GoogleMapProps.Triggers::class.java))
        assertEquals(
            names,
            listOf(
                GoogleMapProps.Triggers.onTap,
                GoogleMapProps.Triggers.onLongPress,
                GoogleMapProps.Triggers.onCameraMove,
                GoogleMapProps.Triggers.onMarkerTap,
            ),
        )
    }

    @Test
    fun c17_5_moveCameraHasFluttersFourParams() {
        assertEquals(
            setOf("targetId", "latitude", "longitude", "zoom"),
            properties(MoveCameraParams::class.java),
        )

        val move = MoveCameraParams(
            action("moveCamera", "targetId" to "main-map", "latitude" to 40.7128, "longitude" to -74.006, "zoom" to 12.5),
        )
        assertEquals<String?>("main-map", move.targetId)
        assertEquals<Double?>(40.7128, move.latitude)
        assertEquals<Double?>(-74.006, move.longitude)
        assertEquals<Double?>(12.5, move.zoom)

        // Flutter's `resolveValue(...) as num?`: an integer or a double.
        val whole = MoveCameraParams(action("moveCamera", "latitude" to 40, "longitude" to -74, "zoom" to 14))
        assertEquals<Double?>(40.0, whole.latitude)
        assertEquals<Double?>(-74.0, whole.longitude)
        assertEquals<Double?>(14.0, whole.zoom)
    }

    /** Where Flutter falls back (targetId "", zoom 14) or does nothing (a missing coordinate), the param reads null. */
    @Test
    fun c17_5_absentParamsReadNull() {
        val absent = MoveCameraParams(action("moveCamera"))
        assertNull(absent.targetId)
        assertNull(absent.latitude)
        assertNull(absent.longitude)
        assertNull(absent.zoom)

        val nulls = MoveCameraParams(
            action("moveCamera", "targetId" to null, "latitude" to null, "longitude" to null, "zoom" to null),
        )
        assertNull(nulls.targetId)
        assertNull(nulls.latitude)
        assertNull(nulls.longitude)
        assertNull(nulls.zoom)
    }

    /**
     * Flutter resolves each param as a value: one sent as a Value reads null
     * here and stays in the raw action for the plugin to resolve.
     */
    @Test
    fun c17_5_aParamSentAsAValueReadsNull() {
        val id = mapOf("type" to "state", "key" to "map", "scope" to "page")
        val at = mapOf("type" to "state", "key" to "at", "scope" to "page")
        val move = MoveCameraParams(
            action("moveCamera", "targetId" to id, "latitude" to at, "longitude" to at, "zoom" to at),
        )
        assertNull(move.targetId)
        assertNull(move.latitude)
        assertNull(move.longitude)
        assertNull(move.zoom)
        assertEquals(JsonValue.of(id).toJsonElement(), move.action["targetId"])
    }
}
