import { App, Flow, PageDefinition } from "../../engine/src/core";
import { V, SetState, ShowSnackbar, Sequential } from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Row,
  Text,
  ElevatedButton,
  Center,
  SizedBox,
} from "../../engine/src/components";

// ── Home Page ─────────────────────────────────────────────

const homePage = PageDefinition.create({
  id: "home",
  title: "Counter",
  state: [{ key: "count", scope: "page", initial: 0 }],
  render: (_ctx, _info) =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Counter Example" }),
        centerTitle: true,
      }),
      body: Center.new({
        child: Column.new({
          mainAxisAlignment: "center",
          children: [
            Text.new({
              data: V.transform(V.pageState("count"), [{ type: "toString" }]),
              style: { fontSize: 48, fontWeight: "bold" },
            }),
            SizedBox.new({ height: 24 }),
            Row.new({
              mainAxisAlignment: "center",
              children: [
                ElevatedButton.new({
                  child: Text.new({ data: "-" }),
                  actions: {
                    onTap: SetState(
                      "count",
                      V.transform(V.pageState("count"), [
                        { type: "subtract", by: V.static(1) },
                      ]),
                    ),
                  },
                }),
                SizedBox.new({ width: 16 }),
                ElevatedButton.new({
                  child: Text.new({ data: "+" }),
                  actions: {
                    onTap: SetState(
                      "count",
                      V.transform(V.pageState("count"), [
                        { type: "add", by: V.static(1) },
                      ]),
                    ),
                  },
                }),
              ],
            }),
            SizedBox.new({ height: 16 }),
            ElevatedButton.new({
              child: Text.new({ data: "Reset" }),
              actions: {
                onTap: Sequential(
                  SetState("count", V.static(0)),
                  ShowSnackbar("Counter reset to 0"),
                ),
              },
            }),
          ],
        }),
      }),
    }),
});

// ── App ──────────────────────────────────────────────────

const homeFlow = Flow.create({
  name: "home",
  routes: [{ path: "home", page: homePage }],
});

export const counterApp = App.create({
  id: "counter",
  name: "Counter",
  flows: [homeFlow],
});
