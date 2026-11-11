import Foundation
import XCTest

@testable import OrcaGatewayCore

/// S13 (23b.35): `encoded()` writes JSON text as the Flutter SDK's
/// `jsonEncode` does, so a 4.0 goes out as `4.0` and Dart reads a double
/// back. Expected text is Dart 3.12.2's printed output. Numbers are checked
/// by kind, never by `==` alone, which equates 4 and 4.0.
final class JSONWriteTests: XCTestCase {
    func body(_ request: HTTPRequest?) -> String {
        String(decoding: request?.body ?? Data(), as: UTF8.self)
    }

    // MARK: W1 the writer

    func testW1_NumbersWriteDartsTextAndReadBackAsTheSameKind() throws {
        let table: [(JSONValue, String)] = [
            (.double(4.0), "4.0"), (.double(100.0), "100.0"), (.double(-0.0), "-0.0"), (.double(0.0), "0.0"),
            (.double(0.1 + 0.2), "0.30000000000000004"), (.double(1e21), "1e+21"), (.double(1e-7), "1e-7"),
            (.double(1.5e-7), "1.5e-7"), (.double(123456789012345680000.0), "123456789012345680000.0"),
            (.double(1e-6), "0.000001"), (.double(-2.5), "-2.5"), (.double(1e20), "100000000000000000000.0"),
            (.double(.greatestFiniteMagnitude), "1.7976931348623157e+308"),
            (.double(.leastNonzeroMagnitude), "5e-324"),
            (.int(4), "4"), (.int(-4), "-4"), (.int(0), "0"),
            (.int(.max), "9223372036854775807"), (.int(.min), "-9223372036854775808"),
            (.bool(true), "true"), (.bool(false), "false"), (.null, "null"),
            ([.double(4.0), .int(4), "x", .null, [.double(1.5e-7)]], #"[4.0,4,"x",null,[1.5e-7]]"#),
        ]
        for (value, dart) in table {
            XCTAssertEqual(try wireText(value), dart, "\(value)")
            let back = try JSONValue.decode(try value.encoded())
            XCTAssertTrue(sameKinds(back, value), "\(value) read back as \(back)")
        }
        // NaN and infinity still throw, as JSONEncoder did and Dart does.
        let invalid: [JSONValue] = [
            .double(.nan), .double(.infinity), .double(-.infinity), [.double(.nan)], ["k": .double(.infinity)],
        ]
        for value in invalid {
            XCTAssertThrowsError(try value.encoded(), "\(value)") { error in
                guard case EncodingError.invalidValue = error else { return XCTFail("\(error)") }
            }
        }
    }

    func testW1_StringsEscapeAsDartAndKeysStaySorted() throws {
        XCTAssertEqual(try wireText("a/b"), #""a/b""#)
        XCTAssertEqual(
            try wireText(.string("\"\\\n\t\r\u{08}\u{0C}\u{01}\u{1F}\u{7F}")),
            #""\"\\\n\t\r\b\f\u0001\u001f"# + "\u{7F}\"")
        XCTAssertEqual(try wireText("é漢🙂"), "\"é漢🙂\"")
        XCTAssertEqual(try wireText(""), #""""#)
        XCTAssertEqual(try wireText([]), "[]")
        XCTAssertEqual(try wireText([:]), "{}")
        XCTAssertEqual(try wireText(["b/c": 100.0, "a": ["b": 4.0]]), #"{"a":{"b":4.0},"b/c":100.0}"#)
        // The order `.sortedKeys` gave on Darwin, which is `keys.sorted()`.
        let keys: JSONValue = ["b": 1, "B": 2, "_x": 3, "a": 4, "aa": 5, "10": 6, "9": 7, "é": 8, "e": 9, "Z": 10]
        XCTAssertEqual(try wireText(keys), #"{"10":6,"9":7,"B":2,"Z":10,"_x":3,"a":4,"aa":5,"b":1,"e":9,"é":8}"#)
    }

    /// `Gen.double()` makes whole-number doubles, which JSONEncoder wrote as ints.
    func testW1_ARoundTripOverGeneratedJSONKeepsEveryNumbersKind() throws {
        for seed: UInt64 in [1, 23, 2026, 0xC0FFEE] {
            var gen = Gen(seed: seed)
            for i in 0..<150 {
                let json = gen.json(depth: 4)
                let written = try wireText(json)
                let back = try JSONValue.decode(Data(written.utf8))
                XCTAssertTrue(sameKinds(back, json), "seed \(seed) #\(i): \(written)")
            }
        }
    }

    // MARK: W3 the paths that send it

    func testW3_ThePagePostBodyKeeps4_0InBothAttempts() async throws {
        let stub = StubEngine(page: try Fixtures.data("sdk-swift/Tests/Pages/counter-home.json"))
        let client = OrcaClient(baseURL: URL(string: "http://localhost:8080")!, appId: "counter", transport: stub)
        _ = try await client.fetchPage("home", appState: ["d": 4.0, "i": 4, "z": -0.0])
        let requests = stub.requests
        XCTAssertEqual(requests.map(\.method), ["POST", "POST"])
        XCTAssertEqual(body(requests.first), #"{"appState":{"d":4.0,"i":4,"z":-0.0}}"#)
        let retry = body(requests.last)
        XCTAssertTrue(retry.hasPrefix(#"{"_orcaCapsVector":{"#), retry)
        XCTAssertTrue(retry.hasSuffix(#"},"appState":{"d":4.0,"i":4,"z":-0.0}}"#), retry)
    }

    func testW3_ExecuteActionsParamsPageStateAndAppStateKeep4_0() async throws {
        let stub = ActionStub(["save": ["actions": []]])
        _ = try await ActionStub.client(stub).executeAction(
            "save", params: ["p": 4.0], pageState: ["s": 100.0], appState: ["a": -0.0, "n": 4])
        XCTAssertEqual(
            body(stub.requests.first),
            #"{"action":"save","appState":{"a":-0.0,"n":4},"pageState":{"s":100.0},"params":{"p":4.0}}"#)
    }

    @MainActor func testW3_TheExecutorsServerActionSendsTheSameBody() async throws {
        let stub = ActionStub(["save": ["actions": []]])
        let store = ElmStore(StoreState(page: ["s": 100.0], app: ["a": 4.0]))
        let executor = ActionExecutor(store: store, client: ActionStub.client(stub))
        try await executor.execute(.serverAction(.init(
            id: "save", params: ["p": ["type": "static", "value": 4.0], "q": 1.5e-7])))
        XCTAssertEqual(
            body(stub.requests.first),
            #"{"action":"save","appState":{"a":4.0},"pageState":{"s":100.0},"params":{"p":4.0,"q":1.5e-7}}"#)
    }

    /// The text DevToolsClient sends: `envelope(...).encoded()`.
    func testW3_TheDevToolsEnvelopeKeeps4_0() throws {
        let change = DevToolsEvent.stateChange(scope: .page, pageId: "home", key: "d", oldValue: 4.0, newValue: 5)
        XCTAssertEqual(
            try wireText(change.envelope(deviceId: "dev", timestamp: 1_793_980_800_000)),
            #"{"deviceId":"dev","payload":{"key":"d","newValue":5,"oldValue":4.0,"pageId":"home","scope":"page"},"#
                + #""timestamp":1793980800000,"type":"state_change"}"#)
        let timing = DevToolsEvent.timing(pageId: "home", path: "/", server: nil, client: .init(
            responseReceivedMs: 12, parseCompleteMs: 12.5, renderStartMs: 13, renderCompleteMs: 14, firstFrameMs: 15))
        XCTAssertEqual(
            try wireText(timing.envelope(deviceId: "dev", timestamp: 1)),
            #"{"deviceId":"dev","payload":{"client":{"firstFrameMs":15.0,"parseCompleteMs":12.5,"#
                + #""renderCompleteMs":14.0,"renderStartMs":13.0,"requestStartMs":0.0,"responseReceivedMs":12.0},"#
                + #""pageId":"home","path":"/"},"timestamp":1,"type":"timing"}"#)
    }
}
