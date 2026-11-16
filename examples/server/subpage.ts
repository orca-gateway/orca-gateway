import { App, Flow, PageDefinition, ServerActionDefinition } from "../../engine/src/core";
import { V, SetState, ServerAction, UpdateSubPage } from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Container,
  Divider,
  ElevatedButton,
  Padding,
  Row,
  SingleChildScrollView,
  SizedBox,
  SubPage,
  Text,
  EdgeInsets,
} from "../../engine/src/components";

// SubPage demo (native parity, step 13): ORCA_APP_ID=subpage. A host page
// with a page embedded in it, by the contract of schema/fixtures/subpage.
//
// The host has a counter in page state named `count`. So has the embedded
// page `detail/<id>`, with another initial value: the client mounts it under
// the prefix `detail:`, so its `count` lives at `detail:count` and the two
// never meet. The SubPage sends the param `from`; the detail page reads it
// from the query string and shows it. "Add 10 on the server" inside the
// detail page posts only that page's own state (`count`, no prefix) and the
// setState it gets back lands on `detail:count` again.
//
// "Replace with B" swaps the mounted page for `detail/b`; "Join C" mounts
// `detail/c` below what is there, under `detail#1:`, with its own `count`.

export const DETAIL_COUNTS: Record<string, number> = { a: 10, b: 20, c: 30 };

const grey = "#757575";

const plusOne = (key: string) => SetState(key, V.transform(V.pageState(key), [{ type: "add", by: V.static(1) }]));

const counted = (label: string) => V.transform(V.pageState("count"), [{ type: "template", template: `${label}: {{value}}` }]);

const addTenAction = ServerActionDefinition.create({
  id: "addTen",
  execute: (ctx) => {
    // Fired inside the sub-page: `count` is the detail page's, not the host's.
    const count = ctx.pageState.count;
    if (typeof count !== "number") return [];
    return [{ type: "setState" as const, scope: "page" as const, key: "count", value: count + 10 }];
  },
});

export const detailPage = PageDefinition.create({
  id: "detail",
  title: "Detail",
  // One render per page id and per `from`: without the two fields a cached
  // render would serve every id and every param value.
  cachePolicy: { requestInfo: ["routeParams.id", "queryParams.from"] },
  state: (ctx) => [{ key: "count", scope: "page", initial: DETAIL_COUNTS[ctx.routeParams.id ?? ""] ?? 0 }],
  render: (ctx) => {
    const id = ctx.routeParams.id ?? "";
    const from = ctx.requestInfo.queryParams.from ?? "nobody";
    return Container.new({
      color: "#F5F5F5",
      padding: EdgeInsets.all(16),
      child: Column.new({
        crossAxisAlignment: "start",
        children: [
          Text.new({ data: `Detail ${id.toUpperCase()}`, style: { fontSize: 18, fontWeight: "bold" } }).withKey("title"),
          Text.new({ data: `Opened from: ${from}`, style: { color: grey, fontSize: 14 } }).withKey("from"),
          SizedBox.new({ height: 8 }),
          Text.new({ data: counted("Detail count"), style: { fontSize: 16 } }).withKey("count"),
          SizedBox.new({ height: 8 }),
          Row.new({
            children: [
              ElevatedButton.new({
                child: Text.new({ data: "+1" }),
                actions: { onTap: plusOne("count") },
              }).withKey("plus"),
              SizedBox.new({ width: 12 }),
              ElevatedButton.new({
                child: Text.new({ data: "Add 10 on the server" }),
                actions: { onTap: ServerAction("addTen") },
              }).withKey("add-ten"),
            ],
          }),
        ],
      }),
    }).withKey("detail-root");
  },
});

const homePage = PageDefinition.create({
  id: "home",
  title: "SubPage",
  state: [{ key: "count", scope: "page", initial: 0 }],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "SubPage" }) }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "stretch",
            children: [
              Text.new({ data: counted("Host count"), style: { fontSize: 16 } }).withKey("host-count"),
              SizedBox.new({ height: 8 }),
              ElevatedButton.new({
                child: Text.new({ data: "Host +1" }),
                actions: { onTap: plusOne("count") },
              }).withKey("host-plus"),
              SizedBox.new({ height: 8 }),
              ElevatedButton.new({
                child: Text.new({ data: "Replace with B" }),
                actions: { onTap: UpdateSubPage("detail", "detail/b", "replace", { from: V.static("Replace with B") }) },
              }).withKey("replace-b"),
              SizedBox.new({ height: 8 }),
              ElevatedButton.new({
                child: Text.new({ data: "Join C" }),
                actions: { onTap: UpdateSubPage("detail", "detail/c", "join", { from: V.static("Join C") }) },
              }).withKey("join-c"),
              Divider.new({}),
              SubPage.new({
                key: "detail",
                pageId: "detail/a",
                params: { from: V.static("the host page") },
              }),
            ],
          }),
        }),
      }),
    }),
});

const subPageFlow = Flow.create({
  name: "subpage",
  routes: [
    { path: "home", page: homePage },
    { path: "detail/:id", page: detailPage },
  ],
});

export const subPageApp = App.create({
  id: "subpage",
  name: "SubPage Demo",
  flows: [subPageFlow],
  actions: [addTenAction],
  navigation: {
    initialRoute: "/home",
  },
});
