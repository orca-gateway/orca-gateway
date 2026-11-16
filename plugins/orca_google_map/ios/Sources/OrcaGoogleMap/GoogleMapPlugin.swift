#if canImport(SwiftUI) && canImport(MapKit)
import Foundation
import OrcaGateway
import SwiftUI

/// A map, the Swift port of the Flutter `GoogleMapPlugin`
/// (lib/src/google_map_plugin.dart, on google_maps_flutter 2.17.0), drawn
/// with MapKit (no key, no dependency): register it with the host,
/// `OrcaApp(..., plugins: [GoogleMapPlugin()])`.
///
/// Widget `GoogleMap`: props `latitude`, `longitude` (default 0) and `zoom`
/// (14), the camera when the map is made; `mapType` (normal, satellite,
/// hybrid; terrain draws MapKit's standard map), `myLocationEnabled` (false;
/// the dot shows once the app holds location permission, which the plugin
/// never asks for) and `markers` ({id, latitude, longitude, title, snippet},
/// in a callout), followed on each update; `zoomControlsEnabled` has no
/// effect, as on google_maps_flutter_ios. Triggers `onTap` and `onLongPress`
/// {latitude, longitude}, `onCameraMove` {latitude, longitude, zoom} while
/// the camera moves, `onMarkerTap` {markerId}. Action `moveCamera`
/// {targetId, latitude, longitude, zoom (14)} on the map whose node id is
/// targetId.
public struct GoogleMapPlugin: OrcaPlugin {
    public let name = "GoogleMapPlugin"
    /// What the widget and the action share (Flutter's static map).
    let maps = GoogleMaps()

    public init() {}

    public var widgets: [String: OrcaWidgetBuilder] {
        ["GoogleMap": { [maps] node, model in AnyView(maps.view(node, model)) }]
    }

    public var actions: [String: OrcaActionHandler] {
        let maps = maps
        return ["moveCamera": { try await maps.moveCamera($0, $1) }]
    }

    public var triggers: [String: [TriggerDefinition]] {
        ["GoogleMap": [
            TriggerDefinition(
                name: GoogleMapProps.Triggers.onTap, dataType: "LatLng",
                description: "Fires when the map is tapped with {latitude, longitude}"),
            TriggerDefinition(
                name: GoogleMapProps.Triggers.onLongPress, dataType: "LatLng",
                description: "Fires on long press with {latitude, longitude}"),
            TriggerDefinition(
                name: GoogleMapProps.Triggers.onCameraMove, dataType: "CameraPosition",
                description: "Fires during camera movement with {latitude, longitude, zoom}"),
            TriggerDefinition(
                name: GoogleMapProps.Triggers.onMarkerTap, dataType: "String",
                description: "Fires when a marker is tapped with {markerId}"),
        ]]
    }
}

/// The maps on screen by node id (Flutter's `_controllers`, keyed by
/// `ctx.node.id`) and moveCamera on them, line for line Flutter's handler
/// (:153-171): targetId resolved as a string value, the numbers as values; a
/// number that is not one fails the action (Dart's `as num?`) before the map
/// is looked up; a missing latitude or longitude, or an unknown target, does
/// nothing.
@MainActor
final class GoogleMaps {
    private(set) var surfaces: [String: MapSurface] = [:]

    nonisolated init() {}

    /// The node's map, its triggers fired through the node's actions.
    func view(_ node: ResolvedNode, _ model: OrcaPageModel) -> MapKitView {
        MapKitView(id: node.id, options: GoogleMapOptions(node), maps: self,
                   fire: { model.fire($0.trigger, on: node, eventData: $0.eventData) })
    }

    /// A map made: at its initial camera, with the props, registered under
    /// the node id (Flutter's onMapCreated).
    func create(_ surface: MapSurface, id: String, options: GoogleMapOptions) {
        surface.show(options.camera, animated: false)
        surface.apply(options)
        surfaces[id] = surface
    }

    /// New props: all but the camera.
    func update(_ surface: MapSurface, options: GoogleMapOptions) {
        surface.apply(options)
    }

    /// The map left the screen: removed, unless a newer one has the id.
    func leave(_ surface: MapSurface, id: String) {
        if surfaces[id] === surface { surfaces[id] = nil }
    }

    func moveCamera(_ action: JSONValue, _ executor: ActionExecutor) throws {
        let params = MoveCameraParams(action).action
        let target = executor.resolve(params["targetId"])
        let latitude = try number(params, "latitude", executor)
        let longitude = try number(params, "longitude", executor)
        let zoom = try number(params, "zoom", executor)
        guard let latitude, let longitude,
              let surface = surfaces[target.isNull ? "" : DartFormat.string(target)] else { return }
        surface.show(MapCamera(latitude: latitude, longitude: longitude, zoom: zoom ?? 14), animated: true)
    }

    /// Dart's `executor.resolveValue(action[key]) as num?`: nil when missing
    /// or null, else a number; anything else throws, as the cast does.
    private func number(_ action: JSONValue, _ key: String, _ executor: ActionExecutor) throws -> Double? {
        let value = executor.resolve(action[key])
        if value.isNull { return nil }
        guard let number = value.doubleValue else { throw GoogleMapNumberError(key: key, value: value) }
        return number
    }
}

/// A param that resolved to something other than a number, where Dart's
/// `as num?` throws: it fails the action, with the video player's text.
struct GoogleMapNumberError: Error, CustomStringConvertible {
    let key: String
    let value: JSONValue

    var description: String { "\(key) is not a number: \(DartFormat.string(value))" }
}
#endif
