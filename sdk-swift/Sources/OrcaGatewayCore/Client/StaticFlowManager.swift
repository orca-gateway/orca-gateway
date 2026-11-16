import Foundation

/// The offline cache of static flows, a port of Flutter's `StaticFlowManager`
/// (sdk/lib/src/client/static_flow_manager.dart) over any KeyValueStore, with
/// Flutter's keys: `orca_nav_config` (the /config body text),
/// `orca_flow_versions` (`{flow: version}` JSON) and `orca_pages_<flow>`
/// (`{path: page}` JSON). Pages, versions and the dynamic paths are mirrored
/// in memory, as in Flutter.
///
/// Where it differs from Dart: every save has landed when the call returns
/// (Flutter does not await them; the store ends the same), and `clearAll`
/// finds the flows to clear from memory, the saved versions and the saved
/// config, since a KeyValueStore cannot list its keys. Thread-safe.
public final class StaticFlowManager: @unchecked Sendable {
    static let configKey = "orca_nav_config"
    static let versionsKey = "orca_flow_versions"
    static let pagesPrefix = "orca_pages_"

    private let store: KeyValueStore
    private let lock = NSLock()
    private var pageCache: [String: [String: PageResponse]] = [:]
    private var versionsCache: [String: Int]?
    private var dynamicPaths: Set<String>?

    /// A cache over `store`; a new one over the same store is a restart.
    public init(store: KeyValueStore) {
        self.store = store
    }

    /// Keep the route paths of the dynamic routes of `flows`' static flows
    /// (children included, no leading slash), which `getCachedPage` never
    /// serves. Call once the boot has its config.
    public func initDynamicPaths(_ flows: [NavFlow]) {
        var paths: Set<String> = []
        for flow in flows where flow.isStatic { Self.collectDynamicPaths(flow.routes, into: &paths) }
        locked { dynamicPaths = paths }
    }

    private static func collectDynamicPaths(_ routes: [NavRoute], into out: inout Set<String>) {
        for route in routes {
            if route.isDynamic { out.insert(route.path.hasPrefix("/") ? String(route.path.dropFirst()) : route.path) }
            if !route.children.isEmpty { collectDynamicPaths(route.children, into: &out) }
        }
    }

    /// Save the /config body text as the server sent it.
    public func saveConfigRaw(_ rawJson: String) {
        store.set(rawJson, forKey: Self.configKey)
    }

    /// The saved config, decoded, with the saved text as its `rawBody`; nil
    /// when none is saved. Throws when the saved text does not decode.
    public func loadConfig() throws -> NavConfig? {
        guard let raw = store.string(forKey: Self.configKey) else { return nil }
        var config = try JSONValue.decode(Data(raw.utf8)).decode(NavConfig.self)
        config.rawBody = raw
        return config
    }

    /// The saved flow versions, from memory once read; empty when none are
    /// saved. Throws when the saved text does not decode.
    public func getLocalVersions() throws -> [String: Int] {
        try locked { try readVersions() }
    }

    /// The saved page for `path` (a route path, no leading slash) in the
    /// static flows among `flows`, memory first, then the store; nil for a
    /// dynamic path and for a path no static flow saved. The pages inside
    /// `flows` are never read. Throws when saved pages do not decode.
    public func getCachedPage(_ path: String, flows: [NavFlow]) throws -> PageResponse? {
        try locked {
            if dynamicPaths?.contains(path) == true { return nil }
            for flow in flows where flow.isStatic {
                if let page = try loadFlowPages(flow.name)?[path] { return page }
            }
            return nil
        }
    }

    /// Save what a fetched config holds for offline use: the pages of each
    /// static flow, the version of each flow that has one (replacing the saved
    /// versions), and remove the pages of a flow in the saved versions that is
    /// gone from `config`.
    public func cacheStaticFlows(_ config: NavConfig) {
        locked {
            var current: Set<String> = []
            var versions: [String: Int] = [:]
            for flow in config.flows {
                current.insert(flow.name)
                if let version = flow.version { versions[flow.name] = version }
                if flow.isStatic, let pages = flow.pages { saveFlowPages(flow.name, pages) }
            }
            for old in ((try? readVersions()) ?? [:]).keys where !current.contains(old) {
                pageCache[old] = nil
                store.set(nil, forKey: Self.pagesPrefix + old)
            }
            versionsCache = versions
            if let text = try? Self.text(.object(versions.mapValues { .int($0) })) {
                store.set(text, forKey: Self.versionsKey)
            }
        }
    }

    /// Remove the saved config, versions and pages, and empty memory.
    public func clearAll() {
        locked {
            var flows = Set(pageCache.keys)
            flows.formUnion(saved(Self.versionsKey)?.objectValue?.keys.map { $0 } ?? [])
            flows.formUnion((saved(Self.configKey)?["flows"].arrayValue ?? []).compactMap { $0["name"].stringValue })
            pageCache = [:]
            versionsCache = nil
            dynamicPaths = nil
            for flow in flows { store.set(nil, forKey: Self.pagesPrefix + flow) }
            store.set(nil, forKey: Self.configKey)
            store.set(nil, forKey: Self.versionsKey)
        }
    }

    // MARK: With the lock held

    private func readVersions() throws -> [String: Int] {
        if let versionsCache { return versionsCache }
        guard let raw = store.string(forKey: Self.versionsKey) else { return [:] }
        let versions = try JSONValue.decode(Data(raw.utf8)).decode([String: Int].self)
        versionsCache = versions
        return versions
    }

    private func saveFlowPages(_ flow: String, _ pages: [String: PageResponse]) {
        pageCache[flow] = pages
        guard let tree = try? pages.mapValues({ try JSONValue(encoding: $0) }),
              let text = try? Self.text(.object(tree))
        else { return }
        store.set(text, forKey: Self.pagesPrefix + flow)
    }

    private func loadFlowPages(_ flow: String) throws -> [String: PageResponse]? {
        if let pages = pageCache[flow] { return pages }
        guard let raw = store.string(forKey: Self.pagesPrefix + flow) else { return nil }
        let pages = try JSONValue.decode(Data(raw.utf8)).decode([String: PageResponse].self)
        pageCache[flow] = pages
        return pages
    }

    /// The JSON saved under `key`, or nil when absent or not JSON.
    private func saved(_ key: String) -> JSONValue? {
        store.string(forKey: key).flatMap { try? JSONValue.decode(Data($0.utf8)) }
    }

    private static func text(_ json: JSONValue) throws -> String {
        String(decoding: try json.encoded(), as: UTF8.self)
    }

    /// NSLock.withLock is missing from older Linux Foundation releases.
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
