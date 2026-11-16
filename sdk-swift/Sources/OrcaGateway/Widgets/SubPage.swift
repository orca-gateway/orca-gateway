#if canImport(SwiftUI)
import SwiftUI

/// What a SubPage draws (contract S5 of schema/fixtures/subpage/README.md).
enum SubPageDrawing: Equatable {
    /// The first fetch is running and the node has a child: that child.
    case child(String)
    /// The first fetch is running and there is no child.
    case spinner
    /// The widget's own fetch failed: this text.
    case error(String)
    /// The root of each mounted page, oldest first, one below the other.
    case pages([String])
}

/// A page embedded in the page (Flutter `OrcaSubPageWidget`). The rules are
/// the core's (`SubPage`, `SubPageRegistry`); this view fetches, hands the
/// answer to the page model and draws the mounted pages. Their nodes live in
/// the host page's node store and their state in its page state, under the
/// prefix of each page, so they are drawn by the same views as any node.
///
/// In a frozen copy (an AnimatedSwitcher's outgoing child) it fetches
/// nothing and draws the pages it had.
@MainActor
struct SubPageNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel

    var body: some View {
        if model.isInert {
            let roots = Self.frozenRoots(of: node.id, in: model)
            SubPageContent(
                drawing: roots.isEmpty ? node.childIds.first.map(SubPageDrawing.child) ?? .pages([]) : .pages(roots),
                identities: roots, model: model)
        } else {
            LiveSubPage(node: node, model: model)
        }
    }

    /// The roots a SubPage was drawing when its frozen copy was taken.
    static func frozenRoots(of id: String, in model: OrcaPageModel) -> [String] {
        model.frozenSubPageRoots[id] ?? []
    }

    /// The fetch a SubPage node asks for: its resolved `pageId` and `params`.
    static func request(of node: ResolvedNode) -> SubPageRequest {
        SubPage.request(pageId: node["pageId"]?.stringValue ?? "", params: node["params"]?.objectValue)
    }
}

/// The SubPage of a live page. Its controller is the page model's, one per
/// SubPage node for as long as that node is in the page (`subPage`), so it
/// outlives this view: a view built again for the same node (a list row
/// given a new identity, a page shown again) draws what is mounted and
/// fetches only when the request is not the one last asked for.
@MainActor
private struct LiveSubPage: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @ObservedObject private var controller: SubPageController

    init(node: ResolvedNode, model: OrcaPageModel) {
        self.node = node
        self.model = model
        controller = model.subPage(node.id)
    }

    var body: some View {
        let request = SubPageNodeView.request(of: node)
        SubPageContent(
            drawing: controller.drawing(childId: node.childIds.first), identities: controller.identities,
            model: model)
            .onAppear { controller.want(request) }
            .onChange(of: request) { controller.want($0) }
    }
}

/// Draws a `SubPageDrawing`. Each page is a view of its own under its entry
/// of `identities` (one per root): a new identity is a new view, with fresh
/// state, and a kept one keeps its view when a page joins.
@MainActor
private struct SubPageContent: View {
    let drawing: SubPageDrawing
    let identities: [String]
    let model: OrcaPageModel

    var body: some View {
        switch drawing {
        case .child(let id):
            NodeView(id: id, model: model)
        case .spinner:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .error(let text):
            Text(text)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .pages(let roots):
            // One stack for one page and for several, so the first page
            // keeps its views when another joins. Around one page the stack
            // is that page: it takes what the page is offered and has its size.
            let pages = Array(zip(identities, roots))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(pages, id: \.0) { _, root in
                    NodeView(id: root, model: model).modifier(JoinedPage(joined: pages.count > 1))
                }
            }
        }
    }
}

/// A page among several takes the width the SubPage has, as a child of
/// Flutter's `Column(crossAxisAlignment: stretch)`: its root is forced to
/// that width (`orcaTight`), and one that does not fill it sits at the start.
/// A page alone is left as it is.
private struct JoinedPage: ViewModifier {
    let joined: Bool
    @Environment(\.orcaTight) private var tight

    func body(content: Content) -> some View {
        content
            .environment(\.orcaTight, joined ? .horizontal : tight)
            .frame(maxWidth: joined ? .infinity : nil, alignment: .leading)
    }
}

