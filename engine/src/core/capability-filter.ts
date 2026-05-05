// Capability-aware filter (Epic 25b slice 2, task 25b.3).
//
// This is the new pipeline stage inserted between `flatten(widgetTree)` and
// `resolver.resolveProps()` in runPipeline. Its job:
//
//   Given a flat ComponentNode[] and a client's capability vector, return
//   a new ComponentNode[] where every feature the client can't render has
//   been handled according to the configured FallbackPolicy.
//
// Architectural notes:
//
//   1. The filter operates at NODE granularity, not prop granularity. If a
//      single node references an unsupported Value kind, Transform, BoolExpr
//      op, Action kind, or has an unsupported widget type, the policy is
//      applied to the whole node. This is a deliberate simplification for
//      slice 2: per-prop stripping requires knowledge of each widget's
//      required props, which would couple the filter to every widget class.
//      Node-level granularity is correct for most real-world scenarios
//      (tenants annotate "this feature needs widget X" in their policy).
//
//   2. The filter is a PURE function. All inputs are values, no side
//      effects. That makes it trivial to unit-test and cache-stable.
//
//   3. Synthesized FallbackPrompt nodes use the frozen v1 prop shape from
//      slice 1. Every property, severity value, and nesting pattern here
//      must remain renderable by every SDK version that has ever shipped —
//      that's the whole point of the frozen contract. See
//      engine/src/components/primitive/fallback-prompt.ts.

import type { ComponentNode } from "../types/node";
import type { CapabilityVector } from "../types/context";
import type { ActionMap } from "../types/action";
import type {
  FallbackMode,
  FallbackPolicyResolver,
  FeatureKey,
} from "./fallback-policy";
import { highestSeverity } from "./fallback-policy";

export interface FilterResult {
  components: ComponentNode[];
  /** Features stripped from the tree under `graceful` mode. Surfaced for
   *  observability — tests assert on this list and a future analytics slice
   *  can pipe it into a tenant-facing "what degraded today" dashboard. */
  droppedFeatures: FeatureKey[];
  /** True when any `require`-mode feature was encountered and the entire
   *  tree was replaced with a single blocking FallbackPrompt. */
  replacedWithBlocker: boolean;
  /** True when a `warn`-mode feature was encountered and a banner was
   *  prepended above the original root. */
  addedWarnBanner: boolean;
}

/** Deterministic ids so cache keys remain stable across identical inputs. */
const WARN_ROOT_ID = "__caps_warn_root__";
const WARN_BANNER_ID = "__caps_warn_banner__";
const BLOCK_ROOT_ID = "__caps_block_root__";

/** FallbackPrompt is frozen-at-v1 and must always be rendered even if a
 *  client's vector (implausibly) omits it. The filter never degrades or
 *  drops FallbackPrompt, and it's pre-added to the "supported" set before
 *  any vector lookup happens. */
const ALWAYS_SUPPORTED_WIDGETS = new Set(["FallbackPrompt"]);

