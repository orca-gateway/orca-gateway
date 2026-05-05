import { describe, expect, it } from "bun:test";
import { Encoder } from "../src/types/widget";
import { V, Expr } from "../src/types/value";
import { Navigate, SetState } from "../src/types/action";
import {
  // Helpers
  EdgeInsets,
  TextStyle,
  BoxDecoration,
  BorderRadius,
  Color,
  Colors,
  Alignment,
  // Layout
  Column,
  Row,
  Container,
  Stack,
  Wrap,
  SingleChildScrollView,
  Expanded,
  Flexible,
  Padding,
  SizedBox,
  // Primitives
  Text,
  Image,
  Icon,
  Divider,
  Spacer,
  CircularProgressIndicator,
  // Inputs
  TextField,
  Checkbox,
  Switch,
  Slider,
  // Buttons
  ElevatedButton,
  TextButton,
  IconButton,
  // Structure
  Scaffold,
  AppBar,
  Card,
  ListView,
  GridView,
  Dialog,
  BottomSheet,
  CustomScrollView,
  SliverList,
  SliverGrid,
  SliverToBoxAdapter,
  SliverAppBar,
} from "../src/components";

// ── 3.23: Helper types ─────────────────────────────────────

describe("EdgeInsets", () => {
  it("all", () => {
    expect(EdgeInsets.all(16)).toEqual({ top: 16, right: 16, bottom: 16, left: 16 });
  });

  it("symmetric", () => {
    expect(EdgeInsets.symmetric({ horizontal: 8, vertical: 16 })).toEqual({
      top: 16, right: 8, bottom: 16, left: 8,
    });
  });

  it("symmetric defaults to 0", () => {
    expect(EdgeInsets.symmetric({ horizontal: 8 })).toEqual({
      top: 0, right: 8, bottom: 0, left: 8,
    });
  });

  it("only", () => {
    expect(EdgeInsets.only({ top: 10, left: 5 })).toEqual({
      top: 10, right: 0, bottom: 0, left: 5,
    });
  });
});

describe("TextStyle", () => {
  it("creates style data", () => {
    const s = TextStyle({ fontSize: 16, fontWeight: "bold", color: Colors.black });
    expect(s.fontSize).toBe(16);
    expect(s.fontWeight).toBe("bold");
    expect(s.color).toBe("0xFF000000");
  });
});

describe("BoxDecoration", () => {
  it("creates decoration data", () => {
    const d = BoxDecoration({
      color: Colors.white,
      borderRadius: 8,
      border: { width: 1, color: Colors.grey },
    });
    expect(d.color).toBe("0xFFFFFFFF");
    expect(d.borderRadius).toBe(8);
  });
});

describe("BorderRadius", () => {
  it("all", () => {
    expect(BorderRadius.all(8)).toEqual({ topLeft: 8, topRight: 8, bottomLeft: 8, bottomRight: 8 });
  });

  it("circular", () => {
    expect(BorderRadius.circular(12)).toEqual(BorderRadius.all(12));
  });

  it("only", () => {
    expect(BorderRadius.only({ topLeft: 8, topRight: 8 })).toEqual({ topLeft: 8, topRight: 8 });
  });
});

describe("Color & Colors", () => {
  it("#RRGGBB → 0xFFRRGGBB", () => {
    expect(Color("#FF0000")).toBe("0xFFFF0000");
    expect(Color("#2196F3")).toBe("0xFF2196F3");
  });

  it("#RGB → 0xFFRRGGBB (expanded)", () => {
    expect(Color("#F00")).toBe("0xFFFF0000");
    expect(Color("#09C")).toBe("0xFF0099CC");
  });

  it("#RGBA → 0xAARRGGBB", () => {
    expect(Color("#F008")).toBe("0x88FF0000");
    expect(Color("#0000")).toBe("0x00000000");
  });

  it("#RRGGBBAA → 0xAARRGGBB", () => {
    expect(Color("#FF000080")).toBe("0x80FF0000");
    expect(Color("#2196F3CC")).toBe("0xCC2196F3");
    expect(Color("#00000000")).toBe("0x00000000");
  });

  it("0xAARRGGBB passthrough", () => {
    expect(Color("0xFF2196F3")).toBe("0xFF2196F3");
    expect(Color("0x80FF0000")).toBe("0x80FF0000");
  });

  it("lowercase input is uppercased", () => {
    expect(Color("#ff0000")).toBe("0xFFFF0000");
    expect(Color("#abcdef")).toBe("0xFFABCDEF");
  });

  it("Colors has standard values in ARGB format", () => {
    expect(Colors.red).toBe("0xFFF44336");
    expect(Colors.blue).toBe("0xFF2196F3");
    expect(Colors.transparent).toBe("0x00000000");
    expect(Colors.white).toBe("0xFFFFFFFF");
    expect(Colors.black).toBe("0xFF000000");
  });
});

