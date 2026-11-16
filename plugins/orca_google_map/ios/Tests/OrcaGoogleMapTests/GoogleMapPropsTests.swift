import Foundation
import XCTest

import OrcaGateway
import OrcaGoogleMap

/// C17.5/S: the types `orca plugin generate --lang swift --types-only` writes
/// for orca_plugin.yaml (Generated/OrcaGoogleMapTypes.swift, kept equal to
/// the generator's output by cli/test/google_map_swift_props_test.dart)
/// read what the Flutter plugin reads (lib/src/google_map_plugin.dart):
/// the GoogleMap node's seven props (markers as the list, each entry read for
/// id, latitude, longitude, title and snippet), its four trigger names, and
/// moveCamera's params from the raw action object.
///
/// P-pkg/S: the manifest takes the SDK by path inside the monorepo and from
/// its mirror once split out, by where the manifest is.
final class GoogleMapPropsTests: XCTestCase {
    /// A GoogleMap node with these props, resolved against `state` as the
    /// SDK resolves a page's node.
    func node(_ props: [String: JSONValue], state: StoreState = StoreState()) throws -> ResolvedNode {
        let page = try JSONValue.object([
            "pageId": "map", "title": "Map", "state": [],
            "components": [
                ["id": "main-map", "type": "GoogleMap", "kind": "primitive", "childMode": "none",
                 "props": .object(props), "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self)
        let renderer = PageRenderer(page: page, registry: WidgetRegistry(types: ["GoogleMap"]))
        return try XCTUnwrap(renderer.resolve("main-map", state: state))
    }

    func testC17_5_S_GoogleMapPropsReadFluttersSevenProps() throws {
        let props = GoogleMapProps(try node([
            "latitude": 37.7749, "longitude": -122.4194, "zoom": 12.5, "mapType": "satellite",
            "myLocationEnabled": true, "zoomControlsEnabled": false,
            "markers": [
                ["id": "marker1", "latitude": 37.7749, "longitude": -122.4194,
                 "title": "San Francisco", "snippet": "This is SF!"],
                ["id": "marker2", "latitude": 37.8044, "longitude": -122.2711],
                "not a marker",
            ],
        ]))
        XCTAssertEqual(props.latitude, 37.7749)
        XCTAssertEqual(props.longitude, -122.4194)
        XCTAssertEqual(props.zoom, 12.5)
        XCTAssertEqual(props.mapType, "satellite")
        XCTAssertEqual(props.myLocationEnabled, true)
        XCTAssertEqual(props.zoomControlsEnabled, false)

        // The list as sent (Flutter's `ctx.prop<List>('markers')`), each entry
        // read by key; one that is not an object stays for the plugin to skip.
        let markers = try XCTUnwrap(props.markers?.arrayValue)
        XCTAssertEqual(markers.count, 3)
        XCTAssertEqual(markers[0]["id"].stringValue, "marker1")
        XCTAssertEqual(markers[0]["latitude"].doubleValue, 37.7749)
        XCTAssertEqual(markers[0]["longitude"].doubleValue, -122.4194)
        XCTAssertEqual(markers[0]["title"].stringValue, "San Francisco")
        XCTAssertEqual(markers[0]["snippet"].stringValue, "This is SF!")
        XCTAssertEqual(markers[1]["id"].stringValue, "marker2")
        XCTAssertNil(markers[1]["title"].stringValue, "the plugin defaults it to \"\"")
        XCTAssertNil(markers[1]["snippet"].stringValue, "the info window has no text")
        XCTAssertNil(markers[2].objectValue)

        // A number, whole or not (Flutter's `ctx.prop<num>(…)?.toDouble()`,
        // a marker's `(m['latitude'] as num?)?.toDouble()`).
        let whole = GoogleMapProps(try node([
            "latitude": 40, "longitude": -74, "zoom": 14,
            "markers": [["id": "nyc", "latitude": 40, "longitude": -74]],
        ]))
        XCTAssertEqual(whole.latitude, 40)
        XCTAssertEqual(whole.longitude, -74)
        XCTAssertEqual(whole.zoom, 14)
        XCTAssertEqual(whole.markers?.arrayValue?.first?["latitude"].doubleValue, 40)
        XCTAssertEqual(whole.markers?.arrayValue?.first?["longitude"].doubleValue, -74)

        // Read resolved, as Flutter's ctx.prop, a Value inside a marker too
        // (both resolve props deep).
        let bound = GoogleMapProps(try node(
            ["zoom": ["type": "state", "key": "zoom", "scope": "page"],
             "markers": [["id": "here", "latitude": ["type": "state", "key": "lat", "scope": "page"],
                          "longitude": 2.35, "title": ["type": "state", "key": "name", "scope": "page"]]]],
            state: StoreState(page: ["zoom": 10, "lat": 48.86, "name": "Paris"])))
        XCTAssertEqual(bound.zoom, 10)
        let here = try XCTUnwrap(bound.markers?.arrayValue?.first)
        XCTAssertEqual(here["latitude"].doubleValue, 48.86)
        XCTAssertEqual(here["title"].stringValue, "Paris")
    }

    func testC17_5_S_AbsentPropsReadNil() throws {
        let props = GoogleMapProps(try node([:]))
        XCTAssertNil(props.latitude, "the plugin defaults it to 0")
        XCTAssertNil(props.longitude, "the plugin defaults it to 0")
        XCTAssertNil(props.zoom, "the plugin defaults it to 14")
        XCTAssertNil(props.mapType, "the plugin draws normal")
        XCTAssertNil(props.myLocationEnabled, "the plugin defaults it to false")
        XCTAssertNil(props.zoomControlsEnabled, "the plugin defaults it to true")
        XCTAssertNil(props.markers, "the plugin draws no pins")
        XCTAssertEqual(props.node.id, "main-map")
    }

    func testC17_5_S_TheTriggerNamesAreFlutters() {
        XCTAssertEqual(
            [GoogleMapProps.Triggers.onTap, GoogleMapProps.Triggers.onLongPress,
             GoogleMapProps.Triggers.onCameraMove, GoogleMapProps.Triggers.onMarkerTap],
            ["onTap", "onLongPress", "onCameraMove", "onMarkerTap"])
    }

    func testC17_5_S_MoveCameraParamsReadFluttersParams() {
        let move = MoveCameraParams([
            "type": "moveCamera", "targetId": "main-map", "latitude": 40.7128, "longitude": -74.006, "zoom": 12.5,
        ])
        XCTAssertEqual(move.targetId, "main-map")
        XCTAssertEqual(move.latitude, 40.7128)
        XCTAssertEqual(move.longitude, -74.006)
        XCTAssertEqual(move.zoom, 12.5)

        // A number, whole or not (Flutter's `as num?` then `toDouble()`).
        let whole = MoveCameraParams(["type": "moveCamera", "targetId": "main-map", "latitude": 40, "longitude": -74,
                                      "zoom": 12])
        XCTAssertEqual(whole.latitude, 40)
        XCTAssertEqual(whole.longitude, -74)
        XCTAssertEqual(whole.zoom, 12)

        // Missing: no target or no coordinate does nothing, no zoom is 14.
        let bare = MoveCameraParams(["type": "moveCamera"])
        XCTAssertNil(bare.targetId)
        XCTAssertNil(bare.latitude)
        XCTAssertNil(bare.longitude)
        XCTAssertNil(bare.zoom)

        // Flutter resolves each param as a value: one sent as a Value reads
        // nil here and stays in the raw action for the plugin to resolve.
        let id: JSONValue = ["type": "state", "key": "map", "scope": "page"]
        let lat: JSONValue = ["type": "state", "key": "lat", "scope": "page"]
        let zoom: JSONValue = ["type": "static", "value": 9]
        let bound = MoveCameraParams(["type": "moveCamera", "targetId": id, "latitude": lat, "longitude": 2.35,
                                      "zoom": zoom])
        XCTAssertNil(bound.targetId)
        XCTAssertNil(bound.latitude)
        XCTAssertNil(bound.zoom)
        XCTAssertEqual(bound.longitude, 2.35)
        XCTAssertEqual(bound.action["targetId"], id)
        XCTAssertEqual(bound.action["latitude"], lat)
        XCTAssertEqual(bound.action["zoom"], zoom)
    }

    #if os(macOS)
    /// This package's directory (this file is Tests/OrcaGoogleMapTests/).
    let packageDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testP_pkg_S_TheManifestTakesTheSDKByPathInTheMonorepoAndFromItsMirrorSplitOut() throws {
        let sdk = packageDir.appendingPathComponent("../../../sdk-swift").standardizedFileURL
        let elsewhere = try temporaryDirectory()

        // In place, evaluated from a directory with no sdk-swift beside it.
        let inPlace = try dumpPackage(packageDir, from: elsewhere)
        XCTAssertEqual(inPlace["name"], "OrcaGoogleMap")
        XCTAssertEqual(inPlace["products"].arrayValue?.map { $0["name"] }, ["OrcaGoogleMap"])
        XCTAssertEqual(inPlace["targets"].arrayValue?.map { $0["name"] },
                       ["OrcaGoogleMap", "OrcaGoogleMapTests"])
        XCTAssertEqual(inPlace["platforms"], try dumpPackage(sdk, from: elsewhere)["platforms"],
                       "the SDK's platforms")
        XCTAssertEqual(inPlace["dependencies"].arrayValue?.count, 1)
        let local = only(only(inPlace["dependencies"])["fileSystem"])
        XCTAssertEqual(local["identity"], "sdk-swift")
        XCTAssertEqual(local["path"].stringValue.map { URL(fileURLWithPath: $0).standardizedFileURL }, sdk)

        // Split out (the manifest at the root of its mirror), evaluated from
        // this package's directory, where ../../../sdk-swift exists.
        let split = elsewhere.appendingPathComponent("split")
        try FileManager.default.createDirectory(at: split, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: packageDir.appendingPathComponent("Package.swift"), to: split.appendingPathComponent("Package.swift"))
        let mirror = try dumpPackage(split, from: packageDir)["dependencies"]
        XCTAssertEqual(mirror.arrayValue?.count, 1)
        let remote = only(only(mirror)["sourceControl"])
        XCTAssertEqual(remote["identity"], "orca-gateway-swift")
        // The URL as a whole JSON string anywhere in the location: SwiftPM
        // writes it bare before its SourceControlURL type, `{"urlString": …}`
        // since.
        let location = String(decoding: try remote["location"].encoded(), as: UTF8.self)
        XCTAssertTrue(location.contains("\"https://github.com/orca-gateway/orca-gateway-swift\""), location)
        XCTAssertEqual(only(remote["requirement"]["range"]), ["lowerBound": "0.1.0-alpha.2", "upperBound": "1.0.0"],
                       "the first sdk-swift release with the plugin API, up to the next major")
    }

    /// The single element of a one-element array, else null.
    func only(_ value: JSONValue) -> JSONValue {
        guard let array = value.arrayValue, array.count == 1 else { return .null }
        return array[0]
    }

    /// A new empty directory, removed after the test.
    func temporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("orca-google-map-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    /// `swift package dump-package` of the package in `dir`, run from `cwd`
    /// with its own scratch directory (this package's .build is the running
    /// test's), as JSON.
    func dumpPackage(_ dir: URL, from cwd: URL) throws -> JSONValue {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift", "package", "--package-path", dir.path, "--scratch-path", try temporaryDirectory().path,
            "dump-package",
        ]
        process.currentDirectoryURL = cwd
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let json = out.fileHandleForReading.readDataToEndOfFile()
        let message = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "dump-package of \(dir.path): \(message)")
        return try JSONValue.decode(json)
    }
    #endif
}
