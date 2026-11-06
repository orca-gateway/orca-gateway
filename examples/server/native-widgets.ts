import { App, Flow, PageDefinition } from "../../engine/src/core";
import { V, Expr, SetState, ShowToast } from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Row,
  Text,
  SizedBox,
  Padding,
  SingleChildScrollView,
  Container,
  Expanded,
  Spacer,
  Icon,
  Image,
  TextField,
  Stack,
  Positioned,
  ClipRRect,
  GestureDetector,
  EdgeInsets,
} from "../../engine/src/components";

// Native widgets demo (Epic 23b, S4). One page that uses every widget the
// iOS SDK gained in S4 (Icon, Image, Container, Expanded, Spacer, TextField,
// Stack, Positioned, ClipRRect, GestureDetector) in a food-delivery card, so
// the same page can be compared on Flutter and iOS. Images come from
// picsum.photos; offline they draw "!" in their box.

const orange = "#FF5722";
const grey = "#757575";

function sectionTitle(text: string) {
  return Text.new({ data: text, style: { fontSize: 18, fontWeight: "bold" } });
}

function foodCard(opts: {
  id: string;
  name: string;
  image: string;
  rating: string;
  minutes: string;
  price: string;
  badge: string;
}) {
  const favKey = `fav_${opts.id}`;
  return Container.new({
    margin: EdgeInsets.only({ bottom: 16 }),
    decoration: {
      color: "#FFFFFF",
      borderRadius: 16,
      boxShadow: [{ color: "#0000001F", blurRadius: 12, offset: { dx: 0, dy: 4 } }],
    },
    child: Column.new({
      crossAxisAlignment: "stretch",
      children: [
        Stack.new({
          children: [
            ClipRRect.new({
              borderRadius: { topLeft: 16, topRight: 16, bottomLeft: 0, bottomRight: 0 },
              child: Image.new({ src: opts.image, height: 160, fit: "cover", alt: opts.name }),
            }),
            Positioned.new({
              top: 12,
              right: 12,
              child: Container.new({
                padding: EdgeInsets.symmetric({ horizontal: 8, vertical: 4 }),
                decoration: { color: orange, borderRadius: 8 },
                child: Text.new({
                  data: opts.badge,
                  style: { color: "#FFFFFF", fontSize: 12, fontWeight: "bold" },
                }),
              }),
            }),
            Positioned.new({
              top: 12,
              left: 12,
              child: GestureDetector.new({
                actions: {
                  onTap: SetState(favKey, V.when([{ when: Expr.eq(V.pageState(favKey), true), then: V.static(false) }], V.static(true))),
                  onLongPress: ShowToast(`${opts.name}: long press`),
                },
                child: Container.new({
                  width: 36,
                  height: 36,
                  alignment: "center",
                  decoration: { color: "#FFFFFF", borderRadius: 18 },
                  child: Icon.new({
                    name: V.when([{ when: Expr.eq(V.pageState(favKey), true), then: V.static("favorite") }], V.static("favorite_border")),
                    color: orange,
                    size: 20,
                  }),
                }),
              }),
            }),
          ],
        }),
        Padding.new({
          padding: EdgeInsets.all(12),
          child: Column.new({
            crossAxisAlignment: "stretch",
            children: [
              Row.new({
                children: [
                  Expanded.new({
                    child: Text.new({
                      data: opts.name,
                      style: { fontSize: 16, fontWeight: "bold" },
                      maxLines: 1,
                    }),
                  }),
                  Icon.new({ name: "star", color: "#FFC107", size: 16 }),
                  SizedBox.new({ width: 4 }),
                  Text.new({ data: opts.rating }),
                ],
              }),
              SizedBox.new({ height: 8 }),
              Row.new({
                children: [
                  Icon.new({ name: "access_time", color: grey, size: 16 }),
                  SizedBox.new({ width: 4 }),
                  Text.new({ data: opts.minutes, style: { color: grey } }),
                  Spacer.new(),
                  Text.new({ data: opts.price, style: { fontSize: 16, fontWeight: "bold", color: orange } }),
                ],
              }),
            ],
          }),
        }),
      ],
    }),
  });
}

