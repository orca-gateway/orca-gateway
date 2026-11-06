import Foundation

/// A wire action (schema/action.schema.json, engine/src/types/action.ts): all
/// 28 kinds, plus `custom:*` and unknown kinds kept verbatim so a newer server
/// never breaks decoding of a whole page.
///
/// Fields that the wire types as `string | Value` (or plain `Value`) are
/// `JSONValue`: the executor resolves them with `ValueResolver` at run time.
/// Optional fields mirror what the Dart executor reads, which is a superset of
/// the TS interfaces in a few places (`showToast.duration`, `share.text`,
/// `navigate.path`, `addComponent.components`).
public indirect enum Action: Equatable, Sendable {
    case navigate(Navigate)
    case goBack
    case switchTab(SwitchTab)
    case openDrawer
    case openDialog(OpenDialog)
    case closeDialog
    case setState(SetState)
    case clearState(ClearState)
    case persistState(PersistState)
    case serverAction(ServerAction)
    case showSnackbar(ShowSnackbar)
    case showToast(ShowToast)
    case updateComponent(UpdateComponent)
    case deleteComponent(DeleteComponent)
    case addComponent(AddComponent)
    case copyToClipboard(CopyToClipboard)
    case share(Share)
    case openUrl(OpenUrl)
    case actionGroup(ActionGroup)
    case conditionalAction(ConditionalAction)
    case animateForward(AnimationRef)
    case animateReverse(AnimationRef)
    case refetchPage
    case updateSubPage(UpdateSubPage)
    case lifecycle(Lifecycle)
    case debugLog(DebugLog)
    case once(Wrapped)
    case always(Wrapped)
    /// `custom:<name>`, handled by a plugin; the whole object is kept.
    case custom(JSONValue)
    /// A kind this build does not know; the whole object is kept.
    case unknown(JSONValue)

    /// The 28 built-in kinds.
    public static let kinds = [
        "navigate", "goBack", "switchTab", "openDrawer", "openDialog", "closeDialog",
        "setState", "clearState", "persistState", "serverAction", "showSnackbar",
        "showToast", "updateComponent", "deleteComponent", "addComponent",
        "copyToClipboard", "share", "openUrl", "actionGroup", "conditionalAction",
        "animateForward", "animateReverse", "refetchPage", "updateSubPage",
        "lifecycle", "debugLog", "once", "always",
    ]

    public var kind: String {
        switch self {
        case .navigate: return "navigate"
        case .goBack: return "goBack"
        case .switchTab: return "switchTab"
        case .openDrawer: return "openDrawer"
        case .openDialog: return "openDialog"
        case .closeDialog: return "closeDialog"
        case .setState: return "setState"
        case .clearState: return "clearState"
        case .persistState: return "persistState"
        case .serverAction: return "serverAction"
        case .showSnackbar: return "showSnackbar"
        case .showToast: return "showToast"
        case .updateComponent: return "updateComponent"
        case .deleteComponent: return "deleteComponent"
        case .addComponent: return "addComponent"
        case .copyToClipboard: return "copyToClipboard"
        case .share: return "share"
        case .openUrl: return "openUrl"
        case .actionGroup: return "actionGroup"
        case .conditionalAction: return "conditionalAction"
        case .animateForward: return "animateForward"
        case .animateReverse: return "animateReverse"
        case .refetchPage: return "refetchPage"
        case .updateSubPage: return "updateSubPage"
        case .lifecycle: return "lifecycle"
        case .debugLog: return "debugLog"
        case .once: return "once"
        case .always: return "always"
        case .custom(let raw), .unknown(let raw): return raw["type"].stringValue ?? ""
        }
    }

    // MARK: Payloads

    public struct Navigate: Codable, Equatable, Sendable {
        public var route: JSONValue?
        /// Legacy alias the Dart executor falls back to when `route` is absent.
        public var path: JSONValue?
        public var params: [String: JSONValue]?
        public var replace: Bool?
        public init(route: JSONValue? = nil, path: JSONValue? = nil,
                    params: [String: JSONValue]? = nil, replace: Bool? = nil) {
            self.route = route; self.path = path; self.params = params; self.replace = replace
        }
    }

    public struct SwitchTab: Codable, Equatable, Sendable {
        public var tabId: String
        public init(tabId: String) { self.tabId = tabId }
    }

    public struct OpenDialog: Codable, Equatable, Sendable {
        public var dialogId: String
        public var heightFactor: Double?
        public init(dialogId: String, heightFactor: Double? = nil) {
            self.dialogId = dialogId; self.heightFactor = heightFactor
        }
    }

    public struct SetState: Codable, Equatable, Sendable {
        public var key: String
        /// Absent means `page`, as in the Dart executor.
        public var scope: StateScope?
        public var value: JSONValue
        public init(key: String, scope: StateScope? = nil, value: JSONValue) {
            self.key = key; self.scope = scope; self.value = value
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            key = try c.decode(String.self, forKey: .key)
            scope = try c.decodeIfPresent(StateScope.self, forKey: .scope)
            value = try c.decodeIfPresent(JSONValue.self, forKey: .value) ?? .null
        }
    }

    public struct ClearState: Codable, Equatable, Sendable {
        public var key: String
        public var scope: StateScope?
        public init(key: String, scope: StateScope? = nil) { self.key = key; self.scope = scope }
    }

    public struct PersistState: Codable, Equatable, Sendable {
        public var key: String
        public var scope: StateScope?
        public var storage: String?
        public init(key: String, scope: StateScope? = nil, storage: String? = nil) {
            self.key = key; self.scope = scope; self.storage = storage
        }
    }

    public struct ServerAction: Codable, Equatable, Sendable {
        public var id: String
        public var params: [String: JSONValue]?
        public init(id: String, params: [String: JSONValue]? = nil) {
            self.id = id; self.params = params
        }
    }

    public struct ShowSnackbar: Codable, Equatable, Sendable {
        public var message: JSONValue?
        public var duration: Int?
        public var action: String?
        public init(message: JSONValue? = nil, duration: Int? = nil, action: String? = nil) {
            self.message = message; self.duration = duration; self.action = action
        }
    }

    public struct ShowToast: Codable, Equatable, Sendable {
        public var message: JSONValue?
        public var duration: Int?
        public init(message: JSONValue? = nil, duration: Int? = nil) {
            self.message = message; self.duration = duration
        }
    }

    public struct UpdateComponent: Codable, Equatable, Sendable {
        public var id: String
        public var props: [String: JSONValue]?
        public init(id: String, props: [String: JSONValue]? = nil) { self.id = id; self.props = props }
    }

    public struct DeleteComponent: Codable, Equatable, Sendable {
        public var id: String
        public init(id: String) { self.id = id }
    }

    public struct AddComponent: Codable, Equatable, Sendable {
        public var parentId: String
        public var node: JSONValue?
        public var components: JSONValue?
        public var position: Int?
        public init(parentId: String, node: JSONValue? = nil, components: JSONValue? = nil,
                    position: Int? = nil) {
            self.parentId = parentId; self.node = node; self.components = components
            self.position = position
        }
    }

    public struct CopyToClipboard: Codable, Equatable, Sendable {
        public var text: JSONValue?
        public init(text: JSONValue? = nil) { self.text = text }
    }

    public struct Share: Codable, Equatable, Sendable {
        public var title: JSONValue?
        public var message: JSONValue?
        public var text: JSONValue?
        public var subject: JSONValue?
        public var url: JSONValue?
        public init(title: JSONValue? = nil, message: JSONValue? = nil, text: JSONValue? = nil,
                    subject: JSONValue? = nil, url: JSONValue? = nil) {
            self.title = title; self.message = message; self.text = text
            self.subject = subject; self.url = url
        }
    }

    public struct OpenUrl: Codable, Equatable, Sendable {
        public var url: JSONValue?
        public init(url: JSONValue? = nil) { self.url = url }
    }

    public struct ActionGroup: Codable, Equatable, Sendable {
        public var mode: String?
        public var actions: [Action]
        public init(mode: String? = nil, actions: [Action]) { self.mode = mode; self.actions = actions }
    }

    public struct ConditionalAction: Codable, Equatable, Sendable {
        public struct Branch: Codable, Equatable, Sendable {
            public var when: BoolExpr
            public var then: Action
            public init(when: BoolExpr, then: Action) { self.when = when; self.then = then }
        }
        public var branches: [Branch]
        public var `else`: Action?
        public init(branches: [Branch], else elseAction: Action? = nil) {
            self.branches = branches; self.else = elseAction
        }
    }

    public struct AnimationRef: Codable, Equatable, Sendable {
        public var animationId: String
        public init(animationId: String) { self.animationId = animationId }
    }

    public struct UpdateSubPage: Codable, Equatable, Sendable {
        public var subPageId: JSONValue
        public var pageId: JSONValue
        public var params: [String: JSONValue]?
        public var mode: JSONValue?
        public init(subPageId: JSONValue, pageId: JSONValue, params: [String: JSONValue]? = nil,
                    mode: JSONValue? = nil) {
            self.subPageId = subPageId; self.pageId = pageId; self.params = params; self.mode = mode
        }
    }

    public struct Lifecycle: Codable, Equatable, Sendable {
        public var action: Action
        public var onLoading: ActionList?
        public var onSuccess: ActionList?
        public var onError: ActionList?
        public var onComplete: ActionList?
        public init(action: Action, onLoading: ActionList? = nil, onSuccess: ActionList? = nil,
                    onError: ActionList? = nil, onComplete: ActionList? = nil) {
            self.action = action; self.onLoading = onLoading; self.onSuccess = onSuccess
            self.onError = onError; self.onComplete = onComplete
        }
    }

    public struct DebugLog: Codable, Equatable, Sendable {
        public var level: String?
        public var message: JSONValue?
        public var tag: String?
        public var data: JSONValue?
        public var includeState: Bool?
        public var includeEvent: Bool?
        public var includeRequest: Bool?
        public var includeStackTrace: Bool?
        public init(level: String? = nil, message: JSONValue? = nil, tag: String? = nil,
                    data: JSONValue? = nil, includeState: Bool? = nil, includeEvent: Bool? = nil,
                    includeRequest: Bool? = nil, includeStackTrace: Bool? = nil) {
            self.level = level; self.message = message; self.tag = tag; self.data = data
            self.includeState = includeState; self.includeEvent = includeEvent
            self.includeRequest = includeRequest; self.includeStackTrace = includeStackTrace
        }
    }

    public struct Wrapped: Codable, Equatable, Sendable {
        public var action: Action
        public init(action: Action) { self.action = action }
    }
}

