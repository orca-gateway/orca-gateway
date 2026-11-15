#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// C16.4 and the drawing half of C16.1: a plugin (Dart `OrcaPlugin`,
/// sdk/lib/src/plugins/orca_plugin.dart) hands its widget names, actions and
/// triggers to the merger through `parts`; its builder draws its widget type
/// through `WidgetView`; a trigger it declares fires the node's action with
/// event data through `model.fire`, as Flutter's `ctx.fireAction`.
@MainActor
final class PluginWidgetTests: XCTestCase {
    /// What builders were asked to draw: node id and the model it came with.
    final class Drawn {
        var calls: [(id: String, model: ObjectIdentifier)] = []
    }

    /// The Flutter example host's `_BadgePlugin` (examples/app/lib/main.dart),
    /// with one action so its parts carry one.
    struct BadgePlugin: OrcaPlugin {
        let drawn: Drawn
        let name = "badge"
        var widgets: [String: OrcaWidgetBuilder] {
            ["ColoredBadge": { [drawn] node, model in
                drawn.calls.append((node.id, ObjectIdentifier(model)))
                return AnyView(Color.orange.frame(width: 40, height: 20))
            }]
        }
        var actions: [String: OrcaActionHandler] { ["hapticFeedback": { _, _ in }] }
        var triggers: [String: [TriggerDefinition]] {
            ["ColoredBadge": [TriggerDefinition(name: "onTap", dataType: "Map<String, dynamic>")]]
        }
    }

    /// Declares a second trigger on the badge and nothing else.
    struct BadgeLongPressPlugin: OrcaPlugin {
        let name = "badge-long-press"
        var triggers: [String: [TriggerDefinition]] {
            ["ColoredBadge": [TriggerDefinition(name: "onLongPress")]]
        }
    }

    /// Only a name: every other member keeps its empty default.
    struct NamedOnlyPlugin: OrcaPlugin {
        let name = "named-only"
    }

    /// A page with a ColoredBadge whose `onTap` stores the event's `label`,
    /// and a node of a type the registry keeps but no builder draws. The
    /// registry knows both types, as OrcaApp's per-app registry will (T8), so
    /// neither is degraded to a FallbackPrompt.
    func model(widgets: WidgetBuilders) throws -> OrcaPageModel {
        let page = try JSONValue.object([
            "pageId": "p", "title": "T",
            "state": [["key": "picked", "scope": "page", "initial": ""]],
            "components": [
                ["id": "badge", "type": "ColoredBadge", "kind": "primitive", "childMode": "none",
                 "props": ["label": "hi", "color": "#FF9800"], "children": [], "watches": [],
                 "actions": ["onTap": ["type": "setState", "scope": "page", "key": "picked",
                                       "value": ["type": "event", "key": "label"]]]],
                ["id": "mystery", "type": "Mystery", "kind": "primitive", "childMode": "none",
                 "props": [:], "children": [], "watches": []],
            ],
        ]).decode(PageResponse.self)
        let registry = WidgetRegistry(types: Set(GeneratedCapabilities.widgets).union(["ColoredBadge", "Mystery"]))
        return OrcaPageModel(page: page, registry: registry, widgets: widgets)
    }

    func builders(_ plugins: [OrcaPlugin]) -> WidgetBuilders {
        let builders = WidgetBuilders()
        for plugin in plugins {
            for (type, builder) in plugin.widgets { builders.register(type, builder) }
        }
        return builders
    }

