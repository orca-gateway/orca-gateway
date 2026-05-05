import { CloseDialogAction } from "../types";
import type { ActionContext, PageContext } from "../types/context";
import type { ComponentNode } from "../types/node";
import { flatten, Widget, type FlattenOptions } from "../types/widget";

// ── Response Actions (what the action author returns) ────

export type ResponseAction =
  | SetStateResponse
  | NavigateResponse
  | GoBackResponse
  | UpdateComponentResponse
  | DeleteComponentResponse
  | AddComponentResponse
  | ReplaceComponentResponse
  | ShowSnackbarResponse
  | ShowToastResponse
  | CopyToClipboardResponse
  | CloseDialogAction;

export interface SetStateResponse {
  type: "setState";
  scope: "page" | "app";
  key: string;
  value: unknown;
}

export interface NavigateResponse {
  type: "navigate";
  route: string;
  params?: Record<string, unknown>;
}

export interface GoBackResponse {
  type: "goBack";
}

/**
 * Update props of an existing component by key/ID.
 * For simple prop changes on leaf or layout nodes (e.g. change text, color).
 * Does NOT affect children — use replaceComponent for subtree swaps.
 */
export interface UpdateComponentResponse {
  type: "updateComponent";
  id: string;
  props: Record<string, unknown>;
}

export interface DeleteComponentResponse {
  type: "deleteComponent";
  id: string;
}

/**
 * Insert a widget tree into a parent.
 * Pass a `widget` — the engine auto-flattens it into ComponentNode[] for the client.
 * Use `keyPrefix` to namespace flattened node IDs (e.g. `"cart-item-42"` → IDs become
 * `"cart-item-42_0"`, `"cart-item-42_1"`, etc.). This prevents ID collisions when
 * the same action is called multiple times. Use a string or a function for dynamic prefixes.
 */
export interface AddComponentResponse {
  type: "addComponent";
  parentId: string;
  widget: Widget;
  keyPrefix: string;
  position?: number;
}

/**
 * Replace a component (and its entire subtree) with a new widget tree.
 * Use this when you need to swap out a layout with children.
 * Pass a `widget` — the engine auto-flattens it.
 * Use `keyPrefix` to namespace flattened node IDs.
 */
export interface ReplaceComponentResponse {
  type: "replaceComponent";
  targetId: string;
  widget: Widget;
  keyPrefix: string;
}

export interface ShowSnackbarResponse {
  type: "showSnackbar";
  message: string;
  duration?: number;
  action?: string;
}

export interface ShowToastResponse {
  type: "showToast";
  message: string;
}

export interface CopyToClipboardResponse {
  type: "copyToClipboard";
  text: string;
}

// ── Wire format (what the client receives after engine resolves widgets) ──

export type WireResponseAction =
  | SetStateResponse
  | NavigateResponse
  | GoBackResponse
  | UpdateComponentResponse
  | DeleteComponentResponse
  | WireAddComponentResponse
  | WireReplaceComponentResponse
  | ShowSnackbarResponse
  | ShowToastResponse
  | CopyToClipboardResponse
  | CloseDialogAction;

export interface WireAddComponentResponse {
  type: "addComponent";
  parentId: string;
  components: ComponentNode[];
  position?: number;
}

export interface WireReplaceComponentResponse {
  type: "replaceComponent";
  targetId: string;
  components: ComponentNode[];
}

/**
 * Check if an ID is auto-generated (numeric) vs a stable key set via .withKey().
 */
function isAutoId(id: string): boolean {
  return /^\d+$/.test(id);
}

/**
 * Prefix auto-generated node IDs in a flattened component list.
 * Stable keys (set via .withKey()) are preserved as-is so they remain
 * targetable by future server actions.
 */
