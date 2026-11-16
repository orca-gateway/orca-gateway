import Foundation
import XCTest

@testable import OrcaGatewayCore

/// Native parity step 13, cases B13.4-S and B13.5-S: schema/fixtures/subpage
/// through the pure SubPage core (`Sources/OrcaGatewayCore/State/SubPage.swift`),
/// as the Flutter runner (sdk/test/conformance/subpage_fixtures_test.dart)
/// runs them through `sub_page_core.dart`. The contract is the oracle of this
/// family: no widget, no client, JSON in and JSON out.
final class SubPageFixtureTests: XCTestCase {
    private typealias Count = (files: Int, cases: Int)

    func test_B13_4_prefixOfPageZeroAndOfAJoinedPage() {
        XCTAssertEqual(SubPage.prefix(key: "detail"), "detail:")
        XCTAssertEqual(SubPage.prefix(key: "detail", join: 0), "detail:")
        XCTAssertEqual(SubPage.prefix(key: "detail", join: 1), "detail#1:")
        XCTAssertEqual(SubPage.prefix(key: "outer:inner", join: 12), "outer:inner#12:")
    }

    func test_B13_4_merge() throws {
        let ran = try run(kind: "merge")
        XCTAssertEqual(ran.files, 6)
        XCTAssertEqual(ran.cases, 17)
    }

    func test_B13_4_actionsRewrite() throws {
        let ran = try run(kind: "actions")
        XCTAssertEqual(ran.files, 1)
        XCTAssertEqual(ran.cases, 9)
    }

    func test_B13_4_requestAndPostedState() throws {
        let ran = try run(kind: "request")
        XCTAssertEqual(ran.files, 2)
        XCTAssertEqual(ran.cases, 35)
    }

    func test_B13_5_sequence() throws {
        let ran = try run(kind: "sequence")
        XCTAssertEqual(ran.files, 3)
        XCTAssertEqual(ran.cases, 11)
    }

    /// Every file and every case, with the counts pinned: a file or a case
    /// that is skipped fails here.
    func test_B13_4_B13_5_everySubPageFixturePasses() throws {
        let files = try Fixtures.files("subpage")
        XCTAssertEqual(files.count, 12)
        var cases = 0
        var kinds = Set<String>()
        for (name, fx) in files {
            kinds.insert(fx["kind"].stringValue ?? "?")
            let ran = try run(name, fx)
            XCTAssertGreaterThan(ran, 0, "\(name): no cases")
            cases += ran
        }
        XCTAssertEqual(cases, 72)
        XCTAssertEqual(kinds, ["merge", "actions", "request", "sequence"])
    }

    func test_B13_4_anUnknownKindIsRefused() {
        let fx: JSONValue = ["kind": "mystery", "cases": [["name": "x"]]]
        XCTAssertThrowsError(try run("unknown.json", fx)) { error in
            XCTAssertEqual(error as? UnknownKind, UnknownKind(file: "unknown.json", kind: "mystery"))
        }
        XCTAssertThrowsError(try run("none.json", ["cases": []]))
    }

    /// Text that is canonically equivalent is not the same text: an id that
    /// starts with `e` + U+0301 is not under the prefix `\u{e9}:`.
    func test_B13_4_textIsComparedByCodePoint() {
        XCTAssertNil(SubPage.prefixOf(prefixes: ["\u{e9}:"], sourceId: "e\u{301}:0"))
        XCTAssertEqual(SubPage.prefixOf(prefixes: ["\u{e9}:"], sourceId: "\u{e9}:0"), "\u{e9}:")
        XCTAssertEqual(
            SubPage.postedState(prefix: "\u{e9}:", pageState: ["e\u{301}:a": 1, "\u{e9}:b": 2]), ["b": 2])
        // A slash followed by a combining mark is still a slash.
        XCTAssertEqual(SubPage.request(pageId: "/a/\u{301}b").path, "a/%CC%81b")
    }

    // MARK: - Runner

    private struct UnknownKind: Error, Equatable {
        let file: String
        let kind: String
    }

    /// The files of one kind; returns how many files and cases ran.
    private func run(kind: String, file: StaticString = #filePath, line: UInt = #line) throws -> Count {
        var total: Count = (0, 0)
        for (name, fx) in try Fixtures.files("subpage") where fx["kind"].stringValue == kind {
            let ran = try run(name, fx, file: file, line: line)
            XCTAssertGreaterThan(ran, 0, "\(name): no cases", file: file, line: line)
            total.files += 1
            total.cases += ran
        }
        return total
    }

