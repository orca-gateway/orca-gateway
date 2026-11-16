import { App, Flow, PageDefinition } from "../../engine/src/core";
import {
  V,
  TV,
  SetState,
  Navigate,
  GoBack,
  Sequential,
  DebugLog,
  Once,
  Always,
  type Action,
  type Widget,
} from "../../engine/src/types";
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
  Center,
  Stack,
  Positioned,
  Image,
  Icon,
  TextField,
  Card,
  ElevatedButton,
  OutlinedButton,
  TextButton,
  EdgeInsets,
  Expanded,
  Align,
  AspectRatio,
  Baseline,
  ConstrainedBox,
  FittedBox,
  Flexible,
  FractionallySizedBox,
  IntrinsicHeight,
  IntrinsicWidth,
  LimitedBox,
  Offstage,
  SafeArea,
  Wrap,
  GestureDetector,
  Opacity,
  RotatedBox,
  ClipRect,
  ClipOval,
  DecoratedBox,
  ColorFiltered,
  BackdropFilter,
  BlurView,
  AbsorbPointer,
  IgnorePointer,
  InteractiveViewer,
} from "../../engine/src/components";

// Native parity, Phase A (pipeline native-parity). One app, one page per plan
// step, each the "torture" page for the props that step brings to Swift and
// Kotlin, so the same page can be compared on Flutter, iOS and Android.
// Pages: polish (step 1), lifecycle (step 2), layout and layout-safe (step 3),
// effects (step 4). Later steps add lists, forms, rich and overlays: one page
// constant each, one entry in `routes`. Images come from picsum.photos; offline
// they draw "!" in their box. Only widgets all three SDKs draw.

const red = "#E53935";
const blue = "#1E88E5";
const amber = "#FFB300";
const green = "#43A047";
const pale = "#ECEFF1";
const grey = "#757575";

const longLine = "A long single line that cannot fit in a 160-wide box";
const paragraph =
  "Justified text stretches every line to the full width of its box except the last one, " +
  "so the gaps between the words grow on the first lines and stay normal on the final line.";

/** A titled section: the case id and what to look for, then its widgets. */
function section(title: string, ...children: Widget[]): Widget {
  return Padding.new({
    padding: EdgeInsets.only({ bottom: 24 }),
    child: Column.new({
      crossAxisAlignment: "start",
      children: [
        Text.new({ data: title, style: { fontSize: 16, fontWeight: "bold" } }),
        SizedBox.new({ height: 8 }),
        ...children,
      ],
    }),
  });
}

/** A Column whose children take its full width (for alignment checks). */
function fullWidth(...children: Widget[]): Widget {
  return Column.new({ crossAxisAlignment: "stretch", gap: 8, children });
}

function box(label: string, color: string): Widget {
  return block(label, color, 48, 32);
}

/** A width × height coloured box with a centred white label. */
function block(label: string, color: string, width: number, height: number): Widget {
  return Container.new({
    width,
    height,
    alignment: "center",
    color,
    child: Text.new({ data: label, style: { color: "#FFFFFF", fontWeight: "bold" } }),
  });
}

function caption(text: string): Widget {
  return Text.new({ data: text, style: { fontSize: 12, color: grey } });
}

function oneLine(overflow: "clip" | "fade" | "ellipsis" | "visible", wrap: "softWrap" | "maxLines"): Widget {
  return Padding.new({
    padding: EdgeInsets.only({ bottom: 8 }),
    child: Column.new({
      crossAxisAlignment: "start",
      children: [
        caption(`overflow ${overflow}, ${wrap === "softWrap" ? "softWrap false" : "maxLines 1"}`),
        SizedBox.new({
          width: 160,
          child: Container.new({
            color: "#FFF3E0",
            child: Text.new({
              data: longLine,
              overflow,
              ...(wrap === "softWrap" ? { softWrap: false } : { maxLines: 1 }),
            }),
          }),
        }),
      ],
    }),
  });
}

function imageBox(label: string, src: string, fit: "fitWidth" | "fitHeight" | "scaleDown" | "none", repeat?: "repeat"): Widget {
  return Column.new({
    crossAxisAlignment: "start",
    children: [
      Container.new({
        width: 120,
        height: 80,
        color: pale,
        child: Image.new({ src, fit, width: 120, height: 80, alt: label, ...(repeat ? { repeat } : {}) }),
      }),
      SizedBox.new({ height: 4 }),
      caption(label),
    ],
  });
}

function numbered(count: number): Widget {
  return Column.new({
    crossAxisAlignment: "start",
    children: Array.from({ length: count }, (_, i) => Text.new({ data: `Item ${i + 1}` })),
  });
}

// ── Step 1 · polish: Text, Container, buttons, Stack, Image, TextField, AppBar,
//    Row/Column directions, Center factors, Card, scroll (A1.1-A1.13) ──────────

