import { describe, expect, it } from "bun:test";
import {
  V,
  Expr,
  flatten,
  Encoder,
  Widget,
  PrimitiveWidget,
  SingleChildLayout,
  MultiChildLayout,
  ButtonWidget,
  Navigate,
  SetState,
  Sequential,
  type ComponentNode,
  type Value,
} from "../src/types";

// ── Test widgets ────────────────────────────────────────────

class TestText extends PrimitiveWidget {
  readonly type = "Text";
  constructor(private data: string | Value) { super(); }
  getProps() { return { data: this.data }; }
}

class TestContainer extends SingleChildLayout {
  readonly type = "Container";
  private color?: string | Value;
  constructor(opts: { child?: Widget; color?: string | Value } = {}) {
    super();
    this.child = opts.child;
    this.color = opts.color;
  }
  getProps() { return { color: this.color }; }
}

class TestColumn extends MultiChildLayout {
  readonly type = "Column";
  private gap: number;
  constructor(children: Widget[], gap = 0) {
    super();
    this.children = children;
    this.gap = gap;
  }
  getProps() { return { gap: this.gap }; }
}

class TestButton extends ButtonWidget {
  readonly type = "ElevatedButton";
  constructor(child?: Widget) { super(); this.child = child; }
  getProps() { return {}; }
}

// ── 4.1: Flatten function ──────────────────────────────────

describe("4.1: flatten(widget): ComponentNode[]", () => {
  it("returns flat array of ComponentNodes", () => {
    const nodes = flatten(new TestText("hello"));
    expect(Array.isArray(nodes)).toBe(true);
    expect(nodes).toHaveLength(1);
    expect(nodes[0].type).toBe("Text");
  });

  it("root is the first element", () => {
    const tree = new TestContainer({
      child: new TestColumn([
        new TestText("a"),
        new TestText("b"),
      ]),
    });
    const nodes = flatten(tree);
    expect(nodes[0].type).toBe("Container");
  });

  it("every node has required fields", () => {
    const nodes = flatten(new TestText("x"));
    const node = nodes[0];
    expect(node).toHaveProperty("id");
    expect(node).toHaveProperty("type");
    expect(node).toHaveProperty("kind");
    expect(node).toHaveProperty("childMode");
    expect(node).toHaveProperty("props");
    expect(node).toHaveProperty("children");
    expect(node).toHaveProperty("watches");
  });
});

// ── 4.2: Single-child layouts ──────────────────────────────

describe("4.2: single-child layouts", () => {
  it("Container children has exactly 1 ID string", () => {
    const nodes = flatten(new TestContainer({ child: new TestText("inner") }));
    const root = nodes[0];
    expect(root.type).toBe("Container");
    expect(root.children).toHaveLength(1);
    expect(typeof root.children[0]).toBe("string");
  });

  it("child ID references a real node", () => {
    const nodes = flatten(new TestContainer({ child: new TestText("inner") }));
    const root = nodes[0];
    const childId = root.children[0];
    const childNode = nodes.find(n => n.id === childId);
    expect(childNode).toBeDefined();
    expect(childNode!.type).toBe("Text");
  });

  it("no child means empty children array", () => {
    const nodes = flatten(new TestContainer());
    expect(nodes[0].children).toEqual([]);
  });
});

// ── 4.3: Multi-child layouts ───────────────────────────────

describe("4.3: multi-child layouts", () => {
  it("Column children has N ID strings", () => {
    const nodes = flatten(new TestColumn([
      new TestText("a"),
      new TestText("b"),
      new TestText("c"),
    ]));
    const root = nodes[0];
    expect(root.type).toBe("Column");
    expect(root.children).toHaveLength(3);
    root.children.forEach(id => expect(typeof id).toBe("string"));
  });

  it("child order is preserved", () => {
    const nodes = flatten(new TestColumn([
      new TestText("first"),
      new TestText("second"),
      new TestText("third"),
    ]));
    const root = nodes[0];
    const childNodes = root.children.map(id => nodes.find(n => n.id === id)!);
    expect(childNodes[0].props.data).toBe("first");
    expect(childNodes[1].props.data).toBe("second");
    expect(childNodes[2].props.data).toBe("third");
  });

  it("empty children array for no children", () => {
    const nodes = flatten(new TestColumn([]));
    expect(nodes[0].children).toEqual([]);
  });
});

