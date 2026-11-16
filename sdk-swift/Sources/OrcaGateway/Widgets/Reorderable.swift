#if canImport(SwiftUI)
import SwiftUI

/// Flutter `ReorderableListView` (LB:686-716).
///
/// Vertical, the default: a plain SwiftUI `List` whose rows are the node's
/// children, drawn as anywhere else (no separator, no row inset, no row
/// background, no minimum row height). A row is dragged after a long press;
/// the drop runs `onReorder` with `{oldIndex, newIndex}` (`ReorderDrop`:
/// `newIndex` is Flutter's raw value), and nothing when the row stays where
/// it was. The list never moves a row itself: it draws the children the
/// page has, so the row returns unless the action changes the order. A
/// SwiftUI List keeps a dropped row where the finger left it when its data
/// did not move, so every drop gives the rows a new identity (`drops`) and
/// the List lays them out again in the children's order, scrolled where it
/// was.
///
/// Horizontal: a scrolling row of the children, with no drag (SwiftUI's
/// `onMove` is the vertical List's).
///
/// `padding` scrolls with the rows, as Flutter's: its top is above the
/// first row and its bottom below the last.
///
/// onScrollBegin, onScrolling and onScrollEnd fire as a
/// SingleChildScrollView's (`ScrollTriggers`): always when horizontal;
/// when vertical on iOS 18 / macOS 15 and later only, where a List reports
/// its scroll geometry and phase (the iOS 16-17 probe sits inside a
/// ScrollView's one content view, which a List does not have).
@MainActor
struct ReorderableListNodeView: View {
    let node: ResolvedNode
    let model: OrcaPageModel
    @Environment(\.layoutDirection) private var direction
    /// The drops so far: the rows' identity, new after each one.
    @State private var drops = 0

    var body: some View {
        if node["scrollDirection"]?.stringValue == "horizontal" {
            row
        } else {
            list
        }
    }

    /// What the List's `onMove` calls: the first moved row and SwiftUI's
    /// destination, the index to insert at before the row is removed, which
    /// is the drop slot. Runs `onReorder`; nil when nothing ran.
    @discardableResult
    func move(from source: IndexSet, to destination: Int) -> Task<Void, Never>? {
        guard let from = source.first,
              let event = ReorderDrop.event(from: from, slot: destination, count: node.childIds.count)
        else { return nil }
        return model.fire("onReorder", on: node, eventData: event)
    }

    private var watched: Bool {
        node.actions.keys.contains(where: ScrollEvent.triggers.contains)
    }

    // MARK: vertical

    @ViewBuilder
    private var list: some View {
        if watched, ScrollNodeView.phased {
            plainList.modifier(ScrollTriggers(node: node, model: model, horizontal: false, reverse: false,
                                              phased: true))
        } else {
            plainList
        }
    }

    private var plainList: some View {
        let ids = node.childIds
        let padding = Props.insets(node["padding"], direction: direction)
        return List {
            ForEach(ids, id: \.self) { id in
                NodeView(id: id, model: model)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: id == ids.first ? padding.top : 0, leading: padding.leading,
                                        bottom: id == ids.last ? padding.bottom : 0, trailing: padding.trailing))
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onMove { source, destination in
                move(from: source, to: destination)
                drops += 1
            }
            .id(drops)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        // A row is as wide as the list, as a Flutter list's child.
        .environment(\.orcaTight, .horizontal)
    }

    // MARK: horizontal

    @ViewBuilder
    private var row: some View {
        if watched {
            let triggers = ScrollTriggers(node: node, model: model, horizontal: true, reverse: false,
                                          phased: ScrollNodeView.phased)
            if triggers.phased {
                ScrollView(.horizontal) { rowContent }.modifier(triggers)
            } else {
                ScrollView(.horizontal) { ScrollTriggers.probe(rowContent) }.modifier(triggers)
            }
        } else {
            ScrollView(.horizontal) { rowContent }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            ForEach(node.childIds, id: \.self) { NodeView(id: $0, model: model) }
        }
        .environment(\.orcaTight, [])
        .orcaPadding(node["padding"])
    }
}
#endif
