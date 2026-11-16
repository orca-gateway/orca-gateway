package com.orcagateway.plugins.googlemap

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.rememberCameraPositionState
import com.google.maps.android.compose.rememberUpdatedMarkerState
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch

/** The device's maps: Google's Maps Compose GoogleMap, the map google_maps_flutter_android draws. */
internal object GoogleMapSurface : MapSurface {
    @Composable
    override fun Draw(options: MapOptions, camera: MapCameraPosition, events: MapEvents, modifier: Modifier) {
        GoogleMapView(options, camera, events, modifier)
    }
}

/**
 * google_maps_flutter's GoogleMap on Maps Compose: the camera state made
 * at [camera] once (initialCameraPosition), the properties and UI settings
 * google_maps_flutter_android gives the map, a Marker per marker, and the
 * map's clicks, long clicks, camera moves and marker clicks told to [events].
 */
@Composable
private fun GoogleMapView(options: MapOptions, camera: MapCameraPosition, events: MapEvents, modifier: Modifier) {
    val currentEvents by rememberUpdatedState(events)
    val cameraState = rememberCameraPositionState { position = camera.toCameraPosition() }
    val scope = rememberCoroutineScope()

    // onCameraMove: each position the map reports while a gesture or an animation (moveCamera's too) moves it,
    // not the one it was made at.
    LaunchedEffect(cameraState) {
        snapshotFlow { cameraState.position }.drop(1).collect { position ->
            currentEvents.cameraMove(position.target.latitude, position.target.longitude, position.zoom.toDouble())
        }
    }

    GoogleMap(
        modifier = modifier,
        cameraPositionState = cameraState,
        // Two of Maps Compose's defaults are not google_maps_flutter's: it turns the 3D buildings off and bounds the
        // zoom out at 3. google_maps_flutter_android keeps the buildings and sets no bound (the map's own minimum).
        properties = MapProperties(
            isBuildingEnabled = true,
            isMyLocationEnabled = options.myLocationEnabled,
            mapType = options.mapType,
            minZoomPreference = 0f,
        ),
        // Google's defaults otherwise, as google_maps_flutter_android leaves them: compass, toolbar, my-location
        // button, gestures.
        uiSettings = MapUiSettings(zoomControlsEnabled = options.zoomControlsEnabled),
        onMapClick = { currentEvents.tap(it.latitude, it.longitude) },
        onMapLongClick = { currentEvents.longPress(it.latitude, it.longitude) },
    ) {
        for (marker in options.markers) {
            key(marker.id) {
                Marker(
                    state = rememberUpdatedMarkerState(LatLng(marker.latitude, marker.longitude)),
                    title = marker.title,
                    snippet = marker.snippet,
                    // Not consumed: Google opens the info window and centres the marker, as with Flutter's.
                    onClick = {
                        currentEvents.markerTap(marker.id)
                        false
                    },
                )
            }
        }
        // Maps Compose composes this content once the GoogleMap exists: Flutter's onMapCreated. moveCamera starts the
        // animation and returns, as animateCamera does; a gesture or another move cuts it short.
        LaunchedEffect(cameraState) {
            currentEvents.created { position ->
                scope.launch { cameraState.animate(CameraUpdateFactory.newCameraPosition(position.toCameraPosition())) }
            }
        }
    }
}

private fun MapCameraPosition.toCameraPosition(): CameraPosition =
    CameraPosition(LatLng(latitude, longitude), zoom.toFloat(), 0f, 0f)