function prefixComponents(components: ComponentNode[], prefix: string): ComponentNode[] {
  // Build remap: auto IDs get prefixed, stable keys stay
  const idMap = new Map<string, string>();
  for (const node of components) {
    idMap.set(node.id, isAutoId(node.id) ? `${prefix}_${node.id}` : node.id);
  }

  const oldIds = new Set(components.map((n) => n.id));
  return components.map((node) => {
    const newId = idMap.get(node.id)!;
    const newChildren = node.children.map((cid) =>
      idMap.get(cid) ?? cid,
    );
    // Remap slot references in props (e.g. Scaffold's body/appBar point to child IDs)
    const newProps: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(node.props)) {
      newProps[k] = typeof v === "string" && oldIds.has(v) ? (idMap.get(v) ?? v) : v;
    }
    return { ...node, id: newId, children: newChildren, props: newProps };
  });
}

/**
 * Resolve ResponseAction[] into wire format.
 * Auto-flattens Widget instances and applies keyPrefix to node IDs.
 *
 * When `actionCtx` is provided (always, from engine.ts), widgets are
 * flattened with a synthesized `PageContext` derived from the ActionContext
 * — this lets authors return `CompositeWidget` trees from server actions
 * just like in `Page.render`. The synthesized context has no `pageId`/
 * `routePath`/`routeParams`/`infoData` (server actions aren't tied to a
 * page render), so composites that don't read those fields keep working;
 * ones that do read them receive empty strings/undefined.
 */
export function resolveResponseActions(
  actions: ResponseAction[],
  actionCtx?: ActionContext,
): WireResponseAction[] {
  const flattenOpts: FlattenOptions | undefined = actionCtx
    ? {
        ctx: actionContextToPageContext(actionCtx),
        info: undefined,
      }
    : undefined;

  return actions.map((action) => {
    if (action.type === "addComponent") {
      const { widget, keyPrefix, ...rest } = action;
      const components = prefixComponents(flatten(widget, flattenOpts), keyPrefix);
      return { ...rest, components };
    }
    if (action.type === "replaceComponent") {
      const { widget, keyPrefix, ...rest } = action;
      const components = prefixComponents(flatten(widget, flattenOpts), keyPrefix);
      return { ...rest, components };
    }
    return action;
  });
}

/** Build a minimal PageContext from an ActionContext so composites can run. */
function actionContextToPageContext(ctx: ActionContext): PageContext {
  return {
    requestInfo: ctx.requestInfo,
    pageId: "",
    routePath: "",
    routeParams: {},
    pageState: ctx.pageState,
    appState: ctx.appState,
  };
}

// ── Schema Validation ─────────────────────────────────────

export type SchemaFieldType = "string" | "number" | "boolean" | "object" | "array";

export interface SchemaField {
  type: SchemaFieldType;
  required?: boolean;
}

export type RequestSchema = Record<string, SchemaField>;

export function validateParams(
  params: Record<string, unknown>,
  schema: RequestSchema,
): string | null {
  for (const [key, field] of Object.entries(schema)) {
    const value = params[key];

    if (value === undefined || value === null) {
      if (field.required !== false) {
        return `Missing required parameter: "${key}"`;
      }
      continue;
    }

    const actualType = Array.isArray(value) ? "array" : typeof value;
    if (actualType !== field.type) {
      return `Parameter "${key}" must be of type "${field.type}", got "${actualType}"`;
    }
  }

  return null;
}

// ── Server Action Definition ──────────────────────────────

export type ExecuteFn = (
  context: ActionContext,
) => ResponseAction[] | Promise<ResponseAction[]>;

export interface ServerActionConfig {
  id: string;
  schema?: RequestSchema;
  execute: ExecuteFn;
}

export class ServerActionDefinition {
  readonly id: string;
  readonly schema?: RequestSchema;
  readonly execute: ExecuteFn;

  private constructor(config: ServerActionConfig) {
    this.id = config.id;
    this.schema = config.schema;
    this.execute = config.execute;
  }

  static create(config: ServerActionConfig): ServerActionDefinition {
    return new ServerActionDefinition(config);
  }
}
