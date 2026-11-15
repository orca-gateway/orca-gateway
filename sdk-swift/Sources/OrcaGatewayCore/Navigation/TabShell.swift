import Foundation

/// One page on a stack of a `TabShell`: one page request (none for an error
/// entry, which is the "not found" screen).
public struct TabShellEntry: Equatable, Sendable {
    /// Unique within the shell, increasing in creation order; the first is 1.
    public let id: Int
    /// The resolution that created the entry.
    public let resolution: RouteResolution
    /// The page this entry requests: an element of `resolution.stack`. For
    /// an error entry, the location's path without its leading slash.
    public let pagePath: String
    /// The last page of its chain: the one that carries the resolution's
    /// location, `scaffoldTitle`, `transition` and "not found".
    public let isTop: Bool

    /// The location shown while this entry is on top: the resolution's for
    /// the top of a chain, the page path with a slash for a parent.
    public var location: String { isTop ? resolution.location : "/" + pagePath }
}

/// What one operation of a `TabShell` changed.
public struct TabShellChange: Equatable, Sendable {
    /// Entries created by the operation whose page is to be requested, in
    /// the order Flutter requests them (a chain bottom to top). An error
    /// entry requests nothing and is not listed.
    public let requested: [TabShellEntry]
    /// Entries that left every stack.
    public let dropped: [TabShellEntry]
    /// The `_tabIndex` value the caller must write into app state; nil: no
    /// write.
    public let tabIndexWrite: Int?

    public init(requested: [TabShellEntry], dropped: [TabShellEntry], tabIndexWrite: Int?) {
        self.requested = requested
        self.dropped = dropped
        self.tabIndexWrite = tabIndexWrite
    }
}

/// The page stacks of an app with tabs, as Flutter's
/// `StatefulShellRoute.indexedStack` and `OrcaShell` keep them
/// (sdk/lib/src/navigation/navigation_handler.dart,
/// sdk/lib/src/widgets/orca_shell.dart). Pure: no page is fetched and no
/// state is written; each operation says which entries are new, which are
/// gone and which `_tabIndex` the caller must write. The session fixtures
/// (schema/fixtures/navigation, files 12 to 14) are the spec.
///
/// - Each tab has its own stack, made on its first visit and kept while the
///   shell is mounted; showing a visited tab again requests nothing.
/// - `go` to a tab's route shows that tab with the route's page chain; the
///   entries the tab already has for the leading pages of the chain stay
///   and are not requested again. The kept entry that is the new top takes
///   the new resolution under its id (another query string changes the
///   location, not the page); a kept one that is no longer the top becomes
///   a parent.
/// - `go` to a route outside the tabs unmounts the shell: every tab stack is
///   forgotten. A `push` of such a route lies over the shell, which stays.
/// - `_tabIndex` is written when the shell is mounted and when the current
///   tab changes, never else.
/// - Without tabs in the config there is never a shell: `over` is the one
///   stack, `go` replaces it with the whole chain, `push` adds the top page.
public struct TabShell: Sendable {
    public let table: RouteTable
    /// A tab shell is mounted: the config has tabs and the last `go` landed
    /// in one.
    public private(set) var hasShell = false
    /// One stack per config tab, bottom to top; empty: not visited yet.
    public private(set) var tabStacks: [[TabShellEntry]]
    /// The tab on screen; nil when `hasShell` is false.
    public private(set) var currentTab: Int?
    /// Routes above the shell; with no shell the whole stack.
    public private(set) var over: [TabShellEntry] = []

    private var lastId = 0

    public init(table: RouteTable) {
        self.table = table
        tabStacks = Array(repeating: [], count: table.config.tabs.count)
    }

    /// The stack on screen bottom to top: the current tab's, then `over`.
    public var visible: [TabShellEntry] {
        (currentTab.map { tabStacks[$0] } ?? []) + over
    }

    /// The visible location, as the fixtures' `location`; empty before the
    /// first `go`.
    public var location: String { visible.last?.location ?? "" }

    /// As the fixtures' `tabIndex`: the shell's index, also under a pushed
    /// route; nil without a shell.
    public var tabIndex: Int? { currentTab }

    // MARK: - Operations

    /// Boot and replace (GoRouter `go`).
    public mutating func go(_ location: String, appState: [String: JSONValue]) -> TabShellChange {
        let resolution = table.resolve(Self.slashed(location), appState: appState)
        var dropped = over
        over = []

        guard resolution.kind == .page, let tab = resolution.tabIndex, tabStacks.indices.contains(tab) else {
            // Outside the tabs, or no route: the shell goes, with its stacks.
            dropped = tabStacks.flatMap { $0 } + dropped
            tabStacks = tabStacks.map { _ in [] }
            hasShell = false
            currentTab = nil
            over = entries(resolution)
            return TabShellChange(requested: over.filter { $0.resolution.kind == .page }, dropped: dropped,
                                  tabIndexWrite: nil)
        }

        // The tab keeps its entries for the leading pages of the chain: the
        // same page path at the same position. The kept top follows the new
        // resolution under its id; a kept former top becomes a parent.
        let old = tabStacks[tab]
        let chain = resolution.stack
        var kept = 0
        while kept < min(old.count, chain.count), old[kept].pagePath == chain[kept] { kept += 1 }
        var stack: [TabShellEntry] = old[..<kept].enumerated().map { index, entry in
            let isTop = index == chain.count - 1
            return TabShellEntry(id: entry.id, resolution: isTop ? resolution : entry.resolution,
                                 pagePath: entry.pagePath, isTop: isTop)
        }
        var requested: [TabShellEntry] = []
        for index in kept..<chain.count {
            requested.append(entry(resolution, chain[index], isTop: index == chain.count - 1))
        }
        stack += requested
        dropped = Array(old[kept...]) + dropped
        tabStacks[tab] = stack

        let write = !hasShell || currentTab != tab ? tab : nil
        hasShell = true
        currentTab = tab
        return TabShellChange(requested: requested, dropped: dropped, tabIndexWrite: write)
    }

