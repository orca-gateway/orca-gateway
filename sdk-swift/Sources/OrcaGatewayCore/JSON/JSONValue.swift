import Foundation

/// A JSON value as it travels on the wire: props, state, Value payloads.
///
/// Numbers keep the int/double split the Dart SDK has: `decode(_:)` reads the
/// number's text, so an integer literal is `.int` and one with a fraction or
/// exponent (`4.0`, `1e2`) or past `Int` is `.double`, as Dart's `jsonDecode`.
/// (A Codable model decoded with JSONDecoder still reads `4.0` as `.int`.)
/// Equality follows Dart's `==`: numbers by value (`3 == 3.0`), strings by
/// UTF-16 code units (no Unicode normalization), and deep value equality for
/// arrays and objects.
public enum JSONValue: Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - Accessors

extension JSONValue {
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    /// The value as a Double when it is any number (`.int` or `.double`).
    public var doubleValue: Double? {
        switch self {
        case .int(let i): return Double(i)
        case .double(let d): return d
        default: return nil
        }
    }

    /// Dart's `(x as num?)?.toInt()`: truncates a double toward zero,
    /// clamping to the Int range; nil for non-numbers, NaN and infinity
    /// (where Dart throws). Never traps, unlike `Int(someDouble)`.
    public var dartInt: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d):
            guard d.isFinite else { return nil }
            if d >= 9.223372036854775807e18 { return Int.max }
            if d <= -9.223372036854775808e18 { return Int.min }
            return Int(d.rounded(.towardZero))
        default: return nil
        }
    }

    public var isNumber: Bool {
        switch self {
        case .int, .double: return true
        default: return false
        }
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// Object member lookup; `.null` when absent or when this is not an object,
    /// like a Dart `map[key]` on a `Map<String, dynamic>`.
    public subscript(key: String) -> JSONValue {
        if case .object(let o) = self { return o[key] ?? .null }
        return .null
    }
}

// MARK: - Equality

extension JSONValue: Equatable {
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let a), .bool(let b)): return a == b
        case (.int(let a), .int(let b)): return a == b
        case (.double(let a), .double(let b)): return a == b
        case (.int(let a), .double(let b)): return Double(a) == b
        case (.double(let a), .int(let b)): return a == Double(b)
        // Same scalars, same UTF-16 units: "\u{e9}" is not "e\u{301}" here,
        // where Swift's String `==` would call them equal.
        case (.string(let a), .string(let b)): return a.utf8.elementsEqual(b.utf8)
        case (.array(let a), .array(let b)): return a == b
        case (.object(let a), .object(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Codable

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Not a JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let b): try container.encode(b)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .string(let s): try container.encode(s)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        }
    }
}

// MARK: - Literals

extension JSONValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByStringLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(floatLiteral value: Double) { self = .double(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        var o: [String: JSONValue] = [:]
        for (k, v) in elements { o[k] = v }
        self = .object(o)
    }
}

// MARK: - Data helpers

extension JSONValue {
    /// Decode any JSON document (object, array or scalar), as Dart's
    /// `jsonDecode` reads it (see `JSONParser`).
    public static func decode(_ data: Data) throws -> JSONValue {
        var parser = JSONParser(data)
        return try parser.document()
    }

    /// Encode with sorted keys, so the output is stable across runs.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Re-read a Codable model as a JSONValue tree (used by tests and by the
    /// effect payloads that must compare as data).
    public init<T: Encodable>(encoding value: T) throws {
        let data = try JSONEncoder().encode(value)
        self = try JSONValue.decode(data)
    }

    /// Decode a Codable model from this tree.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: try encoded())
    }
}


// MARK: - Parser

/// RFC 8259 JSON over UTF-8 bytes, read the way Dart's `jsonDecode` reads it:
/// unlike JSONDecoder it sees a number's text, so `4.0` stays a double. A
/// trailing comma is an error and a repeated key keeps its last value, as in
/// Dart; a number a Double cannot hold (`1e400`), a lone surrogate escape and
/// invalid UTF-8 throw, as JSONDecoder did (Swift strings cannot hold them).
/// Pure Swift, so it reads the same on Linux. Nesting stops at 512 levels, as
/// JSONDecoder's does, rather than overflowing the stack.
struct JSONParser {
    static let maxDepth = 512

    private let bytes: [UInt8]
    private var i = 0
    private var depth = 0

    init(_ data: Data) {
        bytes = [UInt8](data)
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { i = 3 }  // a UTF-8 BOM
    }

    mutating func document() throws -> JSONValue {
        let value = try value()
        skipWhitespace()
        guard i == bytes.count else { throw fail("Unexpected text after the value") }
        return value
    }

    private func fail(_ message: String) -> DecodingError {
        .dataCorrupted(.init(codingPath: [], debugDescription: "\(message) at byte \(i)."))
    }

    private var peek: UInt8? { i < bytes.count ? bytes[i] : nil }

    private mutating func skipWhitespace() {
        while let b = peek, b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09 { i += 1 }
    }

    private mutating func value() throws -> JSONValue {
        skipWhitespace()
        switch peek {
        case UInt8(ascii: "{"): return try object()
        case UInt8(ascii: "["): return try array()
        case UInt8(ascii: "\""): return .string(try string())
        case UInt8(ascii: "t"): try literal("true"); return .bool(true)
        case UInt8(ascii: "f"): try literal("false"); return .bool(false)
        case UInt8(ascii: "n"): try literal("null"); return .null
        default: return try number()
        }
    }