const polishPage = PageDefinition.create({
  id: "polish",
  title: "Polish",
  state: [
    { key: "count", scope: "page", initial: 0 },
    { key: "taps", scope: "page", initial: 0 },
  ],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Polish (step 1)" }),
        leading: Icon.new({ name: "tune" }),
        leadingWidth: 72,
        centerTitle: false,
        elevation: 4,
        shadowColor: red,
      }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "start",
            children: [
              section(
                "A1.9 / A1.13 Navigation and a counter that survives a rotation",
                Text.new({
                  data: V.transform(V.pageState("count"), [TV.template("Count: {{value}}")]),
                  style: { fontSize: 20 },
                }),
                SizedBox.new({ height: 8 }),
                Column.new({
                  crossAxisAlignment: "start",
                  gap: 8,
                  children: [
                    ElevatedButton.new({
                      child: Text.new({ data: "+1" }),
                      actions: { onTap: SetState("count", V.transform(V.pageState("count"), [TV.add(V.static(1))])) },
                    }),
                    OutlinedButton.new({
                      child: Text.new({ data: "Push (back arrow)" }),
                      actions: { onTap: Navigate("polish-pushed") },
                    }),
                    OutlinedButton.new({
                      child: Text.new({ data: "Push (no back arrow)" }),
                      actions: { onTap: Navigate("polish-no-back") },
                    }),
                  ],
                }),
              ),
              section(
                "A1.1 Text: height 1.5, wordSpacing 4, dashed red overline",
                Text.new({
                  data: "Line height one and a half, wide word gaps and a dashed red overline on every line of this text.",
                  style: {
                    fontSize: 16,
                    height: 1.5,
                    wordSpacing: 4,
                    decoration: "overline",
                    decorationStyle: "dashed",
                    decorationColor: red,
                  },
                }),
                SizedBox.new({ height: 8 }),
                ...(["solid", "double", "dotted", "dashed", "wavy"] as const).map((decorationStyle) =>
                  Text.new({
                    data: `underline ${decorationStyle}`,
                    style: { fontSize: 16, decoration: "underline", decorationStyle },
                  }),
                ),
              ),
              section(
                "A1.2 One line in a 160-wide box: clip, fade, ellipsis, visible",
                oneLine("clip", "softWrap"),
                oneLine("fade", "softWrap"),
                oneLine("ellipsis", "maxLines"),
                oneLine("visible", "softWrap"),
              ),
              section(
                "A1.3 textAlign justify, left, right",
                fullWidth(
                  Text.new({ data: paragraph, textAlign: "justify" }),
                  Container.new({ color: pale, child: Text.new({ data: "textAlign left", textAlign: "left" }) }),
                  Container.new({ color: pale, child: Text.new({ data: "textAlign right", textAlign: "right" }) }),
                ),
              ),
              section(
                "A1.4 A 4px blue border insets the amber child by 4px",
                Container.new({
                  decoration: { border: { width: 4, color: blue } },
                  child: Container.new({ width: 80, height: 40, color: amber }),
                }),
              ),
              section(
                "A1.5 / A1.11 Buttons: elevation 6 and padding 24; Outlined autofocus",
                Text.new({
                  data: V.transform(V.pageState("taps"), [TV.template("Elevated tapped {{value}} times")]),
                  style: { color: grey },
                }),
                SizedBox.new({ height: 8 }),
                Column.new({
                  crossAxisAlignment: "start",
                  gap: 12,
                  children: [
                    ElevatedButton.new({
                      elevation: 6,
                      padding: EdgeInsets.all(24),
                      child: Text.new({ data: "Elevated" }),
                      actions: { onTap: SetState("taps", V.transform(V.pageState("taps"), [TV.add(V.static(1))])) },
                    }),
                    OutlinedButton.new({ autofocus: true, child: Text.new({ data: "Outlined (autofocus)" }) }),
                    TextButton.new({ child: Text.new({ data: "Text" }) }),
                  ],
                }),
              ),
              section(
                "A1.6 Stack fit passthrough: the amber box fills 200x100",
                SizedBox.new({
                  width: 200,
                  height: 100,
                  child: Stack.new({
                    fit: "passthrough",
                    children: [
                      Container.new({ color: amber, child: Text.new({ data: "non-positioned" }) }),
                      Positioned.new({
                        right: 4,
                        bottom: 4,
                        child: Container.new({
                          padding: EdgeInsets.symmetric({ horizontal: 6, vertical: 2 }),
                          color: blue,
                          child: Text.new({ data: "Positioned", style: { color: "#FFFFFF", fontSize: 12 } }),
                        }),
                      }),
                    ],
                  }),
                }),
              ),
              section(
                "A1.7 Image fit in 120x80 boxes; scaleDown never enlarges; repeat tiles",
                Row.new({
                  gap: 12,
                  children: [
                    imageBox("fitWidth (tall image)", "https://picsum.photos/seed/orca-tall/200/400", "fitWidth"),
                    imageBox("fitHeight (wide image)", "https://picsum.photos/seed/orca-wide/400/200", "fitHeight"),
                  ],
                }),
                SizedBox.new({ height: 12 }),
                Row.new({
                  gap: 12,
                  children: [
                    imageBox("scaleDown (40x40)", "https://picsum.photos/seed/orca-small/40/40", "scaleDown"),
                    imageBox("repeat (40x40, fit none)", "https://picsum.photos/seed/orca-small/40/40", "none", "repeat"),
                  ],
                }),
              ),
              section(
                "A1.8 TextField: readOnly (focus and select, no edit); decoration styles, isDense",
                fullWidth(
                  TextField.new({
                    readOnly: true,
                    value: "Read only: select me, do not edit me",
                    decoration: { labelText: "readOnly true" },
                  }),
                  TextField.new({
                    decoration: {
                      hintText: "hint in italic blue",
                      hintStyle: { color: blue, fontStyle: "italic" },
                      helperText: "helper in green",
                      helperStyle: { color: green },
                      errorText: "error in bold red (hides the helper)",
                      errorStyle: { color: red, fontWeight: "bold" },
                      isDense: true,
                    },
                  }),
                  TextField.new({
                    decoration: {
                      hintText: "hint in italic blue",
                      hintStyle: { color: blue, fontStyle: "italic" },
                      helperText: "helper in green, 14",
                      helperStyle: { color: green, fontSize: 14 },
                      isDense: true,
                    },
                  }),
                ),
              ),
              section(
                "A1.10 Row rtl (1 on the right), Column up (1 at the bottom), Center factors",
                Row.new({
                  textDirection: "rtl",
                  gap: 8,
                  children: [box("1", red), box("2", blue), box("3", green)],
                }),
                SizedBox.new({ height: 12 }),
                Column.new({
                  verticalDirection: "up",
                  gap: 8,
                  children: [box("1", red), box("2", blue), box("3", green)],
                }),
                SizedBox.new({ height: 12 }),
                caption("Center widthFactor 0.5, heightFactor 2 around an 80x30 box: 40x60"),
                SizedBox.new({ height: 4 }),
                Container.new({
                  decoration: { border: { width: 1, color: grey } },
                  child: Center.new({
                    widthFactor: 0.5,
                    heightFactor: 2,
                    child: Container.new({ width: 80, height: 30, color: amber }),
                  }),
                }),
              ),
              section(
                "A1.11 decorationColor, Card surfaceTintColor, Card clipBehavior",
                Text.new({
                  data: "Black text, red underline",
                  style: { fontSize: 16, color: "#000000", decoration: "underline", decorationColor: red },
                }),
                SizedBox.new({ height: 8 }),
                Card.new({
                  elevation: 6,
                  surfaceTintColor: "#FF00FF",
                  child: Padding.new({
                    padding: EdgeInsets.all(16),
                    child: Text.new({ data: "Card, surfaceTint #FF00FF, elevation 6" }),
                  }),
                }),
                SizedBox.new({ height: 8 }),
                Card.new({
                  clipBehavior: "antiAlias",
                  child: Container.new({
                    width: 220,
                    height: 60,
                    alignment: "center",
                    color: green,
                    child: Text.new({ data: "antiAlias: round corners", style: { color: "#FFFFFF" } }),
                  }),
                }),
              ),
              section(
                "A1.12 Scroll: reverse starts at Item 20; shrinkWrap hugs its content",
                Container.new({
                  width: 200,
                  height: 120,
                  decoration: { border: { width: 1, color: grey } },
                  child: SingleChildScrollView.new({ reverse: true, child: numbered(20) }),
                }),
                SizedBox.new({ height: 12 }),
                Container.new({
                  width: 200,
                  height: 120,
                  alignment: "topLeft",
                  decoration: { border: { width: 1, color: grey } },
                  child: Container.new({
                    color: "#FFF3E0",
                    child: SingleChildScrollView.new({ shrinkWrap: true, child: numbered(2) }),
                  }),
                }),
              ),
            ],
          }),
        }),
      }),
    }),
});

