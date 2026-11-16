/// The sheets openDialog has opened on one page, the Swift side of Flutter's
/// openDialog and closeDialog handlers (sdk/lib/src/widgets/orca_page.dart
/// :323-374, sdk/lib/src/state/action_executor.dart:894-919). Pure: the UI
/// draws `sheets` bottom to top and reports what closes them.
///
/// A sheet holds the Dialog's children subtree, depth-first; Flutter's
/// ComponentRenderer draws such a list from its first node
/// (component_renderer.dart:44-54), the Dialog's first child, so a second
/// child is in the list but nothing draws it. The Dialog's own props
/// (title, dismissible, backgroundColor, borderRadius) are never read, and
/// its type is not checked: any keyed node with children opens.
public struct DialogStack: Equatable, Sendable {
    /// The height of a sheet whose openDialog names none (orca_page.dart:326).
    public static let defaultHeightFactor = 0.5

    /// One open sheet.
    public struct Sheet: Equatable, Sendable, Identifiable {
        /// Which open this is: the same Dialog opened twice is two sheets.
        public let id: Int
        public let dialogId: String
        /// The sheet's height as a fraction of the height available.
        public let heightFactor: Double
        /// The Dialog's children and everything below them, depth-first in
        /// order, as the page held them when the sheet opened: Flutter's
        /// `subtree` list (orca_page.dart:332-343). Never empty.
        public let nodes: [ComponentNode]

        /// The node the sheet draws: the first of `nodes`, the Dialog's first
        /// child on the page.
        public var rootId: String { nodes[0].id }
    }

    /// Open sheets, the bottom one first.
    public private(set) var sheets: [Sheet] = []
    private var opened = 0

    public init() {}

    /// The sheet on top, the one a close or a dismiss takes away.
    public var top: Sheet? { sheets.last }

    /// A sheet's height factor: openDialog's `heightFactor`, 0.5 when absent
    /// (orca_page.dart:326), also when NaN or negative.
    public static func heightFactor(_ value: Double?) -> Double {
        guard let value, value >= 0 else { return defaultHeightFactor }
        return value
    }

    /// openDialog: a sheet of the Dialog `dialogId` of `nodes` (the page's
    /// node map) on top of the stack, and that sheet. An id the page lacks,
    /// or a Dialog none of whose children is on the page, opens nothing and
    /// gives nil (orca_page.dart:329, :344). A child the page lacks is
    /// skipped, as Flutter's `collect`; a node met twice is listed once.
    @discardableResult
    public mutating func open(dialogId: String, heightFactor: Double?,
                              nodes: [String: ComponentNode]) -> Sheet? {
        guard let dialog = nodes[dialogId] else { return nil }
        var subtree: [ComponentNode] = []
        var seen: Set<String> = []
        func collect(_ id: String) {
            guard let node = nodes[id], seen.insert(id).inserted else { return }
            subtree.append(node)
            node.children.forEach(collect)
        }
        dialog.children.forEach(collect)
        guard !subtree.isEmpty else { return nil }
        let sheet = Sheet(id: opened, dialogId: dialogId,
                          heightFactor: Self.heightFactor(heightFactor), nodes: subtree)
        opened += 1
        sheets.append(sheet)
        return sheet
    }

    /// closeDialog: takes the top sheet away and gives it; with none open it
    /// does nothing and gives nil, never closing a page (action_executor.dart
    /// :903-912).
    @discardableResult
    public mutating func close() -> Sheet? {
        sheets.popLast()
    }

    /// A barrier tap, a drag down or Back: takes the top sheet away, whatever
    /// the Dialog's `dismissible` says, and gives it; nil with none open.
    @discardableResult
    public mutating func dismiss() -> Sheet? {
        close()
    }
}