describe("Alignment", () => {
  it("has all positions", () => {
    expect(Alignment.center).toBe("center");
    expect(Alignment.topLeft).toBe("topLeft");
    expect(Alignment.bottomRight).toBe("bottomRight");
  });
});

// ── 3.1: Column ────────────────────────────────────────────

describe("Column", () => {
  it("encodes with childMode multi and children as ID array", () => {
    const col = Column.new({
      children: [Text.new({ data: "A" }), Text.new({ data: "B" })],
      gap: 8,
    });
    const encoder = new Encoder();
    encoder.addNode(col);
    const nodes = encoder.getNodes();

    expect(nodes).toHaveLength(3);
    const colNode = nodes.find(n => n.type === "Column")!;
    expect(colNode.kind).toBe("layout");
    expect(colNode.childMode).toBe("multi");
    expect(colNode.children).toHaveLength(2);
    expect(colNode.props.gap).toBe(8);
  });

  it("supports mainAxisAlignment and crossAxisAlignment", () => {
    const col = Column.new({
      children: [],
      mainAxisAlignment: "center",
      crossAxisAlignment: "stretch",
    });
    expect(col.getProps().mainAxisAlignment).toBe("center");
    expect(col.getProps().crossAxisAlignment).toBe("stretch");
  });
});

// ── 3.2: Row ───────────────────────────────────────────────

describe("Row", () => {
  it("encodes same as Column with horizontal axis", () => {
    const row = Row.new({
      children: [Text.new({ data: "X" })],
      gap: 4,
      mainAxisAlignment: "spaceBetween",
    });
    const encoder = new Encoder();
    encoder.addNode(row);
    const nodes = encoder.getNodes();

    const rowNode = nodes.find(n => n.type === "Row")!;
    expect(rowNode.kind).toBe("layout");
    expect(rowNode.childMode).toBe("multi");
    expect(rowNode.children).toHaveLength(1);
    expect(rowNode.props.gap).toBe(4);
    expect(rowNode.props.mainAxisAlignment).toBe("spaceBetween");
  });
});

// ── 3.3: Container ─────────────────────────────────────────

describe("Container", () => {
  it("encodes with childMode single", () => {
    const c = Container.new({
      child: Text.new({ data: "inside" }),
      padding: EdgeInsets.all(16),
    });
    const encoder = new Encoder();
    encoder.addNode(c);
    const nodes = encoder.getNodes();

    expect(nodes).toHaveLength(2);
    const containerNode = nodes.find(n => n.type === "Container")!;
    expect(containerNode.childMode).toBe("single");
    expect(containerNode.children).toHaveLength(1);
    expect(containerNode.props.padding).toEqual(EdgeInsets.all(16));
  });

  it("supports decoration, width, height, alignment", () => {
    const c = Container.new({
      width: 200,
      height: 100,
      alignment: "center",
      color: Colors.blue,
      decoration: BoxDecoration({ borderRadius: 8 }),
    });
    const props = c.getProps();
    expect(props.width).toBe(200);
    expect(props.height).toBe(100);
    expect(props.alignment).toBe("center");
    expect(props.color).toBe(Colors.blue);
  });
});

// ── 3.4: Stack ─────────────────────────────────────────────

describe("Stack", () => {
  it("multi-child with positioning props", () => {
    const s = Stack.new({
      children: [Text.new({ data: "bg" }), Text.new({ data: "fg" })],
      fit: "expand",
      alignment: "center",
    });
    const encoder = new Encoder();
    encoder.addNode(s);
    const nodes = encoder.getNodes();

    const stackNode = nodes.find(n => n.type === "Stack")!;
    expect(stackNode.childMode).toBe("multi");
    expect(stackNode.children).toHaveLength(2);
    expect(stackNode.props.fit).toBe("expand");
    expect(stackNode.props.alignment).toBe("center");
  });
});

