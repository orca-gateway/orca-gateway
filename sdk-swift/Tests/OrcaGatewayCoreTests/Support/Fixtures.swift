import Foundation
import XCTest

@testable import OrcaGatewayCore

/// The monorepo's conformance fixtures, read at run time from ../schema so
/// the Swift SDK runs exactly the files the engine and the Flutter SDK run.
enum Fixtures {
    /// open-source/ (this file is sdk-swift/Tests/OrcaGatewayCoreTests/Support/).
    static let ossRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Support
        .deletingLastPathComponent()  // OrcaGatewayCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // sdk-swift
        .deletingLastPathComponent()  // open-source

    static func url(_ relative: String) -> URL {
        ossRoot.appendingPathComponent(relative)
    }

    static func data(_ relative: String) throws -> Data {
        try Data(contentsOf: url(relative))
    }

    static func json(_ relative: String) throws -> JSONValue {
        try JSONValue.decode(data(relative))
    }

    /// Fixture files of one set (`render` or `actions`), sorted by name.
    static func files(_ set: String) throws -> [(name: String, json: JSONValue)] {
        let dir = url("schema/fixtures/\(set)")
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".json") }
            .sorted()
        return try names.map { ($0, try json("schema/fixtures/\(set)/\($0)")) }
    }
}

/// Encode a Codable value and read it back as JSON, for JSON-equal checks.
func jsonOf<T: Encodable>(_ value: T) throws -> JSONValue {
    try JSONValue(encoding: value)
}

func decodeModel<T: Decodable>(_ type: T.Type, from json: JSONValue) throws -> T {
    try json.decode(type)
}

/// JSON-equal with a readable failure: both sides printed with sorted keys.
func assertJSONEqual(
    _ actual: JSONValue, _ expected: JSONValue, _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath, line: UInt = #line
) {
    if actual == expected { return }
    let a = (try? actual.encoded()).flatMap { String(data: $0, encoding: .utf8) } ?? "?"
    let e = (try? expected.encoded()).flatMap { String(data: $0, encoding: .utf8) } ?? "?"
    XCTFail("\(message())\n  actual:   \(a)\n  expected: \(e)", file: file, line: line)
}
