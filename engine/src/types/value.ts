// ── Valueable<T> ─────────────────────────────────────────────
// Use on any component prop to make it Value-capable.
// `Valueable<string>` means the prop accepts either a static string
// or a reactive Value expression (V.appState, V.conditional, etc.).

export type Valueable<T> = T | Value;

// ── Value Types ──────────────────────────────────────────────

export type Value =
  | StaticValue
  | StateValue
  | InfoValue
  | RequestValue
  | EventValue
  | TransformValue
  | ConditionalValue
  | TweenValue
  | TweenSequenceValue;

export interface StaticValue {
  type: "static";
  value: unknown;
}

export interface StateValue {
  type: "state";
  key: string;
  scope: StateScope;
}

export type StateScope = "page" | "app";

export interface InfoValue {
  type: "info";
  key: string;
}

export interface RequestValue {
  type: "request";
  key: string;
}

export interface EventValue {
  type: "event";
  key: string;
}

export interface TransformValue {
  type: "transform";
  input: Value;
  by: Transform[];
}

export interface ConditionalValue {
  type: "conditional";
  branches: ConditionalBranch[];
  else?: Value;
}

export interface ConditionalBranch {
  when: BoolExpr;
  then: Value;
}

// ── Animation Value Types ──────────────────────────────────

export interface TweenValue {
  type: "tween";
  begin: unknown;
  end: unknown;
  animationId?: string;
}

export interface TweenSequenceItem {
  value: unknown;
  duration: number;
}

export interface TweenSequenceValue {
  type: "tweenSequence";
  items: TweenSequenceItem[];
  animationId?: string;
}

// ── Transform Types ─────────────────────────────────────────

export type Transform =
  // String
  | ToStringTransform
  | ToUpperCaseTransform
  | ToLowerCaseTransform
  | TrimTransform
  | TemplateTransform
  | RegexTransform
  | SubstringTransform
  | SplitTransform
  | JoinTransform
  // Number
  | MultiplyTransform
  | DivideTransform
  | AddTransform
  | SubtractTransform
  | ModuloTransform
  | RoundTransform
  | FloorTransform
  | CeilTransform
  | AbsTransform
  | ToFixedTransform
  // Boolean
  | NotTransform
  | ToBoolTransform
  // Collection
  | LengthTransform
  | AtTransform
  | FirstTransform
  | LastTransform
  | MapTransform
  | FilterTransform
  | ContainsTransform
  // Format
  | FormatCurrencyTransform
  | FormatDateTransform
  | FormatNumberTransform;

// String transforms
export interface ToStringTransform { type: "toString" }
export interface ToUpperCaseTransform { type: "toUpperCase" }
export interface ToLowerCaseTransform { type: "toLowerCase" }
export interface TrimTransform { type: "trim" }
export interface TemplateTransform {
  type: "template";
  /**
   * Template string with placeholders. `{{value}}` always resolves to the
   * previous pipeline step's output; any other `{{name}}` is looked up in
   * [params] and resolved via the current ValueResolver. Unknown names render
   * as the empty string (matches interpolateTemplates semantics for missing
   * keys and avoids leaking braces into production UI).
   */
  template: string;
  /** Optional named values. Each Value resolves via the active ValueResolver. */
  params?: Record<string, Value>;
}

export interface RegexTransform {
  type: "regex";
  pattern: string;
  flags?: string;
  /**
   * When present, switches the transform from match-only to replace mode.
   * Supports `$1..$9` capture-group backreferences (native), plus `{{value}}`
   * (the matched substring, i.e. `$&`) and `{{<name>}}` placeholders resolved
   * from [params]. Flags containing `g` replace all matches; otherwise the
   * first match only, matching JS `String.prototype.replace` semantics.
   */
  replacement?: string;
  /** Optional named values used inside [replacement]. */
  params?: Record<string, Value>;
}
export interface SubstringTransform { type: "substring"; start: number; length?: number }
export interface SplitTransform { type: "split"; separator: string }
export interface JoinTransform { type: "join"; separator: string }

