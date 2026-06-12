// JSON tree encoder.
//
// The stock `flatten(widget)` encoder at engine/src/types/widget.ts walks
// Widget class instances produced by the `.new()` factories — the path
// taken by code-authored pages. This file is a second encoder that instead
// consumes pages as pre-serialized JSON trees. That shape shows up in
// several places the class-based path doesn't cover:
//
//   - Dashboard / GUI authoring tools that emit page definitions as JSON
//     rather than TypeScript.
//   - Persistence layers that store a page once and render it many times,
//     where deserializing into class instances on every request is wasteful.
//   - Plugin pipelines and third-party tools that build pages in languages
//     other than TypeScript and deliver them as wire-format trees.
//   - The conformance suite at test/conformance.test.ts, which feeds the
//     engine's render spec through a fixed set of JSON fixtures.
//
// Output matches what `flatten(widget)` produces for the equivalent Widget
// tree, including child ordering, assigned ids, resolved props, and the
// `watches` list on each node.
//
// Input tree shape:
//
//   {
//     "type":    "Column",
//     "key":     "stable-id",                                 // optional
//     "props":   { ... },                                     // optional
//     "children": [ <tree>, <tree>, ... ],                    // optional
//     "slots":   [ {"name":"body","widget":<tree>}, ... ],    // optional (structure widgets)
//     "actions": { "onTap": <Action> }                        // optional
//   }

import type { ActionMap } from "../types/action";
import type { ComponentNode } from "../types/node";
import { MAX_TREE_DEPTH, MAX_TREE_NODES } from "../types/widget";
import { WIDGET_REGISTRY, type WidgetRegistryEntry } from "./widget-registry-gen";
import { ValueResolver, type ValueResolverContext } from "./value-resolver";
import { V, isValue, type Value } from "../types/value";

// ── Types ───────────────────────────────────────────────────────────────────

export interface JsonTreeNode {
  type: string;
  key?: string;
  props?: Record<string, unknown>;
  children?: JsonTreeNode[];
  slots?: { name: string; widget: JsonTreeNode }[];
  actions?: ActionMap;
}

export interface JsonTreeEncoderOptions {
  /** Extra widget definitions (e.g. from plugins) merged at runtime. */
  extraWidgets?: Readonly<Record<string, WidgetRegistryEntry>>;
}

// ── Encoder ─────────────────────────────────────────────────────────────────

export class JsonTreeEncoder {
  private nodes: ComponentNode[] = [];
  private nextId = 0;
  private treeDepth = 0;
  private extraWidgets: Readonly<Record<string, WidgetRegistryEntry>>;

  constructor(
    private resolver: ValueResolver,
    options?: JsonTreeEncoderOptions,
  ) {
    this.extraWidgets = options?.extraWidgets ?? {};
  }

  /** Flatten a JSON tree into a `ComponentNode[]` with the root first. */
  encode(tree: JsonTreeNode): ComponentNode[] {
    this.addNode(tree);
    // Children-first → root-first. Mirrors the .reverse() in flatten().
    return this.nodes.reverse();
  }

  /** Check core registry first, then plugin-supplied extras. */
  private lookupWidget(wireType: string): WidgetRegistryEntry | undefined {
    return WIDGET_REGISTRY[wireType] ?? this.extraWidgets[wireType];
  }

  private addNode(tree: JsonTreeNode): string {
    // JSON trees can come from untrusted authoring surfaces (dashboards,
    // stored definitions) — enforce the same absolute ceilings as the
    // class-based encoder so a hostile tree can't blow the stack.
    if (this.treeDepth >= MAX_TREE_DEPTH) {
      throw new Error(`json-tree-encoder: tree exceeded ${MAX_TREE_DEPTH} nesting levels`);
    }
    if (this.nodes.length >= MAX_TREE_NODES) {
      throw new Error(`json-tree-encoder: tree exceeded ${MAX_TREE_NODES} nodes`);
    }
    this.treeDepth++;
    try {
      return this.addNodeInner(tree);
    } finally {
      this.treeDepth--;
    }
  }

