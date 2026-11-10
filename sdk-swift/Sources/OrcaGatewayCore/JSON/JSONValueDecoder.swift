import Foundation

/// A `Decoder` that reads a Codable model straight from a `JSONValue` tree,
/// so a `.double(4.0)` that `JSONValue.decode(_:)` read from the wire stays a
/// double in any `JSONValue` the model holds (JSONDecoder would read it `.int`).
///
/// Everything else reads as JSONDecoder reads it: a number decodes as any
/// numeric type that holds it exactly (`4.0` as `Int`, `4` as `Double`), a
/// missing key is `keyNotFound`, a null where a value is required is
/// `valueNotFound`, any other wrong kind `typeMismatch`, with the coding path
/// of the value. Pure Swift, so it behaves the same on Linux.
struct JSONValueDecoder: Decoder, SingleValueDecodingContainer {
    let value: JSONValue
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    init(_ value: JSONValue, codingPath: [CodingKey] = []) {
        self.value = value
        self.codingPath = codingPath
    }

    // MARK: Decoder

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .object(let object) = value else {
            throw mismatch([String: Any].self, container: "keyed")
        }
        return KeyedDecodingContainer(KeyedContainer<Key>(object: object, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let items) = value else { throw mismatch([Any].self, container: "unkeyed") }
        return UnkeyedContainer(items: items, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer { self }

    // MARK: SingleValueDecodingContainer

    func decodeNil() -> Bool { value.isNull }

    func decode(_ type: Bool.Type) throws -> Bool {
        guard case .bool(let b) = value else { throw mismatch(type) }
        return b
    }

    func decode(_ type: String.Type) throws -> String {
        guard case .string(let s) = value else { throw mismatch(type) }
        return s
    }

    func decode(_ type: Double.Type) throws -> Double {
        switch value {
        case .int(let i): return Double(i)
        case .double(let d): return d
        default: throw mismatch(type)
        }
    }

    func decode(_ type: Float.Type) throws -> Float {
        let d = try decode(Double.self)
        let f = Float(d)
        guard f.isFinite || !d.isFinite else { throw notRepresentable(type) }
        return f
    }

    func decode(_ type: Int.Type) throws -> Int { try integer(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try integer(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try integer(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try integer(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try integer(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try integer(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try integer(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try integer(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try integer(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try integer(type) }

    /// Any other model reads itself from this node; `JSONValue` takes it whole.
    func decode<T: Decodable>(_ type: T.Type) throws -> T { try T(from: self) }

    // MARK: Conversions and errors

    private func integer<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        switch value {
        case .int(let i):
            guard let n = T(exactly: i) else { throw notRepresentable(type) }
            return n
        case .double(let d):
            guard let n = T(exactly: d) else { throw notRepresentable(type) }
            return n
        default:
            throw mismatch(type)
        }
    }

    private func notRepresentable(_ type: Any.Type) -> DecodingError {
        .dataCorrupted(.init(
            codingPath: codingPath, debugDescription: "Number \(value) does not fit in \(type)."))
    }

    private func mismatch(_ type: Any.Type, container: String? = nil) -> DecodingError {
        if value.isNull {
            let found = container.map { "Cannot get \($0) decoding container -- found null value instead" }
            return .valueNotFound(type, .init(
                codingPath: codingPath, debugDescription: found ?? "Expected \(type) value but found null instead."))
        }
        let kind: String
        switch value {
        case .bool: kind = "bool"
        case .int, .double: kind = "a number"
        case .string: kind = "a string"
        case .array: kind = "an array"
        default: kind = "a dictionary"
        }
        return .typeMismatch(type, .init(
            codingPath: codingPath, debugDescription: "Expected to decode \(type) but found \(kind) instead."))
    }
}

/// A coding path step JSONDecoder names the same way: `Index 2` for an
/// element of an unkeyed container, `super` for `superDecoder()`.
private struct PathKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    init(index: Int) { stringValue = "Index \(index)"; intValue = index }
    init(stringValue: String) { self.stringValue = stringValue; intValue = nil }
    init(intValue: Int) { self.init(index: intValue) }
}

private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let object: [String: JSONValue]
    let codingPath: [CodingKey]

    var allKeys: [Key] { object.keys.compactMap { Key(stringValue: $0) } }

    func contains(_ key: Key) -> Bool { object[key.stringValue] != nil }

    private func node(_ key: Key) throws -> JSONValueDecoder {
        guard let value = object[key.stringValue] else {
            throw DecodingError.keyNotFound(key, .init(
                codingPath: codingPath,
                debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."))
        }
        return JSONValueDecoder(value, codingPath: codingPath + [key])
    }

    func decodeNil(forKey key: Key) throws -> Bool { try node(key).decodeNil() }
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try node(key).decode(type) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try node(key).decode(type) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try node(key).decode(type) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try node(key).decode(type) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try node(key).decode(type) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try node(key).decode(type) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try node(key).decode(type) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try node(key).decode(type) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try node(key).decode(type) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try node(key).decode(type) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try node(key).decode(type) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try node(key).decode(type) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try node(key).decode(type) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try node(key).decode(type) }
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T { try node(key).decode(type) }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type, forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try node(key).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try node(key).unkeyedContainer()
    }

    /// The value at `key`, null when absent, as JSONDecoder's.
    func superDecoder(forKey key: Key) throws -> Decoder {
        JSONValueDecoder(object[key.stringValue] ?? .null, codingPath: codingPath + [key])
    }

    func superDecoder() throws -> Decoder {
        JSONValueDecoder(object["super"] ?? .null, codingPath: codingPath + [PathKey(stringValue: "super")])
    }
}

private struct UnkeyedContainer: UnkeyedDecodingContainer {
    let items: [JSONValue]
    let codingPath: [CodingKey]
    private(set) var currentIndex = 0

    init(items: [JSONValue], codingPath: [CodingKey]) {
        self.items = items
        self.codingPath = codingPath
    }

    var count: Int? { items.count }
    var isAtEnd: Bool { currentIndex >= items.count }

    /// The next element, without moving past it.
    private func peek(_ type: Any.Type) throws -> JSONValueDecoder {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(type, .init(
                codingPath: codingPath + [PathKey(index: currentIndex)], debugDescription: "Unkeyed container is at end."))
        }
        return JSONValueDecoder(items[currentIndex], codingPath: codingPath + [PathKey(index: currentIndex)])
    }

    /// Decode the next element and move past it only when that succeeded.
    private mutating func next<T>(_ type: T.Type, _ read: (JSONValueDecoder) throws -> T) throws -> T {
        let result = try read(try peek(type))
        currentIndex += 1
        return result
    }

    mutating func decodeNil() throws -> Bool {
        guard try peek(Any?.self).decodeNil() else { return false }
        currentIndex += 1
        return true
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: String.Type) throws -> String { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: Double.Type) throws -> Double { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: Float.Type) throws -> Float { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: Int.Type) throws -> Int { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: UInt.Type) throws -> UInt { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try next(type) { try $0.decode(type) } }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try next(type) { try $0.decode(type) } }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { try next(type) { try $0.decode(type) } }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        try next(KeyedDecodingContainer<NestedKey>.self) { try $0.container(keyedBy: type) }
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try next(UnkeyedDecodingContainer.self) { try $0.unkeyedContainer() }
    }

    mutating func superDecoder() throws -> Decoder {
        try next(Decoder.self) { $0 }
    }
}