export function filterByCapabilities(
  components: ComponentNode[],
  caps: CapabilityVector | undefined,
  resolver: FallbackPolicyResolver,
): FilterResult {
  // Unversioned client → no negotiation, return the tree unchanged. This
  // keeps pre-25b behavior for any SDK that doesn't advertise capabilities.
  if (!caps || components.length === 0) {
    return {
      components,
      droppedFeatures: [],
      replacedWithBlocker: false,
      addedWarnBanner: false,
    };
  }

  const support = buildSupportLookup(caps);

  // ── Pass 1: per-node unsupported-feature detection ─────────────────────
  //
  // For each node, collect the set of feature keys that are NOT in the
  // client's vector. A node with zero missing features stays untouched.
  const nodeIssues = new Map<string, FeatureKey[]>();
  for (const node of components) {
    const missing = collectUnsupportedFeatures(node, support);
    if (missing.length > 0) {
      nodeIssues.set(node.id, missing);
    }
  }

  if (nodeIssues.size === 0) {
    return {
      components,
      droppedFeatures: [],
      replacedWithBlocker: false,
      addedWarnBanner: false,
    };
  }

  // ── Pass 2: per-node policy decision ───────────────────────────────────
  //
  // For each node with issues, resolve the policy mode for every missing
  // feature and take the highest severity.
  const nodeMode = new Map<string, FallbackMode>();
  const droppedFeatures: FeatureKey[] = [];
  let anyRequire = false;
  let anyWarn = false;

  for (const [nodeId, missing] of nodeIssues) {
    const modes = missing.map((f) => resolver.resolve(f));
    const mode = highestSeverity(modes);
    nodeMode.set(nodeId, mode);
    if (mode === "require") anyRequire = true;
    if (mode === "warn") anyWarn = true;
    if (mode === "graceful") {
      for (const f of missing) droppedFeatures.push(f);
    }
  }

  // ── Pass 3: apply decisions ────────────────────────────────────────────
  //
  // Require wins outright — replace the entire tree with a blocking prompt.
  if (anyRequire) {
    return {
      components: [buildBlockingRoot(nodeIssues)],
      droppedFeatures: [],
      replacedWithBlocker: true,
      addedWarnBanner: false,
    };
  }

  // Graceful drops may promote to warn when the dropped node is a structure
  // widget's slot child (can't leave a dangling slot pointer). See the
  // structure-slot edge case discussion at the top of this file.
  const parentOf = buildParentMap(components);
  const byId = new Map(components.map((n) => [n.id, n]));
  const toDrop = new Set<string>();
  for (const [nodeId, mode] of nodeMode) {
    if (mode !== "graceful") continue;
    const parentId = parentOf.get(nodeId);
    if (parentId) {
      const parent = byId.get(parentId);
      if (parent && parent.kind === "structure") {
        // Promote to warn — dropping a slot child would dangle its pointer.
        nodeMode.set(nodeId, "warn");
        anyWarn = true;
        continue;
      }
    }
    toDrop.add(nodeId);
  }

  let filtered = components;
  if (toDrop.size > 0) {
    filtered = dropNodes(components, toDrop, parentOf);
  }

  if (anyWarn) {
    const warnFeatureKeys: FeatureKey[] = [];
    for (const [nodeId, mode] of nodeMode) {
      if (mode === "warn") {
        const missing = nodeIssues.get(nodeId);
        if (missing) warnFeatureKeys.push(...missing);
      }
    }
    filtered = wrapWithWarnBanner(filtered, warnFeatureKeys);
  }

  return {
    components: filtered,
    droppedFeatures,
    replacedWithBlocker: false,
    addedWarnBanner: anyWarn,
  };
}

// ── Support lookup ────────────────────────────────────────────────────────

interface SupportLookup {
  widgets: Set<string>;
  valueKinds: Set<string>;
  actionKinds: Set<string>;
  transformKinds: Set<string>;
  boolExprOps: Set<string>;
}

function buildSupportLookup(caps: CapabilityVector): SupportLookup {
  return {
    widgets: new Set([...caps.widgets, ...ALWAYS_SUPPORTED_WIDGETS]),
    valueKinds: new Set(caps.valueKinds),
    actionKinds: new Set(caps.actionKinds),
    transformKinds: new Set(caps.transformKinds),
    boolExprOps: new Set(caps.boolExprOps),
  };
}

// ── Unsupported feature collection ────────────────────────────────────────

function collectUnsupportedFeatures(
  node: ComponentNode,
  support: SupportLookup,
): FeatureKey[] {
  const missing: FeatureKey[] = [];

  if (!support.widgets.has(node.type)) {
    missing.push(`widget.${node.type}`);
  }

  // Walk every prop value, checking any Value / Transform / BoolExpr shapes.
  walkPropsForFeatures(node.props, support, missing);

  // Walk every action, checking any Action / nested Action types.
  if (node.actions) {
    walkActionsForFeatures(node.actions, support, missing);
  }

  return missing;
}