// Pushed from polish (A1.9): the AppBar implies a back arrow.
const polishPushedPage = PageDefinition.create({
  id: "polish-pushed",
  title: "Pushed",
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Pushed" }) }),
      body: Center.new({ child: Text.new({ data: "A back arrow shows above." }) }),
    }),
});

// Pushed from polish (A1.9): automaticallyImplyLeading false, no back arrow.
const polishNoBackPage = PageDefinition.create({
  id: "polish-no-back",
  title: "No back arrow",
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "No back arrow" }), automaticallyImplyLeading: false }),
      body: Center.new({
        child: Column.new({
          mainAxisSize: "min",
          children: [
            Text.new({ data: "No back arrow above." }),
            SizedBox.new({ height: 12 }),
            TextButton.new({ child: Text.new({ data: "Go back" }), actions: { onTap: GoBack() } }),
          ],
        }),
      }),
    }),
});

// ── Step 2 · lifecycle: onInit, onVisible, app background / foreground, scroll
//    triggers, once / always / debugLog (A2.1-A2.6) ────────────────────────────

/** SetState key = key + 1 (page scope). */
function bump(key: string) {
  return SetState(key, V.transform(V.pageState(key), [TV.add(V.static(1))]));
}

/** A Text "label: <page state value>", with `decimals` decimals when given. */
function shows(label: string, key: string, decimals?: number): Widget {
  const format = decimals === undefined ? [] : [TV.toFixed(decimals)];
  return Text.new({ data: V.transform(V.pageState(key), [...format, TV.template(`${label}: {{value}}`)]) });
}

/** The scroll event (offset, maxExtent, atEnd, + delta) into page state, with the trigger's name. */
function scrollEvent(trigger: string, ...more: Action[]) {
  return Sequential(
    SetState("scrollLast", V.static(trigger)),
    SetState("scrollOffset", V.event("offset")),
    SetState("scrollMaxExtent", V.event("maxExtent")),
    SetState("scrollAtEnd", V.event("atEnd")),
    ...more,
  );
}