// ── 3.5: Wrap ──────────────────────────────────────────────

describe("Wrap", () => {
  it("multi-child with wrapping props", () => {
    const w = Wrap.new({
      children: [Text.new({ data: "tag1" }), Text.new({ data: "tag2" })],
      spacing: 8,
      runSpacing: 4,
    });
    expect(w.getProps().spacing).toBe(8);
    expect(w.getProps().runSpacing).toBe(4);
  });
});

// ── 3.6: SingleChildScrollView ─────────────────────────────

describe("SingleChildScrollView", () => {
  it("single-child scrollable", () => {
    const sv = SingleChildScrollView.new({
      child: Column.new({ children: [] }),
      scrollDirection: "vertical",
      padding: EdgeInsets.all(8),
    });
    const encoder = new Encoder();
    encoder.addNode(sv);
    const nodes = encoder.getNodes();

    const svNode = nodes.find(n => n.type === "SingleChildScrollView")!;
    expect(svNode.childMode).toBe("single");
    expect(svNode.children).toHaveLength(1);
    expect(svNode.props.scrollDirection).toBe("vertical");
  });
});

// ── 3.7: Expanded / Flexible ───────────────────────────────

describe("Expanded", () => {
  it("single-child with flex", () => {
    const e = Expanded.new({ child: Text.new({ data: "fill" }), flex: 2 });
    const encoder = new Encoder();
    encoder.addNode(e);
    const nodes = encoder.getNodes();

    const eNode = nodes.find(n => n.type === "Expanded")!;
    expect(eNode.childMode).toBe("single");
    expect(eNode.children).toHaveLength(1);
    expect(eNode.props.flex).toBe(2);
  });
});

describe("Flexible", () => {
  it("single-child with flex and fit", () => {
    const f = Flexible.new({ child: Text.new({ data: "flex" }), flex: 3, fit: "tight" });
    expect(f.getProps().flex).toBe(3);
    expect(f.getProps().fit).toBe("tight");
  });
});

// ── 3.8: Padding ───────────────────────────────────────────

describe("Padding", () => {
  it("single-child with EdgeInsets", () => {
    const p = Padding.new({
      child: Text.new({ data: "padded" }),
      padding: EdgeInsets.symmetric({ horizontal: 16, vertical: 8 }),
    });
    const encoder = new Encoder();
    encoder.addNode(p);
    const nodes = encoder.getNodes();

    const pNode = nodes.find(n => n.type === "Padding")!;
    expect(pNode.childMode).toBe("single");
    expect(pNode.children).toHaveLength(1);
    expect(pNode.props.padding).toEqual({ top: 8, right: 16, bottom: 8, left: 16 });
  });
});

// ── 3.9: SizedBox ──────────────────────────────────────────

describe("SizedBox", () => {
  it("width/height constraints", () => {
    const sb = SizedBox.new({ width: 100, height: 50 });
    expect(sb.getProps().width).toBe(100);
    expect(sb.getProps().height).toBe(50);
  });

  it("can wrap a child", () => {
    const sb = SizedBox.new({ child: Text.new({ data: "box" }), width: 200 });
    const encoder = new Encoder();
    encoder.addNode(sb);
    const nodes = encoder.getNodes();
    expect(nodes).toHaveLength(2);
    expect(nodes.find(n => n.type === "SizedBox")!.children).toHaveLength(1);
  });
});

// ── 3.10: Text ─────────────────────────────────────────────

describe("Text", () => {
  it("accepts string data", () => {
    const t = Text.new({ data: "Hello" });
    expect(t.kind).toBe("primitive");
    expect(t.childMode).toBe("none");
    expect(t.getProps().data).toBe("Hello");
  });

  it("accepts Value data", () => {
    const t = Text.new({ data: V.pageState("name") });
    expect(t.getProps().data).toEqual(V.pageState("name"));
  });

  it("accepts TextStyle", () => {
    const t = Text.new({
      data: "styled",
      style: TextStyle({ fontSize: 24, fontWeight: "w700" }),
    });
    expect((t.getProps().style as any).fontSize).toBe(24);
  });

  it("encodes watches from Value data", () => {
    const t = Text.new({ data: V.pageState("username") });
    const encoder = new Encoder();
    encoder.addNode(t);
    expect(encoder.getNodes()[0].watches).toEqual(["username"]);
  });
});

