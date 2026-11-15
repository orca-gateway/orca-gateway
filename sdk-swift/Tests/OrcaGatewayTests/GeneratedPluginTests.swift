#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// C16.6 (Swift cell): the stub `orca plugin generate --lang swift` writes for
/// plugins/orca_google_map/orca_plugin.yaml, committed unchanged in
/// Generated/OrcaGoogleMapPlugin.swift (cli/test/swift_generator_test.dart
/// keeps it equal to the generator's output), compiles against the SDK and
/// works as a plugin: it merges, its placeholder draws, its handler runs.
@MainActor
final class GeneratedPluginTests: XCTestCase {
    /// The raw actions the wrapped moveCamera handler saw.
    @MainActor final class Ran {
        var actions: [JSONValue] = []
        func record(_ action: JSONValue) { actions.append(action) }
    }

    let triggerNames = ["onTap", "onLongPress", "onCameraMove", "onMarkerTap"]

    /// A page with one GoogleMap node; the registry knows the type, as
    /// OrcaApp's per-app registry does for a plugin widget.
    func model(widgets: WidgetBuilders) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T", "state": [],
            "components": [
                ["id": "map", "type": "GoogleMap", "kind": "primitive", "childMode": "none",
                 "props": ["latitude": 30.05, "longitude": 31.24, "mapType": "satellite",
                           "myLocationEnabled": true,
                           "markers": [["id": "m1", "latitude": 30.05, "longitude": 31.24]]],
                 "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self)
        let registry = WidgetRegistry(types: Set(GeneratedCapabilities.widgets).union(["GoogleMap"]))
        return OrcaPageModel(page: page, registry: registry, widgets: widgets)
    }

    func testC16_6_TheGeneratedGoogleMapPluginMergesWithItsNameWidgetActionAndTriggers() throws {
        let plugin = OrcaGoogleMapPlugin()
        XCTAssertEqual(plugin.name, "orca_google_map")
        XCTAssertEqual(
            [GoogleMapProps.Triggers.onTap, GoogleMapProps.Triggers.onLongPress,
             GoogleMapProps.Triggers.onCameraMove, GoogleMapProps.Triggers.onMarkerTap],
            triggerNames)

        let parts = plugin.parts
        XCTAssertEqual(parts.name, "orca_google_map")
        XCTAssertEqual(parts.widgetTypes, ["GoogleMap"])
        XCTAssertEqual(Set(parts.actions.keys), ["moveCamera"])
        XCTAssertEqual(parts.triggers, ["GoogleMap": triggerNames.map { TriggerDefinition(name: $0) }])

        let merged = try PluginMerger.merge(
            builtInWidgets: Set(GeneratedCapabilities.widgets), plugins: [parts])
        XCTAssertEqual(merged.widgetOwners, ["GoogleMap": "orca_google_map"])
        XCTAssertEqual(merged.pluginActionTypes, ["moveCamera"])
        XCTAssertEqual(Set(merged.actions.keys), ["moveCamera"])
        XCTAssertEqual(merged.triggers["GoogleMap"]?.map(\.name), triggerNames)
    }

    func testC16_6_ThePlaceholderBuilderDrawsTheGoogleMapNodeAndItsPropsReadIt() throws {
        let builders = WidgetBuilders()
        for (type, builder) in OrcaGoogleMapPlugin().widgets { builders.register(type, builder) }
        let model = try model(widgets: builders)
        let node = try XCTUnwrap(model.resolve("map"))
        XCTAssertEqual(node.type, "GoogleMap", "not degraded to a FallbackPrompt")

        let renderer = ImageRenderer(content: NodeView(id: "map", model: model))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage, "the placeholder drew nothing")
        XCTAssertGreaterThan(image.width, 0)
        XCTAssertGreaterThan(image.height, 0)

        let props = GoogleMapProps(node)
        XCTAssertEqual(props.latitude, 30.05)
        XCTAssertEqual(props.longitude, 31.24)
        XCTAssertNil(props.zoom)
        XCTAssertEqual(props.mapType, "satellite")
        XCTAssertEqual(props.myLocationEnabled, true)
        XCTAssertNil(props.zoomControlsEnabled)
        XCTAssertEqual(props.markers, [["id": "m1", "latitude": 30.05, "longitude": 31.24]])
    }

    func testC16_6_TheMoveCameraHandlerRunsOnAnExecutorWithNoEffect() async throws {
        let generated = try XCTUnwrap(OrcaGoogleMapPlugin().actions["moveCamera"])
        let ran = Ran()
        let store = ElmStore(StoreState(page: ["count": 1]))
        let executor = ActionExecutor(store: store)
        var effects: [ActionEffect] = []
        var mutations = 0
        executor.onEffect = { effects.append($0) }
        executor.onMutation = { _ in mutations += 1 }
        executor.registerHandler("moveCamera") { [ran] action, executor in
            try await generated(action, executor)
            await ran.record(action)
        }
        let raw: JSONValue = ["type": "custom:moveCamera", "targetId": "map", "latitude": 30.05, "longitude": 31.24]

        try await executor.execute(try raw.decode(Action.self))

        XCTAssertEqual(ran.actions, [raw], "the generated handler ran and returned")
        XCTAssertEqual(effects, [])
        XCTAssertEqual(mutations, 0)
        XCTAssertEqual(store.state, StoreState(page: ["count": 1]))

        let params = MoveCameraParams(raw)
        XCTAssertEqual(params.targetId, "map")
        XCTAssertEqual(params.latitude, 30.05)
        XCTAssertEqual(params.longitude, 31.24)
        XCTAssertNil(params.zoom)
    }
}
#endif