const lifecyclePage = PageDefinition.create({
  id: "lifecycle",
  title: "Lifecycle",
  state: [
    { key: "inits", scope: "page", initial: 0 },
    { key: "visibles", scope: "page", initial: 0 },
    { key: "backgrounds", scope: "page", initial: 0 },
    { key: "foregrounds", scope: "page", initial: 0 },
    { key: "appBackgrounds", scope: "page", initial: 0 },
    { key: "appForegrounds", scope: "page", initial: 0 },
    { key: "scrollLast", scope: "page", initial: "none" },
    { key: "scrollOffset", scope: "page", initial: 0 },
    { key: "scrollMaxExtent", scope: "page", initial: 0 },
    { key: "scrollAtEnd", scope: "page", initial: false },
    { key: "scrollDelta", scope: "page", initial: 0 },
    { key: "scrollBegins", scope: "page", initial: 0 },
    { key: "scrollEnds", scope: "page", initial: 0 },
    { key: "onceCount", scope: "page", initial: 0 },
    { key: "alwaysCount", scope: "page", initial: 0 },
    { key: "redraws", scope: "page", initial: 0 },
  ],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Lifecycle (step 2)" }) }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "start",
            children: [
              section(
                "A2.1 / A2.2 onInit and onVisible run once per mount: both read 1, also after +1 below",
                Column.new({
                  crossAxisAlignment: "start",
                  actions: {
                    onInit: bump("inits"),
                    onVisible: Sequential(
                      bump("visibles"),
                      DebugLog({
                        level: "info",
                        tag: "parity",
                        message: V.transform(V.pageState("visibles"), [TV.template("visible {{value}}")]),
                      }),
                    ),
                  },
                  children: [shows("onInit ran", "inits"), shows("onVisible ran", "visibles")],
                }),
                SizedBox.new({ height: 4 }),
                caption('onVisible also logs "visible 1" (debugLog, level info, tag parity)'),
              ),
              section(
                "A2.3 Send the app to the background and reopen it: each count goes up by one",
                Column.new({
                  crossAxisAlignment: "start",
                  actions: { onBackground: bump("backgrounds"), onForeground: bump("foregrounds") },
                  children: [shows("onBackground", "backgrounds"), shows("onForeground", "foregrounds")],
                }),
                SizedBox.new({ height: 8 }),
                Column.new({
                  crossAxisAlignment: "start",
                  actions: { onAppBackground: bump("appBackgrounds"), onAppForeground: bump("appForegrounds") },
                  children: [shows("onAppBackground", "appBackgrounds"), shows("onAppForeground", "appForegrounds")],
                }),
                SizedBox.new({ height: 4 }),
                caption("All four read 0 on open (no foreground on launch)"),
              ),
              section(
                "A2.4 Scroll the box: offset, maxExtent, atEnd and delta follow it live",
                shows("last trigger", "scrollLast"),
                shows("offset", "scrollOffset", 1),
                shows("maxExtent", "scrollMaxExtent", 1),
                shows("atEnd", "scrollAtEnd"),
                shows("delta (onScrolling)", "scrollDelta", 1),
                shows("onScrollBegin ran", "scrollBegins"),
                shows("onScrollEnd ran", "scrollEnds"),
                SizedBox.new({ height: 8 }),
                Container.new({
                  width: 200,
                  height: 160,
                  decoration: { border: { width: 1, color: grey } },
                  child: SingleChildScrollView.new({
                    actions: {
                      onScrollBegin: scrollEvent("onScrollBegin", bump("scrollBegins")),
                      onScrolling: scrollEvent("onScrolling", SetState("scrollDelta", V.event("delta"))),
                      onScrollEnd: scrollEvent("onScrollEnd", bump("scrollEnds")),
                    },
                    child: numbered(30),
                  }),
                }),
              ),
              section(
                "A2.5 / A2.6 once counts to 1 and stops; always counts every tap; +1 only redraws",
                shows("once", "onceCount"),
                shows("always", "alwaysCount"),
                shows("redraws", "redraws"),
                SizedBox.new({ height: 8 }),
                Column.new({
                  crossAxisAlignment: "start",
                  gap: 8,
                  children: [
                    ElevatedButton.new({
                      child: Text.new({ data: "once" }),
                      actions: { onTap: Once(bump("onceCount")) },
                    }),
                    ElevatedButton.new({
                      child: Text.new({ data: "always" }),
                      actions: { onTap: Always(bump("alwaysCount")) },
                    }),
                    OutlinedButton.new({
                      child: Text.new({ data: "+1 (redraw)" }),
                      actions: { onTap: bump("redraws") },
                    }),
                  ],
                }),
              ),
            ],
          }),
        }),
      }),
    }),
});

// ── Step 3 · layout: the 13 layout and sizing wrappers (A3.2-A3.7); SafeArea at
//    the screen edges on its own page, layout-safe, with no AppBar ───────────

const wrapColors = [red, blue, green, amber];

/** `count` 48×32 boxes numbered from 1, the four colours in turn. */
function numberedBoxes(count: number): Widget[] {
  return Array.from({ length: count }, (_, i) => box(String(i + 1), wrapColors[i % wrapColors.length]!));
}

/** A coloured box with no width of its own: it fills what its parent allows (and its height, when not given). */
function fill(label: string, color: string, height?: number): Widget {
  return Container.new({
    ...(height === undefined ? {} : { height }),
    alignment: "center",
    color,
    child: Text.new({ data: label, style: { color: "#FFFFFF", fontWeight: "bold" } }),
  });
}

/** A 200-wide grey box holding a Wrap, so line breaks and margins can be measured against it. */
function wrapIn200(wrap: Widget): Widget {
  return Container.new({ width: 200, color: pale, child: wrap });
}

/** A 100×60 grey box with a FittedBox around the same 160×80 child, the fit named beside it. */
function fitted(fit: "contain" | "cover" | "scaleDown", expect: string): Widget {
  return Row.new({
    children: [
      Container.new({
        width: 100,
        height: 60,
        color: pale,
        child: FittedBox.new({ fit, child: block("160 × 80", blue, 160, 80) }),
      }),
      SizedBox.new({ width: 24 }),
      Expanded.new({ child: caption(`${fit}: ${expect}`) }),
    ],
  });
}

