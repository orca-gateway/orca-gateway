import { App, Flow, PageDefinition } from "../../engine/src/core";
import { V, TV, SetState, Navigate, GoBack, type Widget } from "../../engine/src/types";
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
} from "../../engine/src/components";

// Native parity, Phase A (pipeline native-parity). One app, one page per plan
// step, each the "torture" page for the props that step brings to Swift and
// Kotlin, so the same page can be compared on Flutter, iOS and Android.
// Pages: polish (step 1). Later steps add lifecycle, layout, effects, lists,
// forms, rich and overlays: one page constant each, one entry in `routes`.
// Images come from picsum.photos; offline they draw "!" in their box. Only
// widgets all three SDKs draw (no Wrap: the native SDKs lack it and the
// capability filter would hoist its children into the parent).

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
  return Container.new({
    width: 48,
    height: 32,
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

const parityFlow = Flow.create({
  name: "parity",
  routes: [
    { path: "polish", page: polishPage },
    { path: "polish-pushed", page: polishPushedPage },
    { path: "polish-no-back", page: polishNoBackPage },
  ],
});

export const parityAApp = App.create({
  id: "parity-a",
  name: "Native parity A",
  flows: [parityFlow],
});
