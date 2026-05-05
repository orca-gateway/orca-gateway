import type { Value, Transform, BoolExpr } from "../types/value";
import { V, isValue } from "../types/value";
import type { RequestInfo } from "../types/context";

const MAX_REGEX_PATTERN_LENGTH = 200;
const MAX_REGEX_INPUT_LENGTH = 10_000;

// ── Value Resolver (Server-Side) ───────────────────────────
//
// Resolves Values that are **static from the client's perspective**:
//   V.static, V.info, V.request → resolved to plain values
//
// Values that reference client-side state are left as Value objects
// so the SDK can re-resolve them when state changes:
//   V.pageState, V.appState, V.transform(V.pageState(...), [...])
//

export interface ValueResolverContext {
  pageState: Record<string, unknown>;
  appState: Record<string, unknown>;
  infoData: unknown;
  requestInfo: RequestInfo;
  /**
   * Per-app configuration bag reachable via `{{config.X}}` template variables
   * inside string props. Optional — omit for OSS engine usage, populated by
   * the cloud app-server with the app's environment config. See
   * interpolateTemplates() for the substitution semantics.
   */
  config?: Record<string, unknown>;
}

export class ValueResolver {
  constructor(private ctx: ValueResolverContext) {}

  /** Resolve a Value to its concrete value. Non-Value inputs pass through. */
  resolve(value: unknown): unknown {
    if (!isValue(value)) return value;

    switch (value.type) {
      case "static":
        return value.value;

      case "state":
        return value.scope === "page"
          ? getByDotPath(this.ctx.pageState, value.key)
          : getByDotPath(this.ctx.appState, value.key);

      case "info":
        return getByDotPath(this.ctx.infoData, value.key);

      case "request":
        return getByDotPath(this.ctx.requestInfo, value.key);

      case "event":
      case "tween":
      case "tweenSequence":
        // Client-side constructs — return as-is for SDK resolution.
        return value;

      case "transform":
        return this.resolveTransform(this.resolve(value.input), value.by);

      case "conditional":
        return this.resolveConditional(value);
    }
  }

