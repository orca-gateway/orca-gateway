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
                model: model)
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

/// The SubPage of a live page. The controller lives as long as this view
/// does, through redraws and while another page covers it: the fetch starts
/// when the view first appears and again only when the request changes, and
/// the pages are unmounted when the view is gone for good.
@MainActor
private struct LiveSubPage: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @StateObject private var controller: SubPageController

    init(node: ResolvedNode, model: OrcaPageModel) {
        self.node = node
        self.model = model
        _controller = StateObject(wrappedValue: SubPageController(key: node.id, model: model))
    }

    var body: some View {
        let request = SubPageNodeView.request(of: node)
        SubPageContent(drawing: controller.drawing(childId: node.childIds.first), model: model)
            .onAppear { controller.want(request) }
            .onChange(of: request) { controller.want($0) }
    }
}

@MainActor
private struct SubPageContent: View {
    let drawing: SubPageDrawing
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
            // One page draws exactly as its root.
            if roots.count == 1 {
                NodeView(id: roots[0], model: model).id(roots[0])
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(roots, id: \.self) { NodeView(id: $0, model: model) }
                }
            }
        }
    }
}

/// The state of one SubPage view: whether its first fetch is still out, why
/// its own fetch failed, and which fetch is the latest. The pages themselves
/// are in the page model's registry.
@MainActor
final class SubPageController: ObservableObject {
    /// Id of the SubPage node.
    let key: String
    /// Names this controller to the page model once it is gone.
    nonisolated let token = UUID()
    private weak var model: OrcaPageModel?
    /// True until a first page is mounted or the first fetch fails.
    @Published private var loading = true
    /// Why the widget's own fetch failed; drawn in the place of the pages.
    @Published private var failure: String?
    /// Bumped when the mounted pages change.
    @Published private var revision = 0
    /// The request of the node, as last asked for.
    private var request: SubPageRequest?
    /// Counts the fetches started for the node's own request; an answer that
    /// is no longer the latest, or that an updateSubPage overtook, is dropped.
    private var load = 0
    /// The fetch for the node's own request, cancelled by a newer one and
    /// when the view is gone.
    private var fetch: Task<Void, Never>?

    init(key: String, model: OrcaPageModel) {
        self.key = key
        self.model = model
    }

    deinit {
        fetch?.cancel()
        // S8: the nodes leave the store, the state keys stay.
        Task { @MainActor [weak model, key, token] in model?.subPageLeft(key, token: token) }
    }

    func drawing(childId: String?) -> SubPageDrawing {
        if loading { return childId.map(SubPageDrawing.child) ?? .spinner }
        if let failure { return .error("SubPage error: \(failure)") }
        return .pages(model?.subPages[key]?.roots ?? [])
    }

    /// The view is on screen asking for `next` (contract S4): fetch it, as a
    /// replace, unless it is what was last asked for. What is mounted stays
    /// on screen while the fetch runs.
    func want(_ next: SubPageRequest) {
        guard let model, !model.isInert else { return }
        model.subPageAppeared(self)
        guard next != request else { return }
        request = next
        load += 1
        let mine = load
        fetch?.cancel()
        fetch = Task { [weak self] in
            do {
                let page = try await model.fetchSubPage(next)
                guard let self, !Task.isCancelled, mine == self.load else { return }
                try self.mount(page, mode: "replace", in: model)
            } catch {
                guard let self, !Task.isCancelled, mine == self.load else { return }
                self.loading = false
                self.failure = error.localizedDescription
            }
        }
    }

    /// The updateSubPage action (contract S7). The old content stays while
    /// the fetch runs; an error leaves it and is thrown to the action chain.
    func update(_ next: SubPageRequest, mode: String) async throws {
        guard let model else { return }
        let page = try await model.fetchSubPage(next)
        // Gone, or replaced by another view of the same SubPage, meanwhile.
        guard model.subPageView(key) === self else { return }
        // The update wins over a fetch of the node's own that is still out.
        load += 1
        try mount(page, mode: mode, in: model)
    }

    private func mount(_ page: PageResponse, mode: String, in model: OrcaPageModel) throws {
        try model.mountSubPage(key, mode: mode, page: page)
        loading = false
        failure = nil
        revision += 1
    }
}
#endif
