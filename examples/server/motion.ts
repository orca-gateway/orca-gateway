import { App, Flow, PageDefinition, ServerActionDefinition } from "../../engine/src/core";
import type { RouteTransition } from "../../engine/src/core/flow";
import {
  V,
  Expr,
  Navigate,
  GoBack,
  SetState,
  ServerAction,
  AnimateForward,
  AnimateReverse,
  type Value,
} from "../../engine/src/types";
import {
  Scaffold,
  AppBar,
  Card,
  Center,
  Column,
  Container,
  ElevatedButton,
  GestureDetector,
  TextButton,
  Row,
  Text,
  SizedBox,
  Padding,
  SingleChildScrollView,
  EdgeInsets,
  AnimatedBuilder,
  AnimatedContainer,
  AnimatedOpacity,
  AnimatedAlign,
  AnimatedSwitcher,
  Hero,
} from "../../engine/src/components";
import { Curves } from "../../engine/src/components/helpers/curves";
import type { Widget } from "../../engine/src/types/widget";

// Motion demo (native parity, step 12). One stack, no tabs, so the Hero and the
// route transitions can be checked by hand on the single-stack hosts:
// ORCA_APP_ID=motion ORCA_BOOT=config. Each page shows one thing:
//   /controlled      an AnimatedBuilder driven by animateForward / animateReverse
//   /implicit        AnimatedContainer, AnimatedOpacity and AnimatedAlign by page state
//   /switcher        an AnimatedSwitcher whose child is replaced by a server action
//   /hero            a Hero that flies to /hero/detail
//   /t/<kind>        one page per route transition kind, 600 ms each

const grey = "#757575";
const SLOW = 600;

// ── Shared pieces ──────────────────────────────────────────

function gap() {
  return SizedBox.new({ height: 12 });
}

function note(text: string) {
  return Text.new({ data: text, style: { color: grey, fontSize: 14 } });
}

function pushButton(label: string, route: string) {
  return ElevatedButton.new({
    child: Text.new({ data: label }),
    actions: { onTap: Navigate(route) },
  });
}

function backButton() {
  return TextButton.new({
    child: Text.new({ data: "Back" }),
    actions: { onTap: GoBack() },
  });
}

function screen(title: string, children: Widget[], backgroundColor?: string) {
  return Scaffold.new({
    appBar: AppBar.new({ title: Text.new({ data: title }) }),
    backgroundColor,
    body: SingleChildScrollView.new({
      child: Padding.new({
        padding: EdgeInsets.all(16),
        child: Column.new({ crossAxisAlignment: "stretch", children }),
      }),
    }),
  });
}

/** `on` while the page state `key` is true, `off` otherwise. */
function byFlag<T>(key: string, on: T, off: T): Value {
  return V.when([{ when: Expr.eq(V.pageState(key), true), then: V.static(on) }], V.static(off));
}

function toggleButton(label: string, key: string) {
  return ElevatedButton.new({
    child: Text.new({ data: label }),
    actions: { onTap: SetState(key, V.transform(V.pageState(key), [{ type: "not" }])) },
  });
}

// ── Route transitions ──────────────────────────────────────

const transitionPages: { kind: RouteTransition["type"]; label: string; color: string; says: string }[] = [
  { kind: "fade", label: "Fade", color: "#E3F2FD", says: "The page fades in from clear to solid." },
  { kind: "slideUp", label: "Slide up", color: "#E8F5E9", says: "The page rises from the bottom edge." },
  { kind: "scale", label: "Scale", color: "#FFF3E0", says: "The page grows from the centre." },
  { kind: "slideRight", label: "Slide right", color: "#F3E5F5", says: "The page comes in from the right edge." },
  { kind: "slide", label: "Slide", color: "#FFEBEE", says: "The page comes in from the left edge." },
  { kind: "none", label: "None", color: "#ECEFF1", says: "No transition asked: the platform's own push." },
];

// ── Pages ──────────────────────────────────────────────────

const menuPage = PageDefinition.create({
  id: "menu",
  title: "Motion",
  render: () =>
    screen("Motion", [
      note("Widgets"),
      gap(),
      pushButton("Controlled animation", "/controlled"),
      gap(),
      pushButton("Implicit animations", "/implicit"),
      gap(),
      pushButton("Switcher", "/switcher"),
      gap(),
      pushButton("Hero", "/hero"),
      gap(),
      note(`Route transitions (${SLOW} ms each)`),
      ...transitionPages.flatMap((t) => [gap(), pushButton(`${t.label} (${t.kind})`, `/t/${t.kind}`)]),
    ]),
});