// ── 3.11: Image ────────────────────────────────────────────

describe("Image", () => {
  it("src, fit, width, height", () => {
    const img = Image.new({ src: "https://example.com/img.png", fit: "cover", width: 300, height: 200 });
    expect(img.kind).toBe("primitive");
    expect(img.getProps().src).toBe("https://example.com/img.png");
    expect(img.getProps().fit).toBe("cover");
  });

  it("accepts Value for src", () => {
    const img = Image.new({ src: V.pageState("avatarUrl") });
    const encoder = new Encoder();
    encoder.addNode(img);
    expect(encoder.getNodes()[0].watches).toEqual(["avatarUrl"]);
  });
});

// ── 3.12: Icon ─────────────────────────────────────────────

describe("Icon", () => {
  it("name, size, color", () => {
    const icon = Icon.new({ name: "home", size: 24, color: Colors.blue });
    expect(icon.kind).toBe("primitive");
    expect(icon.getProps().name).toBe("home");
    expect(icon.getProps().size).toBe(24);
    expect(icon.getProps().color).toBe(Colors.blue);
  });
});

// ── 3.13: Divider / Spacer ─────────────────────────────────

describe("Divider", () => {
  it("default props", () => {
    const d = Divider.new();
    expect(d.kind).toBe("primitive");
    expect(d.childMode).toBe("none");
  });

  it("custom props", () => {
    const d = Divider.new({ thickness: 2, color: Colors.grey, indent: 16 });
    expect(d.getProps().thickness).toBe(2);
    expect(d.getProps().indent).toBe(16);
  });
});

describe("Spacer", () => {
  it("default props", () => {
    const s = Spacer.new();
    expect(s.kind).toBe("primitive");
  });

  it("with flex", () => {
    expect(Spacer.new({ flex: 2 }).getProps().flex).toBe(2);
  });
});

// ── 3.14: TextField ────────────────────────────────────────

describe("TextField", () => {
  it("value, placeholder, onChange action, inputType", () => {
    const tf = TextField.new({
      value: V.pageState("email"),
      placeholder: "Enter email",
      inputType: "email",
      actions: { onChange: SetState("email", V.static("")) },
    });
    expect(tf.kind).toBe("input");
    expect(tf.childMode).toBe("none");
    expect(tf.getProps().placeholder).toBe("Enter email");
    expect(tf.getProps().inputType).toBe("email");
    expect(tf.actions?.onChange).toBeDefined();
  });

  it("encodes watches from value prop", () => {
    const tf = TextField.new({ value: V.pageState("query") });
    const encoder = new Encoder();
    encoder.addNode(tf);
    expect(encoder.getNodes()[0].watches).toEqual(["query"]);
  });
});

// ── 3.15: Checkbox / Switch / Slider ───────────────────────

describe("Checkbox", () => {
  it("value and onChange", () => {
    const cb = Checkbox.new({
      value: V.pageState("agree"),
      label: "I agree",
      actions: { onChange: SetState("agree", V.static(false)) },
    });
    expect(cb.kind).toBe("input");
    expect(cb.getProps().label).toBe("I agree");
  });
});

describe("Switch", () => {
  it("value and onChange", () => {
    const sw = Switch.new({
      value: V.pageState("darkMode"),
      activeColor: Colors.blue,
    });
    expect(sw.kind).toBe("input");
    expect(sw.getProps().activeColor).toBe(Colors.blue);
  });
});

describe("Slider", () => {
  it("value, min, max, divisions", () => {
    const sl = Slider.new({
      value: V.pageState("volume"),
      min: 0,
      max: 100,
      divisions: 10,
    });
    expect(sl.kind).toBe("input");
    expect(sl.getProps().min).toBe(0);
    expect(sl.getProps().max).toBe(100);
    expect(sl.getProps().divisions).toBe(10);
  });
});

// ── 3.16: ElevatedButton / TextButton / IconButton ─────────