// Number transforms
export interface MultiplyTransform { type: "multiply"; by: Value }
export interface DivideTransform { type: "divide"; by: Value }
export interface AddTransform { type: "add"; by: Value }
export interface SubtractTransform { type: "subtract"; by: Value }
export interface ModuloTransform { type: "modulo"; by: Value }
export interface RoundTransform { type: "round" }
export interface FloorTransform { type: "floor" }
export interface CeilTransform { type: "ceil" }
export interface AbsTransform { type: "abs" }
export interface ToFixedTransform { type: "toFixed"; decimals: number }

// Boolean transforms
export interface NotTransform { type: "not" }
export interface ToBoolTransform { type: "toBool" }

// Collection transforms
export interface LengthTransform { type: "length" }
export interface AtTransform { type: "at"; index: number }
export interface FirstTransform { type: "first" }
export interface LastTransform { type: "last" }
export interface MapTransform { type: "map"; transform: Transform }
export interface FilterTransform { type: "filter"; expr: BoolExpr }
export interface ContainsTransform { type: "contains"; value: Value }

// Format transforms
export interface FormatCurrencyTransform { type: "formatCurrency"; currency: string; decimals?: number }
export interface FormatDateTransform { type: "formatDate"; format: string }
export interface FormatNumberTransform { type: "formatNumber"; decimals?: number; useGrouping?: boolean }

// ── BoolExpr Types ──────────────────────────────────────────

export type BoolExpr =
  | EqExpr
  | NeqExpr
  | GtExpr
  | GteExpr
  | LtExpr
  | LteExpr
  | AndExpr
  | OrExpr
  | NotExpr
  | IsNullExpr
  | ContainsExpr
  | StartsWithExpr
  | MatchesExpr;

export interface EqExpr { op: "eq"; left: Value; right: Value }
export interface NeqExpr { op: "neq"; left: Value; right: Value }
export interface GtExpr { op: "gt"; left: Value; right: Value }
export interface GteExpr { op: "gte"; left: Value; right: Value }
export interface LtExpr { op: "lt"; left: Value; right: Value }
export interface LteExpr { op: "lte"; left: Value; right: Value }
export interface AndExpr { op: "and"; exprs: BoolExpr[] }
export interface OrExpr { op: "or"; exprs: BoolExpr[] }
export interface NotExpr { op: "not"; expr: BoolExpr }
export interface IsNullExpr { op: "isNull"; value: Value }
export interface ContainsExpr { op: "contains"; haystack: Value; needle: Value }
export interface StartsWithExpr { op: "startsWith"; str: Value; prefix: Value }
export interface MatchesExpr { op: "matches"; str: Value; regex: string }

// ── V.* Helper Constructors ─────────────────────────────────

export const V = {
  static(value: unknown): StaticValue {
    return { type: "static", value };
  },

  pageState(key: string): StateValue {
    return { type: "state", key, scope: "page" };
  },

  appState(key: string): StateValue {
    return { type: "state", key, scope: "app" };
  },

  info(key: string): InfoValue {
    return { type: "info", key };
  },

  request(key: string): RequestValue {
    return { type: "request", key };
  },

  event(key: string): EventValue {
    return { type: "event", key };
  },

  transform(input: Value, by: Transform[]): TransformValue {
    return { type: "transform", input, by };
  },

  when(branches: ConditionalBranch[], elseValue?: Value): ConditionalValue {
    return { type: "conditional", branches, else: elseValue };
  },

  Tween(begin: unknown, end: unknown, animationId?: string): TweenValue {
    const v: TweenValue = { type: "tween", begin, end };
    if (animationId) v.animationId = animationId;
    return v;
  },

  TweenSequence(items: TweenSequenceItem[], animationId?: string): TweenSequenceValue {
    const v: TweenSequenceValue = { type: "tweenSequence", items };
    if (animationId) v.animationId = animationId;
    return v;
  },

  /** Recursively extract all state watch keys from a Value tree */
  extractWatches(value: Value): string[] {
    const keys = new Set<string>();
    collectWatches(value, keys);
    return Array.from(keys);
  },
} as const;

