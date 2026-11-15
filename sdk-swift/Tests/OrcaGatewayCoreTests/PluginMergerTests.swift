import XCTest

@testable import OrcaGatewayCore

/// C16.3: two plugins claiming the same name fail the way Flutter's
/// `mergePlugins` (sdk/lib/src/plugins/plugin_merger.dart) does, with its four
/// messages verbatim, on the first conflict in merge order.
final class PluginMergerTests: XCTestCase {
    private let noop: OrcaActionHandler = { _, _ in }

    private func plugin(
        _ name: String, widgets: Set<String> = [], actions: [String] = [],
        triggers: [String: [TriggerDefinition]] = [:]
    ) -> PluginParts {
        PluginParts(
            name: name, widgetTypes: widgets,
            actions: Dictionary(uniqueKeysWithValues: actions.map { ($0, noop) }), triggers: triggers)
    }

    /// The message of the conflict `merge` throws, or a failure when it does not throw.
    private func conflict(
        builtIn: Set<String> = [], host: Set<String> = [], custom: [String] = [], _ plugins: [PluginParts],
        file: StaticString = #filePath, line: UInt = #line
    ) -> String? {
        do {
            _ = try PluginMerger.merge(
                builtInWidgets: builtIn, hostWidgets: host,
                customActions: Dictionary(uniqueKeysWithValues: custom.map { ($0, noop) }), plugins: plugins)
            XCTFail("expected a conflict", file: file, line: line)
            return nil
        } catch let error as OrcaPluginConflict {
            XCTAssertEqual(String(describing: error), error.message, file: file, line: line)
            return error.message
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
            return nil
        }
    }

    // MARK: the four messages

