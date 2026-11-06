import Foundation

/// One message for Orca DevTools (schema/devtools-events.schema.json): a type
/// and its payload. `envelope` adds the device id and the time, as the
/// WebSocket client sends it. Each builder below makes the same payload as
/// its Dart counterpart in sdk/lib/src/debug/debug_events.dart, field for
/// field; schema/fixtures/devtools pins both.
public struct DevToolsEvent: Equatable, Sendable {
    public var type: String
    public var payload: [String: JSONValue]

    public init(_ type: String, _ payload: [String: JSONValue]) {
        self.type = type
        self.payload = payload
    }

    /// `{type, deviceId, timestamp, payload}`; `timestamp` in milliseconds
    /// since the Unix epoch.
    public func envelope(deviceId: String, timestamp: Int) -> JSONValue {
        [
            "type": .string(type), "deviceId": .string(deviceId),
            "timestamp": .int(timestamp), "payload": .object(payload),
        ]
    }
}

// MARK: Builders

extension DevToolsEvent {
    /// The handshake, sent first on every connect (Dart `deviceInfoPayload`).
    public static func deviceInfo(
        platform: String, deviceModel: String, appVersion: String = "1.0.0", appName: String? = nil
    ) -> DevToolsEvent {
        var p: [String: JSONValue] = [
            "platform": .string(platform), "appVersion": .string(appVersion),
            "deviceModel": .string(deviceModel),
        ]
        if let appName { p["appName"] = .string(appName) }
        return DevToolsEvent("device_info", p)
    }

    /// The client's marks of one page load, in milliseconds from the
    /// request start (Dart `ClientTimingData`).
    public struct ClientTiming: Equatable, Sendable {
        public var requestStartMs: Double
        public var responseReceivedMs: Double
        public var parseCompleteMs: Double
        public var renderStartMs: Double
        public var renderCompleteMs: Double
        public var firstFrameMs: Double

        public init(requestStartMs: Double = 0, responseReceivedMs: Double, parseCompleteMs: Double,
                    renderStartMs: Double, renderCompleteMs: Double, firstFrameMs: Double) {
            self.requestStartMs = requestStartMs
            self.responseReceivedMs = responseReceivedMs
            self.parseCompleteMs = parseCompleteMs
            self.renderStartMs = renderStartMs
            self.renderCompleteMs = renderCompleteMs
            self.firstFrameMs = firstFrameMs
        }

        var json: JSONValue {
            [
                "requestStartMs": .double(requestStartMs), "responseReceivedMs": .double(responseReceivedMs),
                "parseCompleteMs": .double(parseCompleteMs), "renderStartMs": .double(renderStartMs),
                "renderCompleteMs": .double(renderCompleteMs), "firstFrameMs": .double(firstFrameMs),
            ]
        }
    }

    /// One page load. `server` is the engine's `x-orca-timing` header as
    /// parsed, left out when the engine sent none.
    public static func timing(pageId: String, path: String, server: JSONValue?, client: ClientTiming)
        -> DevToolsEvent
    {
        var p: [String: JSONValue] = [
            "pageId": .string(pageId), "path": .string(path), "client": client.json,
        ]
        if case .object? = server { p["server"] = server }
        return DevToolsEvent("timing", p)
    }

    /// One key of one scope changed; both values are always sent.
    public static func stateChange(
        scope: StateScope, pageId: String, key: String, oldValue: JSONValue, newValue: JSONValue
    ) -> DevToolsEvent {
        DevToolsEvent("state_change", [
            "scope": .string(scope.rawValue), "pageId": .string(pageId), "key": .string(key),
            "oldValue": oldValue, "newValue": newValue,
        ])
    }

    /// Every key whose value differs between two states, page scope first,
    /// keys in order. Flutter reports per dispatched key; a Swift commit
    /// replaces the whole state, so the diff finds the same keys.
    public static func stateChanges(from old: StoreState, to new: StoreState, pageId: String)
        -> [DevToolsEvent]
    {
        var events: [DevToolsEvent] = []
        for scope in [StateScope.page, .app] {
            let before = old[scope], after = new[scope]
            for key in Set(before.keys).union(after.keys).sorted() {
                let was = before[key] ?? .null, now = after[key] ?? .null
                if was != now {
                    events.append(stateChange(scope: scope, pageId: pageId, key: key, oldValue: was, newValue: now))
                }
            }
        }
        return events
    }

    /// One action ran: the action as sent on the wire, and how long it took.
    public static func action(_ action: Action, pageId: String, durationMs: Double) -> DevToolsEvent {
        DevToolsEvent("action", [
            "actionType": .string(action.kind), "family": .string(family(of: action.kind)),
            "pageId": .string(pageId), "data": (try? JSONValue(encoding: action)) ?? .null,
            "durationMs": .double(durationMs),
        ])
    }