function collectWatches(value: Value, keys: Set<string>): void {
  switch (value.type) {
    case "static":
    case "info":
    case "request":
    case "event":
    case "tween":
    case "tweenSequence":
      break;
    case "state":
      keys.add(value.key);
      break;
    case "transform":
      collectWatches(value.input, keys);
      for (const t of value.by) {
        collectTransformWatches(t, keys);
      }
      break;
    case "conditional":
      for (const branch of value.branches) {
        collectExprWatches(branch.when, keys);
        collectWatches(branch.then, keys);
      }
      if (value.else) collectWatches(value.else, keys);
      break;
  }
}

function collectTransformWatches(t: Transform, keys: Set<string>): void {
  switch (t.type) {
    case "multiply":
    case "divide":
    case "add":
    case "subtract":
    case "modulo":
      collectWatches(t.by, keys);
      break;
    case "contains":
      collectWatches(t.value, keys);
      break;
    case "filter":
      collectExprWatches(t.expr, keys);
      break;
    case "template":
    case "regex":
      // Named params may reference page/app state; without this, a watch
      // buried in a template param won't trigger an SDK rebuild.
      if (t.params) {
        for (const v of Object.values(t.params)) {
          collectWatches(v, keys);
        }
      }
      break;
  }
}

function collectExprWatches(expr: BoolExpr, keys: Set<string>): void {
  switch (expr.op) {
    case "eq":
    case "neq":
    case "gt":
    case "gte":
    case "lt":
    case "lte":
      collectWatches(expr.left, keys);
      collectWatches(expr.right, keys);
      break;
    case "and":
    case "or":
      for (const e of expr.exprs) collectExprWatches(e, keys);
      break;
    case "not":
      collectExprWatches(expr.expr, keys);
      break;
    case "isNull":
      collectWatches(expr.value, keys);
      break;
    case "contains":
      collectWatches(expr.haystack, keys);
      collectWatches(expr.needle, keys);
      break;
    case "startsWith":
      collectWatches(expr.str, keys);
      collectWatches(expr.prefix, keys);
      break;
    case "matches":
      collectWatches(expr.str, keys);
      break;
  }
}

// ── Expr.* Helper Constructors ──────────────────────────────

export const Expr = {
  eq(left: Value, right: Value | unknown): EqExpr {
    return { op: "eq", left, right: isValue(right) ? right : V.static(right) };
  },
  neq(left: Value, right: Value | unknown): NeqExpr {
    return { op: "neq", left, right: isValue(right) ? right : V.static(right) };
  },
  gt(left: Value, right: Value | unknown): GtExpr {
    return { op: "gt", left, right: isValue(right) ? right : V.static(right) };
  },
  gte(left: Value, right: Value | unknown): GteExpr {
    return { op: "gte", left, right: isValue(right) ? right : V.static(right) };
  },
  lt(left: Value, right: Value | unknown): LtExpr {
    return { op: "lt", left, right: isValue(right) ? right : V.static(right) };
  },
  lte(left: Value, right: Value | unknown): LteExpr {
    return { op: "lte", left, right: isValue(right) ? right : V.static(right) };
  },
  and(...exprs: BoolExpr[]): AndExpr {
    return { op: "and", exprs };
  },
  or(...exprs: BoolExpr[]): OrExpr {
    return { op: "or", exprs };
  },
  not(expr: BoolExpr): NotExpr {
    return { op: "not", expr };
  },
  isNull(value: Value): IsNullExpr {
    return { op: "isNull", value };
  },
  contains(haystack: Value, needle: Value | unknown): ContainsExpr {
    return { op: "contains", haystack, needle: isValue(needle) ? needle : V.static(needle) };
  },
  startsWith(str: Value, prefix: Value | unknown): StartsWithExpr {
    return { op: "startsWith", str, prefix: isValue(prefix) ? prefix : V.static(prefix) };
  },
  matches(str: Value, regex: string): MatchesExpr {
    return { op: "matches", str, regex };
  },
} as const;

const VALUE_KINDS: ReadonlySet<string> = new Set([
  "static", "state", "info", "request", "event",
  "transform", "conditional", "tween", "tweenSequence",
]);