    func testC16_3_AWidgetClaimedByTwoPluginsNamesTheFirstOwner() {
        XCTAssertEqual(
            conflict([plugin("MapPlugin", widgets: ["MapView"]), plugin("OtherMap", widgets: ["MapView"])]),
            #"Widget type "MapView" from plugin "OtherMap" conflicts with plugin "MapPlugin"."#)
    }

    func testC16_3_APluginWidgetNamedLikeABuiltInConflictsWithARegisteredWidget() {
        XCTAssertEqual(
            conflict(builtIn: ["Text", "Column"], [plugin("Fancy", widgets: ["Text"])]),
            #"Widget type "Text" from plugin "Fancy" conflicts with an already registered widget."#)
    }

    func testC16_3_APluginWidgetNamedLikeAHostWidgetConflictsWithARegisteredWidget() {
        XCTAssertEqual(
            conflict(builtIn: ["Text"], host: ["Chart"], [plugin("Charts", widgets: ["Chart"])]),
            #"Widget type "Chart" from plugin "Charts" conflicts with an already registered widget."#)
    }

    func testC16_3_AnActionClaimedByTwoPluginsNamesTheFirstOwner() {
        XCTAssertEqual(
            conflict([plugin("MapPlugin", actions: ["centerMap"]), plugin("OtherMap", actions: ["centerMap"])]),
            #"Action type "centerMap" from plugin "OtherMap" conflicts with plugin "MapPlugin"."#)
    }

    func testC16_3_APluginActionNamedLikeAStandaloneActionConflictsWithARegisteredAction() {
        XCTAssertEqual(
            conflict(custom: ["track"], [plugin("Analytics", actions: ["track"])]),
            #"Action type "track" from plugin "Analytics" conflicts with an already registered action."#)
    }

    // MARK: the first conflict wins

    func testC16_3_WithinAPluginSortedWidgetKeysDecideTheFirstConflict() {
        // "Map" (owned by A) sorts before "Text" (a built-in).
        XCTAssertEqual(
            conflict(builtIn: ["Text"], [plugin("A", widgets: ["Map"]), plugin("B", widgets: ["Text", "Map"])]),
            #"Widget type "Map" from plugin "B" conflicts with plugin "A"."#)
    }

    func testC16_3_WithinAPluginSortedActionKeysDecideTheFirstConflict() {
        // "alpha" (standalone) sorts before "zoom" (owned by A).
        XCTAssertEqual(
            conflict(custom: ["alpha"], [plugin("A", actions: ["zoom"]), plugin("B", actions: ["zoom", "alpha"])]),
            #"Action type "alpha" from plugin "B" conflicts with an already registered action."#)
    }

    func testC16_3_APluginsWidgetsAreCheckedBeforeItsActions() {
        XCTAssertEqual(
            conflict([
                plugin("A", widgets: ["Map"], actions: ["a"]),
                plugin("B", widgets: ["Map"], actions: ["a"]),
            ]),
            #"Widget type "Map" from plugin "B" conflicts with plugin "A"."#)
    }

    func testC16_3_AnEarlierPluginsConflictIsReportedBeforeALaterOnes() {
        XCTAssertEqual(
            conflict(builtIn: ["Text"], [
                plugin("A", actions: ["go"]),
                plugin("B", actions: ["go"]),
                plugin("C", widgets: ["Text"]),
            ]),
            #"Action type "go" from plugin "B" conflicts with plugin "A"."#)
    }

    // MARK: what a merge keeps

    func testC16_3_APluginActionNamedLikeABuiltInActionMerges() throws {
        let result = try PluginMerger.merge(
            builtInWidgets: ["Text"], plugins: [plugin("Router", actions: ["navigate", "setState"])])
        XCTAssertEqual(Set(result.actions.keys), ["navigate", "setState"])
        XCTAssertEqual(result.pluginActionTypes, ["navigate", "setState"])
    }

    func testC16_3_TriggersConcatenatePerWidgetTypeInPluginOrder() throws {
        let pan = TriggerDefinition(name: "onPan", dataType: "Offset")
        let zoom = TriggerDefinition(name: "onZoom", dataType: "double", description: "pinch")
        let tap = TriggerDefinition(name: "onTap")
        let result = try PluginMerger.merge(builtInWidgets: [], plugins: [
            plugin("A", widgets: ["MapView"], triggers: ["MapView": [pan]]),
            plugin("B", triggers: ["MapView": [zoom, tap], "Chart": [tap]]),
        ])
        XCTAssertEqual(result.triggers["MapView"], [pan, zoom, tap])
        XCTAssertEqual(result.triggers["Chart"], [tap])
        XCTAssertNil(tap.dataType)
        XCTAssertNil(tap.description)
    }

    func testC16_3_StandaloneActionsAreMergedButOnlyPluginNamesAreRecordedAsPlugins() throws {
        let result = try PluginMerger.merge(
            builtInWidgets: ["Text"], hostWidgets: ["Chart"],
            customActions: ["track": noop],
            plugins: [
                plugin("Maps", widgets: ["MapView", "MapMarker"], actions: ["centerMap"]),
                plugin("Video", widgets: ["VideoPlayer"], actions: ["play", "pause"]),
            ])
        XCTAssertEqual(Set(result.actions.keys), ["track", "centerMap", "play", "pause"])
        XCTAssertEqual(result.pluginActionTypes, ["centerMap", "play", "pause"])
        XCTAssertEqual(result.pluginWidgetTypes, ["MapView", "MapMarker", "VideoPlayer"])
        XCTAssertEqual(result.widgetTypes, ["MapView", "MapMarker", "VideoPlayer"])
        XCTAssertEqual(
            result.widgetOwners, ["MapView": "Maps", "MapMarker": "Maps", "VideoPlayer": "Video"])
        XCTAssertTrue(result.triggers.isEmpty)
    }

    func testC16_3_NoPluginsKeepsTheStandaloneActions() throws {
        let result = try PluginMerger.merge(builtInWidgets: ["Text"], customActions: ["track": noop], plugins: [])
        XCTAssertEqual(Set(result.actions.keys), ["track"])
        XCTAssertTrue(result.pluginActionTypes.isEmpty)
        XCTAssertTrue(result.pluginWidgetTypes.isEmpty)
        XCTAssertTrue(result.widgetOwners.isEmpty)
    }
}