function walkPropsForFeatures(
  value: unknown,
  support: SupportLookup,
  missing: FeatureKey[],
): void {
  if (value === null || value === undefined) return;
  if (typeof value !== "object") return;

  if (Array.isArray(value)) {
    for (const item of value) walkPropsForFeatures(item, support, missing);
    return;
  }

  const obj = value as Record<string, unknown>;

  // Value objects: { type: "static" | "state" | ... }
  const valueType = obj.type;
  if (typeof valueType === "string") {
    const knownValueKinds = new Set([
      "static",
      "state",
      "info",
      "request",
      "event",
      "transform",
      "conditional",
      "tween",
      "tweenSequence",
    ]);
    if (knownValueKinds.has(valueType)) {
      if (!support.valueKinds.has(valueType)) {
        missing.push(`value.${valueType}`);
      }
    }
    // Transforms inside TransformValue.by
    if (valueType === "transform" && Array.isArray(obj.by)) {
      for (const t of obj.by) {
        if (t && typeof t === "object") {
          const tt = (t as Record<string, unknown>).type;
          if (typeof tt === "string" && !support.transformKinds.has(tt)) {
            missing.push(`transform.${tt}`);
          }
          // Nested transforms inside MapTransform.transform, etc.
          walkPropsForFeatures(t, support, missing);
        }
      }
      walkPropsForFeatures(obj.input, support, missing);
      return;
    }
    // Conditional values: walk branches + else
    if (valueType === "conditional" && Array.isArray(obj.branches)) {
      for (const branch of obj.branches) {
        if (branch && typeof branch === "object") {
          const b = branch as Record<string, unknown>;
          walkBoolExprForFeatures(b.when, support, missing);
          walkPropsForFeatures(b.then, support, missing);
        }
      }
      walkPropsForFeatures(obj.else, support, missing);
      return;
    }
  }

  // BoolExpr objects: { op: "eq" | "and" | ... }
  const opKind = obj.op;
  if (typeof opKind === "string") {
    walkBoolExprForFeatures(obj, support, missing);
    return;
  }

  // Plain object: recurse into every value.
  for (const v of Object.values(obj)) {
    walkPropsForFeatures(v, support, missing);
  }
}

function walkBoolExprForFeatures(
  expr: unknown,
  support: SupportLookup,
  missing: FeatureKey[],
): void {
  if (!expr || typeof expr !== "object") return;
  const e = expr as Record<string, unknown>;
  const op = e.op;
  if (typeof op === "string") {
    if (!support.boolExprOps.has(op)) {
      missing.push(`boolExpr.${op}`);
    }
  }
  // Walk nested BoolExprs and Values.
  for (const v of Object.values(e)) {
    if (v && typeof v === "object") {
      if (Array.isArray(v)) {
        for (const item of v) walkBoolExprForFeatures(item, support, missing);
      } else {
        const inner = v as Record<string, unknown>;
        if (typeof inner.op === "string") {
          walkBoolExprForFeatures(inner, support, missing);
        } else if (typeof inner.type === "string") {
          walkPropsForFeatures(inner, support, missing);
        }
      }
    }
  }
}

function walkActionsForFeatures(
  actions: ActionMap,
  support: SupportLookup,
  missing: FeatureKey[],
): void {
  for (const action of Object.values(actions)) {
    walkSingleAction(action, support, missing);
  }
}

function walkSingleAction(
  action: unknown,
  support: SupportLookup,
  missing: FeatureKey[],
): void {
  if (!action || typeof action !== "object") return;
  const a = action as Record<string, unknown>;
  const kind = a.type;
  if (typeof kind === "string") {
    if (!support.actionKinds.has(kind)) {
      missing.push(`action.${kind}`);
    }
    // Recurse into common nesting shapes.
    if (kind === "actionGroup" && Array.isArray(a.actions)) {
      for (const nested of a.actions) walkSingleAction(nested, support, missing);
    } else if (kind === "conditionalAction" && Array.isArray(a.branches)) {
      for (const branch of a.branches) {
        if (branch && typeof branch === "object") {
          const b = branch as Record<string, unknown>;
          walkBoolExprForFeatures(b.when, support, missing);
          walkSingleAction(b.then, support, missing);
        }
      }
      if (a.else) walkSingleAction(a.else, support, missing);
    } else if (kind === "lifecycle") {
      walkSingleAction(a.action, support, missing);
      for (const k of ["onLoading", "onSuccess", "onError", "onComplete"] as const) {
        const v = a[k];
        if (Array.isArray(v)) {
          for (const item of v) walkSingleAction(item, support, missing);
        } else if (v) {
          walkSingleAction(v, support, missing);
        }
      }
    }
    // Walk any Value params nested in action fields (e.g. SetState.value).
    for (const [key, v] of Object.entries(a)) {
      if (key === "type" || key === "actions" || key === "branches") continue;
      walkPropsForFeatures(v, support, missing);
    }
  }
}