  private addNodeInner(tree: JsonTreeNode): string {
    if (!tree || typeof tree !== "object") {
      throw new Error("json-tree-encoder: tree node is not an object");
    }
    const wireType = tree.type;
    if (!wireType) {
      throw new Error("json-tree-encoder: tree node missing `type`");
    }
    const meta = this.lookupWidget(wireType);
    if (!meta) {
      throw new Error(
        `json-tree-encoder: unknown widget type "${wireType}" ` +
          `(regenerate registry: bun run schema/gen-widget-registry.ts)`,
      );
    }

    // Assign id: prefer author-supplied key, else monotonic counter (stringified).
    const id = tree.key && tree.key.length > 0 ? tree.key : String(this.nextId++);

    // Walk children first so the flat array ends up child-first / root-last.
    const childIds: string[] = [];
    if (tree.children) {
      for (let i = 0; i < tree.children.length; i++) {
        const child = tree.children[i];
        if (!child || typeof child !== "object") {
          throw new Error(`json-tree-encoder: ${wireType}.children[${i}] is not an object`);
        }
        childIds.push(this.addNode(child));
      }
    }

    // Resolve props now so slot id injection operates on the resolved copy.
    const resolvedProps = this.resolver.resolveProps(tree.props ?? {});

    // Walk slots (structure widgets only). Each slot id goes BOTH into
    // childIds and into resolvedProps under the slot name — the same trick
    // the class-based encoder in widget.ts uses for StructureWidget.
    if (tree.slots) {
      if (meta.kind !== "structure") {
        throw new Error(
          `json-tree-encoder: ${wireType} declares slots but kind=${meta.kind} ` +
            `(slots are only valid on structure widgets)`,
        );
      }
      for (let i = 0; i < tree.slots.length; i++) {
        const slot = tree.slots[i];
        if (!slot || typeof slot !== "object" || !slot.name || !slot.widget) {
          throw new Error(`json-tree-encoder: ${wireType}.slots[${i}] malformed`);
        }
        const sid = this.addNode(slot.widget);
        childIds.push(sid);
        resolvedProps[slot.name] = sid;
      }
    }

    // Watches from the resolved props — same set the SDK walks for re-renders.
    const watches = extractPropsWatches(resolvedProps);

    const node: ComponentNode = {
      id,
      type: meta.type,
      kind: meta.kind,
      childMode: meta.childMode,
      props: resolvedProps,
      children: childIds,
      watches,
    };
    if (tree.actions) node.actions = tree.actions;

    this.nodes.push(node);
    return id;
  }
}

// ── Convenience entry point ─────────────────────────────────────────────────

export function encodeJsonTree(
  tree: JsonTreeNode,
  ctx: ValueResolverContext,
  options?: JsonTreeEncoderOptions,
): ComponentNode[] {
  return new JsonTreeEncoder(new ValueResolver(ctx), options).encode(tree);
}

// ── Watch extraction ────────────────────────────────────────────────────────
//
// Copy of `extractPropsWatches` / `walkForValues` from widget.ts. Keeping it
// local so json-tree-encoder stays decoupled from the class-based encoder's
// internals — they serve different inputs and shouldn't silently share
// private helpers.

function extractPropsWatches(props: Record<string, unknown>): string[] {
  const keys = new Set<string>();
  walkForValues(props, keys);
  // Sorted output. The SDK treats `watches` as a set, so ordering is not
  // semantically meaningful — but deterministic ordering lets consumers
  // (conformance tests, snapshot tests, tooling that diffs renders) compare
  // outputs without being sensitive to implementation-defined iteration
  // order. Sorting is a strict improvement over whatever order Object.keys
  // happened to return for the input shape.
  return Array.from(keys).sort();
}

function walkForValues(obj: unknown, keys: Set<string>): void {
  if (obj === null || obj === undefined) return;
  if (typeof obj !== "object") return;

  if (isValue(obj)) {
    for (const k of V.extractWatches(obj as Value)) keys.add(k);
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