    /// The DevTools Actions panel's grouping (Dart `inferActionFamily`).
    public static func family(of actionType: String) -> String {
        let exact: [String: String] = [
            "setState": "state", "navigate": "navigation", "goBack": "navigation",
            "switchTab": "navigation", "showSnackbar": "ui-feedback", "showToast": "ui-feedback",
            "openDrawer": "ui-feedback", "serverAction": "data", "actionGroup": "lifecycle",
            "conditionalAction": "data", "openUrl": "ui-feedback", "copyToClipboard": "ui-feedback",
            "share": "ui-feedback", "updateComponent": "state", "deleteComponent": "state",
            "addComponent": "state", "replaceComponent": "state",
        ]
        if let family = exact[actionType] { return family }
        let upper = actionType.uppercased()
        func any(_ parts: [String]) -> Bool { parts.contains { upper.contains($0) } }
        if upper.hasPrefix("NAVIGATE") || upper.hasPrefix("GO_") || upper.contains("ROUTE") {
            return "navigation"
        }
        if upper.hasPrefix("SET_") || upper.hasPrefix("UPDATE_") || upper.hasPrefix("TOGGLE_") {
            return "state"
        }
        if any(["TOAST", "SNACKBAR", "MODAL", "ALERT", "SCROLL"]) { return "ui-feedback" }
        if upper.hasPrefix("APP_") || any(["LIFECYCLE", "AUTH_"]) { return "lifecycle" }
        if any(["FETCH", "LOAD", "CART", "SUBMIT", "APPLY_"]) { return "data" }
        return "custom"
    }

    /// One measured phase of a request (`dns`, `connect`, `tls`, `request`,
    /// `wait`, `download`).
    public struct NetworkPhase: Equatable, Sendable {
        public var phase: String
        public var durationMs: Double

        public init(_ phase: String, _ durationMs: Double) {
            self.phase = phase
            self.durationMs = durationMs
        }
    }

    /// One HTTP request; `statusCode` 0 when the transport failed. Pass
    /// headers through `sanitize` first. Empty and missing fields are left
    /// out, as Dart does.
    public static func network(
        method: String, url: String, statusCode: Int, durationMs: Double,
        requestSizeBytes: Int? = nil, responseSizeBytes: Int? = nil,
        requestHeaders: [String: String] = [:], responseHeaders: [String: String] = [:],
        phases: [NetworkPhase] = []
    ) -> DevToolsEvent {
        var p: [String: JSONValue] = [
            "method": .string(method), "url": .string(url), "statusCode": .int(statusCode),
            "durationMs": .double(durationMs),
        ]
        if let requestSizeBytes { p["requestSizeBytes"] = .int(requestSizeBytes) }
        if let responseSizeBytes { p["responseSizeBytes"] = .int(responseSizeBytes) }
        if !requestHeaders.isEmpty { p["requestHeaders"] = .object(requestHeaders.mapValues(JSONValue.string)) }
        if !responseHeaders.isEmpty { p["responseHeaders"] = .object(responseHeaders.mapValues(JSONValue.string)) }
        if !phases.isEmpty {
            p["phases"] = .array(phases.map { ["phase": .string($0.phase), "durationMs": .double($0.durationMs)] })
        }
        return DevToolsEvent("network", p)
    }

    /// Headers never sent to DevTools as they are (Dart `_sanitizeHeaders`).
    public static let redactedHeaders: Set<String> = [
        "authorization", "cookie", "set-cookie", "x-api-key", "proxy-authorization",
    ]

    public static func sanitize(_ headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { out, header in
            out[header.key] = redactedHeaders.contains(header.key.lowercased()) ? "<redacted>" : header.value
        }
    }

    /// A node redrew because a key it watches changed. `propTraces` maps a
    /// prop to its transform steps (`{op, in?, out}`); the Swift resolver does
    /// not trace, so the SDK sends it empty.
    public static func widgetRebuild(
        widgetId: String, widgetType: String, watches: [String], propTraces: [String: [JSONValue]] = [:]
    ) -> DevToolsEvent {
        DevToolsEvent("widget_rebuild", [
            "widgetId": .string(widgetId), "widgetType": .string(widgetType),
            "watches": .array(watches.map(JSONValue.string)), "propTraces": .object(propTraces.mapValues(JSONValue.array)),
        ])
    }

    /// An error; DevTools files it as a warning when the message or context
    /// contains "warn", "notfound" or "404".
    public static func error(message: String, stackTrace: String? = nil, context: String? = nil)
        -> DevToolsEvent
    {
        var p: [String: JSONValue] = ["message": .string(message)]
        if let stackTrace { p["stackTrace"] = .string(stackTrace) }
        if let context { p["context"] = .string(context) }
        return DevToolsEvent("error", p)
    }

    /// The warning for a drawn FallbackPrompt (Dart
    /// `DebugErrorEvent.fallbackPrompt`), sent once per unknown type.
    public static func fallbackPrompt(_ widgetType: String) -> DevToolsEvent {
        error(message: "Unsupported widget type \"\(widgetType)\"; drew a FallbackPrompt",
              context: "warn: FallbackPrompt")
    }
}
