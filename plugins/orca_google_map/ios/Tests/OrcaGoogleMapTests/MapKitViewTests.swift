#if canImport(SwiftUI) && canImport(MapKit)
import Foundation
import MapKit
import SwiftUI
import XCTest
#if canImport(UIKit)
import UIKit
import UIKit.UIGestureRecognizerSubclass
#elseif canImport(AppKit)
import AppKit
#endif

import OrcaGateway
@testable import OrcaGoogleMap

/// C17.1/S on screen: the plugin's GoogleMap is a real MKMapView, drawn
/// through sdk-swift's NodeView in a real window, in the /map page's shape
/// (examples/server/custom.ts: a Column, a Container 300 high with 16 of
/// padding around the map, a Text under it). Its own path is checked here:
/// registered when made and gone when it leaves, its mapType, its region from
/// Google's zoom, its annotations and their callouts, its delegate and
/// gestures firing the node's triggers through model.fire, and moveCamera
/// animating it.
@MainActor
final class MapKitViewTests: XCTestCase {
    static let sf = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    static let nyc = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.006)

    /// The /map page on the real plugin, on screen.
    @MainActor final class Screen {
        let plugin = GoogleMapPlugin()
        let model: OrcaPageModel
        let shown = Shown()
        let hosted: Hosted

        /// `top`: where the window starts on the screen (100 clears an
        /// iPhone's status bar, so nothing is under a safe-area inset).
        init(_ page: PageResponse, top: CGFloat = 100) {
            let builders = WidgetBuilders()
            for (type, builder) in plugin.widgets { builders.register(type, builder) }
            model = OrcaPageModel(
                page: page, registry: WidgetRegistry(types: Set(GeneratedCapabilities.widgets).union(["GoogleMap"])),
                widgets: builders)
            for (type, handler) in plugin.actions { model.executor.registerHandler(type, handler) }
            hosted = Hosted(AnyView(Shown.Toggled(shown: shown, model: model)), top: top, width: 300, height: 600)
        }

        /// The map registered under "main-map" once it is laid out and placed.
        func map(_ test: MapKitViewTests) throws -> MapKitSurface {
            test.pump(until: { (self.plugin.maps.surfaces["main-map"] as? MapKitSurface)?.markerAnnotations.isEmpty == false })
            return try XCTUnwrap(plugin.maps.surfaces["main-map"] as? MapKitSurface, "no MKMapView on screen")
        }

        func page(_ key: String) -> JSONValue? { model.store.state.page[key] }

        func set(_ key: String, _ value: JSONValue) {
            Task { await model.run(.setState(.init(key: key, scope: .page, value: value))) }
        }

        func run(_ raw: JSONValue) throws {
            let action = try raw.decode(Action.self)
            Task { await model.run(action) }
        }
    }

    /// The /map page: `kind`, `pins` and `lat` in page state feed the map's
    /// mapType, markers and latitude; each trigger keeps its payload in page
    /// state.
    func page() throws -> PageResponse {
        let pins: JSONValue = [
            ["id": "marker1", "latitude": 37.7749, "longitude": -122.4194, "title": "San Francisco",
             "snippet": "This is SF!"],
            ["id": "marker2", "latitude": 37.8044, "longitude": -122.2711, "title": "Oakland"],
        ]
        var initial: [JSONValue] = [
            ["key": "kind", "scope": "page", "initial": "satellite"], ["key": "pins", "scope": "page", "initial": pins],
            ["key": "lat", "scope": "page", "initial": 37.7749], ["key": "markerId", "scope": "page", "initial": ""],
            ["key": "markerTaps", "scope": "page", "initial": 0],
        ]
        for key in ["tapLat", "tapLng", "pressLat", "pressLng", "camLat", "camLng", "camZoom"] {
            initial.append(["key": .string(key), "scope": "page", "initial": -1])
        }
        let components: [JSONValue] = [
            ["id": "column", "type": "Column", "kind": "layout", "childMode": "multi", "props": [:],
             "children": ["box", "below"], "watches": []],
            ["id": "box", "type": "Container", "kind": "layout", "childMode": "single",
             "props": ["width": 300, "height": 300, "padding": ["top": 16, "left": 16, "bottom": 16, "right": 16]],
             "children": ["main-map"], "watches": []],
            mapNode([
                "onTap": store([("tapLat", "latitude"), ("tapLng", "longitude")]),
                "onLongPress": store([("pressLat", "latitude"), ("pressLng", "longitude")]),
                "onCameraMove": store([("camLat", "latitude"), ("camLng", "longitude"), ("camZoom", "zoom")]),
                "onMarkerTap": store([("markerId", "markerId")], counting: "markerTaps"),
            ]),
            ["id": "below", "type": "Text", "kind": "primitive", "childMode": "none", "props": ["data": "Below the map"],
             "children": [], "watches": []],
        ]
        return try JSONValue.object([
            "pageId": "map", "title": "Map", "state": .array(initial), "components": .array(components),
        ]).decode(PageResponse.self)
    }

    /// The page's GoogleMap node, "main-map", with these actions, and its
    /// mapType `kind` in page state unless one is given.
    func mapNode(_ actions: [String: JSONValue], mapType: JSONValue? = nil) -> JSONValue {
        func state(_ key: String) -> JSONValue { ["type": "state", "scope": "page", "key": .string(key)] }
        return [
            "id": "main-map", "type": "GoogleMap", "kind": "primitive", "childMode": "none",
            "props": ["latitude": state("lat"), "longitude": -122.4194, "zoom": 12, "mapType": mapType ?? state("kind"),
                      "markers": state("pins")],
            "children": [], "watches": ["kind", "pins", "lat"], "actions": .object(actions),
        ]
    }

    /// Each event field into its page state key, and one more in `counting`
    /// (how many times the trigger fired).
    func store(_ pairs: [(String, String)], counting: String? = nil) -> JSONValue {
        var actions: [JSONValue] = pairs.map { key, field in
            ["type": "setState", "scope": "page", "key": .string(key), "value": ["type": "event", "key": .string(field)]]
        }
        if let counting {
            actions.append(["type": "setState", "scope": "page", "key": .string(counting), "value": [
                "type": "transform", "input": ["type": "state", "scope": "page", "key": .string(counting)],
                "by": [["type": "add", "by": 1]],
            ]])
        }
        return .object(["type": "actionGroup", "actions": .array(actions)])
    }

    /// Google's zoom of what the map shows now (its width, its longitude span).
    func zoom(_ map: MKMapView) -> Double {
        GoogleZoom.zoom(longitudeDelta: map.region.span.longitudeDelta, width: Double(map.bounds.width))
    }

    func annotation(_ map: MapKitSurface, _ id: String) throws -> MarkerAnnotation {
        try XCTUnwrap(map.markerAnnotations.first { $0.marker.id == id }, id)
    }

    // MARK: Made, placed, gone

    func testC17_1_S_InSdkSwiftsColumnTheMapFillsTheDemos300HighBox() throws {
        let screen = Screen(try page())
        defer { screen.hosted.close() }
        let map = try screen.map(self)

        XCTAssertEqual(screen.hosted.frame(of: map), CGRect(x: 16, y: 16, width: 268, height: 268),
                       "the Container's 300 x 300 less its 16 of padding")
    }

    func testC17_1_S_OnScreenTheMapIsRegisteredUnderItsNodeIdAndRemovedWhenItLeaves() throws {
        let screen = Screen(try page())
        defer { screen.hosted.close() }
        let map = try screen.map(self)
        XCTAssertTrue(map.delegate is MapKitView.Coordinator)
        XCTAssertEqual(Array(screen.plugin.maps.surfaces.keys), ["main-map"])

        screen.shown.on = false
        pump(until: { screen.plugin.maps.surfaces.isEmpty })
        XCTAssertTrue(screen.plugin.maps.surfaces.isEmpty, "the map that left is still registered")
    }

    // MARK: The props

    func testC17_1_S_TheMapShowsGooglesZoomAroundTheCameraPropsAndItsMapTypeAndMarkers() throws {
        // At the screen's top, so on an iPhone the status bar covers the
        // map's top: MapKit fits a region inside the safe area.
        let screen = Screen(try page(), top: 0)
        defer { screen.hosted.close() }
        let map = try screen.map(self)
        #if os(iOS)
        XCTAssertGreaterThan(map.safeAreaInsets.top, 0, "the map is not under the status bar")
        #endif

        XCTAssertEqual(map.region.center.latitude, Self.sf.latitude, accuracy: 1e-4)
        XCTAssertEqual(map.region.center.longitude, Self.sf.longitude, accuracy: 1e-4)
        XCTAssertEqual(zoom(map), 12, accuracy: 0.01, "zoom 12 across the map's 268 points")
        XCTAssertEqual(map.mapType, .satellite)
        XCTAssertFalse(map.showsUserLocation, "myLocationEnabled false")

        let pins = map.markerAnnotations.sorted { $0.marker.id < $1.marker.id }
        XCTAssertEqual(pins.map(\.marker.id), ["marker1", "marker2"])
        XCTAssertEqual(pins.map(\.title), ["San Francisco", "Oakland"])
        XCTAssertEqual(pins.map(\.subtitle), ["This is SF!", nil], "the snippet under the title in the callout")
        XCTAssertEqual(pins.map(\.coordinate.latitude), [37.7749, 37.8044])
        XCTAssertEqual(pins.map(\.coordinate.longitude), [-122.4194, -122.2711])

        // MapKit makes a pin's view as it lays the map out.
        pump(until: { map.view(for: pins[0]) != nil })
        let pin = try XCTUnwrap(map.view(for: pins[0]), "marker1 is not on screen")
        XCTAssertTrue(pin.canShowCallout, "the title and snippet in a callout")
        XCTAssertNotNil(pin.image, "an invisible pin")
        XCTAssertGreaterThan(pin.bounds.width, 20)
    }

    /// Google's default marker, which Flutter draws, is red: the pin is a
    /// white glyph on a red disc, its palette kept (an image drawn as a
    /// template loses it, the disc drawn black).
    func testC17_1_S_TheMarkersPinIsWhiteOnARedDiscAsGooglesDefaultMarkerIs() throws {
        let screen = Screen(try page())
        defer { screen.hosted.close() }
        let map = try screen.map(self)
        _ = try middle(of: "marker1", on: map)
        let pin = try XCTUnwrap(map.view(for: try annotation(map, "marker1")), "marker1 is not on screen")
        let image = try XCTUnwrap(pin.image, "an invisible pin")
        #if canImport(UIKit)
        XCTAssertEqual(image.renderingMode, .alwaysOriginal, "the pin is drawn as a template")
        #elseif canImport(AppKit)
        XCTAssertFalse(image.isTemplate, "the pin is drawn as a template")
        #endif

        // The disc left of the glyph, halfway down, as the view draws it.
        let disc = try colour(of: pin, at: CGPoint(x: pin.bounds.width * 0.22, y: pin.bounds.height / 2))
        XCTAssertGreaterThan(disc.alpha, 0.9, "nothing drawn on the disc")
        XCTAssertGreaterThan(disc.red, 0.7, "the disc is not red: \(disc)")
        XCTAssertLessThan(disc.green, 0.4, "the disc is not red: \(disc)")
        XCTAssertLessThan(disc.blue, 0.4, "the disc is not red: \(disc)")
    }

    func testC17_1_S_MapTypeAndMarkersFollowThePropsAndTheCameraDoesNot() throws {
        let screen = Screen(try page())
        defer { screen.hosted.close() }
        let map = try screen.map(self)
        let kept = try annotation(map, "marker1")

        screen.set("kind", "terrain")
        screen.set("pins", [["id": "marker1", "latitude": 37.7749, "longitude": -122.4194, "title": "San Francisco",
                             "snippet": "This is SF!"],
                            ["id": "nyc", "latitude": 40.7128, "longitude": -74.006]])
        screen.set("lat", 10)
        pump(until: { Set(map.markerAnnotations.map(\.marker.id)) == ["marker1", "nyc"] && map.mapType == .standard })

        XCTAssertEqual(map.mapType, .standard, "terrain: MapKit's standard map")
        XCTAssertEqual(Set(map.markerAnnotations.map(\.marker.id)), ["marker1", "nyc"])
        XCTAssertTrue(map.annotations.contains { $0 === kept }, "an unchanged marker stays as it is")
        XCTAssertEqual(map.region.center.latitude, Self.sf.latitude, accuracy: 1e-4,
                       "the camera is the props' when the map was made")
        XCTAssertEqual(screen.page("camZoom"), -1, "nothing moved the camera")
    }

    // MARK: The triggers

    func testC17_1_S_SelectingAMarkerFiresOnMarkerTapWithItsId() throws {
        let screen = Screen(try page())
        defer { screen.hosted.close() }
        let map = try screen.map(self)

        let marker = try annotation(map, "marker1")
        map.selectAnnotation(marker, animated: false)
        pump(until: { screen.page("markerId") == "marker1" })
        XCTAssertEqual(screen.page("markerId"), "marker1")
        XCTAssertTrue(map.selectedAnnotations.contains { $0 === marker })
    }

    /// Google fires onMarkerTap on every tap on a marker; MapKit selects a
    /// marker once, so a tap on the one already selected is the tap's. A tap
    /// on its callout is not a tap on the marker.
    func testC17_1_S_ATapOnTheSelectedMarkerFiresOnMarkerTapAgainAndAFirstTapFiresItOnce() throws {
        let screen = Screen(try page())
        defer { screen.hosted.close() }
        let map = try screen.map(self)
        let coordinator = try XCTUnwrap(map.delegate as? MapKitView.Coordinator)
        let marker = try annotation(map, "marker1")

        // A first tap: it begins with nothing selected, MapKit selects the
        // marker (didSelect), then the tap ends on its pin.
        var pin = try middle(of: "marker1", on: map)
        try touchBegins(on: map, coordinator)
        gesture(on: coordinator) {
            map.selectAnnotation(marker, animated: false)
            coordinator.tapped(at: pin, on: map)
        }
        // didSelect's, should MapKit call it after selecting.
        pump(until: { screen.page("markerTaps") != 0 })
        XCTAssertEqual(screen.page("markerTaps"), 1, "a first tap fires onMarkerTap once")
        XCTAssertEqual(screen.page("markerId"), "marker1")

        // Again, on the pin still selected: MapKit selects nothing.
        screen.set("markerId", "")
        pump(until: { screen.page("markerId") == "" })
        pin = try middle(of: "marker1", on: map)
        try touchBegins(on: map, coordinator)
        gesture(on: coordinator) { coordinator.tapped(at: pin, on: map) }
        XCTAssertEqual(screen.page("markerId"), "marker1", "a tap on the selected marker fired nothing")
        XCTAssertEqual(screen.page("markerTaps"), 2)
        XCTAssertTrue(map.selectedAnnotations.contains { $0 === marker })
        XCTAssertEqual(screen.page("tapLat"), -1, "a tap on a marker fired onTap")

        // On its callout (MapKit puts it in the pin's view): Google's info
        // window, whose tap is neither onMarkerTap nor onTap.
        let view = try XCTUnwrap(map.view(for: marker))
        pump(until: { view.subviews.contains { !$0.isHidden } })
        let callout = try XCTUnwrap(view.subviews.first { !$0.isHidden }, "no callout on the selected marker")
        let onCallout = callout.convert(CGPoint(x: callout.bounds.midX, y: callout.bounds.midY), to: map)
        XCTAssertTrue(map.annotationView(at: onCallout) === view, "the callout is not in the pin's view")
        try touchBegins(on: map, coordinator)
        gesture(on: coordinator) { coordinator.tapped(at: onCallout, on: map) }
        XCTAssertEqual(screen.page("markerTaps"), 2, "a tap on the callout fired onMarkerTap")
        XCTAssertEqual(screen.page("tapLat"), -1, "a tap on the callout fired onTap")
    }

    func testC17_1_S_ATapOffAnyMarkerFiresOnTapAndALongPressFiresOnLongPressWithTheirCoordinates() throws {
        let screen = Screen(try page())
        defer { screen.hosted.close() }
        let map = try screen.map(self)
        let coordinator = try XCTUnwrap(map.delegate as? MapKitView.Coordinator)

        #if canImport(UIKit)
        let mine = (map.gestureRecognizers ?? []).filter { $0.delegate === coordinator }
        XCTAssertEqual(mine.compactMap { ($0 as? UITapGestureRecognizer)?.numberOfTapsRequired }.sorted(), [1, 2],
                       "a tap, and a double tap it waits out (a double tap zooms)")
        XCTAssertEqual(mine.filter { $0 is UILongPressGestureRecognizer }.count, 1)
        #elseif canImport(AppKit)
        let mine = map.gestureRecognizers.filter { $0.delegate === coordinator }
        XCTAssertEqual(mine.compactMap { ($0 as? NSClickGestureRecognizer)?.numberOfClicksRequired }.sorted(), [1, 2],
                       "a click, and a double click it waits out (a double click zooms)")
        XCTAssertEqual(mine.filter { $0 is NSPressGestureRecognizer }.count, 1)
        #endif

        // On the marker: no onTap.
        let onMarker = try middle(of: "marker1", on: map)
        gesture(on: coordinator) { coordinator.tapped(at: onMarker, on: map) }
        XCTAssertEqual(screen.page("tapLat"), -1, "a tap on a marker fired onTap")

        let off = CGPoint(x: 30, y: 40)
        let there = map.convert(off, toCoordinateFrom: map)
        gesture(on: coordinator) { coordinator.tapped(at: off, on: map) }
        XCTAssertEqual(screen.page("tapLat")?.doubleValue ?? 0, there.latitude, accuracy: 1e-9)
        XCTAssertEqual(screen.page("tapLng")?.doubleValue ?? 0, there.longitude, accuracy: 1e-9)

        let press = CGPoint(x: 200, y: 100)
        let pressed = map.convert(press, toCoordinateFrom: map)
        gesture(on: coordinator) { coordinator.longPressed(at: press, on: map) }
        XCTAssertEqual(screen.page("pressLat")?.doubleValue ?? 0, pressed.latitude, accuracy: 1e-9)
        XCTAssertEqual(screen.page("pressLng")?.doubleValue ?? 0, pressed.longitude, accuracy: 1e-9)
        XCTAssertEqual(screen.page("markerId"), "", "no marker was tapped")
    }

    func testC17_1_S_MoveCameraAnimatesTheMapAndOnCameraMoveFiresWhileItMoves() throws {
        let screen = Screen(try page())
        defer { screen.hosted.close() }
        let map = try screen.map(self)
        // Laid out at the initial camera, its pins drawn where it put them.
        _ = try middle(of: "marker1", on: map)
        XCTAssertEqual(screen.page("camZoom"), -1, "placing the initial camera is not a move")

        try screen.run(["type": "moveCamera", "targetId": "main-map", "latitude": 40.7128, "longitude": -74.006,
                        "zoom": 14])
        pump(until: { abs((screen.page("camZoom")?.doubleValue ?? 0) - 14) < 0.01 &&
                      abs((screen.page("camLat")?.doubleValue ?? 0) - Self.nyc.latitude) < 1e-4 })

        XCTAssertEqual(map.region.center.latitude, Self.nyc.latitude, accuracy: 1e-4)
        XCTAssertEqual(map.region.center.longitude, Self.nyc.longitude, accuracy: 1e-4)
        XCTAssertEqual(zoom(map), 14, accuracy: 0.01)
        XCTAssertEqual(screen.page("camLat")?.doubleValue ?? 0, Self.nyc.latitude, accuracy: 1e-4,
                       "onCameraMove {latitude} did not follow the camera")
        XCTAssertEqual(screen.page("camLng")?.doubleValue ?? 0, Self.nyc.longitude, accuracy: 1e-4)
        XCTAssertEqual(screen.page("camZoom")?.doubleValue ?? 0, 14, accuracy: 0.01)

        // To the edge of what Google's LatLng takes, without a MapKit
        // exception: the pole and the whole world, until the map is over
        // longitude 200 as LatLng keeps it, -160 (the move has run to its end).
        try screen.run(["type": "moveCamera", "targetId": "main-map", "latitude": 95, "longitude": 200, "zoom": 0])
        pump(until: { abs(map.region.center.longitude + 160) < 1e-4 })
        XCTAssertTrue(CLLocationCoordinate2DIsValid(map.region.center))
    }


    func testC17_1_S_TheTriggersRunTheNodesActionsAsTheyAreNow() throws {
        let screen = Screen(try page())
        defer { screen.hosted.close() }
        let map = try screen.map(self)

        // The new node's map is hybrid too: the map showing it is SwiftUI's
        // update with the new node, which hands the map its triggers' new
        // actions as it hands it the props.
        try screen.run(["type": "replaceComponent", "targetId": "main-map", "components": [mapNode([
            "onMarkerTap": ["type": "setState", "scope": "page", "key": "markerId",
                            "value": ["type": "static", "value": "the new action"]],
        ], mapType: "hybrid")]])
        pump(until: { (screen.plugin.maps.surfaces["main-map"] as? MapKitSurface)?.mapType == .hybrid })
        XCTAssertTrue(screen.plugin.maps.surfaces["main-map"] === map, "the node's new actions made a new map")
        XCTAssertEqual(map.mapType, .hybrid, "the map has not had the new node")

        map.selectAnnotation(try annotation(map, "marker1"), animated: false)
        pump(until: { screen.page("markerId") != "" })
        XCTAssertEqual(screen.page("markerId"), "the new action", "a trigger ran the node's old action")
    }

    /// The map's own gestures, on a map off screen with its triggers recorded.
    func testC17_1_S_ALongPressFiresOnceAsItBeginsAndATapWaitsOutADoubleTap() throws {
        final class Fired {
            var events: [MapEvent] = []
        }
        let fired = Fired()
        let map = MapKitSurface(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let coordinator = MapKitView.Coordinator(id: "m", maps: GoogleMaps(), fire: {
            fired.events.append($0)
            return nil
        })
        coordinator.listen(to: map)

        #if canImport(UIKit)
        let mine = (map.gestureRecognizers ?? []).filter { $0.delegate === coordinator }
        let taps = mine.compactMap { $0 as? UITapGestureRecognizer }
        let tap = try XCTUnwrap(taps.first { $0.numberOfTapsRequired == 1 })
        let double = try XCTUnwrap(taps.first { $0.numberOfTapsRequired == 2 })
        let press = try XCTUnwrap(mine.compactMap { $0 as? UILongPressGestureRecognizer }.first)
        let mapKits = UIPanGestureRecognizer()
        #elseif canImport(AppKit)
        let mine = map.gestureRecognizers.filter { $0.delegate === coordinator }
        let clicks = mine.compactMap { $0 as? NSClickGestureRecognizer }
        let tap = try XCTUnwrap(clicks.first { $0.numberOfClicksRequired == 1 })
        let double = try XCTUnwrap(clicks.first { $0.numberOfClicksRequired == 2 })
        let press = try XCTUnwrap(mine.compactMap { $0 as? NSPressGestureRecognizer }.first)
        let mapKits = NSPanGestureRecognizer()
        #endif
        XCTAssertEqual(mine.count, 3)
        XCTAssertTrue(coordinator.gestureRecognizer(tap, shouldRequireFailureOf: double),
                      "a tap waits out a double tap (MapKit's zoom), as Google's onTap does")
        for (gesture, other) in [(double, tap), (tap, mapKits), (press, double)] {
            XCTAssertFalse(coordinator.gestureRecognizer(gesture, shouldRequireFailureOf: other))
        }
        XCTAssertTrue(coordinator.gestureRecognizer(tap, shouldRecognizeSimultaneouslyWith: mapKits),
                      "beside MapKit's own gestures")

        // A press fires as it begins, not before and not after (AppKit
        // sets a press's state only as it recognizes one).
        coordinator.press(press)
        #if canImport(UIKit)
        press.state = .began
        coordinator.press(press)
        press.state = .changed
        coordinator.press(press)
        #endif
        coordinator.tap(tap)
        #if canImport(UIKit)
        XCTAssertEqual(fired.events.map(\.trigger), ["onLongPress", "onTap"], "a long press fires once, as it begins")
        #elseif canImport(AppKit)
        XCTAssertEqual(fired.events.map(\.trigger), ["onTap"], "a press that has not begun fired")
        #endif
    }

    // MARK: Helpers

    /// The colour `view`'s layer draws at `point` (from its top left), its
    /// components 0 to 1, unpremultiplied.
    func colour(of view: MKAnnotationView, at point: CGPoint) throws
        -> (red: Double, green: Double, blue: Double, alpha: Double) {
        #if canImport(UIKit)
        let layer = view.layer
        #elseif canImport(AppKit)
        let layer = try XCTUnwrap(view.layer, "the pin has no layer")
        #endif
        let scale: CGFloat = 2
        let width = Int(view.bounds.width * scale), height = Int(view.bounds.height * scale)
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        // Top left first, as the view's coordinates.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        layer.render(in: context)
        let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = Int(point.y * scale) * width * 4 + Int(point.x * scale) * 4
        let alpha = Double(pixels[offset + 3]) / 255
        func component(_ index: Int) -> Double { alpha > 0 ? Double(pixels[offset + index]) / 255 / alpha : 0 }
        return (component(0), component(1), component(2), alpha)
    }

    /// The middle of the marker `id`'s pin, once MapKit has made it, put it
    /// there and shown it.
    func middle(of id: String, on map: MapKitSurface) throws -> CGPoint {
        let marker = try annotation(map, id)
        let place = map.convert(marker.coordinate, toPointTo: map)
        func middle(of pin: MKAnnotationView) -> CGPoint {
            pin.convert(CGPoint(x: pin.bounds.midX, y: pin.bounds.midY), to: map)
        }
        pump(until: {
            guard let pin = map.view(for: marker), !pin.isHidden else { return false }
            return hypot(middle(of: pin).x - place.x, middle(of: pin).y - place.y) < 1
        })
        let pin = try XCTUnwrap(map.view(for: marker), "\(id) is not on screen")
        XCTAssertFalse(pin.isHidden, "the pin is not shown")
        XCTAssertEqual(middle(of: pin).x, place.x, accuracy: 1, "the pin is not over its marker")
        XCTAssertEqual(middle(of: pin).y, place.y, accuracy: 1)
        return middle(of: pin)
    }

    /// Does `body`, a gesture handed to the map's coordinator, and runs the
    /// main run loop until the actions of the triggers it fired have run. A
    /// trigger fires, or does not, as the coordinator takes the gesture; its
    /// action runs in a task after (model.fire), so what is checked next is
    /// all the gesture did.
    func gesture(on coordinator: MapKitView.Coordinator, _ body: () -> Void) {
        @MainActor final class Fired {
            var tasks: [Task<Void, Never>] = []
            var ran = false
        }
        let fired = Fired()
        let fire = coordinator.fire
        coordinator.fire = { event in
            let task = fire(event)
            if let task { fired.tasks.append(task) }
            return task
        }
        body()
        coordinator.fire = fire
        Task { [tasks = fired.tasks] in
            for task in tasks { await task.value }
            fired.ran = true
        }
        pump(until: { fired.ran })
        XCTAssertTrue(fired.ran, "the fired actions did not run")
    }

    /// What UIKit (AppKit) asks the map's tap as a touch (a click) begins;
    /// the tap still takes it.
    func touchBegins(on map: MapKitSurface, _ coordinator: MapKitView.Coordinator) throws {
        #if canImport(UIKit)
        let tap = try XCTUnwrap((map.gestureRecognizers ?? []).first {
            $0.delegate === coordinator && ($0 as? UITapGestureRecognizer)?.numberOfTapsRequired == 1
        })
        XCTAssertEqual((coordinator as UIGestureRecognizerDelegate).gestureRecognizer?(tap, shouldReceive: UITouch()),
                       true)
        #elseif canImport(AppKit)
        let click = try XCTUnwrap(map.gestureRecognizers.first {
            $0.delegate === coordinator && ($0 as? NSClickGestureRecognizer)?.numberOfClicksRequired == 1
        })
        let down = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))
        XCTAssertEqual(
            (coordinator as NSGestureRecognizerDelegate).gestureRecognizer?(click, shouldAttemptToRecognizeWith: down),
            true)
        #endif
    }

    /// Runs the main run loop until `done`, so SwiftUI draws, MapKit lays out
    /// and the fired actions run. 30 s at most: on CI's iOS simulator MapKit
    /// can hold the main thread for 15 s and more as it loads.
    func pump(until done: () -> Bool, timeout: Double = 30) {
        let deadline = Date().addingTimeInterval(timeout)
        while !done() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    }

    /// Whether the page is on screen.
    @MainActor final class Shown: ObservableObject {
        @Published var on = true

        struct Toggled: View {
            @ObservedObject var shown: Shown
            let model: OrcaPageModel

            var body: some View {
                if shown.on { NodeView(id: "column", model: model) }
            }
        }
    }

    /// A view in a real window (UIKit or AppKit), as sdk-swift's
    /// LifecycleTests host a node, kept on screen until `close`.
    @MainActor final class Hosted {
        #if canImport(UIKit)
        private let window: UIWindow
        #elseif canImport(AppKit)
        private let window: NSWindow
        #endif

        init(_ content: AnyView, top: CGFloat, width: CGFloat, height: CGFloat) {
            let root = content.frame(width: width, height: height, alignment: .topLeading)
            let size = CGRect(x: 0, y: 0, width: width, height: height)
            #if canImport(UIKit)
            let host = UIHostingController(rootView: root)
            window = UIWindow(frame: size.offsetBy(dx: 0, dy: top))
            window.rootViewController = host
            window.isHidden = false
            host.view.frame = size
            host.view.layoutIfNeeded()
            #elseif canImport(AppKit)
            window = NSWindow(contentRect: size.offsetBy(dx: 0, dy: top), styleMask: [.titled], backing: .buffered,
                              defer: false)
            window.isReleasedWhenClosed = false
            let host = NSHostingView(rootView: root)
            host.frame = size
            window.contentView = host
            window.orderFront(nil)
            window.contentView?.layoutSubtreeIfNeeded()
            #endif
        }

        /// Where `view` is, from the top left of the content.
        func frame(of view: MKMapView) -> CGRect {
            #if canImport(UIKit)
            return view.convert(view.bounds, to: window.rootViewController?.view)
            #elseif canImport(AppKit)
            let root = window.contentView!
            let rect = view.convert(view.bounds, to: root)
            return root.isFlipped ? rect : CGRect(
                x: rect.minX, y: root.bounds.height - rect.maxY, width: rect.width, height: rect.height)
            #endif
        }

        func close() {
            #if canImport(UIKit)
            window.isHidden = true
            #elseif canImport(AppKit)
            window.orderOut(nil)
            #endif
        }
    }
}
#endif
