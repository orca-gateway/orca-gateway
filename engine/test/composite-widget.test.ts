import { describe, expect, it } from "bun:test";
import {
  CompositeWidget,
  MultiChildLayout,
  PrimitiveWidget,
  SingleChildLayout,
  Widget,
  flatten,
  type FlattenOptions,
} from "../src/types";
import type { PageContext } from "../src/types/context";
import { Navigate } from "../src/types/action";

// ── Test widgets ────────────────────────────────────────────

class TestText extends PrimitiveWidget {
  readonly type = "Text";
  constructor(private data: string) {
    super();
  }
  getProps() {
    return { data: this.data };
  }
}

class TestColumn extends MultiChildLayout {
  readonly type = "Column";
  constructor(children: Widget[]) {
    super();
    this.children = children;
  }
  getProps() {
    return {};
  }
}

class TestPadding extends SingleChildLayout {
  readonly type = "Padding";
  constructor(child?: Widget) {
    super();
    this.child = child;
  }
  getProps() {
    return {};
  }
}

class TestSizedBox extends SingleChildLayout {
  readonly type = "SizedBox";
  constructor(child?: Widget) {
    super();
    this.child = child;
  }
  getProps() {
    return {};
  }
}

// ── Test composites ─────────────────────────────────────────

interface CardInfo {
  title: string;
  subtitle: string;
}

class PaymentCard extends CompositeWidget<CardInfo> {
  build(_ctx: PageContext, info: CardInfo): Widget {
    return new TestColumn([new TestText(info.title), new TestText(info.subtitle)]);
  }
}

class UsesContext extends CompositeWidget {
  build(ctx: PageContext, _info: unknown): Widget {
    return new TestText(ctx.pageId);
  }
}

class WrapsOtherComposite extends CompositeWidget<CardInfo> {
  build(_ctx: PageContext, info: CardInfo): Widget {
    return new PaymentCard();
  }
}

// ── Test helpers ────────────────────────────────────────────

function makeCtx(): PageContext {
  return {
    requestInfo: {} as PageContext["requestInfo"],
    pageId: "test-page",
    routePath: "/test",
    routeParams: {},
    pageState: {},
    appState: {},
  };
}

function opts(info: unknown = undefined): FlattenOptions {
  return { ctx: makeCtx(), info };
}

// ── Tests ───────────────────────────────────────────────────

describe("CompositeWidget — basic expansion", () => {
  it("expands to its built subtree and leaves no composite in the wire output", () => {
    const card = new PaymentCard();
    const nodes = flatten(card, opts({ title: "Visa", subtitle: "**** 4242" }));

    for (const node of nodes) {
      expect(node.type).not.toBe("__composite__");
      expect(node.kind).not.toBe("composite");
    }

    const root = nodes[0];
    expect(root.type).toBe("Column");
    expect(root.children).toHaveLength(2);

    const childTypes = root.children.map((id) => nodes.find((n) => n.id === id)!.type);
    expect(childTypes).toEqual(["Text", "Text"]);
  });

  it("injects infoData into build()", () => {
    const card = new PaymentCard();
    const nodes = flatten(card, opts({ title: "Mastercard", subtitle: "Debit" }));
    const root = nodes[0];
    expect(root.type).toBe("Column");
    // Use root.children order — preserves semantic child order vs post-order.
    const byId = (id: string) => nodes.find((n) => n.id === id)!;
    expect(byId(root.children[0]).props.data).toBe("Mastercard");
    expect(byId(root.children[1]).props.data).toBe("Debit");
  });

  it("injects PageContext into build()", () => {
    const nodes = flatten(new UsesContext(), opts());
    const root = nodes[0];
    expect(root.type).toBe("Text");
    expect(root.props.data).toBe("test-page");
  });
});

