import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:orca_gateway/orca_gateway.dart';

/// Orca Gateway plugin for Google Maps.
///
/// Registers a `GoogleMap` widget and map-related actions.
///
/// ## Widget: `GoogleMap`
///
/// Props:
/// - `latitude` (double) — initial camera latitude
/// - `longitude` (double) — initial camera longitude
/// - `zoom` (double) — initial zoom level (default 14)
/// - `mapType` (String) — "normal", "satellite", "terrain", "hybrid"
/// - `myLocationEnabled` (bool) — show user location dot
/// - `zoomControlsEnabled` (bool) — show zoom +/- buttons
/// - `markers` (List) — list of marker objects with `id`, `latitude`, `longitude`, `title`, `snippet`
///
/// ## Triggers:
/// - `onTap` — fires with `{latitude, longitude}` when the map is tapped
/// - `onLongPress` — fires with `{latitude, longitude}` on long press
/// - `onCameraMove` — fires with `{latitude, longitude, zoom}` during camera movement
/// - `onMarkerTap` — fires with `{markerId}` when a marker is tapped
///
/// ## Actions:
/// - `moveCamera` — moves camera to `{latitude, longitude, zoom?}`
class GoogleMapPlugin extends OrcaPlugin {
  GoogleMapPlugin()
      : super(
          name: 'GoogleMapPlugin',
          widgets: {
            'GoogleMap': _buildGoogleMap,
          },
          actions: {
            'moveCamera': _handleMoveCamera,
          },
          triggers: {
            'GoogleMap': [
              const TriggerDefinition(
                name: 'onTap',
                dataType: 'LatLng',
                description: 'Fires when the map is tapped with {latitude, longitude}',
              ),
              const TriggerDefinition(
                name: 'onLongPress',
                dataType: 'LatLng',
                description: 'Fires on long press with {latitude, longitude}',
              ),
              const TriggerDefinition(
                name: 'onCameraMove',
                dataType: 'CameraPosition',
                description: 'Fires during camera movement with {latitude, longitude, zoom}',
              ),
              const TriggerDefinition(
                name: 'onMarkerTap',
                dataType: 'String',
                description: 'Fires when a marker is tapped with {markerId}',
              ),
            ],
          },
          // Epic 38.1/38.2: the native map view has no faithful web preview.
          widgetMetadata: {
            'GoogleMap': WidgetWebMetadata(
              isSupportedOnWeb: false,
              displayName: 'Google Maps',
              iconName: 'map',
            ),
          },
          // Epic 38.5: branded web stub shown in the preview in place of the
          // real platform view.
          webStubs: {
            'GoogleMap': _buildGoogleMapWebStub,
          },
        );

  /// Stores controllers by widget key for camera control actions.
  static final Map<String, GoogleMapController> _controllers = {};
}

/// Web stub for `GoogleMap` (Epic 38.5). google_maps_flutter has no usable web
/// platform view in the preview host, so substitute a branded placeholder that
/// occupies the map's slot.
Widget _buildGoogleMapWebStub(OrcaComponentContext ctx) {
  return const OrcaWebStub(label: 'Google Maps', icon: Icons.map_outlined);
}

Widget _buildGoogleMap(OrcaComponentContext ctx) {
  final lat = (ctx.prop<num>('latitude'))?.toDouble() ?? 0;
  final lng = (ctx.prop<num>('longitude'))?.toDouble() ?? 0;
  final zoom = (ctx.prop<num>('zoom'))?.toDouble() ?? 14;
  final mapTypeStr = ctx.prop<String>('mapType');
  final myLocationEnabled = ctx.propOr<bool>('myLocationEnabled', false);
  final zoomControlsEnabled = ctx.propOr<bool>('zoomControlsEnabled', true);
  final rawMarkers = ctx.prop<List>('markers');

  final mapType = switch (mapTypeStr) {
    'satellite' => MapType.satellite,
    'terrain' => MapType.terrain,
    'hybrid' => MapType.hybrid,
    _ => MapType.normal,
  };

  final markers = <Marker>{};
  if (rawMarkers != null) {
    for (final m in rawMarkers) {
      if (m is! Map) continue;
      final id = m['id']?.toString() ?? '';
      final mLat = (m['latitude'] as num?)?.toDouble();
      final mLng = (m['longitude'] as num?)?.toDouble();
      if (mLat == null || mLng == null) continue;
      markers.add(Marker(
        markerId: MarkerId(id),
        position: LatLng(mLat, mLng),
        infoWindow: InfoWindow(
          title: m['title'] as String? ?? '',
          snippet: m['snippet'] as String?,
        ),
        onTap: () => ctx.fireAction('onMarkerTap', eventData: {'markerId': id}),
      ));
    }
  }

  return GoogleMap(
    initialCameraPosition: CameraPosition(
      target: LatLng(lat, lng),
      zoom: zoom,
    ),
    mapType: mapType,
    myLocationEnabled: myLocationEnabled,
    zoomControlsEnabled: zoomControlsEnabled,
    markers: markers,
    onMapCreated: (controller) {
      GoogleMapPlugin._controllers[ctx.node.id] = controller;
    },
    onTap: (latLng) => ctx.fireAction('onTap', eventData: {
      'latitude': latLng.latitude,
      'longitude': latLng.longitude,
    }),
    onLongPress: (latLng) => ctx.fireAction('onLongPress', eventData: {
      'latitude': latLng.latitude,
      'longitude': latLng.longitude,
    }),
    onCameraMove: (position) => ctx.fireAction('onCameraMove', eventData: {
      'latitude': position.target.latitude,
      'longitude': position.target.longitude,
      'zoom': position.zoom,
    }),
  );
}

Future<void> _handleMoveCamera(
    Map<String, dynamic> action, ActionExecutor executor) async {
  final targetId = executor.resolveString(action['targetId'] ?? '');
  final lat = (executor.resolveValue(action['latitude']) as num?)?.toDouble();
  final lng = (executor.resolveValue(action['longitude']) as num?)?.toDouble();
  final zoom = (executor.resolveValue(action['zoom']) as num?)?.toDouble();

  if (lat == null || lng == null) return;

  final controller = GoogleMapPlugin._controllers[targetId];
  if (controller == null) return;

  await controller.animateCamera(CameraUpdate.newCameraPosition(
    CameraPosition(
      target: LatLng(lat, lng),
      zoom: zoom ?? 14,
    ),
  ));
}
