import { App, Flow, PageDefinition, ServerActionDefinition } from "../../engine/src/core";
import { V, TV, ServerAction } from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Container,
  Expanded,
  Icon,
  Padding,
  Row,
  SizedBox,
  Text,
  ReorderableListView,
  EdgeInsets,
} from "../../engine/src/components";

// Reorder demo (native parity, step 13): ORCA_APP_ID=reorder. One page, one
// ReorderableListView of five rows.
//
// The order lives in page state as a list (`order`). The five rows are fixed
// nodes; row i shows `order[i]` through the `at` transform, so a new list
// redraws every label. A drop fires `onReorder` with the event {oldIndex,
// newIndex}; the client never reorders by itself. The action sends both
// indices to `moveRow`, which reads the list from the page state the client
// posts with every server action and answers with a setState of the moved
// list. The server keeps nothing.

export const INITIAL_ORDER = ["Apples", "Bread", "Coffee", "Dates", "Eggs"] as const;

const grey = "#757575";

/**
 * `newIndex` is the client's raw value: the insertion index before the dragged
 * row is removed (the first of three rows dropped at the end gives 3). Null
 * when the indices do not fit the list.
 */
export function moveRow(order: readonly string[], oldIndex: number, newIndex: number): string[] | null {
  const inList = Number.isInteger(oldIndex) && oldIndex >= 0 && oldIndex < order.length;
  const isSlot = Number.isInteger(newIndex) && newIndex >= 0 && newIndex <= order.length;
  if (!inList || !isSlot) return null;
  const next = [...order];
  const [row] = next.splice(oldIndex, 1);
  next.splice(newIndex > oldIndex ? newIndex - 1 : newIndex, 0, row!);
  return next;
}

const moveRowAction = ServerActionDefinition.create({
  id: "moveRow",
  schema: {
    oldIndex: { type: "number", required: true },
    newIndex: { type: "number", required: true },
  },
  execute: (ctx) => {
    const order = ctx.pageState.order;
    if (!Array.isArray(order)) return [];
    const oldIndex = ctx.actionParams.oldIndex as number;
    const newIndex = ctx.actionParams.newIndex as number;
    const next = moveRow(order as string[], oldIndex, newIndex);
    if (!next) return [];
    return [
      { type: "setState" as const, scope: "page" as const, key: "order", value: next },
      { type: "setState" as const, scope: "page" as const, key: "lastMove", value: `${oldIndex} → ${newIndex}` },
    ];
  },
});

function row(index: number) {
  return Container.new({
    color: index % 2 === 0 ? "#FFFFFF" : "#F5F5F5",
    padding: EdgeInsets.symmetric({ horizontal: 16, vertical: 14 }),
    child: Row.new({
      children: [
        Icon.new({ name: "menu", size: 20, color: grey }),
        SizedBox.new({ width: 12 }),
        Text.new({
          data: V.transform(V.pageState("order"), [TV.at(index)]),
          style: { fontSize: 16 },
        }).withKey(`reorder-label-${index}`),
      ],
    }),
  }).withKey(`reorder-row-${index}`);
}

const homePage = PageDefinition.create({
  id: "home",
  title: "Reorder",
  state: [
    { key: "order", scope: "page", initial: [...INITIAL_ORDER] },
    { key: "lastMove", scope: "page", initial: "none yet" },
  ],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Reorder" }) }),
      body: Column.new({
        crossAxisAlignment: "stretch",
        children: [
          Padding.new({
            padding: EdgeInsets.all(16),
            child: Row.new({
              children: [
                Text.new({ data: "Last move (oldIndex → newIndex): ", style: { color: grey, fontSize: 14 } }),
                Text.new({ data: V.pageState("lastMove"), style: { fontSize: 14 } }).withKey("reorder-last"),
              ],
            }),
          }),
          Expanded.new({
            child: ReorderableListView.new({
              padding: EdgeInsets.only({ bottom: 16 }),
              children: INITIAL_ORDER.map((_, i) => row(i)),
              actions: {
                onReorder: ServerAction("moveRow", {
                  oldIndex: V.event("oldIndex"),
                  newIndex: V.event("newIndex"),
                }),
              },
            }).withKey("reorder-list"),
          }),
        ],
      }),
    }),
});

const reorderFlow = Flow.create({
  name: "reorder",
  routes: [{ path: "home", page: homePage }],
});

export const reorderApp = App.create({
  id: "reorder",
  name: "Reorder Demo",
  flows: [reorderFlow],
  actions: [moveRowAction],
  navigation: {
    initialRoute: "/home",
  },
});