describe("ElevatedButton", () => {
  it("child widget + onTap action", () => {
    const btn = ElevatedButton.new({
      child: Text.new({ data: "Submit" }),
      actions: { onTap: Navigate("/success") },
    });
    expect(btn.kind).toBe("button");
    expect(btn.childMode).toBe("single");
    expect(btn.actions?.onTap).toEqual(Navigate("/success"));
  });

  it("encodes child into flat array", () => {
    const btn = ElevatedButton.new({
      child: Text.new({ data: "Go" }),
    });
    const encoder = new Encoder();
    encoder.addNode(btn);
    const nodes = encoder.getNodes();
    expect(nodes).toHaveLength(2);
    const btnNode = nodes.find(n => n.type === "ElevatedButton")!;
    expect(btnNode.children).toHaveLength(1);
  });
});

describe("TextButton", () => {
  it("child + props", () => {
    const btn = TextButton.new({
      child: Text.new({ data: "Cancel" }),
      color: Colors.red,
    });
    expect(btn.kind).toBe("button");
    expect(btn.getProps().color).toBe(Colors.red);
  });
});

describe("IconButton", () => {
  it("child + size", () => {
    const btn = IconButton.new({
      child: Icon.new({ name: "menu" }),
      size: 48,
      actions: { onTap: Navigate("/menu") },
    });
    expect(btn.kind).toBe("button");
    expect(btn.getProps().size).toBe(48);
  });
});

// ── 3.17: CircularProgressIndicator ────────────────────────

describe("CircularProgressIndicator", () => {
  it("default (indeterminate)", () => {
    const cpi = CircularProgressIndicator.new();
    expect(cpi.kind).toBe("primitive");
    expect(cpi.type).toBe("CircularProgressIndicator");
  });

  it("determinate with value", () => {
    const cpi = CircularProgressIndicator.new({ value: V.pageState("progress"), color: Colors.blue });
    expect(cpi.getProps().color).toBe(Colors.blue);

    const encoder = new Encoder();
    encoder.addNode(cpi);
    expect(encoder.getNodes()[0].watches).toEqual(["progress"]);
  });
});

// ── 3.18: Scaffold ─────────────────────────────────────────

describe("Scaffold", () => {
  it("encodes appBar, body, floatingActionButton as slot children", () => {
    const scaffold = Scaffold.new({
      appBar: AppBar.new({ title: Text.new({ data: "Home" }) }),
      body: Column.new({ children: [Text.new({ data: "content" })] }),
      backgroundColor: Colors.white,
    });
    const encoder = new Encoder();
    encoder.addNode(scaffold);
    const nodes = encoder.getNodes();

    const scaffoldNode = nodes.find(n => n.type === "Scaffold")!;
    expect(scaffoldNode.kind).toBe("structure");
    expect(scaffoldNode.props.backgroundColor).toBe(Colors.white);
    // Slots are encoded as children
    expect(scaffoldNode.children.length).toBeGreaterThanOrEqual(2);
    // Slot IDs stored in props
    expect(scaffoldNode.props.appBar).toBeDefined();
    expect(scaffoldNode.props.body).toBeDefined();
  });
});

// ── 3.19: AppBar ───────────────────────────────────────────

describe("AppBar", () => {
  it("title, leading, actions, backgroundColor", () => {
    const bar = AppBar.new({
      title: Text.new({ data: "Settings" }),
      leading: IconButton.new({ child: Icon.new({ name: "arrow_back" }) }),
      backgroundColor: Colors.blue,
      centerTitle: true,
    });
    const encoder = new Encoder();
    encoder.addNode(bar);
    const nodes = encoder.getNodes();

    const barNode = nodes.find(n => n.type === "AppBar")!;
    expect(barNode.kind).toBe("structure");
    expect(barNode.props.backgroundColor).toBe(Colors.blue);
    expect(barNode.props.centerTitle).toBe(true);
    expect(barNode.props.title).toBeDefined();
    expect(barNode.props.leading).toBeDefined();
  });
});

// ── 3.20: Card ─────────────────────────────────────────────