    /// One more page over what is shown (GoRouter `push`): the top page of
    /// the location's chain. A tab's route, any tab's, goes on the current
    /// tab's stack; any other route, and every route while something lies
    /// over the shell or no shell is mounted, goes on `over`.
    public mutating func push(_ location: String, appState: [String: JSONValue]) -> TabShellChange {
        let resolution = table.resolve(Self.slashed(location), appState: appState)
        guard let top = entries(resolution).last else { return .none }
        if let tab = currentTab, over.isEmpty, resolution.kind == .page, resolution.tabIndex != nil {
            tabStacks[tab].append(top)
        } else {
            over.append(top)
        }
        return TabShellChange(requested: resolution.kind == .page ? [top] : [], dropped: [], tabIndexWrite: nil)
    }

    /// Pop the page on top: of `over` first, then of the current tab. Nothing
    /// at a root (a tab's first page, or the only page when no shell).
    public mutating func pop() -> TabShellChange {
        if let tab = currentTab {
            if let top = over.popLast() { return TabShellChange(requested: [], dropped: [top], tabIndexWrite: nil) }
            guard tabStacks[tab].count > 1 else { return .none }
            return TabShellChange(requested: [], dropped: [tabStacks[tab].removeLast()], tabIndexWrite: nil)
        }
        guard over.count > 1 else { return .none }
        return TabShellChange(requested: [], dropped: [over.removeLast()], tabIndexWrite: nil)
    }

    /// A tap on the tab bar (`goBranch`): another tab shows its stack as it
    /// was left, or its `initialRoute` on its first visit; the current tab
    /// pops to its root. What lies over the shell is dropped. No shell or an
    /// index out of range: no change.
    public mutating func selectTab(_ index: Int, appState: [String: JSONValue]) -> TabShellChange {
        guard hasShell, let current = currentTab, tabStacks.indices.contains(index) else { return .none }
        if tabStacks[index].isEmpty {
            return go(table.config.tabs[index].initialRoute, appState: appState)
        }
        var dropped = over
        over = []
        if index == current {
            dropped = Array(tabStacks[index].dropFirst()) + dropped
            tabStacks[index] = Array(tabStacks[index].prefix(1))
            return TabShellChange(requested: [], dropped: dropped, tabIndexWrite: nil)
        }
        currentTab = index
        return TabShellChange(requested: [], dropped: dropped, tabIndexWrite: index)
    }

    /// The `switchTab` action: `go` to the tab's `initialRoute`. An unknown
    /// id (always, without tabs): no change.
    public mutating func switchTab(_ tabId: String, appState: [String: JSONValue]) -> TabShellChange {
        guard let tab = table.config.tabs.first(where: { $0.id == tabId }) else { return .none }
        return go(tab.initialRoute, appState: appState)
    }

    /// App state `_tabIndex` was written by someone else: an int that is
    /// another tab's index shows that tab as a tap does. Anything else (not
    /// an int, the current index, out of range, no shell): no change.
    public mutating func tabIndexChanged(_ value: JSONValue?, appState: [String: JSONValue]) -> TabShellChange {
        guard hasShell, case .int(let index)? = value, index != currentTab else { return .none }
        return selectTab(index, appState: appState)
    }

    // MARK: - Entries

    private mutating func entry(_ resolution: RouteResolution, _ pagePath: String, isTop: Bool) -> TabShellEntry {
        lastId += 1
        return TabShellEntry(id: lastId, resolution: resolution, pagePath: pagePath, isTop: isTop)
    }

    /// Fresh entries for a resolution bottom to top: its page chain, or one
    /// error entry.
    private mutating func entries(_ resolution: RouteResolution) -> [TabShellEntry] {
        guard resolution.kind == .page, !resolution.stack.isEmpty else {
            let path = resolution.location.prefix { $0 != "?" && $0 != "#" }
            var trimmed = path
            while trimmed.hasPrefix("/") { trimmed = trimmed.dropFirst() }
            return [entry(resolution, String(trimmed), isTop: true)]
        }
        let last = resolution.stack.count - 1
        var out: [TabShellEntry] = []
        for (index, pagePath) in resolution.stack.enumerated() {
            out.append(entry(resolution, pagePath, isTop: index == last))
        }
        return out
    }

    private static func slashed(_ location: String) -> String {
        location.hasPrefix("/") ? location : "/" + location
    }
}

private extension TabShellChange {
    static let none = TabShellChange(requested: [], dropped: [], tabIndexWrite: nil)
}