const layoutPage = PageDefinition.create({
  id: "layout",
  title: "Layout",
  state: [
    { key: "offstageHidden", scope: "page", initial: false },
    { key: "offstageCount", scope: "page", initial: 0 },
  ],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Layout (step 3)" }) }),
      body: SafeArea.new({
        child: SingleChildScrollView.new({
          child: Padding.new({
            padding: EdgeInsets.all(16),
            child: Column.new({
              crossAxisAlignment: "start",
              children: [
                section(
                  "A3.2 AspectRatio, FractionallySizedBox, ConstrainedBox, LimitedBox",
                  caption("AspectRatio 16/9 in a 320-wide box: 320 × 180"),
                  SizedBox.new({ height: 4 }),
                  SizedBox.new({
                    width: 320,
                    child: AspectRatio.new({ aspectRatio: 16 / 9, child: fill("320 × 180", blue) }),
                  }),
                  SizedBox.new({ height: 12 }),
                  caption("FractionallySizedBox widthFactor 0.5 in a 320 × 48 grey box: the amber half is 160 wide, centred"),
                  SizedBox.new({ height: 4 }),
                  Container.new({
                    width: 320,
                    height: 48,
                    color: pale,
                    child: FractionallySizedBox.new({
                      widthFactor: 0.5,
                      child: fill("160", amber),
                    }),
                  }),
                  SizedBox.new({ height: 12 }),
                  caption("ConstrainedBox min 120 × 40, max 200 × 60 around a box asking 300 × 20: drawn 200 × 40"),
                  SizedBox.new({ height: 4 }),
                  ConstrainedBox.new({
                    constraints: { minWidth: 120, maxWidth: 200, minHeight: 40, maxHeight: 60 },
                    child: block("asks 300 × 20", blue, 300, 20),
                  }),
                  SizedBox.new({ height: 8 }),
                  caption("ConstrainedBox min 150 × 50 inside a tight 100 × 30 SizedBox: the parent wins, 100 × 30"),
                  SizedBox.new({ height: 4 }),
                  SizedBox.new({
                    width: 100,
                    height: 30,
                    child: ConstrainedBox.new({
                      constraints: { minWidth: 150, minHeight: 50 },
                      child: fill("100 × 30", red),
                    }),
                  }),
                  SizedBox.new({ height: 12 }),
                  caption("LimitedBox maxWidth 100 around a box that fills its width, in a horizontal scroll view (unbounded): 100 wide"),
                  SizedBox.new({ height: 4 }),
                  SingleChildScrollView.new({
                    scrollDirection: "horizontal",
                    child: LimitedBox.new({ maxWidth: 100, child: fill("100", green, 32) }),
                  }),
                  SizedBox.new({ height: 8 }),
                  caption("The same LimitedBox in the page column (bounded): the cap does not apply, full width"),
                  SizedBox.new({ height: 4 }),
                  LimitedBox.new({ maxWidth: 100, child: fill("full width", green, 32) }),
                ),
                section(
                  "A3.3 Wrap: full lines break to the next one",
                  caption("spacing 8, runSpacing 12, 9 boxes in a 200-wide grey box: 3 per line (48+8+48+8+48 = 160), 3 lines 12 apart"),
                  SizedBox.new({ height: 4 }),
                  wrapIn200(Wrap.new({ spacing: 8, runSpacing: 12, children: numberedBoxes(9) })),
                  SizedBox.new({ height: 12 }),
                  caption("alignment center, 8 boxes: every line centred; the two full lines have 20 grey each side, the last line of 2 boxes 48 each side"),
                  SizedBox.new({ height: 4 }),
                  wrapIn200(Wrap.new({ spacing: 8, runSpacing: 12, alignment: "center", children: numberedBoxes(8) })),
                  SizedBox.new({ height: 12 }),
                  caption("crossAxisAlignment end, boxes 20, 32 and 44 tall: in each line the boxes share their bottom edge"),
                  SizedBox.new({ height: 4 }),
                  wrapIn200(
                    Wrap.new({
                      spacing: 8,
                      runSpacing: 12,
                      crossAxisAlignment: "end",
                      children: [20, 32, 44, 20, 32, 44].map((height, i) =>
                        block(String(i + 1), wrapColors[i % wrapColors.length]!, 48, height),
                      ),
                    }),
                  ),
                ),
                section(
                  "A3.4 Align, Flexible next to Expanded, Baseline",
                  caption("Align bottomRight in a 200 × 80 grey box: the red box sits in its bottom-right corner"),
                  SizedBox.new({ height: 4 }),
                  Container.new({
                    width: 200,
                    height: 80,
                    color: pale,
                    child: Align.new({ alignment: "bottomRight", child: box("A", red) }),
                  }),
                  SizedBox.new({ height: 12 }),
                  caption("Align topRight, widthFactor 2, heightFactor 1.5 around a 48 × 32 box: the grey area is 96 × 48, the box in its top-right corner"),
                  SizedBox.new({ height: 4 }),
                  Container.new({
                    color: pale,
                    child: Align.new({ alignment: "topRight", widthFactor: 2, heightFactor: 1.5, child: box("B", blue) }),
                  }),
                  SizedBox.new({ height: 12 }),
                  caption("Row 320 wide, flex 1 each (shares of 160): Flexible (loose) keeps its 60-wide red box, Expanded (tight) fills 160 in blue, the last 100 stay grey"),
                  SizedBox.new({ height: 4 }),
                  Container.new({
                    width: 320,
                    color: pale,
                    child: Row.new({
                      children: [
                        Flexible.new({ flex: 1, fit: "loose", child: block("60", red, 60, 32) }),
                        Expanded.new({ flex: 1, child: fill("160", blue, 32) }),
                      ],
                    }),
                  }),
                  SizedBox.new({ height: 12 }),
                  caption("Baseline 40 alphabetic around 14 and 32 px text, in a Row aligned to the top: both words stand where the 40-tall red bar ends"),
                  SizedBox.new({ height: 4 }),
                  Row.new({
                    crossAxisAlignment: "start",
                    children: [
                      Container.new({ width: 8, height: 40, color: red }),
                      SizedBox.new({ width: 8 }),
                      Baseline.new({
                        baseline: 40,
                        baselineType: "alphabetic",
                        child: Text.new({ data: "Small", style: { fontSize: 14 } }),
                      }),
                      SizedBox.new({ width: 16 }),
                      Baseline.new({
                        baseline: 40,
                        baselineType: "alphabetic",
                        child: Text.new({ data: "Large", style: { fontSize: 32 } }),
                      }),
                    ],
                  }),
                ),
                section(
                  "A3.5 IntrinsicHeight and IntrinsicWidth",
                  caption("IntrinsicHeight around a Row with crossAxisAlignment stretch; the boxes ask 20, 60 and 40 tall: all three are 60 tall"),
                  SizedBox.new({ height: 4 }),
                  IntrinsicHeight.new({
                    child: Row.new({
                      crossAxisAlignment: "stretch",
                      gap: 8,
                      children: [block("20", red, 60, 20), block("60", blue, 60, 60), block("40", green, 60, 40)],
                    }),
                  }),
                  SizedBox.new({ height: 12 }),
                  caption("IntrinsicWidth stepWidth 50 around a Column with crossAxisAlignment stretch; the boxes ask 70, 130 and 90 wide: all three are 150 wide (130 rounded up to a step of 50), as wide as the grey ruler"),
                  SizedBox.new({ height: 4 }),
                  IntrinsicWidth.new({
                    stepWidth: 50,
                    child: Column.new({
                      crossAxisAlignment: "stretch",
                      gap: 4,
                      children: [block("70", red, 70, 24), block("130", blue, 130, 24), block("90", green, 90, 24)],
                    }),
                  }),
                  SizedBox.new({ height: 4 }),
                  Container.new({ width: 150, height: 6, color: grey }),
                ),
                section(
                  "A3.6 Offstage: hide and show; the counter and the typed text survive",
                  shows("offstage", "offstageHidden"),
                  SizedBox.new({ height: 8 }),
                  ElevatedButton.new({
                    child: Text.new({ data: "Hide / show" }),
                    actions: {
                      onTap: SetState("offstageHidden", V.transform(V.pageState("offstageHidden"), [TV.not()])),
                    },
                  }),
                  SizedBox.new({ height: 8 }),
                  block("above", grey, 120, 24),
                  Offstage.new({
                    offstage: V.pageState("offstageHidden"),
                    child: Container.new({
                      padding: EdgeInsets.all(8),
                      color: "#FFF3E0",
                      child: Column.new({
                        crossAxisAlignment: "start",
                        gap: 8,
                        children: [
                          shows("counter", "offstageCount"),
                          ElevatedButton.new({ child: Text.new({ data: "+1" }), actions: { onTap: bump("offstageCount") } }),
                          TextField.new({ decoration: { hintText: "type here, then hide and show" } }),
                        ],
                      }),
                    }),
                  }),
                  block("below", grey, 120, 24),
                  SizedBox.new({ height: 4 }),
                  caption("Hidden: nothing drawn and no gap, \"above\" touches \"below\". Shown again: the counter and the text are as you left them"),
                  SizedBox.new({ height: 12 }),
                  caption(
                    "This page's body sits in a SafeArea (all edges): nothing added under the AppBar, which already took the status bar; " +
                      "scrolled to the end, the last section stops above the home indicator. The edges themselves are on a page with no AppBar",
                  ),
                  SizedBox.new({ height: 4 }),
                  OutlinedButton.new({
                    child: Text.new({ data: "SafeArea (layout-safe)" }),
                    actions: { onTap: Navigate("layout-safe") },
                  }),
                ),
                section(
                  "A3.7 FittedBox on the same 160 × 80 child in 100 × 60 grey boxes, always centred",
                  fitted("contain", "scaled ×0.625 to 100 × 50, grey bands 5 tall above and below"),
                  SizedBox.new({ height: 16 }),
                  fitted("cover", "scaled ×0.75 to 120 × 60, the full height; 10 spills past each side (no clip)"),
                  SizedBox.new({ height: 16 }),
                  fitted("scaleDown", "the child is bigger than the box, so the same as contain: 100 × 50"),
                ),
              ],
            }),
          }),
        }),
      }),
    }),
});