describe("Card", () => {
  it("child, elevation, padding", () => {
    const card = Card.new({
      child: Text.new({ data: "card content" }),
      elevation: 4,
      padding: EdgeInsets.all(16),
    });
    expect(card.kind).toBe("layout");
    expect(card.childMode).toBe("single");
    expect(card.getProps().elevation).toBe(4);
    expect(card.getProps().padding).toEqual(EdgeInsets.all(16));

    const encoder = new Encoder();
    encoder.addNode(card);
    expect(encoder.getNodes()).toHaveLength(2);
  });
});

// ── 3.21: ListView / GridView ──────────────────────────────

describe("ListView", () => {
  it("children, scrollDirection", () => {
    const lv = ListView.new({
      children: [Text.new({ data: "item 1" }), Text.new({ data: "item 2" })],
      scrollDirection: "vertical",
      shrinkWrap: true,
    });
    expect(lv.kind).toBe("layout");
    expect(lv.childMode).toBe("multi");
    expect(lv.getProps().scrollDirection).toBe("vertical");
    expect(lv.getProps().shrinkWrap).toBe(true);

    const encoder = new Encoder();
    encoder.addNode(lv);
    const nodes = encoder.getNodes();
    expect(nodes.find(n => n.type === "ListView")!.children).toHaveLength(2);
  });
});

describe("GridView", () => {
  it("children, crossAxisCount, spacing", () => {
    const gv = GridView.new({
      children: [Text.new({ data: "1" }), Text.new({ data: "2" }), Text.new({ data: "3" })],
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    });
    expect(gv.getProps().crossAxisCount).toBe(2);
    expect(gv.getProps().mainAxisSpacing).toBe(8);

    const encoder = new Encoder();
    encoder.addNode(gv);
    expect(encoder.getNodes().find(n => n.type === "GridView")!.children).toHaveLength(3);
  });
});

// ── 3.22: Dialog / BottomSheet ─────────────────────────────

describe("Dialog", () => {
  it("child, dismissible", () => {
    const d = Dialog.new({
      child: Text.new({ data: "Are you sure?" }),
      dismissible: false,
      borderRadius: 12,
    });
    expect(d.childMode).toBe("single");
    expect(d.getProps().dismissible).toBe(false);
    expect(d.getProps().borderRadius).toBe(12);
  });
});

describe("BottomSheet", () => {
  it("child, dismissible", () => {
    const bs = BottomSheet.new({
      child: Column.new({ children: [Text.new({ data: "sheet" })] }),
      dismissible: true,
    });
    expect(bs.childMode).toBe("single");
    expect(bs.getProps().dismissible).toBe(true);
  });
});

// ── CustomScrollView ───────────────────────────────────────

describe("CustomScrollView", () => {
  it("takes slivers as children", () => {
    const csv = CustomScrollView.new({
      slivers: [
        SliverList.new({ children: [Text.new({ data: "item" })] }),
        SliverToBoxAdapter.new({ child: Text.new({ data: "box" }) }),
      ],
      scrollDirection: "vertical",
    });
    const encoder = new Encoder();
    encoder.addNode(csv);
    const nodes = encoder.getNodes();

    const csvNode = nodes.find(n => n.type === "CustomScrollView")!;
    expect(csvNode.kind).toBe("layout");
    expect(csvNode.childMode).toBe("multi");
    expect(csvNode.children).toHaveLength(2);
    expect(csvNode.props.scrollDirection).toBe("vertical");
  });

  it("supports reverse and shrinkWrap", () => {
    const csv = CustomScrollView.new({
      slivers: [],
      reverse: true,
      shrinkWrap: true,
    });
    expect(csv.getProps().reverse).toBe(true);
    expect(csv.getProps().shrinkWrap).toBe(true);
  });
});

// ── SliverList ─────────────────────────────────────────────

describe("SliverList", () => {
  it("multi-child sliver", () => {
    const sl = SliverList.new({
      children: [Text.new({ data: "a" }), Text.new({ data: "b" })],
    });
    const encoder = new Encoder();
    encoder.addNode(sl);
    const nodes = encoder.getNodes();

    const slNode = nodes.find(n => n.type === "SliverList")!;
    expect(slNode.childMode).toBe("multi");
    expect(slNode.children).toHaveLength(2);
  });
});

// ── SliverGrid ─────────────────────────────────────────────

