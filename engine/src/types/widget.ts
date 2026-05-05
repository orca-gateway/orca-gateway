import type { ActionMap } from "./action";
import type { ChildMode, ComponentKind, ComponentNode } from "./node";
import type { PageContext } from "./context";
import type { Value } from "./value";
import { V, isValue } from "./value";

// ── Widget Kind (authoring vs wire) ─────────────────────────
//
// `ComponentKind` (node.ts) is the wire contract — one of five values that
// ever appear on a serialized `ComponentNode`. `WidgetKind` extends it with
// `"composite"` for server-side-only authoring widgets that expand before
// serialization and NEVER reach the wire format. The encoder's type contract
// enforces this: composites are handled in a dedicated branch that recurses
// into `build()`, so no `ComponentNode.kind` is ever written with "composite".

export type WidgetKind = ComponentKind | "composite";

// ── Flatten ─────────────────────────────────────────────────

/**
 * Options for `flatten()` that let the encoder expand `CompositeWidget`
 * subclasses. Only the Page pipeline's stage-3 call site has both of these
 * in scope; other callers (navigation shell, server-action wire resolution,
 * plugin-build harness) legitimately don't, and encountering a composite
 * without opts throws a clear error instead of silently degrading.
 */
export interface FlattenOptions {
  ctx: PageContext;
  info: unknown;
}

/** Maximum CompositeWidget nesting depth — guards accidental infinite recursion. */
export const MAX_COMPOSITE_DEPTH = 32;

/** Flatten a widget tree into a `ComponentNode[]` array with root first. */
export function flatten(widget: Widget, opts?: FlattenOptions): ComponentNode[] {
  const encoder = new Encoder(opts);
  encoder.addNode(widget);
  const nodes = encoder.getNodes();
  // Encoder produces children-first order; reverse so root is first.
  return nodes.reverse();
}

// ── Encoder ─────────────────────────────────────────────────

export class Encoder {
  private nodes: ComponentNode[] = [];
  private nextId = 0;
  private depth = 0;
  private readonly renderOpts?: FlattenOptions;

  constructor(renderOpts?: FlattenOptions) {
    this.renderOpts = renderOpts;
  }

  addNode(widget: Widget): string {
    // CompositeWidget expansion must run BEFORE the instanceof chain below —
    // composites have no wire representation and must be replaced by their
    // built subtree in-place. Their own `type`/`kind`/`getProps()` never
    // reach `ComponentNode`.
    if (widget instanceof CompositeWidget) {
      if (!this.renderOpts) {
        throw new Error(
          `CompositeWidget (${widget.constructor.name}) encountered outside a Page render context. ` +
            `flatten() was called without { ctx, info } — composites only work inside Page.render.`,
        );
      }
      if (this.depth >= MAX_COMPOSITE_DEPTH) {
        throw new Error(
          `CompositeWidget nesting exceeded ${MAX_COMPOSITE_DEPTH} levels at ${widget.constructor.name} — likely accidental recursion.`,
        );
      }
      this.depth++;
      const built = widget.build(this.renderOpts.ctx, this.renderOpts.info);
      propagateKeyAndActions(widget, built);
      const id = this.addNode(built);
      this.depth--;
      return id;
    }

    const id = widget.key ?? String(this.nextId++);
    const childIds: string[] = [];

    if (widget instanceof SingleChildLayout && widget.child) {
      childIds.push(this.addNode(widget.child));
    } else if (widget instanceof MultiChildLayout) {
      for (const child of widget.children) {
        childIds.push(this.addNode(child));
      }
    } else if (widget instanceof ButtonWidget && widget.child) {
      childIds.push(this.addNode(widget.child));
    }

    const props = widget.getProps();

    // Handle structure widgets with named slots (Scaffold, AppBar)
    if (widget instanceof StructureWidget && "getSlotWidgets" in widget) {
      const slots = (widget as unknown as { getSlotWidgets(): { name: string; widget: Widget }[] }).getSlotWidgets();
      for (const slot of slots) {
        const slotId = this.addNode(slot.widget);
        childIds.push(slotId);
        (props as Record<string, unknown>)[slot.name] = slotId;
      }
    }

    const watches = extractPropsWatches(props);

    // Safe cast: the CompositeWidget branch above returned early, so every
    // remaining widget's `kind` is one of the five ComponentKind values.
    this.nodes.push({
      id,
      type: widget.type,
      kind: widget.kind as ComponentKind,
      childMode: widget.childMode,
      props,
      children: childIds,
      watches,
      actions: widget.actions,
    });

    return id;
  }

  getNodes(): ComponentNode[] {
    return this.nodes;
  }
}