/// `Action | Action[]`, as lifecycle callbacks allow either.
public enum ActionList: Equatable, Sendable, Codable {
    case single(Action)
    case many([Action])

    public var actions: [Action] {
        switch self {
        case .single(let a): return [a]
        case .many(let list): return list
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let list = try? c.decode([Action].self) {
            self = .many(list)
        } else {
            self = .single(try c.decode(Action.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .single(let a): try c.encode(a)
        case .many(let list): try c.encode(list)
        }
    }
}

extension Action: Codable {
    private enum TypeKey: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: TypeKey.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "navigate": self = .navigate(try Navigate(from: decoder))
        case "goBack": self = .goBack
        case "switchTab": self = .switchTab(try SwitchTab(from: decoder))
        case "openDrawer": self = .openDrawer
        case "openDialog": self = .openDialog(try OpenDialog(from: decoder))
        case "closeDialog": self = .closeDialog
        case "setState": self = .setState(try SetState(from: decoder))
        case "clearState": self = .clearState(try ClearState(from: decoder))
        case "persistState": self = .persistState(try PersistState(from: decoder))
        case "serverAction": self = .serverAction(try ServerAction(from: decoder))
        case "showSnackbar": self = .showSnackbar(try ShowSnackbar(from: decoder))
        case "showToast": self = .showToast(try ShowToast(from: decoder))
        case "updateComponent": self = .updateComponent(try UpdateComponent(from: decoder))
        case "deleteComponent": self = .deleteComponent(try DeleteComponent(from: decoder))
        case "addComponent": self = .addComponent(try AddComponent(from: decoder))
        case "copyToClipboard": self = .copyToClipboard(try CopyToClipboard(from: decoder))
        case "share": self = .share(try Share(from: decoder))
        case "openUrl": self = .openUrl(try OpenUrl(from: decoder))
        case "actionGroup": self = .actionGroup(try ActionGroup(from: decoder))
        case "conditionalAction": self = .conditionalAction(try ConditionalAction(from: decoder))
        case "animateForward": self = .animateForward(try AnimationRef(from: decoder))
        case "animateReverse": self = .animateReverse(try AnimationRef(from: decoder))
        case "refetchPage": self = .refetchPage
        case "updateSubPage": self = .updateSubPage(try UpdateSubPage(from: decoder))
        case "lifecycle": self = .lifecycle(try Lifecycle(from: decoder))
        case "debugLog": self = .debugLog(try DebugLog(from: decoder))
        case "once": self = .once(try Wrapped(from: decoder))
        case "always": self = .always(try Wrapped(from: decoder))
        default:
            let raw = try JSONValue(from: decoder)
            self = type.hasPrefix("custom:") ? .custom(raw) : .unknown(raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .custom(let raw), .unknown(let raw):
            try raw.encode(to: encoder)
            return
        case .navigate(let p): try p.encode(to: encoder)
        case .switchTab(let p): try p.encode(to: encoder)
        case .openDialog(let p): try p.encode(to: encoder)
        case .setState(let p): try p.encode(to: encoder)
        case .clearState(let p): try p.encode(to: encoder)
        case .persistState(let p): try p.encode(to: encoder)
        case .serverAction(let p): try p.encode(to: encoder)
        case .showSnackbar(let p): try p.encode(to: encoder)
        case .showToast(let p): try p.encode(to: encoder)
        case .updateComponent(let p): try p.encode(to: encoder)
        case .deleteComponent(let p): try p.encode(to: encoder)
        case .addComponent(let p): try p.encode(to: encoder)
        case .copyToClipboard(let p): try p.encode(to: encoder)
        case .share(let p): try p.encode(to: encoder)
        case .openUrl(let p): try p.encode(to: encoder)
        case .actionGroup(let p): try p.encode(to: encoder)
        case .conditionalAction(let p): try p.encode(to: encoder)
        case .animateForward(let p), .animateReverse(let p): try p.encode(to: encoder)
        case .updateSubPage(let p): try p.encode(to: encoder)
        case .lifecycle(let p): try p.encode(to: encoder)
        case .debugLog(let p): try p.encode(to: encoder)
        case .once(let p), .always(let p): try p.encode(to: encoder)
        case .goBack, .openDrawer, .closeDialog, .refetchPage: break
        }
        var c = encoder.container(keyedBy: TypeKey.self)
        try c.encode(kind, forKey: .type)
    }
}

extension Action {
    public var json: JSONValue { (try? JSONValue(encoding: self)) ?? .null }
}