describe("SliverGrid", () => {
  it("multi-child with crossAxisCount", () => {
    const sg = SliverGrid.new({
      children: [Text.new({ data: "1" }), Text.new({ data: "2" })],
      crossAxisCount: 3,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
    });
    expect(sg.getProps().crossAxisCount).toBe(3);
    expect(sg.getProps().mainAxisSpacing).toBe(4);

    const encoder = new Encoder();
    encoder.addNode(sg);
    expect(encoder.getNodes().find(n => n.type === "SliverGrid")!.children).toHaveLength(2);
  });
});

// ── SliverToBoxAdapter ─────────────────────────────────────

describe("SliverToBoxAdapter", () => {
  it("wraps a single box widget", () => {
    const stba = SliverToBoxAdapter.new({
      child: Container.new({ child: Text.new({ data: "wrapped" }) }),
    });
    const encoder = new Encoder();
    encoder.addNode(stba);
    const nodes = encoder.getNodes();

    const stbaNode = nodes.find(n => n.type === "SliverToBoxAdapter")!;
    expect(stbaNode.childMode).toBe("single");
    expect(stbaNode.children).toHaveLength(1);
  });
});

// ── SliverAppBar ───────────────────────────────────────────

describe("SliverAppBar", () => {
  it("encodes title, leading, flexibleSpace as slots", () => {
    const bar = SliverAppBar.new({
      title: Text.new({ data: "Sliver" }),
      floating: true,
      pinned: true,
      expandedHeight: 200,
      backgroundColor: Colors.blue,
    });
    const encoder = new Encoder();
    encoder.addNode(bar);
    const nodes = encoder.getNodes();

    const barNode = nodes.find(n => n.type === "SliverAppBar")!;
    expect(barNode.kind).toBe("structure");
    expect(barNode.props.floating).toBe(true);
    expect(barNode.props.pinned).toBe(true);
    expect(barNode.props.expandedHeight).toBe(200);
    expect(barNode.props.backgroundColor).toBe(Colors.blue);
    expect(barNode.props.title).toBeDefined();
  });

  it("supports snap and flexibleSpace", () => {
    const bar = SliverAppBar.new({
      title: Text.new({ data: "Title" }),
      flexibleSpace: Image.new({ src: "bg.png", fit: "cover" }),
      floating: true,
      snap: true,
      expandedHeight: 300,
    });
    const encoder = new Encoder();
    encoder.addNode(bar);
    const nodes = encoder.getNodes();

    const barNode = nodes.find(n => n.type === "SliverAppBar")!;
    expect(barNode.props.snap).toBe(true);
    expect(barNode.props.flexibleSpace).toBeDefined();
    expect(barNode.children).toHaveLength(2); // title + flexibleSpace
  });
});

// ── Full sliver scroll tree ────────────────────────────────

describe("Full sliver scroll tree", () => {
  it("CustomScrollView with SliverAppBar + SliverList encodes correctly", () => {
    const tree = CustomScrollView.new({
      slivers: [
        SliverAppBar.new({
          title: Text.new({ data: "Products" }),
          pinned: true,
          expandedHeight: 200,
        }),
        SliverList.new({
          children: [
            Text.new({ data: "Item 1" }),
            Text.new({ data: "Item 2" }),
            Text.new({ data: "Item 3" }),
          ],
        }),
        SliverToBoxAdapter.new({
          child: Text.new({ data: "Footer" }),
        }),
      ],
    });

    const encoder = new Encoder();
    encoder.addNode(tree);
    const nodes = encoder.getNodes();

    // Text("Products") + SliverAppBar + 3 x Text(Item) + SliverList +
    // Text("Footer") + SliverToBoxAdapter + CustomScrollView = 9
    expect(nodes).toHaveLength(9);

    const csvNode = nodes.find(n => n.type === "CustomScrollView")!;
    expect(csvNode.children).toHaveLength(3); // 3 slivers
  });
});

// ── 3.24: Barrel export ────────────────────────────────────