    /// The image `view` draws at its ideal size, or nil when it draws nothing.
    func image<V: View>(_ view: V) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.cgImage
    }

    // MARK: C16.4

    func testC16_4_APluginsPartsCarryItsWidgetNamesActionsAndTriggers() {
        let parts = BadgePlugin(drawn: Drawn()).parts
        XCTAssertEqual(parts.name, "badge")
        XCTAssertEqual(parts.widgetTypes, ["ColoredBadge"])
        XCTAssertEqual(Set(parts.actions.keys), ["hapticFeedback"])
        XCTAssertEqual(parts.triggers, ["ColoredBadge": [TriggerDefinition(name: "onTap", dataType: "Map<String, dynamic>")]])

        let bare = NamedOnlyPlugin()
        XCTAssertTrue(bare.widgets.isEmpty)
        XCTAssertTrue(bare.actions.isEmpty)
        XCTAssertTrue(bare.triggers.isEmpty)
        let empty = bare.parts
        XCTAssertEqual(empty.name, "named-only")
        XCTAssertEqual(empty.widgetTypes, [])
        XCTAssertTrue(empty.actions.isEmpty)
        XCTAssertEqual(empty.triggers, [:])
    }

    func testC16_4_DeclaredTriggersReachTheMergeAndConcatenatePerWidgetType() throws {
        let plugins: [OrcaPlugin] = [BadgePlugin(drawn: Drawn()), BadgeLongPressPlugin(), NamedOnlyPlugin()]
        let merged = try PluginMerger.merge(
            builtInWidgets: Set(GeneratedCapabilities.widgets), plugins: plugins.map(\.parts))
        XCTAssertEqual(merged.triggers["ColoredBadge"]?.map(\.name), ["onTap", "onLongPress"])
        XCTAssertEqual(merged.widgetOwners, ["ColoredBadge": "badge"])
        XCTAssertEqual(merged.pluginActionTypes, ["hapticFeedback"])
    }

    func testC16_4_APluginTriggerFiredThroughTheModelRunsTheNodesActionWithEventData() async throws {
        let model = try model(widgets: builders([BadgePlugin(drawn: Drawn())]))
        let node = try XCTUnwrap(model.resolve("badge"))
        XCTAssertEqual(node.type, "ColoredBadge")
        let trigger = try XCTUnwrap(BadgePlugin(drawn: Drawn()).triggers["ColoredBadge"]?.first?.name)

        await model.fire(trigger, on: node, eventData: ["label": "x"])?.value

        XCTAssertEqual(model.store.value("picked"), "x")
    }

    // MARK: C16.1 (drawing)

    func testC16_1_WidgetViewDrawsThePluginBuilderForItsType() throws {
        let drawn = Drawn()
        let model = try model(widgets: builders([BadgePlugin(drawn: drawn)]))

        let image = try XCTUnwrap(image(NodeView(id: "badge", model: model)), "the badge drew nothing")

        XCTAssertEqual(image.width, 40)
        XCTAssertEqual(image.height, 20)
        XCTAssertEqual(drawn.calls.map(\.id), ["badge"])
        XCTAssertEqual(drawn.calls.first?.model, ObjectIdentifier(model))
    }

    func testC16_1_ATypeWithNoBuilderDrawsNothing() throws {
        let drawn = Drawn()
        let model = try model(widgets: builders([BadgePlugin(drawn: drawn)]))
        XCTAssertEqual(model.resolve("mystery")?.type, "Mystery")

        let image = image(NodeView(id: "mystery", model: model))

        XCTAssertTrue(image == nil || image!.width == 0 || image!.height == 0, "the unknown type drew something")
        XCTAssertTrue(drawn.calls.isEmpty)
    }

    func testC16_1_WidgetBuildersRegisterReplaceAndListTypes() throws {
        let builders = WidgetBuilders()
        XCTAssertEqual(builders.types, [])
        XCTAssertNil(builders.builder(for: "ColoredBadge"))

        var log: [String] = []
        builders.register("ColoredBadge") { _, _ in log.append("first"); return AnyView(EmptyView()) }
        builders.register("Rating") { _, _ in log.append("rating"); return AnyView(EmptyView()) }
        builders.register("ColoredBadge") { _, _ in log.append("second"); return AnyView(EmptyView()) }
        XCTAssertEqual(builders.types, ["ColoredBadge", "Rating"])

        let model = try model(widgets: builders)
        XCTAssertTrue(model.widgets === builders)
        let node = try XCTUnwrap(model.resolve("badge"))
        _ = try XCTUnwrap(builders.builder(for: "ColoredBadge"))(node, model)
        XCTAssertEqual(log, ["second"])
        XCTAssertNil(builders.builder(for: "Mystery"))
    }

    func testC16_1_APageModelDrawsNoExtraTypesByDefault() {
        let model = OrcaPageModel(page: PageResponse(pageId: "p", title: "P"))
        XCTAssertEqual(model.widgets.types, [])
    }
}
#endif