  /**
   * Recursively resolve all Value objects in a props record.
   * Values that reference state are left as-is for client-side resolution.
   */
  resolveProps(props: Record<string, unknown>): Record<string, unknown> {
    const resolved: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(props)) {
      resolved[key] = this.resolveDeep(val);
    }
    return resolved;
  }

  // ── Transform pipeline (10.7) ────────────────────────────

  private resolveTransform(input: unknown, transforms: Transform[]): unknown {
    let current = input;
    for (const t of transforms) {
      current = this.applyTransform(current, t);
    }
    return current;
  }

  private applyTransform(current: unknown, t: Transform): unknown {
    switch (t.type) {
      // ── String transforms (10.1) ─────────────────────────
      case "toString":
        return String(current ?? "");
      case "toUpperCase":
        return String(current).toUpperCase();
      case "toLowerCase":
        return String(current).toLowerCase();
      case "trim":
        return String(current).trim();
      case "template":
        return this.expandPlaceholders(t.template, current, t.params);
      case "regex": {
        if (t.pattern.length > MAX_REGEX_PATTERN_LENGTH) return null;
        try {
          const input = String(current).slice(0, MAX_REGEX_INPUT_LENGTH);
          const re = new RegExp(t.pattern, t.flags);
          // Match-only mode (replacement absent): return match[0] or null.
          if (t.replacement === undefined) {
            const match = input.match(re);
            return match ? match[0] : null;
          }
          // Replace mode: for each match, expand {{value}} (= matched text) +
          // named placeholders AFTER native `$1..$9` backref expansion, so the
          // two substitution systems compose cleanly without escaping games.
          return input.replace(re, (matched: string, ...args: unknown[]) => {
            const groups = args.slice(0, -2) as string[];
            const backreffed = t.replacement!.replace(/\$([1-9])/g, (_, g: string) => {
              const idx = Number(g) - 1;
              return idx < groups.length ? (groups[idx] ?? "") : "";
            });
            return this.expandPlaceholders(backreffed, matched, t.params);
          });
        } catch {
          return null;
        }
      }
      case "substring":
        return String(current).substring(t.start, t.length !== undefined ? t.start + t.length : undefined);
      case "split":
        return String(current).split(t.separator);
      case "join":
        return Array.isArray(current) ? current.join(t.separator) : String(current);

      // ── Number transforms (10.2) ─────────────────────────
      case "add":
        return (current as number) + (this.resolve(t.by) as number);
      case "subtract":
        return (current as number) - (this.resolve(t.by) as number);
      case "multiply":
        return (current as number) * (this.resolve(t.by) as number);
      case "divide":
        return (current as number) / (this.resolve(t.by) as number);
      case "modulo":
        return (current as number) % (this.resolve(t.by) as number);
      case "round":
        return Math.round(current as number);
      case "floor":
        return Math.floor(current as number);
      case "ceil":
        return Math.ceil(current as number);
      case "abs":
        return Math.abs(current as number);
      case "toFixed":
        return (current as number).toFixed(t.decimals);

      // ── Boolean transforms (10.3) ────────────────────────
      case "not":
        return !current;
      case "toBool":
        return Boolean(current);

      // ── Collection transforms (10.4) ─────────────────────
      case "length":
        if (Array.isArray(current)) return current.length;
        if (typeof current === "string") return current.length;
        return 0;
      case "at":
        return Array.isArray(current) ? current[t.index] : undefined;
      case "first":
        return Array.isArray(current) ? current[0] : undefined;
      case "last":
        return Array.isArray(current) ? current[current.length - 1] : undefined;
      case "map":
        return Array.isArray(current)
          ? current.map((item) => this.applyTransform(item, t.transform))
          : current;
      case "filter":
        return Array.isArray(current)
          ? current.filter((item) => this.evaluateBoolExpr(t.expr, item))
          : current;
      case "contains": {
        const needle = this.resolve(t.value);
        if (Array.isArray(current)) return current.includes(needle);
        if (typeof current === "string") return current.includes(String(needle));
        return false;
      }

      // ── Format transforms (10.5) ─────────────────────────
      case "formatCurrency": {
        const num = current as number;
        const decimals = t.decimals ?? 2;
        return new Intl.NumberFormat(undefined, {
          style: "currency",
          currency: t.currency,
          minimumFractionDigits: decimals,
          maximumFractionDigits: decimals,
        }).format(num);
      }
      case "formatDate": {
        const date = current instanceof Date ? current : new Date(current as string | number);
        return formatDateString(date, t.format);
      }
      case "formatNumber": {
        const num = current as number;
        return new Intl.NumberFormat(undefined, {
          minimumFractionDigits: t.decimals,
          maximumFractionDigits: t.decimals,
          useGrouping: t.useGrouping ?? true,
        }).format(num);
      }
    }
  }

  // ── Conditional resolution ───────────────────────────────

  private resolveConditional(value: Value & { type: "conditional" }): unknown {
    for (const branch of value.branches) {
      if (this.evaluateBoolExpr(branch.when)) {
        return this.resolve(branch.then);
      }
    }
    return value.else ? this.resolve(value.else) : undefined;
  }

  /** Evaluate a BoolExpr. Optional contextValue for filter expressions. */
  evaluateBoolExpr(expr: BoolExpr, contextValue?: unknown): boolean {
    switch (expr.op) {
      case "eq":
        return this.resolve(expr.left) === this.resolve(expr.right);
      case "neq":
        return this.resolve(expr.left) !== this.resolve(expr.right);
      case "gt":
        return (this.resolve(expr.left) as number) > (this.resolve(expr.right) as number);
      case "gte":
        return (this.resolve(expr.left) as number) >= (this.resolve(expr.right) as number);
      case "lt":
        return (this.resolve(expr.left) as number) < (this.resolve(expr.right) as number);
      case "lte":
        return (this.resolve(expr.left) as number) <= (this.resolve(expr.right) as number);
      case "and":
        return expr.exprs.every((e) => this.evaluateBoolExpr(e, contextValue));
      case "or":
        return expr.exprs.some((e) => this.evaluateBoolExpr(e, contextValue));
      case "not":
        return !this.evaluateBoolExpr(expr.expr, contextValue);
      case "isNull": {
        const val = this.resolve(expr.value);
        return val === null || val === undefined;
      }
      case "contains": {
        const haystack = this.resolve(expr.haystack);
        const needle = this.resolve(expr.needle);
        if (typeof haystack === "string") return haystack.includes(String(needle));
        if (Array.isArray(haystack)) return haystack.includes(needle);
        return false;
      }
      case "startsWith":
        return String(this.resolve(expr.str)).startsWith(String(this.resolve(expr.prefix)));
      case "matches": {
        if (expr.regex.length > MAX_REGEX_PATTERN_LENGTH) return false;
        try {
          const input = String(this.resolve(expr.str)).slice(0, MAX_REGEX_INPUT_LENGTH);
          return new RegExp(expr.regex).test(input);
        } catch {
          return false;
        }
      }
    }
  }

  /**
   * Substitute `{{value}}` (= [currentValue]) and `{{<name>}}` (= resolved
   * [params][name]) inside a template string. Shared by the `template` and
   * `regex` (replace-mode) transforms. Identifier-only placeholders — no dot
   * paths — matching `/\{\{\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\}\}/g`. Unknown
   * names render as the empty string to avoid leaking braces into UI.
   */
  private expandPlaceholders(
    template: string,
    currentValue: unknown,
    params: Record<string, Value> | undefined,
  ): string {
    return template.replace(
      /\{\{\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\}\}/g,
      (_, name: string) => {
        if (name === "value") return String(currentValue ?? "");
        if (params && Object.prototype.hasOwnProperty.call(params, name)) {
          const resolved = this.resolve(params[name]);
          return resolved === null || resolved === undefined ? "" : String(resolved);
        }
        return "";
      },
    );
  }

  /**
   * Substitute `{{requestInfo.X}}` and `{{config.X}}` tokens in a plain string
   * using the context. Only those two roots are recognized — every other path
   * is left as the literal `{{...}}` token so authoring mistakes surface in
   * the rendered output rather than silently losing content. Mirrors
   * Resolver.InterpolateTemplates in the Go port for byte-for-byte parity.
   */
  interpolateTemplates(s: string): string {
    if (!s.includes("{{")) return s;
    let out = "";
    let i = 0;
    while (i < s.length) {
      if (s[i] === "{" && s[i + 1] === "{") {
        const end = s.indexOf("}}", i + 2);
        if (end === -1) {
          out += s.slice(i);
          return out;
        }
        const path = s.slice(i + 2, end).trim();
        out += this.lookupTemplatePath(path);
        i = end + 2;
        continue;
      }
      out += s[i];
      i++;
    }
    return out;
  }

  private lookupTemplatePath(path: string): string {
    if (path.startsWith("requestInfo.")) {
      const val = getByDotPath(this.ctx.requestInfo, path.slice("requestInfo.".length));
      return val === undefined || val === null ? "" : String(val);
    }
    if (path.startsWith("config.")) {
      const val = getByDotPath(this.ctx.config ?? {}, path.slice("config.".length));
      return val === undefined || val === null ? "" : String(val);
    }
    return `{{${path}}}`;
  }

  private resolveDeep(val: unknown): unknown {
    if (val === null || val === undefined) return val;
    if (typeof val === "string") return this.interpolateTemplates(val);
    if (typeof val !== "object") return val;

    if (isValue(val)) {
      if (!hasStateRefs(val)) {
        // No state refs → fully resolve to plain value
        return this.resolve(val);
      }
      // Has state refs → partially resolve: replace server-only leaves
      // (info, request) with V.static(resolved) so the SDK can handle them
      return this.partialResolve(val);
    }

    if (Array.isArray(val)) {
      return val.map((item) => this.resolveDeep(item));
    }

    // Plain object — recurse into values
    const result: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(val as Record<string, unknown>)) {
      result[k] = this.resolveDeep(v);
    }
    return result;
  }

  /**
   * Partially resolve a Value tree: replace server-only leaves (info, request,
   * static) with V.static(resolved) while keeping state refs and the overall
   * structure intact for SDK-side resolution.
   */
  private partialResolve(value: Value): Value {
    switch (value.type) {
      case "static":
        return value;

      case "state":
      case "event":
      case "tween":
      case "tweenSequence":
        // Keep as-is — SDK resolves these client-side
        return value;

      case "info":
        return V.static(getByDotPath(this.ctx.infoData, value.key));

      case "request":
        return V.static(getByDotPath(this.ctx.requestInfo, value.key));

      case "transform":
        return {
          type: "transform",
          input: this.partialResolve(value.input),
          by: value.by.map((t) => this.partialResolveTransform(t)),
        };

      case "conditional":
        return {
          type: "conditional",
          branches: value.branches.map((b) => ({
            when: this.partialResolveBoolExpr(b.when),
            then: this.partialResolve(b.then),
          })),
          ...(value.else ? { else: this.partialResolve(value.else) } : {}),
        };
    }
  }

  private partialResolveTransform(t: Transform): Transform {
    switch (t.type) {
      case "multiply":
      case "divide":
      case "add":
      case "subtract":
      case "modulo":
        return { ...t, by: this.partialResolve(t.by) };
      case "contains":
        return { ...t, value: this.partialResolve(t.value) };
      case "filter":
        return { ...t, expr: this.partialResolveBoolExpr(t.expr) };
      case "template":
      case "regex": {
        // Params may reference state — if we don't recurse into them here,
        // any `V.info(...)` / `V.request(...)` inside a param would leak to
        // the SDK unresolved, and any `V.pageState(...)` would survive but
        // not be flagged as a watch at the right level. We rebuild the params
        // map preserving state/event refs and statically folding the rest.
        if (!t.params) return t;
        const resolved: Record<string, Value> = {};
        for (const [k, v] of Object.entries(t.params)) {
          resolved[k] = this.partialResolve(v);
        }
        return { ...t, params: resolved };
      }
      default:
        return t;
    }
  }

  private partialResolveBoolExpr(expr: BoolExpr): BoolExpr {
    switch (expr.op) {
      case "eq":
      case "neq":
      case "gt":
      case "gte":
      case "lt":
      case "lte":
        return { ...expr, left: this.partialResolve(expr.left), right: this.partialResolve(expr.right) };
      case "and":
      case "or":
        return { ...expr, exprs: expr.exprs.map((e) => this.partialResolveBoolExpr(e)) };
      case "not":
        return { ...expr, expr: this.partialResolveBoolExpr(expr.expr) };
      case "isNull":
        return { ...expr, value: this.partialResolve(expr.value) };
      case "contains":
        return { ...expr, haystack: this.partialResolve(expr.haystack), needle: this.partialResolve(expr.needle) };
      case "startsWith":
        return { ...expr, str: this.partialResolve(expr.str), prefix: this.partialResolve(expr.prefix) };
      case "matches":
        return { ...expr, str: this.partialResolve(expr.str) };
    }
  }
}

