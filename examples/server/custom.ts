import { App, Flow, PageDefinition } from "../../engine/src/core";
import {
  V,
  Expr,
  SetState,
  ShowSnackbar,
  Sequential,
  Custom,
  Lifecycle,
  PrimitiveWidget,
  Parallel,
} from "../../engine/src/types";
import type { ActionMap, CustomAction, Value, Valueable } from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Column,
  Text,
  ElevatedButton,
  Center,
  SizedBox,
  Padding,
  Row,
  Icon,
  EdgeInsets,
  TextButton,
  Container,
} from "../../engine/src/components";
import { TV } from "../../engine/src/types/value";
import { GoogleMap, MoveCamera } from "./orca_google_map";

// ── Custom Widget: ColoredBadge ─────────────────────────
// Defined server-side, rendered by a custom builder on the Flutter side.

interface ColoredBadgeProps {
  label: string | ReturnType<typeof V.transform>;
  color: string;
  actions?: ActionMap;
}

class ColoredBadge extends PrimitiveWidget {
  readonly type = "ColoredBadge";
  private label: ColoredBadgeProps["label"];
  private color: string;

  private constructor(props: ColoredBadgeProps) {
    super();
    this.label = props.label;
    this.color = props.color;
    this.actions = props.actions;
  }

  static new(props: ColoredBadgeProps): ColoredBadge {
    return new ColoredBadge(props);
  }

  getProps(): Record<string, unknown> {
    return { label: this.label, color: this.color };
  }
}

// ── Home Page ─────────────────────────────────────────────

const homePage = PageDefinition.create({
  id: "custom-home",
  title: "Custom Extensions",
  state: [
    { key: "rating", scope: "page", initial: 0 },
    { key: "hapticCount", scope: "page", initial: 0 },
    { key: "paying", scope: "page", initial: false },
    { key: "paid", scope: "page", initial: false },
  ],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Custom Actions & Components" }),
        centerTitle: true,
      }),
      body: Center.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            mainAxisAlignment: "center",
            crossAxisAlignment: "center",
            children: [
              TextButton.new({
                child: Row.new({
                  mainAxisSize: "min",
                  children: [
                    Icon.new({ name: "map", size: 20 }),
                    SizedBox.new({ width: 8 }),
                    Text.new({ data: "Go to Map Page" }),
                  ],
                }),
                actions: {
                  onTap: Custom("navigate", { path: "/map" }),
                },
              }),
              // ── Section 1: Custom Actions ──────────────
              Text.new({
                data: "Custom Actions",
                style: { fontSize: 22, fontWeight: "bold" },
              }),
              SizedBox.new({ height: 16 }),

              // Custom "hapticFeedback" action
              ElevatedButton.new({
                child: Row.new({
                  mainAxisSize: "min",
                  children: [
                    Icon.new({ name: "vibration", size: 20 }),
                    SizedBox.new({ width: 8 }),
                    Text.new({ data: "Trigger Haptic" }),
                  ],
                }),
                actions: {
                  onTap: Sequential(
                    Custom("hapticFeedback", { intensity: "heavy" }),
                    SetState(
                      "hapticCount",
                      V.transform(V.pageState("hapticCount"), [
                        { type: "add", by: V.static(1) },
                      ]),
                    ),
                  ),
                },
              }),
              SizedBox.new({ height: 4 }),
              Text.new({
                data: V.transform(V.pageState("hapticCount"), [
                  { type: "toString" },
                  { type: "template", template: "Haptics triggered: {{value}}" },
                ]),
                style: { fontSize: 13, color: "#888888" },
              }),

              SizedBox.new({ height: 20 }),

              // Custom "showConfetti" action
              ElevatedButton.new({
                child: Row.new({
                  mainAxisSize: "min",
                  children: [
                    Icon.new({ name: "celebration", size: 20 }),
                    SizedBox.new({ width: 8 }),
                    Text.new({ data: "Show Confetti" }),
                  ],
                }),
                actions: {
                  onTap: Custom("showConfetti", {
                    duration: 3000,
                    colors: ["#FF0000", "#00FF00", "#0000FF", "#FFD700"],
                  }),
                },
              }),

              SizedBox.new({ height: 20 }),

              // Custom "rateApp" action combined with built-in actions
              ElevatedButton.new({
                child: Row.new({
                  mainAxisSize: "min",
                  children: [
                    Icon.new({ name: "star", size: 20 }),
                    SizedBox.new({ width: 8 }),
                    Text.new({ data: "Rate This App" }),
                  ],
                }),
                actions: {
                  onTap: Sequential(
                    Custom("rateApp", {
                      appStoreId: "com.example.orca",
                      fallbackUrl: "https://example.com/rate",
                    }),
                    SetState("rating", V.static(5)),
                    ShowSnackbar("Thanks for rating!"),
                  ),
                },
              }),
              SizedBox.new({ height: 4 }),
              Text.new({
                data: V.transform(V.pageState("rating"), [
                  { type: "toString" },
                  { type: "template", template: "Current rating: {{value}}" },
                ]),
                style: { fontSize: 13, color: "#888888" },
              }),

              SizedBox.new({ height: 20 }),

              // Custom action with Lifecycle wrapper
              ElevatedButton.new({
                child: Row.new({
                  mainAxisSize: "min",
                  children: [
                    Icon.new({ name: "payment", size: 20 }),
                    SizedBox.new({ width: 8 }),
                    Text.new({
                      data: V.when([
                        {
                          when: Expr.eq(V.pageState("paying"), V.static(true)),
                          then: V.static("Processing...")
                        },
                        {
                          when: Expr.eq(V.pageState("paid"), V.static(true)),
                          then: V.static("Paid ✓")
                        },
                      ], V.static("Pay $29.99")),
                    }),
                  ],
                }),
                actions: {
                  onTap: Lifecycle(
                    Custom("processPayment", { amount: 29.99, currency: "USD" }),
                    {
                      onLoading: SetState("paying", V.static(true)),
                      onSuccess: Sequential(
                        SetState("paid", V.static(true)),
                        ShowSnackbar("Payment successful!"),
                      ),
                      onError: ShowSnackbar("Payment failed. Try again."),
                      onComplete: SetState("paying", V.static(false)),
                    },
                  ),
                },
              }),

              SizedBox.new({ height: 32 }),

              // ── Section 2: Custom Component ────────────
              Text.new({
                data: "Custom Component",
                style: { fontSize: 22, fontWeight: "bold" },
              }),
              SizedBox.new({ height: 16 }),

              // ColoredBadge — rendered by custom Flutter builder
              ColoredBadge.new({
                label: "CUSTOM BADGE",
                color: "#4CAF50",
                actions: {
                  onTap: Sequential(
                    Custom("hapticFeedback", { intensity: "light" }),
                    ShowSnackbar("Badge tapped!"),
                  ),
                },
              }),

              SizedBox.new({ height: 12 }),

              // Reactive badge — label updates from state
              ColoredBadge.new({
                label: V.transform(V.pageState("hapticCount"), [
                  { type: "toString" },
                  { type: "template", template: "TAPS: {{value}}" },
                ]),
                color: "#2196F3",
              }),

              SizedBox.new({ height: 12 }),

              ColoredBadge.new({
                label: "RATE: ★★★★★",
                color: "#FF9800",
                actions: {
                  onTap: Custom("rateApp", {
                    appStoreId: "com.example.orca",
                  }),
                },
              }),
            ],
          }),
        }),
      }),
    }),
});

