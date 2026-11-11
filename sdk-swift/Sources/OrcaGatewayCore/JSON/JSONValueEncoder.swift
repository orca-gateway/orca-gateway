import Foundation

/// An `Encoder` that builds a `JSONValue` tree straight from a Codable model,
/// so a `Double` stays a `.double` (`4.0` too) where JSONEncoder's text, read
/// back with `JSONValue.decode(_:)`, made it `.int(4)`. The write-side twin
/// of `JSONValueDecoder`.
///
/// Everything else writes as JSONEncoder writes it: a second
/// `container(keyedBy:)` on one encoder adds to the same object, an
/// `encodeIfPresent` of nil leaves the key out, `encodeNil` writes null, an
/// integer past `Int` is a `.double`, NaN and infinity throw
/// `EncodingError.invalidValue`, and coding paths name their steps the same
/// way. Pure Swift, so it behaves the same on Linux.
struct JSONValueEncoder: Encoder, SingleValueEncodingContainer {
    let node: Node
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    init(_ node: Node = Node(), codingPath: [CodingKey] = []) {
        self.node = node
        self.codingPath = codingPath
    }

    /// The tree `value` writes; throws as JSONEncoder does when it writes nothing.
    static func tree<T: Encodable>(of value: T) throws -> JSONValue {
        let encoder = JSONValueEncoder()
        try value.encode(to: encoder)
        guard let tree = encoder.node.value else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: [], debugDescription: "Top-level \(T.self) did not encode any values."))
        }
        return tree
    }

    // MARK: Encoder

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        KeyedEncodingContainer(KeyedContainer<Key>(object: node.object(), codingPath: codingPath))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        UnkeyedContainer(array: node.array(), codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer { self }

    // MARK: SingleValueEncodingContainer

    func encodeNil() throws { node.set(.null) }
    func encode(_ value: Bool) throws { node.set(.bool(value)) }
    func encode(_ value: String) throws { node.set(.string(value)) }

    func encode(_ value: Double) throws {
        guard value.isFinite else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: codingPath, debugDescription: "Unable to encode Double.\(value) directly in JSON."))
        }
        node.set(.double(value))
    }

    /// As JSONEncoder's text of the Float reads back: `Float(0.1)` is 0.1.
    func encode(_ value: Float) throws {
        guard value.isFinite else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: codingPath, debugDescription: "Unable to encode Float.\(value) directly in JSON."))
        }
        node.set(.double(Double(value.description) ?? Double(value)))
    }

    func encode(_ value: Int) throws { integer(value) }
    func encode(_ value: Int8) throws { integer(value) }
    func encode(_ value: Int16) throws { integer(value) }
    func encode(_ value: Int32) throws { integer(value) }
    func encode(_ value: Int64) throws { integer(value) }
    func encode(_ value: UInt) throws { integer(value) }
    func encode(_ value: UInt8) throws { integer(value) }
    func encode(_ value: UInt16) throws { integer(value) }
    func encode(_ value: UInt32) throws { integer(value) }
    func encode(_ value: UInt64) throws { integer(value) }

    /// Any other model writes itself into this node; `JSONValue` writes its
    /// own kinds through the containers above.
    func encode<T: Encodable>(_ value: T) throws { try value.encode(to: self) }

    /// `.int` when it fits, else the `.double` `JSONValue.decode(_:)` reads
    /// from JSONEncoder's digits.
    private func integer<T: BinaryInteger>(_ value: T) {
        node.set(Int(exactly: value).map(JSONValue.int) ?? .double(Double(value)))
    }
}

extension JSONValueEncoder {
    /// One value being built, by reference, so a container handed out keeps
    /// writing into the tree after it is returned.
    final class Node {
        private var leaf: JSONValue?
        private var members: [String: Node]?
        private var items: [Node]?