describe("CompositeWidget — nesting", () => {
  it("nested composites expand recursively", () => {
    const wrapper = new WrapsOtherComposite();
    const nodes = flatten(wrapper, opts({ title: "Amex", subtitle: "Platinum" }));

    expect(nodes).toHaveLength(3); // Column + 2 Text
    expect(nodes[0].type).toBe("Column");
    for (const n of nodes) {
      expect(n.kind).not.toBe("composite");
    }
  });

  it("throws when nesting depth exceeds MAX_COMPOSITE_DEPTH", () => {
    class Infinite extends CompositeWidget {
      build(): Widget {
        return new Infinite();
      }
    }
    expect(() => flatten(new Infinite(), opts())).toThrow(/nesting exceeded/);
  });

  it("works when composite is nested inside a normal layout", () => {
    const tree = new TestColumn([new TestText("header"), new PaymentCard(), new TestText("footer")]);
    const nodes = flatten(tree, opts({ title: "Visa", subtitle: "**** 4242" }));

    const root = nodes[0];
    expect(root.type).toBe("Column");
    expect(root.children).toHaveLength(3);

    const childTypes = root.children.map((id) => nodes.find((n) => n.id === id)!.type);
    // Middle child expanded to Column (PaymentCard's build)
    expect(childTypes).toEqual(["Text", "Column", "Text"]);
  });
});

describe("CompositeWidget — flatten without opts", () => {
  it("throws a clear error when a composite is encountered without opts", () => {
    expect(() => flatten(new PaymentCard())).toThrow(/outside a Page render context/);
  });

  it("does NOT throw for a tree with no composites and no opts", () => {
    const tree = new TestColumn([new TestText("hello")]);
    expect(() => flatten(tree)).not.toThrow();
  });
});

describe("CompositeWidget — key and action propagation", () => {
  it("propagates composite.key onto the built root when root has no key", () => {
    const card = new PaymentCard();
    card.key = "payment-card-1";
    const nodes = flatten(card, opts({ title: "Visa", subtitle: "x" }));
    expect(nodes[0].id).toBe("payment-card-1");
  });

  it("does not overwrite an existing key on the built root", () => {
    class KeyedComposite extends CompositeWidget {
      build(): Widget {
        const col = new TestColumn([new TestText("a")]);
        col.key = "inner-key";
        return col;
      }
    }
    const c = new KeyedComposite();
    c.key = "outer-key";
    const nodes = flatten(c, opts());
    expect(nodes[0].id).toBe("inner-key");
  });

  it("propagates composite.actions onto the built root when root has no actions", () => {
    const card = new PaymentCard();
    card.actions = { onTap: Navigate("/details") };
    const nodes = flatten(card, opts({ title: "Visa", subtitle: "x" }));
    expect(nodes[0].actions).toBeDefined();
    expect(nodes[0].actions?.onTap).toBeDefined();
  });

  it("throws when composite has actions but built root is a pass-through widget", () => {
    class BadCompositePadding extends CompositeWidget {
      build(): Widget {
        return new TestPadding(new TestText("inside"));
      }
    }
    const bad = new BadCompositePadding();
    bad.actions = { onTap: Navigate("/x") };
    expect(() => flatten(bad, opts())).toThrow(/pass-through widget/);
  });

  it("throws when composite has actions but built root is SizedBox", () => {
    class BadSizedBox extends CompositeWidget {
      build(): Widget {
        return new TestSizedBox(new TestText("inside"));
      }
    }
    const bad = new BadSizedBox();
    bad.actions = { onTap: Navigate("/x") };
    expect(() => flatten(bad, opts())).toThrow(/pass-through widget/);
  });

  it("allows a pass-through root when composite has NO actions", () => {
    class OkPadding extends CompositeWidget {
      build(): Widget {
        return new TestPadding(new TestText("inside"));
      }
    }
    const c = new OkPadding();
    expect(() => flatten(c, opts())).not.toThrow();
  });

  it("defers propagation through nested composites (inner composite handles its own)", () => {
    class Inner extends CompositeWidget {
      build(): Widget {
        return new TestColumn([new TestText("inner-child")]);
      }
    }
    class Outer extends CompositeWidget {
      build(): Widget {
        return new Inner();
      }
    }
    const outer = new Outer();
    outer.key = "outer-key";
    const nodes = flatten(outer, opts());
    // The Outer's key is NOT propagated to Inner (a composite); after Inner
    // expands, its built root (Column) has no key set from outer's key
    // because the nested-composite branch returned early.
    expect(nodes[0].type).toBe("Column");
    expect(nodes[0].id).not.toBe("outer-key");
  });
});