const mapPage = PageDefinition.create({
  id: "map",
  title: "Map Page",
  state: [
    { key: "latTap", scope: "page", initial: 0 },
    { key: "lngTap", scope: "page", initial: 0 },
    { key: "latMoveCamera", scope: "page", initial: 0 },
    { key: "lngMoveCamera", scope: "page", initial: 0 },
    { key: "zoomMoveCamera", scope: "page", initial: 0 },
  ],
  render: (ctx) =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Map Integration" }),
        centerTitle: true,
      }),
      body: Column.new({
        children: [
          Container.new({
            width: V.static(ctx.requestInfo.screenSize.width),
            height: V.static(300),
            padding: EdgeInsets.all(16),
            child: GoogleMap.new({
              latitude: 37.7749,
              longitude: -122.4194,
              zoom: 12,
              mapType: "normal",
              myLocationEnabled: true,
              zoomControlsEnabled: true,
              markers: [
                {
                  id: "marker1",
                  latitude: 37.7749,
                  longitude: -122.4194,
                  title: "San Francisco",
                  snippet: "This is SF!",
                },
                {
                  id: "marker2",
                  latitude: 37.8044,
                  longitude: -122.2711,
                  title: "Oakland",
                  snippet: "This is Oakland!",
                },
              ],
              actions: {
                onCameraMove: Parallel(
                  SetState(
                    "latMoveCamera",
                    V.event("latitude"),
                  ),
                  SetState(
                    "lngMoveCamera",
                    V.event("longitude"),
                  ),
                  SetState(
                    "zoomMoveCamera",
                    V.event("zoom"),
                  ),
                ),
                onTap: Parallel(
                  SetState(
                    "latTap",
                    V.event("latitude"),
                  ),
                  SetState(
                    "lngTap",
                    V.event("longitude"),
                  ),
                ),
              },
            }).withKey("main-map"),
          }),
          Text.new({
            data: V.transform(V.pageState("latTap"), [
              TV.template("Map tapped on lat {{value}}"),
            ]),
          }),
          Text.new({
            data: V.transform(V.pageState("lngTap"), [
              TV.template("Map tapped on lng {{value}}"),
            ]),
          }),

          Text.new({
            data: V.transform(V.pageState("latMoveCamera"), [
              TV.template("Camera moved to lat {{value}}"),
            ]),
          }),
          Text.new({
            data: V.transform(V.pageState("lngMoveCamera"), [
              TV.template("Camera moved to lng {{value}}"),
            ]),
          }),
          Text.new({
            data: V.transform(V.pageState("zoomMoveCamera"), [
              TV.template("Camera moved to zoom {{value}}"),
            ]),
          }),


          ElevatedButton.new({
            child: Text.new({ data: "Move Camera to NYC" }),
            actions: {
              onTap: MoveCamera("main-map", 40.7128, -74.0060, 14),
            },
          }),

        ],
      }),

    }),
});

// ── App ──────────────────────────────────────────────────

const customFlow = Flow.create({
  name: "custom",
  routes: [{ path: "home", page: homePage }, { path: "map", page: mapPage }],
});

export const customApp = App.create({
  id: "custom",
  name: "Custom Extensions",
  flows: [customFlow],
});
