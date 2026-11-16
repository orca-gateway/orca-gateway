#if canImport(SwiftUI) && canImport(MapKit)
import Foundation
import MapKit
import XCTest

import OrcaGateway
@testable import OrcaGoogleMap

/// C17.1/S: the Swift GoogleMapPlugin does what the Flutter plugin does
/// (lib/src/google_map_plugin.dart on google_maps_flutter 2.17.0), with the
/// MapKit view swapped for a fake surface: its name, widget, action and four
/// triggers; the props with Flutter's defaults (the camera read once, when
/// the map is created; mapType, myLocationEnabled and the markers on each
/// update); a map per node id, registered when created and removed when it
/// leaves; each trigger's name and payload; moveCamera's target and numbers
/// resolved as values, an unknown target, a missing or non-number param; and
/// Google's zoom to and from a MapKit span.
@MainActor
final class GoogleMapPluginTests: XCTestCase {
    /// A map on screen as the plugin drives it, recorded.
    @MainActor final class FakeSurface: MapSurface {
        private(set) var calls: [String] = []
        private(set) var applied: [GoogleMapOptions] = []

        func show(_ camera: MapCamera, animated: Bool) {
            calls.append("show \(camera.latitude) \(camera.longitude) \(camera.zoom)\(animated ? " animated" : "")")
        }

        func apply(_ options: GoogleMapOptions) {
            calls.append("apply")
            applied.append(options)
        }
    }

    /// The plugin, its actions registered on an executor as OrcaApp registers
    /// a plugin's actions on every page.
    @MainActor final class Harness {
        let plugin = GoogleMapPlugin()
        let executor: ActionExecutor
        var maps: GoogleMaps { plugin.maps }

        init(_ state: StoreState = StoreState()) {
            executor = ActionExecutor(store: ElmStore(state))
            for (type, handler) in plugin.actions { executor.registerHandler(type, handler) }
        }

        func run(_ raw: JSONValue) async throws {
            try await executor.execute(try raw.decode(Action.self))
        }

        /// The error the action fails with, as text; nil when it does not fail.
        func failure(_ raw: JSONValue) async -> String? {
            do {
                try await run(raw)
                return nil
            } catch {
                return "\(error)"
            }
        }

        /// A fake map created for node `id` with `options`.
        func create(_ id: String = "main-map", _ options: GoogleMapOptions = GoogleMapOptions()) -> FakeSurface {
            let surface = FakeSurface()
            maps.create(surface, id: id, options: options)
            return surface
        }
    }

    /// The /map page's GoogleMap props (examples/server/custom.ts).
    static let demo: [String: JSONValue] = [
        "latitude": 37.7749, "longitude": -122.4194, "zoom": 12, "mapType": "satellite",
        "myLocationEnabled": true, "zoomControlsEnabled": false,
        "markers": [
            ["id": "marker1", "latitude": 37.7749, "longitude": -122.4194,
             "title": "San Francisco", "snippet": "This is SF!"],
            ["id": "marker2", "latitude": 37.8044, "longitude": -122.2711],
        ],
    ]