    private mutating func literal(_ word: String) throws {
        let expected = Array(word.utf8)
        guard bytes[i...].starts(with: expected) else { throw fail("Expected \(word)") }
        i += expected.count
    }

    private mutating func enter() throws {
        depth += 1
        guard depth <= Self.maxDepth else { throw fail("Nested deeper than \(Self.maxDepth)") }
    }

    private mutating func array() throws -> JSONValue {
        try enter()
        defer { depth -= 1 }
        i += 1
        var items: [JSONValue] = []
        skipWhitespace()
        if peek == UInt8(ascii: "]") {
            i += 1
            return .array(items)
        }
        while true {
            items.append(try value())
            skipWhitespace()
            switch peek {
            case UInt8(ascii: ","): i += 1
            case UInt8(ascii: "]"): i += 1; return .array(items)
            default: throw fail("Expected , or ]")
            }
        }
    }

    private mutating func object() throws -> JSONValue {
        try enter()
        defer { depth -= 1 }
        i += 1
        var members: [String: JSONValue] = [:]
        skipWhitespace()
        if peek == UInt8(ascii: "}") {
            i += 1
            return .object(members)
        }
        while true {
            skipWhitespace()
            guard peek == UInt8(ascii: "\"") else { throw fail("Expected a key") }
            let key = try string()
            skipWhitespace()
            guard peek == UInt8(ascii: ":") else { throw fail("Expected :") }
            i += 1
            members[key] = try value()
            skipWhitespace()
            switch peek {
            case UInt8(ascii: ","): i += 1
            case UInt8(ascii: "}"): i += 1; return .object(members)
            default: throw fail("Expected , or }")
            }
        }
    }

    /// `-?(0|[1-9][0-9]*)(.[0-9]+)?([eE][+-]?[0-9]+)?`: an integer literal is
    /// `.int` when it fits, anything else `.double`.
    private mutating func number() throws -> JSONValue {
        let start = i
        if peek == UInt8(ascii: "-") { i += 1 }
        if peek == UInt8(ascii: "0") { i += 1 } else { try digits() }
        var integer = true
        if peek == UInt8(ascii: ".") {
            integer = false
            i += 1
            try digits()
        }
        if peek == UInt8(ascii: "e") || peek == UInt8(ascii: "E") {
            integer = false
            i += 1
            if peek == UInt8(ascii: "+") || peek == UInt8(ascii: "-") { i += 1 }
            try digits()
        }
        let text = String(decoding: bytes[start..<i], as: UTF8.self)
        if integer, let n = Int(text) { return .int(n) }
        guard let d = Double(text), d.isFinite else { throw fail("Number \(text) is not representable") }
        return .double(d)
    }

    private mutating func digits() throws {
        let start = i
        while let b = peek, b >= UInt8(ascii: "0"), b <= UInt8(ascii: "9") { i += 1 }
        guard i > start else { throw fail("Expected a digit") }
    }

    private mutating func string() throws -> String {
        i += 1  // the opening quote
        var buffer: [UInt8] = []
        while let b = peek {
            i += 1
            switch b {
            case UInt8(ascii: "\""):
                let s = String(decoding: buffer, as: UTF8.self)
                guard s.utf8.elementsEqual(buffer) else { throw fail("Invalid UTF-8") }
                return s
            case UInt8(ascii: "\\"):
                try escape(into: &buffer)
            case 0..<0x20:
                throw fail("Unescaped control character")
            default:
                buffer.append(b)
            }
        }
        throw fail("Unterminated string")
    }

    private mutating func escape(into buffer: inout [UInt8]) throws {
        guard let b = peek else { throw fail("Unterminated string") }
        i += 1
        switch b {
        case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"): buffer.append(b)
        case UInt8(ascii: "b"): buffer.append(0x08)
        case UInt8(ascii: "f"): buffer.append(0x0C)
        case UInt8(ascii: "n"): buffer.append(0x0A)
        case UInt8(ascii: "r"): buffer.append(0x0D)
        case UInt8(ascii: "t"): buffer.append(0x09)
        case UInt8(ascii: "u"):
            let unit = try hex4()
            var scalar = Unicode.Scalar(unit)
            if UTF16.isLeadSurrogate(unit), bytes[i...].starts(with: [UInt8(ascii: "\\"), UInt8(ascii: "u")]) {
                i += 2
                let trail = try hex4()
                if UTF16.isTrailSurrogate(trail) {
                    scalar = Unicode.Scalar(0x10000 + (UInt32(unit - 0xD800) << 10) + UInt32(trail - 0xDC00))
                }
            }
            guard let scalar else { throw fail("Lone surrogate escape") }
            buffer.append(contentsOf: scalar.utf8)
        default:
            throw fail("Invalid escape")
        }
    }

    private mutating func hex4() throws -> UInt16 {
        var unit: UInt16 = 0
        for _ in 0..<4 {
            guard let b = peek else { throw fail("Expected four hex digits") }
            let digit: UInt8
            switch b {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): digit = b - UInt8(ascii: "0")
            case UInt8(ascii: "a")...UInt8(ascii: "f"): digit = b - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): digit = b - UInt8(ascii: "A") + 10
            default: throw fail("Expected four hex digits")
            }
            unit = unit << 4 | UInt16(digit)
            i += 1
        }
        return unit
    }
}