const PULSE = "pulse";

const controlledPage = PageDefinition.create({
  id: "controlled",
  title: "Controlled",
  state: [{ key: "done", scope: "page", initial: 0 }],
  render: () =>
    screen("Controlled", [
      note("The box does not move until a button asks. Forward always starts again from the small box; Reverse goes back from where it is."),
      gap(),
      SizedBox.new({
        height: 180,
        child: Center.new({
          child: AnimatedBuilder.new({
            animationId: PULSE,
            autoStart: false,
            duration: SLOW,
            curve: Curves.EaseInOut,
            children: [
              Container.new({
                width: V.Tween(80, 240, PULSE),
                height: V.Tween(60, 160, PULSE),
                decoration: {
                  color: V.Tween("#BBDEFB", "#1565C0", PULSE),
                  borderRadius: V.Tween(8, 32, PULSE),
                },
              }),
            ],
            actions: {
              onComplete: SetState("done", V.transform(V.pageState("done"), [{ type: "add", by: V.static(1) }])),
            },
          }),
        }),
      }),
      gap(),
      Text.new({
        data: V.transform(V.pageState("done"), [{ type: "toString" }, { type: "template", template: "Runs completed: {{value}}" }]),
        style: { fontSize: 18, fontWeight: "bold" },
      }),
      gap(),
      Row.new({
        mainAxisAlignment: "center",
        children: [
          ElevatedButton.new({
            child: Text.new({ data: "Forward" }),
            actions: { onTap: AnimateForward(PULSE) },
          }),
          SizedBox.new({ width: 16 }),
          ElevatedButton.new({
            child: Text.new({ data: "Reverse" }),
            actions: { onTap: AnimateReverse(PULSE) },
          }),
        ],
      }),
      gap(),
      backButton(),
    ]),
});

const implicitPage = PageDefinition.create({
  id: "implicit",
  title: "Implicit",
  state: [
    { key: "big", scope: "page", initial: false },
    { key: "faded", scope: "page", initial: false },
    { key: "moved", scope: "page", initial: false },
  ],
  render: () =>
    screen("Implicit", [
      note(`AnimatedContainer: width, height and colour change over ${SLOW} ms, easeInOut.`),
      gap(),
      SizedBox.new({
        height: 170,
        child: Center.new({
          child: AnimatedContainer.new({
            duration: SLOW,
            curve: Curves.EaseInOut,
            width: byFlag("big", 240, 120),
            height: byFlag("big", 160, 80),
            color: byFlag("big", "#E91E63", "#2196F3"),
          }),
        }),
      }),
      toggleButton("Resize and recolour", "big"),
      gap(),
      note(`AnimatedOpacity: solid to faint over ${SLOW} ms, no curve named (easeInOut).`),
      gap(),
      AnimatedOpacity.new({
        duration: SLOW,
        opacity: byFlag("faded", 0.15, 1),
        child: Container.new({ height: 60, color: "#4CAF50" }),
      }),
      gap(),
      toggleButton("Fade", "faded"),
      gap(),
      note(`AnimatedAlign: corner to corner over ${SLOW} ms with bounceOut, so the square bounces as it lands.`),
      gap(),
      Container.new({
        height: 160,
        color: "#EEEEEE",
        child: AnimatedAlign.new({
          duration: SLOW,
          curve: Curves.BounceOut,
          alignment: byFlag("moved", "bottomRight", "topLeft"),
          child: Container.new({ width: 48, height: 48, color: "#FF9800" }),
        }),
      }),
      gap(),
      toggleButton("Move", "moved"),
      gap(),
      backButton(),
    ]),
});

// The switcher's child is a different node on each side: a different key (the
// node id) and a different widget class, so it counts as a new child whichever
// of the two the client compares. Page state alone cannot swap a node, so the
// button asks the server to replace it.

type Face = "a" | "b";

function faceKey(face: Face) {
  return `switcher-face-${face}`;
}