    /// A page with one GoogleMap node, "main-map", whose onMarkerTap keeps
    /// the marker's id in page state.
    func model(_ props: [String: JSONValue]) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "map", "title": "Map", "state": [["key": "tapped", "scope": "page", "initial": ""]],
            "components": [
                ["id": "main-map", "type": "GoogleMap", "kind": "primitive", "childMode": "none",
                 "props": .object(props), "children": [], "watches": [],
                 "actions": [
                     "onMarkerTap": ["type": "setState", "scope": "page", "key": "tapped",
                                     "value": ["type": "event", "key": "markerId"]],
                 ]],
            ],
        ]).decode(PageResponse.self)
        return OrcaPageModel(page: page, registry: WidgetRegistry(types: ["GoogleMap"]))
    }

    func options(_ props: [String: JSONValue]) throws -> GoogleMapOptions {
        GoogleMapOptions(try XCTUnwrap(try model(props).resolve("main-map")))
    }

    func marker(_ id: String, _ latitude: Double, _ longitude: Double, title: String = "",
                snippet: String? = nil) -> MapMarker {
        MapMarker(id: id, latitude: latitude, longitude: longitude, title: title, snippet: snippet)
    }

    // MARK: The plugin

    func testC17_1_S_ThePluginHasFluttersNameWidgetActionAndFourTriggers() throws {
        let plugin = GoogleMapPlugin()
        XCTAssertEqual(plugin.name, "GoogleMapPlugin")
        XCTAssertEqual(Set(plugin.widgets.keys), ["GoogleMap"])
        XCTAssertEqual(Set(plugin.actions.keys), ["moveCamera"])
        XCTAssertEqual(plugin.triggers, ["GoogleMap": [
            TriggerDefinition(name: "onTap", dataType: "LatLng",
                              description: "Fires when the map is tapped with {latitude, longitude}"),
            TriggerDefinition(name: "onLongPress", dataType: "LatLng",
                              description: "Fires on long press with {latitude, longitude}"),
            TriggerDefinition(name: "onCameraMove", dataType: "CameraPosition",
                              description: "Fires during camera movement with {latitude, longitude, zoom}"),
            TriggerDefinition(name: "onMarkerTap", dataType: "String",
                              description: "Fires when a marker is tapped with {markerId}"),
        ]])

        let merged = try PluginMerger.merge(
            builtInWidgets: Set(GeneratedCapabilities.widgets), plugins: [plugin.parts])
        XCTAssertEqual(merged.widgetOwners, ["GoogleMap": "GoogleMapPlugin"])
        XCTAssertEqual(merged.pluginActionTypes, ["moveCamera"])
        XCTAssertTrue(plugin.maps.surfaces.isEmpty)
    }

    // MARK: The props

    func testC17_1_S_TheWidgetReadsFluttersPropsWithTheirDefaults() throws {
        XCTAssertEqual(try options(Self.demo), GoogleMapOptions(
            camera: MapCamera(latitude: 37.7749, longitude: -122.4194, zoom: 12), mapType: .satellite,
            myLocationEnabled: true,
            markers: [marker("marker1", 37.7749, -122.4194, title: "San Francisco", snippet: "This is SF!"),
                      marker("marker2", 37.8044, -122.2711)]))

        XCTAssertEqual(try options([:]), GoogleMapOptions(
            camera: MapCamera(latitude: 0, longitude: 0, zoom: 14), mapType: .normal, myLocationEnabled: false,
            markers: []), "latitude and longitude 0, zoom 14, normal, no location, no markers")

        // Flutter's `prop<T>` cast throws in the build; on this SDK a prop of
        // the wrong type reads as absent (the generated types), as the video
        // player's: its default.
        XCTAssertEqual(try options([
            "latitude": "37", "longitude": true, "zoom": "12", "mapType": 1, "myLocationEnabled": "yes",
            "markers": ["id": "not a list"],
        ]), GoogleMapOptions())

        let model = try model(Self.demo)
        let node = try XCTUnwrap(model.resolve("main-map"))
        let view = GoogleMaps().view(node, model)
        XCTAssertEqual(view.id, "main-map")
        XCTAssertEqual(view.options, GoogleMapOptions(node))
    }

    func testC17_1_S_MapTypeIsFluttersAndTerrainDrawsMapKitsStandardMap() throws {
        for (prop, type, mapKit) in [
            ("normal", GoogleMapType.normal, MKMapType.standard), ("satellite", .satellite, .satellite),
            ("hybrid", .hybrid, .hybrid), ("terrain", .terrain, .standard), ("roadmap", .normal, .standard),
        ] {
            XCTAssertEqual(try options(["mapType": .string(prop)]).mapType, type, prop)
            XCTAssertEqual(type.mapKit, mapKit, "\(prop): MapKit has no relief map")
        }
        XCTAssertEqual(try options([:]).mapType.mapKit, .standard)
    }

    func testC17_1_S_TheMarkersReadFluttersFieldsAndSkipOnesWithoutBothCoordinates() throws {
        let markers = try options(["markers": [
            ["id": "full", "latitude": 1.5, "longitude": 2, "title": "Title", "snippet": "Snippet"],
            ["latitude": 3, "longitude": 4],
            ["id": 7, "latitude": 5, "longitude": 6, "title": 8, "snippet": false],
            "not a marker",
            ["id": "no-latitude", "longitude": 1],
            ["id": "no-longitude", "latitude": 1],
            ["id": "text-latitude", "latitude": "1", "longitude": 1],
            ["id": "dup", "latitude": 10, "longitude": 10, "title": "first"],
            ["id": "dup", "latitude": 20, "longitude": 20, "title": "last"],
            ["id": "far", "latitude": 100, "longitude": 190],
        ]]).markers

        XCTAssertEqual(markers, [
            marker("full", 1.5, 2, title: "Title", snippet: "Snippet"),
            marker("", 3, 4),
            marker("7", 5, 6),
            marker("dup", 20, 20, title: "last"),
            marker("far", 90, -170),
        ], """
            id the Dart toString ("" when absent), title "" and snippet none when absent (or, unlike Flutter's \
            throwing cast, not text); a marker without both numbers is skipped; one id once, the last (Flutter \
            keys them by id); positions as Google's LatLng (latitude clamped to 90, longitude into -180..<180)
            """)
    }

    // MARK: A map per node id

    func testC17_1_S_AMapIsRegisteredUnderItsNodeIdWhenCreatedAndRemovedWhenItLeaves() {
        let h = Harness()
        let options = GoogleMapOptions(camera: MapCamera(latitude: 37.7749, longitude: -122.4194, zoom: 12))
        let map = h.create("main-map", options)
        XCTAssertEqual(map.calls, ["show 37.7749 -122.4194 12.0", "apply"],
                       "created: the initial camera, not animated, then what follows the props")
        XCTAssertEqual(map.applied, [options])
        XCTAssertTrue(h.maps.surfaces["main-map"] === map)

        let other = h.create("other-map")
        XCTAssertEqual(Set(h.maps.surfaces.keys), ["main-map", "other-map"])

        h.maps.leave(map, id: "main-map")
        XCTAssertNil(h.maps.surfaces["main-map"], "removed when the view leaves")
        XCTAssertTrue(h.maps.surfaces["other-map"] === other)

        let newer = h.create("other-map")
        h.maps.leave(other, id: "other-map")
        XCTAssertTrue(h.maps.surfaces["other-map"] === newer, "an older map leaving keeps the newer one under the id")
    }

    func testC17_1_S_TheCameraPropsAreReadOnceAndTheRestFollowsThePropsOnEachUpdate() {
        let h = Harness()
        let map = h.create()
        let next = GoogleMapOptions(
            camera: MapCamera(latitude: 40.7128, longitude: -74.006, zoom: 3), mapType: .hybrid,
            myLocationEnabled: true, markers: [marker("nyc", 40.7128, -74.006)])
        h.maps.update(map, options: next)
        h.maps.update(map, options: GoogleMapOptions())

        XCTAssertEqual(map.calls, ["show 0.0 0.0 14.0", "apply", "apply", "apply"],
                       "an update never moves the camera (Flutter's initialCameraPosition)")
        XCTAssertEqual(map.applied, [GoogleMapOptions(), next, GoogleMapOptions()])
    }

    // MARK: The triggers

    func testC17_1_S_EachTriggerFiresFluttersNameAndPayload() async throws {
        let events: [(MapEvent, String, [String: JSONValue])] = [
            (.tap(latitude: 37.5, longitude: -122.25), "onTap", ["latitude": 37.5, "longitude": -122.25]),
            (.longPress(latitude: 1, longitude: 2), "onLongPress", ["latitude": 1.0, "longitude": 2.0]),
            (.cameraMove(MapCamera(latitude: 40.7128, longitude: -74.006, zoom: 13.5)), "onCameraMove",
             ["latitude": 40.7128, "longitude": -74.006, "zoom": 13.5]),
            (.markerTap(id: "marker1"), "onMarkerTap", ["markerId": "marker1"]),
        ]
        for (event, trigger, data) in events {
            XCTAssertEqual(event.trigger, trigger)
            XCTAssertEqual(event.eventData, data, trigger)
        }

        // Through the node's action, as Flutter's ctx.fireAction.
        let model = try model(Self.demo)
        let view = GoogleMaps().view(try XCTUnwrap(model.resolve("main-map")), model)
        await view.fire(.markerTap(id: "marker2"))?.value
        XCTAssertEqual(model.store.state.page["tapped"], "marker2")
        XCTAssertNil(view.fire(.tap(latitude: 1, longitude: 2)), "a trigger the node has no action for runs nothing")
    }

    // MARK: moveCamera

    func testC17_1_S_MoveCameraAnimatesTheMapRegisteredUnderTheTargetToTheCentreAndZoom() async throws {
        let h = Harness()
        let map = h.create()
        let other = h.create("other-map")
        try await h.run(["type": "moveCamera", "targetId": "main-map", "latitude": 40.7128, "longitude": -74.006,
                         "zoom": 11.5])
        try await h.run(["type": "custom:moveCamera", "targetId": "main-map", "latitude": 48, "longitude": 2])
        try await h.run(["type": "moveCamera", "targetId": "main-map", "latitude": 95, "longitude": 200, "zoom": 3])

        XCTAssertEqual(map.calls, ["show 0.0 0.0 14.0", "apply", "show 40.7128 -74.006 11.5 animated",
                                   "show 48.0 2.0 14.0 animated", "show 90.0 -160.0 3.0 animated"],
                       "zoom 14 when absent; the centre as Google's LatLng")
        XCTAssertEqual(other.calls, ["show 0.0 0.0 14.0", "apply"])
    }

    func testC17_1_S_MoveCameraWithAnUnknownOrEmptyTargetOrWithoutBothCoordinatesDoesNothing() async throws {
        let h = Harness()
        let map = h.create()
        for params: [String: JSONValue] in [
            ["targetId": "ghost", "latitude": 1, "longitude": 2],
            ["targetId": "", "latitude": 1, "longitude": 2],
            ["latitude": 1, "longitude": 2, "zoom": 3],
            ["targetId": .null, "latitude": 1, "longitude": 2],
            ["targetId": "main-map", "longitude": 2, "zoom": 3],
            ["targetId": "main-map", "latitude": 1],
            ["targetId": "main-map", "latitude": .null, "longitude": 2],
        ] {
            try await h.run(.object(params.merging(["type": "moveCamera"]) { $1 }))
        }
        XCTAssertEqual(map.calls, ["show 0.0 0.0 14.0", "apply"])

        h.maps.leave(map, id: "main-map")
        try await h.run(["type": "moveCamera", "targetId": "main-map", "latitude": 1, "longitude": 2])
        XCTAssertEqual(map.calls, ["show 0.0 0.0 14.0", "apply"], "a map that left is not moved")
    }

    func testC17_1_S_AMoveCameraNumberThatIsNotANumberFailsTheAction() async throws {
        let h = Harness()
        let map = h.create()
        for (params, message) in [
            (["latitude": "40", "longitude": 2], "latitude is not a number: 40"),
            (["latitude": 1, "longitude": true], "longitude is not a number: true"),
            (["latitude": 1, "longitude": 2, "zoom": "close"], "zoom is not a number: close"),
            (["longitude": 2, "zoom": ["a"]], "zoom is not a number: [a]"),
        ] as [([String: JSONValue], String)] {
            for target: JSONValue in ["main-map", "ghost"] {
                let failure = await h.failure(.object(params.merging(["type": "moveCamera", "targetId": target]) { $1 }))
                XCTAssertEqual(failure, message, "Dart's `as num?` throws before the map is looked up: the action fails")
            }
        }
        XCTAssertEqual(map.calls, ["show 0.0 0.0 14.0", "apply"])
    }

    func testC17_1_S_MoveCameraResolvesItsTargetAndNumbersAsValues() async throws {
        let h = Harness(StoreState(page: ["map": "main-map", "lat": 51.5, "lng": -0.12, "zoom": 9]))
        let map = h.create()
        let seven = h.create("7")
        func value(_ key: String) -> JSONValue { ["type": "state", "scope": "page", "key": .string(key)] }

        try await h.run(["type": "moveCamera", "targetId": value("map"), "latitude": value("lat"),
                         "longitude": value("lng"), "zoom": value("zoom")])
        try await h.run(["type": "moveCamera", "targetId": 7, "latitude": ["type": "static", "value": 1],
                         "longitude": 2])

        XCTAssertEqual(map.calls.last, "show 51.5 -0.12 9.0 animated")
        XCTAssertEqual(seven.calls.last, "show 1.0 2.0 14.0 animated", "a number reads as its Dart toString")
    }

    // MARK: Google's zoom

    func testC17_1_S_GooglesZoomGoesToAndFromAMapKitSpan() {
        // Zoom z: the world is 256 * 2^z points wide.
        let span = GoogleZoom.span(zoom: 12, latitude: 0, size: CGSize(width: 300, height: 300))
        XCTAssertEqual(span.longitudeDelta, 360 * 300 / (256 * 4096), accuracy: 1e-12)
        XCTAssertEqual(span.latitudeDelta, span.longitudeDelta, accuracy: span.longitudeDelta * 1e-6,
                       "at the equator a square view spans as many degrees each way")

        let north = GoogleZoom.span(zoom: 12, latitude: 60, size: CGSize(width: 300, height: 300))
        XCTAssertEqual(north.longitudeDelta, span.longitudeDelta, accuracy: 1e-12)
        XCTAssertEqual(north.latitudeDelta, span.longitudeDelta / 2, accuracy: span.longitudeDelta * 1e-5,
                       "Mercator: at 60° a degree of latitude is twice as tall as one of longitude")

        let wide = GoogleZoom.span(zoom: 3, latitude: 0, size: CGSize(width: 400, height: 200))
        XCTAssertEqual(wide.longitudeDelta, 360 * 400 / (256 * 8), accuracy: 1e-9)
        XCTAssertLessThan(wide.latitudeDelta, wide.longitudeDelta / 2, "the height, stretched further from the centre")

        for zoom in [0.0, 2.5, 12, 14, 21] {
            for width in [120.0, 300, 1024] {
                let delta = GoogleZoom.span(zoom: zoom, latitude: 37.7749, size: CGSize(width: width, height: 200))
                    .longitudeDelta
                XCTAssertEqual(GoogleZoom.zoom(longitudeDelta: delta, width: width), zoom, accuracy: 1e-9,
                               "back with log2 at zoom \(zoom), \(width) wide")
            }
        }
        XCTAssertEqual(GoogleZoom.zoom(longitudeDelta: 360, width: 256), 0, accuracy: 1e-12)
    }
}
#endif