function extractPropsWatches(props: Record<string, unknown>): string[] {
  const keys = new Set<string>();
  walkForValues(props, keys);
  return Array.from(keys);
}

function walkForValues(obj: unknown, keys: Set<string>): void {
  if (obj === null || obj === undefined) return;
  if (typeof obj !== "object") return;

  if (isValue(obj)) {
    for (const k of V.extractWatches(obj)) keys.add(k);
    return;
  }

  if (Array.isArray(obj)) {
    for (const item of obj) walkForValues(item, keys);
    return;
  }

  for (const val of Object.values(obj as Record<string, unknown>)) {
    walkForValues(val, keys);
  }
}

// ── Composite key / action propagation ──────────────────────
//
// When a composite has its own `key` or `actions`, we want them to apply to
// the root of whatever `build()` produced. Two correctness cases matter:
//
// 1. Nested composites: if `build()` returns another CompositeWidget, we
//    don't copy anything — the inner composite's own expansion will handle
//    key/action propagation on its turn. Copying onto a composite that's
//    about to expand would just get discarded.
//
// 2. Pass-through layouts: if the composite carries actions but `build()`
//    returned a pointer-transparent widget (SizedBox, Padding, Align, etc.),
//    actions would silently fail on the client because those widgets don't
//    receive gestures. We throw with a clear message rather than let the
//    bug slip into production.

const PASS_THROUGH_TYPES = new Set([
  "SizedBox",
  "Padding",
  "Align",
  "Expanded",
  "Flexible",
  "IgnorePointer",
]);

function propagateKeyAndActions(composite: CompositeWidget, built: Widget): void {
  // Nested composite: defer to its own expansion.
  if (built instanceof CompositeWidget) return;

  if (composite.actions && PASS_THROUGH_TYPES.has(built.type)) {
    throw new Error(
      `CompositeWidget ${composite.constructor.name} has actions but its build() returned a pass-through widget (${built.type}). ` +
        `Actions on pass-through widgets never fire. Either wrap build()'s root in a semantic widget, or put the actions inside build().`,
    );
  }

  if (composite.key && !built.key) built.key = composite.key;
  if (composite.actions && !built.actions) built.actions = composite.actions;
}

// ── Widget Base Classes ─────────────────────────────────────

export abstract class Widget {
  abstract readonly type: string;
  abstract readonly kind: WidgetKind;
  abstract readonly childMode: ChildMode;
  actions?: ActionMap;
  /** Stable key used as the component ID. When set, server actions can target this component. */
  key?: string;

  /** Set a stable key on this widget (fluent). */
  withKey(key: string): this {
    this.key = key;
    return this;
  }

  abstract getProps(): Record<string, unknown>;
}

// Layout widgets
export abstract class LayoutWidget extends Widget {
  readonly kind = "layout" as const;
}

export abstract class SingleChildLayout extends LayoutWidget {
  readonly childMode = "single" as const;
  child?: Widget;
}

export abstract class MultiChildLayout extends LayoutWidget {
  readonly childMode = "multi" as const;
  children: Widget[] = [];
}

// Primitive widgets (no children)
export abstract class PrimitiveWidget extends Widget {
  readonly kind = "primitive" as const;
  readonly childMode = "none" as const;
}

// Input widgets (no children)
export abstract class InputWidget extends Widget {
  readonly kind = "input" as const;
  readonly childMode = "none" as const;
}

// Button widgets (single child — the label/content)
export abstract class ButtonWidget extends Widget {
  readonly kind = "button" as const;
  readonly childMode = "single" as const;
  child?: Widget;
}

// Structure widgets (varies)
export abstract class StructureWidget extends Widget {
  readonly kind = "structure" as const;
}

// ── CompositeWidget ─────────────────────────────────────────
//
// Server-side authoring widget that expands to its built subtree during
// flatten. Never appears in the wire format. `TInfo` lets authors narrow
// the page's `infoData` type within `build()` when the enclosing Page is
// typed (`class MyPage extends Page<MyInfo>`).
//
// Composites live in author app code — they are NOT scanned by the widget
// registry codegen (the scraper's BASE_DEFAULTS lookup returns null for
// `CompositeWidget`, auto-skipping them). Do not place them under
// `engine/src/components/` or the codegen will emit a "⚠ skipping unknown
// base" warning on every run.

export abstract class CompositeWidget<TInfo = unknown> extends Widget {
  readonly kind = "composite" as const;
  readonly childMode = "none" as const;
  // Sentinel type string — if this ever reaches the wire format, the SDK
  // will fail to render it, exposing a bug in the composite-expansion path.
  readonly type = "__composite__";

  abstract build(context: PageContext, info: TInfo): Widget;

  getProps(): Record<string, unknown> {
    return {};
  }
}