// Pushed from layout (A3.6): no AppBar, so the status bar and the notch reach
// the body. Two halves: SafeArea on all edges, and SafeArea with top false.
const layoutSafePage = PageDefinition.create({
  id: "layout-safe",
  title: "SafeArea",
  render: () =>
    Scaffold.new({
      body: Row.new({
        crossAxisAlignment: "stretch",
        children: [
          Expanded.new({
            child: SafeArea.new({
              child: Container.new({
                padding: EdgeInsets.all(12),
                alignment: "center",
                color: blue,
                child: Column.new({
                  mainAxisSize: "min",
                  children: [
                    Text.new({
                      data: "SafeArea, all edges: this colour stops below the notch",
                      textAlign: "center",
                      style: { color: "#FFFFFF" },
                    }),
                    SizedBox.new({ height: 16 }),
                    ElevatedButton.new({ child: Text.new({ data: "Back" }), actions: { onTap: GoBack() } }),
                  ],
                }),
              }),
            }),
          }),
          Expanded.new({
            child: SafeArea.new({
              top: false,
              child: Container.new({
                padding: EdgeInsets.all(12),
                alignment: "center",
                color: amber,
                child: Text.new({
                  data: "SafeArea top false: this colour reaches under the status bar",
                  textAlign: "center",
                }),
              }),
            }),
          }),
        ],
      }),
    }),
});