// ── 4.4: Primitives ────────────────────────────────────────

describe("4.4: primitive widgets", () => {
  it("Text has empty children array", () => {
    const nodes = flatten(new TestText("hello"));
    expect(nodes[0].children).toEqual([]);
    expect(nodes[0].childMode).toBe("none");
  });

  it("primitive props are preserved", () => {
    const nodes = flatten(new TestText("hello world"));
    expect(nodes[0].props.data).toBe("hello world");
  });
});

// ── 4.5: Deeply nested trees ───────────────────────────────

describe("4.5: deeply nested trees", () => {
  it("10+ levels deep flattens correctly", () => {
    let widget: Widget = new TestText("leaf");
    for (let i = 0; i < 10; i++) {
      widget = new TestContainer({ child: widget });
    }
    const nodes = flatten(widget);

    // 10 containers + 1 text = 11
    expect(nodes).toHaveLength(11);

    // root is the outermost container
    expect(nodes[0].type).toBe("Container");

    // last is the leaf text
    expect(nodes[nodes.length - 1].type).toBe("Text");
  });

  it("parent→child references are valid across all levels", () => {
    let widget: Widget = new TestText("leaf");
    for (let i = 0; i < 5; i++) {
      widget = new TestContainer({ child: widget });
    }
    const nodes = flatten(widget);
    const nodeMap = new Map(nodes.map(n => [n.id, n]));

    for (const node of nodes) {
      for (const childId of node.children) {
        expect(nodeMap.has(childId)).toBe(true);
      }
    }
  });
});

// ── 4.6: Preserve Value objects in props ───────────────────

describe("4.6: Value objects preserved in props", () => {
  it("StateValue serialized as-is", () => {
    const value = V.pageState("username");
    const nodes = flatten(new TestText(value));
    expect(nodes[0].props.data).toEqual({ type: "state", key: "username", scope: "page" });
  });

  it("TransformValue serialized as-is", () => {
    const value = V.transform(V.pageState("price"), [
      { type: "multiply", by: V.pageState("qty") },
      { type: "formatCurrency", currency: "USD" },
    ]);
    const nodes = flatten(new TestText(value));
    const data = nodes[0].props.data as any;
    expect(data.type).toBe("transform");
    expect(data.input).toEqual(V.pageState("price"));
    expect(data.by).toHaveLength(2);
  });

  it("ConditionalValue serialized as-is", () => {
    const value = V.when(
      [{ when: Expr.gt(V.pageState("stock"), V.static(0)), then: V.static("In Stock") }],
      V.static("Out of Stock"),
    );
    const nodes = flatten(new TestText(value));
    const data = nodes[0].props.data as any;
    expect(data.type).toBe("conditional");
    expect(data.branches).toHaveLength(1);
    expect(data.else).toEqual(V.static("Out of Stock"));
  });

  it("nested Value in layout props preserved", () => {
    const nodes = flatten(new TestContainer({ color: V.appState("theme.primary") }));
    expect(nodes[0].props.color).toEqual({ type: "state", key: "theme.primary", scope: "app" });
  });
});

// ── 4.7: Auto-extract watches ──────────────────────────────