function faceWidget(face: Face): Widget {
  const label = (text: string, color: string) =>
    Center.new({ child: Text.new({ data: text, style: { fontSize: 22, fontWeight: "bold", color } }) });
  if (face === "a") {
    return Container.new({ width: 220, height: 120, color: "#1565C0", child: label("Side A", "#FFFFFF") }).withKey(faceKey("a"));
  }
  return Card.new({
    child: SizedBox.new({ width: 220, height: 120, child: label("Side B", "#E65100") }),
  }).withKey(faceKey("b"));
}

const flipFaceAction = ServerActionDefinition.create({
  id: "flipFace",
  schema: { current: { type: "string", required: true } },
  execute: (ctx) => {
    const current: Face = ctx.actionParams.current === "b" ? "b" : "a";
    const next: Face = current === "a" ? "b" : "a";
    return [
      { type: "replaceComponent" as const, targetId: faceKey(current), keyPrefix: `switcher-${next}`, widget: faceWidget(next) },
      { type: "setState" as const, scope: "page" as const, key: "face", value: next },
    ];
  },
});

const switcherPage = PageDefinition.create({
  id: "switcher",
  title: "Switcher",
  state: [{ key: "face", scope: "page", initial: "a" }],
  render: () =>
    screen("Switcher", [
      note(`The child is replaced by another node: the old one fades out while the new one fades in, over ${SLOW} ms.`),
      gap(),
      SizedBox.new({
        height: 160,
        child: Center.new({
          child: AnimatedSwitcher.new({ duration: SLOW, child: faceWidget("a") }),
        }),
      }),
      gap(),
      Text.new({
        data: V.transform(V.pageState("face"), [{ type: "toUpperCase" }, { type: "template", template: "Showing side {{value}}" }]),
      }),
      gap(),
      ElevatedButton.new({
        child: Text.new({ data: "Swap" }),
        actions: { onTap: ServerAction("flipFace", { current: V.pageState("face") }) },
      }),
      gap(),
      backButton(),
    ]),
});

const HERO_TAG = "motion-hero";
const heroColor = "#7E57C2";

const heroPage = PageDefinition.create({
  id: "hero",
  title: "Hero",
  render: () =>
    screen("Hero", [
      note("Tap the square. It carries the same tag as the large one on the next page."),
      gap(),
      Row.new({
        children: [
          // The tap sits inside the Hero, so a host that must know the tag at
          // push time finds it around the widget that navigated.
          Hero.new({
            tag: HERO_TAG,
            child: GestureDetector.new({
              actions: { onTap: Navigate("/hero/detail") },
              child: Container.new({ width: 72, height: 72, decoration: { color: heroColor, borderRadius: 12 } }),
            }),
          }),
          SizedBox.new({ width: 16 }),
          note("Tap me"),
        ],
      }),
      gap(),
      backButton(),
    ]),
});

const heroDetailPage = PageDefinition.create({
  id: "hero-detail",
  title: "Hero detail",
  render: () =>
    screen("Hero detail", [
      Hero.new({
        tag: HERO_TAG,
        child: Container.new({ height: 280, decoration: { color: heroColor, borderRadius: 12 } }),
      }),
      gap(),
      note("Going back flies the square home where the host supports it."),
      gap(),
      backButton(),
    ]),
});

function transitionPage(t: (typeof transitionPages)[number]) {
  return PageDefinition.create({
    id: `t-${t.kind}`,
    title: t.label,
    render: () =>
      screen(
        t.label,
        [
          Text.new({ data: `Transition: ${t.kind}`, style: { fontSize: 24, fontWeight: "bold" } }),
          SizedBox.new({ height: 8 }),
          note(`${t.says} Back plays it the other way.`),
          gap(),
          backButton(),
        ],
        t.color,
      ),
  });
}

// ── Flow and app ───────────────────────────────────────────

const motionFlow = Flow.create({
  name: "motion",
  routes: [
    { path: "menu", page: menuPage },
    { path: "controlled", page: controlledPage },
    { path: "implicit", page: implicitPage },
    { path: "switcher", page: switcherPage },
    { path: "hero", page: heroPage, children: [{ path: "detail", page: heroDetailPage }] },
    ...transitionPages.map((t) => ({
      path: `t/${t.kind}`,
      page: transitionPage(t),
      transition: { type: t.kind, duration: SLOW, curve: Curves.EaseInOut },
    })),
  ],
});

export const motionApp = App.create({
  id: "motion",
  name: "Motion Demo",
  flows: [motionFlow],
  actions: [flipFaceAction],
  navigation: {
    initialRoute: "/menu",
  },
});