describe("Barrel export", () => {
  it("all layout components importable", () => {
    expect(Column).toBeDefined();
    expect(Row).toBeDefined();
    expect(Container).toBeDefined();
    expect(Stack).toBeDefined();
    expect(Wrap).toBeDefined();
    expect(SingleChildScrollView).toBeDefined();
    expect(Expanded).toBeDefined();
    expect(Flexible).toBeDefined();
    expect(Padding).toBeDefined();
    expect(SizedBox).toBeDefined();
  });

  it("all primitive components importable", () => {
    expect(Text).toBeDefined();
    expect(Image).toBeDefined();
    expect(Icon).toBeDefined();
    expect(Divider).toBeDefined();
    expect(Spacer).toBeDefined();
    expect(CircularProgressIndicator).toBeDefined();
  });

  it("all input components importable", () => {
    expect(TextField).toBeDefined();
    expect(Checkbox).toBeDefined();
    expect(Switch).toBeDefined();
    expect(Slider).toBeDefined();
  });

  it("all button components importable", () => {
    expect(ElevatedButton).toBeDefined();
    expect(TextButton).toBeDefined();
    expect(IconButton).toBeDefined();
  });

  it("all structure components importable", () => {
    expect(Scaffold).toBeDefined();
    expect(AppBar).toBeDefined();
    expect(Card).toBeDefined();
    expect(ListView).toBeDefined();
    expect(GridView).toBeDefined();
    expect(Dialog).toBeDefined();
    expect(BottomSheet).toBeDefined();
    expect(CustomScrollView).toBeDefined();
    expect(SliverList).toBeDefined();
    expect(SliverGrid).toBeDefined();
    expect(SliverToBoxAdapter).toBeDefined();
    expect(SliverAppBar).toBeDefined();
  });

  it("all helper types importable", () => {
    expect(EdgeInsets).toBeDefined();
    expect(TextStyle).toBeDefined();
    expect(BoxDecoration).toBeDefined();
    expect(BorderRadius).toBeDefined();
    expect(Color).toBeDefined();
    expect(Colors).toBeDefined();
    expect(Alignment).toBeDefined();
  });
});

// ── 3.25: Encode correctness ───────────────────────────────

describe("Nested tree encode", () => {
  it("complex widget tree produces correct flat array", () => {
    const tree = Scaffold.new({
      appBar: AppBar.new({
        title: Text.new({ data: "Products" }),
      }),
      body: Column.new({
        children: [
          Container.new({
            child: Text.new({ data: V.pageState("title") }),
            padding: EdgeInsets.all(16),
          }),
          ElevatedButton.new({
            child: Text.new({ data: "Add to Cart" }),
            actions: { onTap: Navigate("/cart") },
          }),
          CircularProgressIndicator.new(),
        ],
      }),
    });

    const encoder = new Encoder();
    encoder.addNode(tree);
    const nodes = encoder.getNodes();

    // Count: Text("Products") + AppBar + Text(title) + Container +
    //        Text("Add to Cart") + ElevatedButton + CircularProgressIndicator +
    //        Column + Scaffold = 9
    expect(nodes).toHaveLength(9);

    // All have valid IDs
    const ids = nodes.map(n => n.id);
    expect(new Set(ids).size).toBe(9);

    // Root (Scaffold) is last
    const scaffold = nodes[nodes.length - 1];
    expect(scaffold.type).toBe("Scaffold");

    // Value watches propagate
    const containerNode = nodes.find(n => n.type === "Container")!;
    // Container itself doesn't watch, but its child Text does
    const textWithState = nodes.find(n => n.type === "Text" && n.watches.length > 0)!;
    expect(textWithState.watches).toEqual(["title"]);
  });

  it("all nodes have required fields", () => {
    const tree = ListView.new({
      children: [
        Card.new({
          child: Row.new({
            children: [
              Icon.new({ name: "star" }),
              Expanded.new({ child: Text.new({ data: "item" }) }),
            ],
          }),
        }),
      ],
    });

    const encoder = new Encoder();
    encoder.addNode(tree);
    const nodes = encoder.getNodes();

    for (const node of nodes) {
      expect(node).toHaveProperty("id");
      expect(node).toHaveProperty("type");
      expect(node).toHaveProperty("kind");
      expect(node).toHaveProperty("childMode");
      expect(node).toHaveProperty("props");
      expect(node).toHaveProperty("children");
      expect(node).toHaveProperty("watches");
      expect(typeof node.id).toBe("string");
      expect(Array.isArray(node.children)).toBe(true);
      expect(Array.isArray(node.watches)).toBe(true);
    }
  });
});