    /// One file: every case. Throws on a kind this runner does not know.
    @discardableResult
    private func run(_ name: String, _ fx: JSONValue, file: StaticString = #filePath, line: UInt = #line) throws
        -> Int {
        let kind = fx["kind"].stringValue ?? ""
        let cases = fx["cases"].arrayValue ?? []
        for c in cases {
            let label = "\(name) · \(c["name"].stringValue ?? "?")"
            switch kind {
            case "merge": merge(c, label, file: file, line: line)
            case "actions": actions(c, label, file: file, line: line)
            case "request": request(c, label, file: file, line: line)
            case "sequence": sequence(c, label, file: file, line: line)
            default: throw UnknownKind(file: name, kind: kind)
            }
        }
        guard ["merge", "actions", "request", "sequence"].contains(kind) else {
            throw UnknownKind(file: name, kind: kind)
        }
        return cases.count
    }

    private func merge(_ c: JSONValue, _ label: String, file: StaticString, line: UInt) {
        guard let prefix = c["prefix"].stringValue, let expected = c["expected"].objectValue,
            let nodes = expected["nodes"], let state = expected["state"]
        else { return XCTFail("\(label): malformed case", file: file, line: line) }
        let merged = SubPage.merge(prefix: prefix, response: c["response"])
        assertJSONEqual(.array(merged.nodes), nodes, "\(label): nodes", file: file, line: line)
        assertJSONEqual(.object(merged.state), state, "\(label): state", file: file, line: line)
    }

    private func actions(_ c: JSONValue, _ label: String, file: StaticString, line: UInt) {
        guard let prefix = c["prefix"].stringValue, let input = c["actions"].arrayValue,
            let expected = c["expected"].arrayValue
        else { return XCTFail("\(label): malformed case", file: file, line: line) }
        let rewritten = SubPage.rewriteActions(prefix: prefix, actions: input)
        assertJSONEqual(.array(rewritten), .array(expected), label, file: file, line: line)
    }

    private func request(_ c: JSONValue, _ label: String, file: StaticString, line: UInt) {
        guard let expected = c["expected"].objectValue else {
            return XCTFail("\(label): no expected", file: file, line: line)
        }
        if let fetch = c["fetch"].objectValue {
            guard let pageId = fetch["pageId"]?.stringValue, let path = expected["path"]?.stringValue,
                let query = expected["query"]?.stringValue
            else { return XCTFail("\(label): malformed fetch", file: file, line: line) }
            let request = SubPage.request(pageId: pageId, params: fetch["params"]?.objectValue)
            XCTAssertEqual(request.path, path, "\(label): path", file: file, line: line)
            XCTAssertEqual(request.query, query, "\(label): query", file: file, line: line)
            XCTAssertEqual(
                request.location, query.isEmpty ? path : "\(path)?\(query)", "\(label): location",
                file: file, line: line)
        } else if let action = c["action"].objectValue {
            guard let prefixes = action["prefixes"]?.arrayValue, let pageState = action["pageState"]?.objectValue,
                let posted = expected["pageState"], let wanted = expected["prefix"]
            else { return XCTFail("\(label): malformed action", file: file, line: line) }
            let prefix = SubPage.prefixOf(
                prefixes: prefixes.compactMap(\.stringValue), sourceId: action["sourceId"]?.stringValue)
            XCTAssertEqual(prefixes.compactMap(\.stringValue).count, prefixes.count, label, file: file, line: line)
            XCTAssertEqual(prefix, wanted.stringValue, "\(label): prefix", file: file, line: line)
            assertJSONEqual(
                .object(SubPage.postedState(prefix: prefix, pageState: pageState)), posted,
                "\(label): pageState", file: file, line: line)
        } else {
            XCTFail("\(label): neither fetch nor action", file: file, line: line)
        }
    }

    private func sequence(_ c: JSONValue, _ label: String, file: StaticString, line: UInt) {
        guard let key = c["subPageKey"].stringValue, var state = c["pageState"].objectValue,
            let steps = c["steps"].arrayValue, !steps.isEmpty
        else { return XCTFail("\(label): malformed case", file: file, line: line) }
        var mounts = SubPageMounts(subPageKey: key)
        for (i, step) in steps.enumerated() {
            let op = step["op"].stringValue ?? "?"
            let at = "\(label) · step \(i) (\(op))"
            var removed: [String] = []
            switch op {
            case "set":
                guard let stateKey = step["key"].stringValue, let value = step.objectValue?["value"] else {
                    return XCTFail("\(at): malformed set", file: file, line: line)
                }
                state[stateKey] = value
            case "mount", "update":
                let mode = op == "mount" ? "replace" : step["mode"].stringValue
                guard let mode else { return XCTFail("\(at): no mode", file: file, line: line) }
                let change = mounts.apply(mode: mode, response: step["response"], pageStateKeys: Array(state.keys))
                for gone in change.removedStateKeys { state[gone] = nil }
                state.merge(change.seeds) { _, seed in seed }
                removed = change.removedNodeIds
                // What the step adds is the merge of its response.
                let merged = SubPage.merge(prefix: change.prefix, response: step["response"])
                assertJSONEqual(.array(change.nodes), .array(merged.nodes), "\(at): nodes", file: file, line: line)
                assertJSONEqual(.object(change.seeds), .object(merged.state), "\(at): seeds", file: file, line: line)
            default:
                return XCTFail("\(at): unknown op", file: file, line: line)
            }
            guard let expected = step["expected"].objectValue else {
                return XCTFail("\(at): no expected", file: file, line: line)
            }
            XCTAssertEqual(mounts.prefixes, strings(expected["prefixes"]), "\(at): prefixes", file: file, line: line)
            XCTAssertEqual(mounts.roots, strings(expected["roots"]), "\(at): roots", file: file, line: line)
            XCTAssertEqual(sorted(mounts.nodeIds), strings(expected["nodeIds"]), "\(at): nodeIds", file: file, line: line)
            XCTAssertEqual(
                sorted(removed), strings(expected["removedNodeIds"]), "\(at): removedNodeIds", file: file, line: line)
            assertJSONEqual(.object(state), expected["state"] ?? .null, "\(at): state", file: file, line: line)
            XCTAssertEqual(mounts.pages.map(\.prefix), mounts.prefixes, at, file: file, line: line)
        }
    }

    /// A list of strings, nil when the value is missing or holds anything else.
    private func strings(_ value: JSONValue?) -> [String]? {
        guard let items = value?.arrayValue else { return nil }
        let texts = items.compactMap(\.stringValue)
        return texts.count == items.count ? texts : nil
    }

    /// Sorted by code point, which is the order of the UTF-8 bytes.
    private func sorted(_ ids: [String]) -> [String] {
        ids.sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
    }
}