export function isValue(v: unknown): v is Value {
  return (
    typeof v === "object" &&
    v !== null &&
    "type" in v &&
    typeof (v as Record<string, unknown>).type === "string" &&
    VALUE_KINDS.has((v as Record<string, unknown>).type as string)
  );
}


// ── TV: Transform Value Helpers ────────────────────────────

export class TV {
  // String
  static toString(): ToStringTransform { return { type: "toString" }; }
  static toUpperCase(): ToUpperCaseTransform { return { type: "toUpperCase" }; }
  static toLowerCase(): ToLowerCaseTransform { return { type: "toLowerCase" }; }
  static trim(): TrimTransform { return { type: "trim" }; }
  static template(template: string, params?: Record<string, Value>): TemplateTransform {
    const t: TemplateTransform = { type: "template", template };
    if (params && Object.keys(params).length > 0) t.params = params;
    return t;
  }
  static regex(
    pattern: string,
    flags?: string,
    replacement?: string,
    params?: Record<string, Value>,
  ): RegexTransform {
    const t: RegexTransform = { type: "regex", pattern };
    if (flags !== undefined) t.flags = flags;
    if (replacement !== undefined) t.replacement = replacement;
    if (params && Object.keys(params).length > 0) t.params = params;
    return t;
  }
  static substring(start: number, length?: number): SubstringTransform { return { type: "substring", start, length }; }
  static split(separator: string): SplitTransform { return { type: "split", separator }; }
  static join(separator: string): JoinTransform { return { type: "join", separator }; }

  // Number
  static multiply(by: Value): MultiplyTransform { return { type: "multiply", by }; }
  static divide(by: Value): DivideTransform { return { type: "divide", by }; }
  static add(by: Value): AddTransform { return { type: "add", by }; }
  static subtract(by: Value): SubtractTransform { return { type: "subtract", by }; }
  static modulo(by: Value): ModuloTransform { return { type: "modulo", by }; }
  static round(): RoundTransform { return { type: "round" }; }
  static floor(): FloorTransform { return { type: "floor" }; }
  static ceil(): CeilTransform { return { type: "ceil" }; }
  static abs(): AbsTransform { return { type: "abs" }; }
  static toFixed(decimals: number): ToFixedTransform { return { type: "toFixed", decimals }; }

  // Boolean
  static not(): NotTransform { return { type: "not" }; }
  static toBool(): ToBoolTransform { return { type: "toBool" }; }

  // Collection
  static length(): LengthTransform { return { type: "length" }; }
  static at(index: number): AtTransform { return { type: "at", index }; }
  static first(): FirstTransform { return { type: "first" }; }
  static last(): LastTransform { return { type: "last" }; }
  static map(transform: Transform): MapTransform { return { type: "map", transform }; }
  static filter(expr: BoolExpr): FilterTransform { return { type: "filter", expr }; }
  static contains(value: Value): ContainsTransform { return { type: "contains", value }; }

  // Format
  static formatCurrency(currency: string, decimals?: number): FormatCurrencyTransform { return { type: "formatCurrency", currency, decimals }; }
  static formatDate(format: string): FormatDateTransform { return { type: "formatDate", format }; }
  static formatNumber(decimals?: number, useGrouping?: boolean): FormatNumberTransform { return { type: "formatNumber", decimals, useGrouping }; }
}

// ── Version metadata (Epic 25b) ─────────────────────────────
//
// Per-kind protocol version metadata consumed by open-source/schema/gen-sdk-capabilities.ts.
// Empty maps = every kind defaults to "1.0.0". When a new kind is added, put an
// entry here with its protocol version, e.g.:
//
//   export const VALUE_KIND_VERSIONS = { "tween": { introducedIn: "1.1.0" } };

export const VALUE_KIND_VERSIONS: Record<
  string,
  { introducedIn: string; removedIn?: string }
> = {};

export const TRANSFORM_KIND_VERSIONS: Record<
  string,
  { introducedIn: string; removedIn?: string }
> = {};

export const BOOL_EXPR_OP_VERSIONS: Record<
  string,
  { introducedIn: string; removedIn?: string }
> = {};