// ── Structural transforms ─────────────────────────────────────────────────

function buildParentMap(components: ComponentNode[]): Map<string, string> {
  const parentOf = new Map<string, string>();
  for (const node of components) {
    for (const childId of node.children) {
      parentOf.set(childId, node.id);
    }
  }
  return parentOf;
}

function dropNodes(
  components: ComponentNode[],
  toDrop: Set<string>,
  _parentOf: Map<string, string>,
): ComponentNode[] {
  // Strategy: rewrite each surviving node's `children` array to skip dropped
  // IDs and pull up the dropped node's own children in-place.
  const byId = new Map(components.map((n) => [n.id, n]));

  function expandChildList(ids: string[]): string[] {
    const out: string[] = [];
    for (const id of ids) {
      if (toDrop.has(id)) {
        const dropped = byId.get(id);
        if (dropped) {
          // Recursively expand in case multiple consecutive drops cascade.
          out.push(...expandChildList(dropped.children));
        }
      } else {
        out.push(id);
      }
    }
    return out;
  }

  const survivors: ComponentNode[] = [];
  for (const node of components) {
    if (toDrop.has(node.id)) continue;
    const newChildren = expandChildList(node.children);
    if (newChildren.length === node.children.length &&
        newChildren.every((id, i) => id === node.children[i])) {
      survivors.push(node);
    } else {
      survivors.push({ ...node, children: newChildren });
    }
  }
  return survivors;
}

// ── Synthesized FallbackPrompt nodes ──────────────────────────────────────

function buildBlockingRoot(
  nodeIssues: Map<string, FeatureKey[]>,
): ComponentNode {
  const allFeatures: FeatureKey[] = [];
  for (const missing of nodeIssues.values()) {
    for (const f of missing) allFeatures.push(f);
  }
  const uniqueFeatures = [...new Set(allFeatures)];
  return {
    id: BLOCK_ROOT_ID,
    type: "FallbackPrompt",
    kind: "primitive",
    childMode: "none",
    props: {
      title: "Update required",
      body:
        `This screen needs features that this app version can't render ` +
        `(${uniqueFeatures.slice(0, 3).join(", ")}` +
        `${uniqueFeatures.length > 3 ? `, +${uniqueFeatures.length - 3} more` : ""}). ` +
        `Please update from your app store to continue.`,
      severity: "blocking",
    },
    children: [],
    watches: [],
  };
}

function wrapWithWarnBanner(
  components: ComponentNode[],
  missingFeatures: FeatureKey[],
): ComponentNode[] {
  if (components.length === 0) return components;
  const originalRoot = components[0];
  const uniqueFeatures = [...new Set(missingFeatures)];

  const banner: ComponentNode = {
    id: WARN_BANNER_ID,
    type: "FallbackPrompt",
    kind: "primitive",
    childMode: "none",
    props: {
      title: "Some content needs an update",
      body:
        `Parts of this screen use features that your current app version ` +
        `can't fully render (${uniqueFeatures.slice(0, 2).join(", ")}` +
        `${uniqueFeatures.length > 2 ? `, +${uniqueFeatures.length - 2} more` : ""}). ` +
        `Please update when convenient for the full experience.`,
      severity: "warn",
    },
    children: [],
    watches: [],
  };

  const wrapper: ComponentNode = {
    id: WARN_ROOT_ID,
    type: "Column",
    kind: "layout",
    childMode: "multi",
    props: {
      mainAxisAlignment: "start",
      crossAxisAlignment: "stretch",
    },
    children: [WARN_BANNER_ID, originalRoot.id],
    watches: [],
  };

  return [wrapper, banner, ...components];
}