// ── State reference detection ──────────────────────────────

/** Returns true if the Value tree needs client-side resolution (state or event refs). */
function hasStateRefs(value: Value): boolean {
  return V.extractWatches(value).length > 0 || containsEventRefs(value);
}

/** Check if a Value tree contains any event references. */
function containsEventRefs(value: Value): boolean {
  switch (value.type) {
    case "event":
      return true;
    case "transform":
      return containsEventRefs(value.input);
    case "conditional":
      return value.branches.some(b => containsEventRefs(b.then)) ||
        (value.else ? containsEventRefs(value.else) : false);
    default:
      return false;
  }
}

// ── Dot-path traversal ─────────────────────────────────────

/** Traverse an object/array by dot-delimited path. Numeric segments index arrays. */
export function getByDotPath(obj: unknown, path: string): unknown {
  const segments = path.split(".");
  let current: unknown = obj;

  for (const seg of segments) {
    if (current === null || current === undefined) return undefined;

    if (Array.isArray(current)) {
      const idx = Number(seg);
      if (Number.isNaN(idx)) return undefined;
      current = current[idx];
    } else if (typeof current === "object") {
      current = (current as Record<string, unknown>)[seg];
    } else {
      return undefined;
    }
  }

  return current;
}

// ── Date formatting ────────────────────────────────────────

function formatDateString(date: Date, format: string): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return format
    .replace("yyyy", String(date.getFullYear()))
    .replace("MM", pad(date.getMonth() + 1))
    .replace("dd", pad(date.getDate()))
    .replace("HH", pad(date.getHours()))
    .replace("mm", pad(date.getMinutes()))
    .replace("ss", pad(date.getSeconds()));
}

