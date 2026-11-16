package com.orcagateway.plugins.googlemap

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.google.maps.android.compose.MapType
import com.orcagateway.core.json.DartFormat
import com.orcagateway.core.json.JsonValue

/** Flutter's `CameraPosition(target: LatLng(latitude, longitude), zoom: zoom)`: Google's zoom, no tilt, no bearing. */
internal data class MapCameraPosition(val latitude: Double, val longitude: Double, val zoom: Double)

/** A marker as Flutter's plugin builds it: tapped, it opens an info window with its title and snippet. */
internal data class MapMarker(
    val id: String,
    val latitude: Double,
    val longitude: Double,
    val title: String,
    val snippet: String?,
)

/** What a map draws on each update of its props (the camera is read once, apart: [initialCamera]). */
internal data class MapOptions(
    val mapType: MapType,
    /** Asked for by the props and allowed by a location permission the app holds. */
    val myLocationEnabled: Boolean,
    val zoomControlsEnabled: Boolean,
    val markers: List<MapMarker>,
)

/** A drawn map's camera (google_maps_flutter's GoogleMapController). */
internal fun interface MapCamera {
    /** Starts animating to [position] and returns, as animateCamera does. */
    fun animateTo(position: MapCameraPosition)
}

/** Where a drawn map tells the plugin what happened (google_maps_flutter's callbacks). */
internal interface MapEvents {
    /** onMapCreated: the map is there, and [camera] moves it. */
    fun created(camera: MapCamera)

    /** A tap off any marker. */
    fun tap(latitude: Double, longitude: Double)

    fun longPress(latitude: Double, longitude: Double)

    /** Each move of the camera, by a gesture or an animation. */
    fun cameraMove(latitude: Double, longitude: Double, zoom: Double)

    fun markerTap(markerId: String)
}

/**
 * What draws a map: Google's Maps Compose on a device ([GoogleMapSurface]),
 * a fake in the tests (Robolectric cannot draw Google Maps).
 */
internal interface MapSurface {
    /**
     * A map made at [camera] (read when it is made, never again) drawing
     * [options], in the box of [modifier]; it tells [events] what happens.
     */
    @Composable
    fun Draw(options: MapOptions, camera: MapCameraPosition, events: MapEvents, modifier: Modifier)
}

/** Flutter's `initialCameraPosition`: latitude 0, longitude 0 and zoom 14 unless the props say. */
internal fun initialCamera(props: GoogleMapProps): MapCameraPosition =
    MapCameraPosition(props.latitude ?: 0.0, props.longitude ?: 0.0, props.zoom ?: 14.0)

/**
 * Flutter's `_buildGoogleMap` (:89-133) with its defaults: mapType normal,
 * myLocationEnabled false (and on only with [locationPermitted]),
 * zoomControlsEnabled true, no markers. A prop of the wrong type reads as
 * absent (Flutter's cast throws).
 */
internal fun mapOptions(props: GoogleMapProps, locationPermitted: Boolean): MapOptions = MapOptions(
    mapType = mapType(props.mapType),
    myLocationEnabled = (props.myLocationEnabled ?: false) && locationPermitted,
    zoomControlsEnabled = props.zoomControlsEnabled ?: true,
    markers = markers(props.markers),
)

/** Flutter's switch: its four names, anything else normal. */
private fun mapType(name: String?): MapType = when (name) {
    "satellite" -> MapType.SATELLITE
    "terrain" -> MapType.TERRAIN
    "hybrid" -> MapType.HYBRID
    else -> MapType.NORMAL
}

/**
 * Flutter's marker loop: an entry that is not an object, or lacks either
 * coordinate, is skipped; the id is its Dart text or "", the title "" and
 * the snippet none when absent.
 */
private fun markers(raw: JsonValue?): List<MapMarker> = raw?.arrayValue.orEmpty().mapNotNull { entry ->
    if (entry !is JsonValue.Object) return@mapNotNull null
    val latitude = entry["latitude"].doubleValue ?: return@mapNotNull null
    val longitude = entry["longitude"].doubleValue ?: return@mapNotNull null
    val id = entry["id"].takeUnless { it.isNull }?.let(DartFormat::string) ?: ""
    MapMarker(id, latitude, longitude, entry["title"].stringValue ?: "", entry["snippet"].stringValue)
}

/**
 * google_maps_flutter_android's `hasLocationPermission`: the app holds
 * ACCESS_FINE_LOCATION or ACCESS_COARSE_LOCATION. Without either it leaves
 * the my-location layer off (the Maps SDK would throw).
 */
internal fun hasLocationPermission(context: Context): Boolean =
    context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