// ── Step 4 · effects: the 11 visual effect and touch wrappers (A4.1-A4.5) ─────

/** A `columns` × `rows` board of `size` squares, grey and white in turn. */
function checks(columns: number, rows: number, size: number): Widget {
  return Column.new({
    mainAxisSize: "min",
    children: Array.from({ length: rows }, (_, r) =>
      Row.new({
        mainAxisSize: "min",
        children: Array.from({ length: columns }, (_, c) =>
          Container.new({ width: size, height: size, color: (r + c) % 2 === 0 ? grey : "#FFFFFF" }),
        ),
      }),
    ),
  });
}

/** `count` upright stripes, each `width` × `height`, the four colours in turn. */
function stripes(count: number, width: number, height: number): Widget {
  return Row.new({
    mainAxisSize: "min",
    children: Array.from({ length: count }, (_, i) =>
      Container.new({ width, height, color: wrapColors[i % wrapColors.length]! }),
    ),
  });
}

/** A 64 × 64 Stack whose 96 × 96 stripes spill 16 past each edge (a Stack does not clip), handed to `wrap`. */
function spill(wrap: (stack: Widget) => Widget): Widget {
  return Padding.new({
    padding: EdgeInsets.all(16),
    child: SizedBox.new({
      width: 64,
      height: 64,
      child: wrap(
        Stack.new({
          children: [
            SizedBox.new({ width: 64, height: 64 }),
            Positioned.new({ left: -16, top: -16, child: stripes(6, 16, 96) }),
          ],
        }),
      ),
    }),
  });
}

/** A width × height box with a centred label (bold when asked) and nothing drawn: what is behind it shows. */
function clearBox(label: string, width: number, height: number, bold = false): Widget {
  return SizedBox.new({
    width,
    height,
    child: Center.new({ child: Text.new({ data: label, ...(bold ? { style: { fontWeight: "bold" } } : {}) }) }),
  });
}

/** A 64 × 64 ring, two colours: an amber disc inside a 10-wide blue rim, the corners clear. */
function ring(): Widget {
  return Container.new({
    width: 64,
    height: 64,
    decoration: { color: amber, borderRadius: 32, border: { width: 10, color: blue } },
  });
}

/** Behind: a 240 × 120 grey tap area counting into `behindKey`. In front, centred: a button counting into `frontKey`, handed to `wrap`. */
function overlap(behindKey: string, frontKey: string, wrap: (button: Widget) => Widget): Widget {
  return Stack.new({
    alignment: "center",
    children: [
      GestureDetector.new({
        actions: { onTap: bump(behindKey) },
        child: Container.new({
          width: 240,
          height: 120,
          alignment: "topLeft",
          padding: EdgeInsets.all(8),
          color: pale,
          child: Text.new({ data: "behind: tap the grey" }),
        }),
      }),
      wrap(ElevatedButton.new({ child: Text.new({ data: "front" }), actions: { onTap: bump(frontKey) } })),
    ],
  });
}