const homePage = PageDefinition.create({
  id: "home",
  title: "Native Widgets",
  state: [
    { key: "query", scope: "page", initial: "" },
    { key: "fav_pizza", scope: "page", initial: false },
    { key: "fav_bowl", scope: "page", initial: true },
  ],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Native Widgets" }), centerTitle: true }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "stretch",
            children: [
              // Search: Container + Icon + Expanded(TextField), two-way state.
              Container.new({
                padding: EdgeInsets.symmetric({ horizontal: 12, vertical: 10 }),
                decoration: { color: "#F2F2F2", borderRadius: 12 },
                child: Row.new({
                  children: [
                    Icon.new({ name: "search", size: 20, color: grey }),
                    SizedBox.new({ width: 8 }),
                    Expanded.new({
                      child: TextField.new({
                        placeholder: "Search dishes",
                        value: V.pageState("query"),
                        actions: { onChange: SetState("query", V.event("value")) },
                      }),
                    }),
                  ],
                }),
              }),
              SizedBox.new({ height: 8 }),
              Text.new({
                data: V.transform(V.pageState("query"), [{ type: "template", template: "You typed: {{value}}" }]),
                style: { color: grey, fontSize: 12 },
              }),
              SizedBox.new({ height: 16 }),
              sectionTitle("Popular near you"),
              SizedBox.new({ height: 12 }),
              foodCard({
                id: "pizza",
                name: "Margherita Pizza",
                image: "https://picsum.photos/seed/orca-pizza/800/480",
                rating: "4.8",
                minutes: "25 min",
                price: "$12.50",
                badge: "20% OFF",
              }),
              foodCard({
                id: "bowl",
                name: "Salmon Poke Bowl",
                image: "https://picsum.photos/seed/orca-bowl/800/480",
                rating: "4.6",
                minutes: "15 min",
                price: "$14.00",
                badge: "NEW",
              }),
              sectionTitle("Flex"),
              SizedBox.new({ height: 8 }),
              // Expanded flex 1 : 2, then a Spacer pushing a label right.
              Row.new({
                children: [
                  Expanded.new({
                    flex: 1,
                    child: Container.new({
                      height: 40,
                      alignment: "center",
                      decoration: { color: "#FFE0B2", borderRadius: 8 },
                      child: Text.new({ data: "flex 1" }),
                    }),
                  }),
                  SizedBox.new({ width: 8 }),
                  Expanded.new({
                    flex: 2,
                    child: Container.new({
                      height: 40,
                      alignment: "center",
                      decoration: {
                        borderRadius: 8,
                        gradient: { colors: ["#FF5722", "#FFC107"], begin: "centerLeft", end: "centerRight" },
                      },
                      child: Text.new({ data: "flex 2", style: { color: "#FFFFFF" } }),
                    }),
                  }),
                ],
              }),
              SizedBox.new({ height: 8 }),
              Row.new({
                children: [
                  Text.new({ data: "Left" }),
                  Spacer.new(),
                  Text.new({ data: "Spacer pushes this right" }),
                ],
              }),
              SizedBox.new({ height: 16 }),
              GestureDetector.new({
                actions: {
                  onTap: ShowToast("Tapped"),
                  onDoubleTap: ShowToast("Double tapped"),
                },
                child: Container.new({
                  padding: EdgeInsets.all(16),
                  decoration: { borderRadius: 12, border: { color: orange, width: 1 } },
                  child: Text.new({ data: "Tap or double tap this box", textAlign: "center" }),
                }),
              }),
            ],
          }),
        }),
      }),
    }),
});

const widgetsFlow = Flow.create({
  name: "widgets",
  routes: [{ path: "home", page: homePage }],
});

export const nativeWidgetsApp = App.create({
  id: "native-widgets",
  name: "Native Widgets",
  flows: [widgetsFlow],
});