describe("4.7: auto-extract watches", () => {
  it("extracts state keys from props", () => {
    const nodes = flatten(new TestText(V.pageState("username")));
    expect(nodes[0].watches).toContain("username");
  });

  it("extracts nested state keys from transform", () => {
    const value = V.transform(V.pageState("price"), [
      { type: "multiply", by: V.pageState("qty") },
    ]);
    const nodes = flatten(new TestText(value));
    expect(nodes[0].watches).toContain("price");
    expect(nodes[0].watches).toContain("qty");
  });

  it("extracts from conditional branches", () => {
    const value = V.when(
      [{ when: Expr.gt(V.pageState("stock"), V.static(0)), then: V.pageState("label") }],
      V.pageState("fallback"),
    );
    const nodes = flatten(new TestText(value));
    expect(nodes[0].watches).toContain("stock");
    expect(nodes[0].watches).toContain("label");
    expect(nodes[0].watches).toContain("fallback");
  });

  it("static values produce empty watches", () => {
    const nodes = flatten(new TestText("plain string"));
    expect(nodes[0].watches).toEqual([]);
  });
});

// ── 4.8: Preserve actions ──────────────────────────────────

describe("4.8: preserve actions", () => {
  it("single action preserved", () => {
    const text = new TestText("tap me");
    text.actions = { onTap: Navigate("/home") };
    const nodes = flatten(text);
    expect(nodes[0].actions).toBeDefined();
    expect(nodes[0].actions!.onTap).toEqual({ type: "navigate", route: "/home", params: undefined });
  });

  it("multiple triggers preserved", () => {
    const text = new TestText("interact");
    text.actions = {
      onTap: Navigate("/detail"),
      onLongPress: SetState("selected", V.static(true)),
    };
    const nodes = flatten(text);
    expect(nodes[0].actions!.onTap).toBeDefined();
    expect(nodes[0].actions!.onLongPress).toBeDefined();
  });

  it("complex action group preserved", () => {
    const text = new TestText("submit");
    text.actions = {
      onTap: Sequential(
        SetState("loading", V.static(true)),
        Navigate("/next"),
      ),
    };
    const nodes = flatten(text);
    const action = nodes[0].actions!.onTap as any;
    expect(action.type).toBe("actionGroup");
    expect(action.actions).toHaveLength(2);
  });

  it("no actions means undefined", () => {
    const nodes = flatten(new TestText("no actions"));
    expect(nodes[0].actions).toBeUndefined();
  });
});

// ── 4.9: ID stability ──────────────────────────────────────

describe("4.9: ID stability (deterministic)", () => {
  it("same tree produces same IDs", () => {
    const makeTree = () => new TestColumn([
      new TestContainer({ child: new TestText("a") }),
      new TestText("b"),
      new TestContainer({ child: new TestColumn([new TestText("c"), new TestText("d")]) }),
    ]);

    const run1 = flatten(makeTree());
    const run2 = flatten(makeTree());

    expect(run1.length).toBe(run2.length);
    for (let i = 0; i < run1.length; i++) {
      expect(run1[i].id).toBe(run2[i].id);
      expect(run1[i].type).toBe(run2[i].type);
      expect(run1[i].children).toEqual(run2[i].children);
    }
  });

  it("different trees produce different structures", () => {
    const tree1 = flatten(new TestColumn([new TestText("a")]));
    const tree2 = flatten(new TestColumn([new TestText("a"), new TestText("b")]));
    expect(tree1.length).not.toBe(tree2.length);
  });
});

// ── 4.10: Performance test ─────────────────────────────────

describe("4.10: performance", () => {
  it("flatten 1000-node tree in < 5ms", () => {
    // Build a wide tree: Column with 999 Text children = 1000 nodes
    const children: Widget[] = [];
    for (let i = 0; i < 999; i++) {
      children.push(new TestText(`item-${i}`));
    }
    const tree = new TestColumn(children);

    const start = performance.now();
    const nodes = flatten(tree);
    const elapsed = performance.now() - start;
    expect(nodes).toHaveLength(1000);
    expect(elapsed).toBeLessThan(5);
  });

  it("flatten deep tree (500 levels) without stack overflow", () => {
    let widget: Widget = new TestText("leaf");
    for (let i = 0; i < 499; i++) {
      widget = new TestContainer({ child: widget });
    }
    const nodes = flatten(widget);
    expect(nodes).toHaveLength(500);
  });
});
