import { App, Flow, PageDefinition } from "../../engine/src/core";
import {
  Scaffold,
  Center,
  Container,
  CustomScrollView,
  Icon,
  Padding,
  SliverAppBar,
  SliverGrid,
  SliverList,
  SliverToBoxAdapter,
  Text,
  EdgeInsets,
} from "../../engine/src/components";
import type { SliverAppBarProps } from "../../engine/src/components/structure/sliver-app-bar";
import type { MaterialIcons } from "../../engine/src/types/icons";

// Slivers demo (native parity, step 13): ORCA_APP_ID=slivers. Three tabs, so
// no route is wrapped in a second bar: each page is one CustomScrollView and
// its only bar is the SliverAppBar, the first sliver.
//
//   Pinned    /pinned    pinned, expandedHeight 200: shrinks to the toolbar and stays
//   Floating  /floating  floating, no expandedHeight: leaves, comes back on a reverse scroll
//   Plain     /plain     neither, expandedHeight 120: scrolls away with the content
//
// Below the bar the three pages are the same (`content`): a heading in a
// SliverToBoxAdapter, a SliverGrid of 6 cells (3 across, spacing 8, ratio
// 1.5), a SliverList of 40 rows of one height, and a closing SliverToBoxAdapter.
// Nothing here has state: the pages only scroll.

export const GRID_CELLS = 6;
export const LIST_ROWS = 40;
export const ROW_HEIGHT = 48;

const white = "#FFFFFF";
const grey = "#757575";
const CELL_COLORS = ["#1976D2", "#388E3C", "#F57C00", "#7B1FA2", "#C2185B", "#00796B"];

interface Variant {
  id: string;
  label: string;
  icon: MaterialIcons;
  /** The colour of the bar's flexibleSpace. */
  color: string;
  bar: Pick<SliverAppBarProps, "pinned" | "floating" | "expandedHeight">;
}

const VARIANTS: Variant[] = [
  { id: "pinned", label: "Pinned", icon: "star", color: "#1976D2", bar: { pinned: true, expandedHeight: 200 } },
  { id: "floating", label: "Floating", icon: "arrow_downward", color: "#388E3C", bar: { floating: true } },
  { id: "plain", label: "Plain", icon: "list", color: "#F57C00", bar: { expandedHeight: 120 } },
];

function bar(v: Variant) {
  return SliverAppBar.new({
    ...v.bar,
    title: Text.new({ data: v.label }).withKey(`${v.id}-title`),
    flexibleSpace: Container.new({ color: v.color }).withKey(`${v.id}-space`),
    actions: [Icon.new({ name: "info", color: white }).withKey(`${v.id}-action`)],
  }).withKey(`${v.id}-bar`);
}

function cell(id: string, n: number) {
  return Container.new({
    color: CELL_COLORS[(n - 1) % CELL_COLORS.length]!,
    child: Center.new({
      child: Text.new({ data: `${n}`, style: { color: white, fontSize: 18, fontWeight: "bold" } }).withKey(
        `${id}-cell-label-${n}`,
      ),
    }),
  }).withKey(`${id}-cell-${n}`);
}

function row(id: string, n: number) {
  return Container.new({
    height: ROW_HEIGHT,
    color: n % 2 === 0 ? "#F5F5F5" : white,
    padding: EdgeInsets.symmetric({ horizontal: 16 }),
    alignment: "centerLeft",
    child: Text.new({ data: `Row ${n}`, style: { fontSize: 16 } }).withKey(`${id}-row-label-${n}`),
  }).withKey(`${id}-row-${n}`);
}

/** The slivers under the bar, the same on every tab. `id` prefixes the node keys. */
function content(id: string) {
  return [
    SliverToBoxAdapter.new({
      child: Padding.new({
        padding: EdgeInsets.all(16),
        child: Text.new({
          data: `${GRID_CELLS} grid cells, then ${LIST_ROWS} rows`,
          style: { fontSize: 18, fontWeight: "bold" },
        }).withKey(`${id}-heading`),
      }),
    }).withKey(`${id}-heading-box`),
    SliverGrid.new({
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      children: Array.from({ length: GRID_CELLS }, (_, i) => cell(id, i + 1)),
    }).withKey(`${id}-grid`),
    SliverList.new({
      children: Array.from({ length: LIST_ROWS }, (_, i) => row(id, i + 1)),
    }).withKey(`${id}-list`),
    SliverToBoxAdapter.new({
      child: Padding.new({
        padding: EdgeInsets.all(24),
        child: Center.new({
          child: Text.new({ data: "End of list", style: { color: grey, fontSize: 14 } }).withKey(`${id}-end`),
        }),
      }),
    }).withKey(`${id}-end-box`),
  ];
}

function page(v: Variant) {
  return PageDefinition.create({
    id: v.id,
    title: v.label,
    render: () =>
      Scaffold.new({
        body: CustomScrollView.new({ slivers: [bar(v), ...content(v.id)] }).withKey(`${v.id}-scroll`),
      }),
  });
}

const flows = VARIANTS.map((v) =>
  Flow.create({
    name: v.id,
    routes: [{ path: v.id, page: page(v) }],
  }),
);

export const sliversApp = App.create({
  id: "slivers",
  name: "Slivers Demo",
  flows,
  navigation: {
    initialRoute: "/pinned",
    initialAppState: { _tabIndex: 0 },
    tabs: VARIANTS.map((v) => ({ id: v.id, label: v.label, icon: v.icon, initialRoute: `/${v.id}` })),
  },
});