describe("CompositeWidget — server-action responses", () => {
  // Regression: composites used in Page.render are also naturally reused in
  // server-action handlers (AddComponent/ReplaceComponent). Before the fix,
  // resolveResponseActions called flatten() with no opts and any composite
  // in the response threw "outside a Page render context". The engine now
  // threads the ActionContext through so composites work in both places.
  it("resolveResponseActions with ActionContext expands composites in addComponent", async () => {
    const { resolveResponseActions } = await import("../src/core/server-action");
    // A server-action-style composite: no dependency on getInfoData, but may
    // read pageState via the synthesized PageContext.
    class ChatBubble extends CompositeWidget {
      constructor(private msg: string) {
        super();
      }
      build(_ctx: PageContext, _info: unknown): Widget {
        return new TestColumn([new TestText(this.msg)]);
      }
    }
    const actionCtx = {
      requestInfo: {} as PageContext["requestInfo"],
      pageState: { username: "alice" },
      appState: {},
      actionParams: {},
    };
    const result = resolveResponseActions(
      [
        {
          type: "addComponent",
          parentId: "list",
          keyPrefix: "row",
          widget: new ChatBubble("hello"),
        },
      ],
      actionCtx,
    );
    expect(result).toHaveLength(1);
    const action = result[0] as { type: string; components: { type: string; kind: string }[] };
    expect(action.type).toBe("addComponent");
    // Composite expanded — the returned components are ONLY the primitive
    // nodes from ChatBubble.build() (Column + Text), never "__composite__".
    for (const n of action.components) {
      expect(n.kind).not.toBe("composite");
      expect(n.type).not.toBe("__composite__");
    }
    expect(action.components.some((n) => n.type === "Column")).toBe(true);
    expect(action.components.some((n) => n.type === "Text")).toBe(true);
  });

  it("resolveResponseActions without ActionContext still throws for composites (unchanged contract)", async () => {
    const { resolveResponseActions } = await import("../src/core/server-action");
    class TrivialComposite extends CompositeWidget {
      build(): Widget {
        return new TestText("x");
      }
    }
    expect(() =>
      resolveResponseActions([
        {
          type: "addComponent",
          parentId: "list",
          keyPrefix: "row",
          widget: new TrivialComposite(),
        },
      ]),
    ).toThrow(/outside a Page render context/);
  });

  it("resolveResponseActions with ActionContext works for non-composite widgets too", async () => {
    const { resolveResponseActions } = await import("../src/core/server-action");
    const actionCtx = {
      requestInfo: {} as PageContext["requestInfo"],
      pageState: {},
      appState: {},
      actionParams: {},
    };
    const result = resolveResponseActions(
      [
        {
          type: "replaceComponent",
          targetId: "list",
          keyPrefix: "row",
          widget: new TestColumn([new TestText("a")]),
        },
      ],
      actionCtx,
    );
    expect(result).toHaveLength(1);
  });
});

describe("CompositeWidget — wire-format invariant", () => {
  it("no node in the flat output carries kind='composite' or type='__composite__'", () => {
    const tree = new TestColumn([
      new PaymentCard(),
      new WrapsOtherComposite(),
      new UsesContext(),
    ]);
    const nodes = flatten(tree, opts({ title: "T", subtitle: "S" }));
    for (const node of nodes) {
      expect(node.kind).not.toBe("composite");
      expect(node.type).not.toBe("__composite__");
    }
  });
});