const effectsPage = PageDefinition.create({
  id: "effects",
  title: "Effects",
  state: [
    { key: "absorbBehind", scope: "page", initial: 0 },
    { key: "absorbFront", scope: "page", initial: 0 },
    { key: "ignoreBehind", scope: "page", initial: 0 },
    { key: "ignoreFront", scope: "page", initial: 0 },
    { key: "ignoring", scope: "page", initial: true },
  ],
  render: () =>
    Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Effects (step 4)" }) }),
      body: SingleChildScrollView.new({
        child: Padding.new({
          padding: EdgeInsets.all(16),
          child: Column.new({
            crossAxisAlignment: "start",
            children: [
              section(
                "A4.1 Opacity 0.5, RotatedBox one quarter turn",
                caption("Opacity 0.5 (left) and 1 (right), the same blue box over the checks: they show through the left one only"),
                SizedBox.new({ height: 4 }),
                Stack.new({
                  alignment: "center",
                  children: [
                    checks(10, 4, 20),
                    Row.new({
                      mainAxisSize: "min",
                      gap: 16,
                      children: [Opacity.new({ opacity: 0.5, child: block("0.5", blue, 80, 40) }), block("1", blue, 80, 40)],
                    }),
                  ],
                }),
                SizedBox.new({ height: 12 }),
                caption("RotatedBox quarterTurns 1 around a 120 × 40 box, top-left in a 140 × 140 grey box: it takes 40 × 120, the label reads downwards, 100 grey to its right and 20 below it"),
                SizedBox.new({ height: 4 }),
                Container.new({
                  width: 140,
                  height: 140,
                  alignment: "topLeft",
                  color: pale,
                  child: RotatedBox.new({ quarterTurns: 1, child: block("120 × 40", green, 120, 40) }),
                }),
              ),
              section(
                "A4.2 ClipRect, ClipOval, DecoratedBox",
                caption("The same 64 × 64 box with stripes spilling 16 past each edge: no clip, ClipRect (a 64 × 64 square), ClipOval (a 64 circle)"),
                SizedBox.new({ height: 4 }),
                Row.new({
                  mainAxisSize: "min",
                  gap: 8,
                  children: [
                    spill((stack) => stack),
                    spill((stack) => ClipRect.new({ child: stack })),
                    spill((stack) => ClipOval.new({ child: stack })),
                  ],
                }),
                SizedBox.new({ height: 12 }),
                caption("A 6 blue border on grey: DecoratedBox stays 80 × 40, the border under its label; a Container with the same decoration grows to 92 × 52, the label inset. Last, DecoratedBox foreground: a 6 red border over the amber box, still 80 × 40"),
                SizedBox.new({ height: 4 }),
                Row.new({
                  mainAxisSize: "min",
                  crossAxisAlignment: "start",
                  gap: 16,
                  children: [
                    DecoratedBox.new({ decoration: { color: pale, border: { width: 6, color: blue } }, child: clearBox("80 × 40", 80, 40) }),
                    Container.new({ decoration: { color: pale, border: { width: 6, color: blue } }, child: clearBox("80 × 40", 80, 40) }),
                    DecoratedBox.new({
                      position: "foreground",
                      decoration: { border: { width: 6, color: red } },
                      child: block("80 × 40", amber, 80, 40),
                    }),
                  ],
                }),
              ),
              section(
                "A4.3 ColorFiltered, BackdropFilter, BlurView",
                caption("The two-colour ring as is; ColorFiltered multiply #64B5F6: the ring's two colours darken and the clear corners take #64B5F6, kept to the 64 × 64 box by a ClipRect (Flutter's filter reaches the nearest clip, the natives stop at the box); srcIn green: a green disc, the corners stay clear"),
                SizedBox.new({ height: 4 }),
                Row.new({
                  mainAxisSize: "min",
                  gap: 16,
                  children: [
                    ring(),
                    ClipRect.new({ child: ColorFiltered.new({ color: "#64B5F6", blendMode: "multiply", child: ring() }) }),
                    ColorFiltered.new({ color: green, blendMode: "srcIn", child: ring() }),
                  ],
                }),
                SizedBox.new({ height: 12 }),
                caption("BackdropFilter sigma 6 on the stripes: blurred inside the 140 × 60 box only, sharp around it (the ClipRect keeps Flutter's blur to the box, as the natives do)"),
                SizedBox.new({ height: 4 }),
                Stack.new({
                  alignment: "center",
                  children: [
                    stripes(12, 20, 100),
                    ClipRect.new({ child: BackdropFilter.new({ blurX: 6, blurY: 6, child: clearBox("sigma 6", 140, 60, true) }) }),
                  ],
                }),
                SizedBox.new({ height: 12 }),
                caption("BlurView sigma 8, overlay #FFFFFF80, radius 12: frosted, half white, round corners"),
                SizedBox.new({ height: 4 }),
                Stack.new({
                  alignment: "center",
                  children: [
                    stripes(12, 20, 100),
                    BlurView.new({ blurX: 8, blurY: 8, overlayColor: "#FFFFFF80", borderRadius: 12, child: clearBox("BlurView 8", 140, 60, true) }),
                  ],
                }),
              ),
              section(
                "A4.4 AbsorbPointer, IgnorePointer",
                caption("AbsorbPointer around the front button: a tap on it moves neither count; a tap on the grey around it counts behind"),
                shows("behind", "absorbBehind"),
                shows("front", "absorbFront"),
                SizedBox.new({ height: 4 }),
                overlap("absorbBehind", "absorbFront", (button) => AbsorbPointer.new({ child: button })),
                SizedBox.new({ height: 12 }),
                caption("IgnorePointer around the front button: ignoring true, a tap on it counts behind; flipped to false, it counts front"),
                shows("ignoring", "ignoring"),
                shows("behind", "ignoreBehind"),
                shows("front", "ignoreFront"),
                SizedBox.new({ height: 4 }),
                OutlinedButton.new({
                  child: Text.new({ data: "Flip ignoring" }),
                  actions: { onTap: SetState("ignoring", V.transform(V.pageState("ignoring"), [TV.not()])) },
                }),
                SizedBox.new({ height: 8 }),
                overlap("ignoreBehind", "ignoreFront", (button) =>
                  IgnorePointer.new({ ignoring: V.pageState("ignoring"), child: button }),
                ),
              ),
              section(
                "A4.5 InteractiveViewer (defaults) around a 5 × 5 numbered grid in a 296 × 200 box",
                caption("Pinch to zoom: in up to 2.5, never out below 1 (the grid fills the box, whatever minScale 0.8 says). Then drag sideways to pan: it stops at the grid's edges; at scale 1 nothing pans. An up/down drag scrolls the page. Nothing draws outside the box"),
                SizedBox.new({ height: 4 }),
                Container.new({
                  width: 296,
                  height: 200,
                  color: pale,
                  child: InteractiveViewer.new({
                    child: Wrap.new({ spacing: 12, runSpacing: 10, children: numberedBoxes(25) }),
                  }),
                }),
              ),
            ],
          }),
        }),
      }),
    }),
});

const parityFlow = Flow.create({
  name: "parity",
  routes: [
    { path: "polish", page: polishPage },
    { path: "polish-pushed", page: polishPushedPage },
    { path: "polish-no-back", page: polishNoBackPage },
    { path: "lifecycle", page: lifecyclePage },
    { path: "layout", page: layoutPage },
    { path: "layout-safe", page: layoutSafePage },
    { path: "effects", page: effectsPage },
  ],
});

export const parityAApp = App.create({
  id: "parity-a",
  name: "Native parity A",
  flows: [parityFlow],
});