        /// What was written here; nil when nothing was (an empty object
        /// inside a tree, as JSONEncoder writes it).
        var value: JSONValue? {
            if let members { return .object(members.mapValues { $0.value ?? .object([:]) }) }
            if let items { return .array(items.map { $0.value ?? .object([:]) }) }
            return leaf
        }

        func set(_ value: JSONValue) {
            leaf = value
            members = nil
            items = nil
        }

        /// This node as an object, kept when it already is one: a second
        /// `container(keyedBy:)` adds to the first.
        func object() -> Node {
            if members == nil {
                leaf = nil
                items = nil
                members = [:]
            }
            return self
        }

        /// This node as an array, kept when it already is one.
        func array() -> Node {
            if items == nil {
                leaf = nil
                members = nil
                items = []
            }
            return self
        }

        /// A new member at `key`, replacing any, as JSONEncoder's does.
        func member(_ key: String) -> Node {
            let child = Node()
            members?[key] = child
            return child
        }

        /// A new last item.
        func item() -> Node {
            let child = Node()
            items?.append(child)
            return child
        }

        var count: Int { items?.count ?? 0 }
    }
}

/// A coding path step JSONEncoder names the same way: `Index 2` for an
/// element of an unkeyed container, `super` for `superEncoder()`.
private struct PathKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init(index: Int) { stringValue = "Index \(index)"; intValue = index }
    init(stringValue: String) { self.stringValue = stringValue; intValue = nil }
    init(intValue: Int) { self.init(index: intValue) }
}

private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let object: JSONValueEncoder.Node
    let codingPath: [CodingKey]

    private func node(_ key: CodingKey) -> JSONValueEncoder {
        JSONValueEncoder(object.member(key.stringValue), codingPath: codingPath + [key])
    }

    func encodeNil(forKey key: Key) throws { try node(key).encodeNil() }
    func encode(_ value: Bool, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: String, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: Double, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: Float, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: Int, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: Int8, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: Int16, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: Int32, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: Int64, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: UInt, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: UInt8, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: UInt16, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: UInt32, forKey key: Key) throws { try node(key).encode(value) }
    func encode(_ value: UInt64, forKey key: Key) throws { try node(key).encode(value) }
    func encode<T: Encodable>(_ value: T, forKey key: Key) throws { try node(key).encode(value) }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type, forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        node(key).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        node(key).unkeyedContainer()
    }

    func superEncoder() -> Encoder { node(PathKey(stringValue: "super")) }
    func superEncoder(forKey key: Key) -> Encoder { node(key) }
}

private struct UnkeyedContainer: UnkeyedEncodingContainer {
    let array: JSONValueEncoder.Node
    let codingPath: [CodingKey]

    var count: Int { array.count }

    /// A new last element.
    private func next() -> JSONValueEncoder {
        let index = PathKey(index: array.count)
        return JSONValueEncoder(array.item(), codingPath: codingPath + [index])
    }

    func encodeNil() throws { try next().encodeNil() }
    func encode(_ value: Bool) throws { try next().encode(value) }
    func encode(_ value: String) throws { try next().encode(value) }
    func encode(_ value: Double) throws { try next().encode(value) }
    func encode(_ value: Float) throws { try next().encode(value) }
    func encode(_ value: Int) throws { try next().encode(value) }
    func encode(_ value: Int8) throws { try next().encode(value) }
    func encode(_ value: Int16) throws { try next().encode(value) }
    func encode(_ value: Int32) throws { try next().encode(value) }
    func encode(_ value: Int64) throws { try next().encode(value) }
    func encode(_ value: UInt) throws { try next().encode(value) }
    func encode(_ value: UInt8) throws { try next().encode(value) }
    func encode(_ value: UInt16) throws { try next().encode(value) }
    func encode(_ value: UInt32) throws { try next().encode(value) }
    func encode(_ value: UInt64) throws { try next().encode(value) }
    func encode<T: Encodable>(_ value: T) throws { try next().encode(value) }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        next().container(keyedBy: type)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer { next().unkeyedContainer() }

    func superEncoder() -> Encoder { next() }
}
