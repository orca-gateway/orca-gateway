#if canImport(SwiftUI)
import Foundation
import SwiftUI
import XCTest

@testable import OrcaGateway

/// T4.6: a host button style applies to buttons the server did not style,
/// and a server style prop wins over it.
@MainActor
final class OrcaThemeTests: XCTestCase {
    let theme = OrcaTheme(
        elevatedButton: OrcaButtonStyle { $0.label },
        outlinedButton: OrcaButtonStyle { $0.label },
        textButton: OrcaButtonStyle { $0.label })

    /// A node of one type with these props, resolved by a page model.
    func button(_ type: String, _ props: [String: JSONValue] = [:]) -> ResolvedNode {
        let page = try? NativeWidgetTests().page(field: [
            "id": "b", "type": .string(type), "kind": "button", "childMode": "single",
            "props": .object(props), "children": [], "watches": [],
        ])
        return OrcaPageModel(page: page!, registry: WidgetRegistry(types: [type])).resolve("b")!
    }

    func testTheHostStylesButtonsTheServerLeftPlain() {
        XCTAssertNotNil(theme.buttonStyle(for: button("ElevatedButton")))
        XCTAssertNotNil(theme.buttonStyle(for: button("OutlinedButton")))
        XCTAssertNotNil(theme.buttonStyle(for: button("TextButton")))
        XCTAssertNil(OrcaTheme().buttonStyle(for: button("ElevatedButton")))
        XCTAssertNil(theme.buttonStyle(for: button("Text")))
    }

    func testAServerStylePropWins() {
        XCTAssertNil(theme.buttonStyle(for: button("ElevatedButton", ["backgroundColor": "#FF5722"])))
        XCTAssertNil(theme.buttonStyle(for: button("ElevatedButton", ["borderRadius": 24])))
        XCTAssertNil(theme.buttonStyle(for: button("OutlinedButton", ["borderColor": "#000000"])))
        XCTAssertNil(theme.buttonStyle(for: button("TextButton", ["color": "#1976D2"])))
        // Props that do not style the button leave the host style on.
        XCTAssertNotNil(theme.buttonStyle(for: button("ElevatedButton", ["enabled": true])))
        // A null prop is no style.
        XCTAssertNotNil(theme.buttonStyle(for: button("TextButton", ["color": .null])))
    }

    func testTheThemeTravelsInTheEnvironment() {
        var values = EnvironmentValues()
        XCTAssertNil(values.orcaTheme.elevatedButton)
        values.orcaTheme = theme
        XCTAssertNotNil(values.orcaTheme.elevatedButton)
    }
}
#endif