/// What one SubPage node holds while it is in its page, besides its mounted
/// pages (those are in the page model's registry): whether its first fetch
/// is still out, why its own fetch failed, what it last asked for and which
/// fetch is the latest. The page model keeps it by node id and drops it when
/// the node leaves (Kotlin's `SubPageSlot`).
@MainActor
final class SubPageController: ObservableObject {
    /// Id of the SubPage node.
    let key: String
    private weak var model: OrcaPageModel?
    /// True until a first page is mounted or the first fetch fails.
    @Published private var loading = true
    /// Why the widget's own fetch failed; drawn in the place of the pages.
    @Published private var failure: String?
    /// Bumped when the mounted pages change.
    @Published private var revision = 0
    /// Counts the mounts that are not a join. It is part of the identity of
    /// each drawn page, so a page that replaces another gets views of its
    /// own: nothing of the old page (a nested SubPage, an animation
    /// controller, a text field's text) carries over, even with the same ids.
    private var generation = 0
    /// The request of the node, as last asked for.
    private var request: SubPageRequest?
    /// Counts the fetches started for the node's own request; an answer that
    /// is no longer the latest, or that an updateSubPage overtook, is dropped.
    private var load = 0
    /// The fetch for the node's own request, cancelled by a newer one and
    /// when the node leaves the page.
    private var fetch: Task<Void, Never>?

    init(key: String, model: OrcaPageModel) {
        self.key = key
        self.model = model
    }

    /// The node left the page: its fetch is of no use.
    func cancel() {
        fetch?.cancel()
    }

    func drawing(childId: String?) -> SubPageDrawing {
        if loading { return childId.map(SubPageDrawing.child) ?? .spinner }
        if let failure { return .error("SubPage error: \(failure)") }
        return .pages(model?.subPages[key]?.roots ?? [])
    }

    /// The identity of each drawn page, in the order of the drawing's roots:
    /// the count of replaces, then the page's prefix.
    var identities: [String] {
        (model?.subPages[key]?.pages ?? []).filter { $0.rootId != nil }.map { "\(generation)/\($0.prefix)" }
    }

    /// The message of a failed fetch, as Kotlin draws it (Flutter prints the
    /// same text after its exception's name): `Failed to fetch page: <status>`
    /// for a status other than 200.
    static func message(of error: Error) -> String {
        if case OrcaClientError.http(let status, _) = error { return "Failed to fetch page: \(status)" }
        return error.localizedDescription
    }

    /// Whether this is still the controller of a SubPage of the page: its
    /// node is in the store and the page it was in has not been replaced by
    /// one with the same ids (whose SubPage has a controller of its own).
    private func isCurrent(in model: OrcaPageModel) -> Bool {
        model.subPageView(key) === self
    }

    /// A view of the node is on screen asking for `next` (contract S4):
    /// fetch it, as a replace, unless it is what was last asked for, by this
    /// view or one before it. What is mounted stays on screen while the
    /// fetch runs.
    func want(_ next: SubPageRequest) {
        guard let model, !model.isInert, isCurrent(in: model), next != request else { return }
        request = next
        load += 1
        let mine = load
        fetch?.cancel()
        fetch = Task { [weak self] in
            do {
                let page = try await model.fetchSubPage(next)
                guard let self, !Task.isCancelled, mine == self.load, self.isCurrent(in: model) else { return }
                try self.mount(page, mode: "replace", in: model)
            } catch {
                guard let self, !Task.isCancelled, mine == self.load, self.isCurrent(in: model) else { return }
                self.loading = false
                self.failure = Self.message(of: error)
            }
        }
    }

    /// The updateSubPage action (contract S7). The old content stays while
    /// the fetch runs; an error leaves it and is thrown to the action chain.
    func update(_ next: SubPageRequest, mode: String) async throws {
        guard let model else { return }
        let page = try await model.fetchSubPage(next)
        // The node left the page meanwhile.
        guard isCurrent(in: model) else { return }
        // The update wins over a fetch of the node's own that is still out.
        load += 1
        try mount(page, mode: mode, in: model)
    }

    private func mount(_ page: PageResponse, mode: String, in model: OrcaPageModel) throws {
        // Page 0 is only ever mounted by a replace; a join mounts `K#j:`.
        if try model.mountSubPage(key, mode: mode, page: page) == SubPage.prefix(key: key) { generation += 1 }
        loading = false
        failure = nil
        revision += 1
    }
}
#endif
