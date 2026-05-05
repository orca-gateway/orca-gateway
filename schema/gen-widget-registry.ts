#!/usr/bin/env bun
/**
 * Widget registry codegen.
 *
 * Scans every widget class under open-source/engine/src/components/ and emits two
 * artifacts that MUST stay in lockstep with the source classes:
 *
 *   1. open-source/engine/src/core/widget-registry-gen.ts
 *      Typed registry consumed by the JSON tree encoder (see
 *      json-tree-encoder.ts) and by plugins that need to introspect the
 *      built-in widget set.
 *
 *   2. open-source/schema/widget-registry.json
 *      Language-neutral manifest with the same entries. Downstream tools
 *      (SDK type generators, alternative-language ports, plugin validators)
 *      can consume this without having to parse TypeScript. Keeping the
 *      manifest alongside the schemas in schema/ makes it part of the
 *      engine's public contract.
 *
 * Why codegen and not hand-written? The engine adds widgets routinely; any
 * drift between the TS union type, the registry, and downstream consumers
 * would show up as opaque runtime errors. Regenerating from a single source
 * of truth — the widget class files — removes the bookkeeping.
 *
 * Scraping strategy — widget files follow a strict, stable shape:
 *
 *   export class <Name> extends <BaseClass> {
 *     readonly type = "<WireName>";
 *     [readonly childMode = "none" as const;]  // when base default is overridden
 *     [getSlotWidgets() { ... slots.push({ name: "<slot>", ... }) ... }]
 *   }
 *
 * That's enough structure for ~30 lines of regex to extract everything. No
 * AST parser required — we pay for that simplicity with the restriction
 * that the scraper is only as correct as the conventions above. If a new
 * widget breaks the convention, the scraper skips it with a warning and
 * downstream consumers fail loudly on the missing entry.
 */
// @ts-expect-error Bun-specific API
import { readdirSync, readFileSync, writeFileSync, mkdirSync } from "fs";
// @ts-expect-error Bun-specific API
import { join, dirname, relative } from "path";

// ── Base class → default (kind, childMode) ──────────────────────────────────

const BASE_DEFAULTS: Record<string, { kind: string; childMode: string }> = {
  MultiChildLayout: { kind: "layout", childMode: "multi" },
  SingleChildLayout: { kind: "layout", childMode: "single" },
  PrimitiveWidget: { kind: "primitive", childMode: "none" },
  InputWidget: { kind: "input", childMode: "none" },
  ButtonWidget: { kind: "button", childMode: "single" },
  StructureWidget: { kind: "structure", childMode: "none" },
};

// ── Scraper ─────────────────────────────────────────────────────────────────

interface PropEntry {
  /** Prop name as declared in the TS interface. */
  name: string;
  /** `true` when declared with `?:`. */
  optional: boolean;
  /**
   * Semantic kind of the prop:
   *   - `value`     — a scalar/literal (optionally wrapped in Valueable<T>).
   *                   `type` holds the inner T; `valueable` says whether the
   *                   declaration was `Valueable<T>` or a plain T.
   *   - `widget`    — a single Widget reference. Used by button children only;
   *                   slot widgets are declared separately on structure kinds.
   *   - `widgetList`— a `Widget[]` reference. Used for dynamic-slot patterns
   *                   like BottomNavigationBar's `items`.
   *   - `actionMap` — an `ActionMap` reference. Surfaced separately so Dart
   *                   codegen can emit the right `Map<String, dynamic>?` type.
   */
  kind: "value" | "widget" | "widgetList" | "actionMap";
  /** For `value` kind: the inner TS type (e.g. `number`, `string`, `EdgeInsetsData`). Empty otherwise. */
  type: string;
  /** For `value` kind only: true when the TS declaration was `Valueable<T>`. */
  valueable: boolean;
}

interface RegistryEntry {
  type: string;
  kind: string;
  childMode: string;
  slots: string[];
  /** Typed prop shape extracted from the `<Name>Props` TS interface. */
  props: PropEntry[];
  /**
   * Protocol version when this widget was added. Missing annotations default
   * to "1.0.0" — only widgets added AFTER the initial 1.0 contract need an
   * explicit `static readonly introducedIn = "..."` on the class. See Epic 25b.
   */
  introducedIn: string;
  /** Protocol version when this widget was removed, or omitted if still present. */
  removedIn?: string;
  /**
   * `true` when the widget carries a frozen prop-shape contract — its `getProps()`
   * keys cannot change in subsequent versions. Enforced by the frozen-contract
   * golden test. Set with `static readonly frozen = true` on the class.
   * The canonical example is FallbackPrompt, which must be renderable by every
   * SDK version that ever shipped so the server always has an emergency channel.
   */
  frozen?: boolean;
  /**
   * `false` when the widget cannot render inside the Flutter Web preview
   * (Epic 38 task 38.1). Defaults to `true` — core widgets are web-capable
   * unless an author explicitly opts out by adding
   * `static readonly isSupportedOnWeb = false` to the class. Plugin widgets
   * declare the same flag in their plugin manifest, not here. The SDK's
   * ComponentRegistry consults this at render time: on web, an unsupported
   * widget is substituted with either its registered web stub or the
   * UnsupportedWidgetPlaceholder so preview sessions stay visually honest.
   */
  isSupportedOnWeb: boolean;
  /**
   * Action triggers this widget fires. Sourced from `static readonly triggers`
   * on the widget class. Empty when the widget fires no triggers (e.g. pure
   * display widgets like Text, Divider). Authors + tooling read this to know
   * which triggers can be attached to `actions: {...}` on a given widget —
   * e.g. `{"triggers": ["onTap", "onLongPress"]}` for ElevatedButton.
   *
   * Note: app-lifecycle triggers (`onAppBackground`, `onAppForeground`) and
   * action-chain triggers (`onSuccess`, `onError`, `onComplete`) are not
   * listed here because they're widget-agnostic — they fire on any widget
   * that declares them.
   */
  triggers: string[];
  sourceFile: string;
}

function walkTsFiles(dir: string, acc: string[] = []): string[] {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      walkTsFiles(full, acc);
    } else if (entry.isFile() && entry.name.endsWith(".ts") && entry.name !== "index.ts" && entry.name !== "helpers.ts") {
      acc.push(full);
    }
  }
  return acc;
}

function scrapeWidget(file: string): RegistryEntry | null {
  const src = readFileSync(file, "utf8");

  const classMatch = src.match(/export\s+class\s+(\w+)\s+extends\s+(\w+)/);
  if (!classMatch) return null;

  const [, className, baseClass] = classMatch;
  const base = BASE_DEFAULTS[baseClass];
  if (!base) return null;

  const typeMatch = src.match(/readonly\s+type\s*=\s*"([^"]+)"/);
  if (!typeMatch) {
    console.warn(`⚠  ${file}: class ${className} has no "readonly type" literal, skipping`);
    return null;
  }
  const wireType = typeMatch[1];

  let childMode = base.childMode;
  const childModeMatch = src.match(/readonly\s+childMode\s*=\s*"([^"]+)"/);
  if (childModeMatch) childMode = childModeMatch[1];

  // Structure widgets: extract static slot names from getSlotWidgets(). We
  // pull everything between `getSlotWidgets()` and its closing brace, then
  // match string-literal slot names. Template-literal names like
  // `action_${i}` are variadic and intentionally skipped — they're declared
  // at authoring time in the input tree, not ahead of time in the registry.
  const slots: string[] = [];
  if (base.kind === "structure") {
    const slotFn = src.match(/getSlotWidgets\s*\([^)]*\)[^{]*\{([\s\S]*?)\n\s{2}\}/);
    if (slotFn) {
      const body = slotFn[1];
      const nameRe = /slots\.push\(\s*\{\s*name:\s*"([^"]+)"/g;
      let m: RegExpExecArray | null;
      while ((m = nameRe.exec(body)) !== null) slots.push(m[1]);
    }
  }

  // Version + frozen annotations (Epic 25b). All optional — defaults mean
  // "shipped in the initial 1.0 contract, still supported, not frozen".
  const introducedMatch = src.match(/static\s+readonly\s+introducedIn\s*=\s*"([^"]+)"/);
  const introducedIn = introducedMatch ? introducedMatch[1] : "1.0.0";

  const removedMatch = src.match(/static\s+readonly\s+removedIn\s*=\s*"([^"]+)"/);
  const removedIn = removedMatch ? removedMatch[1] : undefined;

  const frozenMatch = src.match(/static\s+readonly\s+frozen\s*=\s*true/);
  const frozen = frozenMatch ? true : undefined;

  // Epic 38, task 38.1 — web-support opt-out annotation. Default is true for
  // core widgets; an author sets it false by adding
  // `static readonly isSupportedOnWeb = false` to the class. We explicitly
  // match only the literal `false` so typos like `"false"` fail loudly instead
  // of silently flipping the bit.
  const webOptOutMatch = src.match(/static\s+readonly\s+isSupportedOnWeb\s*=\s*false\b/);
  const isSupportedOnWeb = webOptOutMatch ? false : true;

  // Action triggers — scraped from `static readonly triggers = ["..."]`.
  // Missing annotation = empty array (no widget-specific triggers). We only
  // match array-literal string items to keep this deterministic; anything
  // more dynamic should live in the triggers file, not here.
  const triggers = scrapeTriggers(src);

  const props = scrapeProps(src, className, slots);

  const entry: RegistryEntry = {
    type: wireType,
    kind: base.kind,
    childMode,
    slots,
    props,
    introducedIn,
    isSupportedOnWeb,
    triggers,
    sourceFile: file,
  };
  if (removedIn) entry.removedIn = removedIn;
  if (frozen) entry.frozen = frozen;
  return entry;
}

/**
 * Scrape the `<ClassName>Props` interface body for typed prop entries.
 *
 * Assumptions that must hold in every widget source file:
 *   1. The interface is named exactly `<ClassName>Props` and closes with a
 *      line containing only `}`.
 *   2. Every field is declared on a single line shaped like `name[?]: Type;`
 *      (no multi-line inline object types, no nested blocks).
 *   3. `children`, `child` (when it's the slot child of a single-child
 *      layout/button), `actions`, and any name already listed in the
 *      widget's fixed `slots` are handled by the encoder/base class and are
 *      therefore not surfaced as typed props in the registry.
 *
 * We only strip `child` when the widget is NOT a button — button widgets
 * route their child through the ButtonWidget base, but the typed-prop
 * constructor on the downstream side still wants to accept it. We keep that
 * consistent by always stripping here and letting the Dart generator emit
 * `Widget? child` from `childMode === 'single'` instead of from the props
 * list. Same logic for `children` on multi-child layouts.
 */
/**
 * Scrape `static readonly triggers = ["onTap", ...]` from the class body.
 * Returns `[]` when the annotation is missing. Matches only simple array
 * literals of string literals — anything richer (computed values, spreads)
 * is intentionally out of scope so this stays deterministic.
 */
function scrapeTriggers(src: string): string[] {
  const m = src.match(/static\s+readonly\s+triggers\s*(?::\s*[^=]+)?=\s*\[([\s\S]*?)\]\s+as\s+const\b|static\s+readonly\s+triggers\s*(?::\s*[^=]+)?=\s*\[([\s\S]*?)\]/);
  if (!m) return [];
  const body = (m[1] ?? m[2] ?? "").trim();
  if (!body) return [];
  const names: string[] = [];
  const nameRe = /"([^"]+)"|'([^']+)'/g;
  let match: RegExpExecArray | null;
  while ((match = nameRe.exec(body)) !== null) {
    names.push(match[1] ?? match[2]);
  }
  return names;
}

function scrapeProps(src: string, className: string, slots: string[]): PropEntry[] {
  const ifaceRe = new RegExp(
    `export\\s+interface\\s+${className}Props\\s*\\{([\\s\\S]*?)\\n\\}`,
  );
  const m = src.match(ifaceRe);
  if (!m) return [];
  const body = m[1];

  const skip = new Set<string>(["children", "child", "actions", ...slots]);
  const out: PropEntry[] = [];

  for (const raw of body.split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("//") || line.startsWith("/*") || line.startsWith("*")) continue;
    const lm = line.match(/^(\w+)(\?)?:\s*(.+?);?$/);
    if (!lm) continue;
    const [, name, opt, rawType] = lm;
    if (skip.has(name)) continue;

    const optional = !!opt;
    const typeStr = rawType.trim();

    if (typeStr === "ActionMap") {
      // `actions` is filtered above, but some widgets spell the trigger map
      // field differently. Record it as actionMap so Dart codegen can emit
      // `Map<String, dynamic>?` rather than `dynamic`.
      out.push({ name, optional, kind: "actionMap", type: "", valueable: false });
      continue;
    }
    if (typeStr === "Widget") {
      out.push({ name, optional, kind: "widget", type: "", valueable: false });
      continue;
    }
    if (typeStr === "Widget[]") {
      out.push({ name, optional, kind: "widgetList", type: "", valueable: false });
      continue;
    }

    const valMatch = typeStr.match(/^Valueable<(.+)>$/);
    if (valMatch) {
      out.push({ name, optional, kind: "value", type: valMatch[1].trim(), valueable: true });
    } else {
      out.push({ name, optional, kind: "value", type: typeStr, valueable: false });
    }
  }
  return out;
}

// ── Emitters ────────────────────────────────────────────────────────────────

function emitTS(entries: RegistryEntry[]): string {
  const banner = `// Code generated by open-source/schema/gen-widget-registry.ts — DO NOT EDIT.\n`
    + `// Run: bun run open-source/schema/gen-widget-registry.ts\n\n`;
  const header = `export interface WidgetPropEntry {\n`
    + `  readonly name: string;\n`
    + `  readonly optional: boolean;\n`
    + `  readonly kind: "value" | "widget" | "widgetList" | "actionMap";\n`
    + `  readonly type: string;\n`
    + `  readonly valueable: boolean;\n`
    + `}\n\n`
    + `export interface WidgetRegistryEntry {\n`
    + `  readonly type: string;\n`
    + `  readonly kind: "layout" | "primitive" | "input" | "button" | "structure";\n`
    + `  readonly childMode: "single" | "multi" | "none";\n`
    + `  readonly slots: readonly string[];\n`
    + `  readonly props: readonly WidgetPropEntry[];\n`
    + `  readonly introducedIn: string;\n`
    + `  readonly removedIn?: string;\n`
    + `  readonly frozen?: boolean;\n`
    + `  readonly isSupportedOnWeb: boolean;\n`
    + `  readonly triggers: readonly string[];\n`
    + `}\n\n`;
  const body = `export const WIDGET_REGISTRY: Readonly<Record<string, WidgetRegistryEntry>> = {\n`
    + entries
      .map((e) => {
        const parts = [
          `type: ${JSON.stringify(e.type)}`,
          `kind: ${JSON.stringify(e.kind)}`,
          `childMode: ${JSON.stringify(e.childMode)}`,
          `slots: ${JSON.stringify(e.slots)}`,
          `props: ${JSON.stringify(e.props)}`,
          `introducedIn: ${JSON.stringify(e.introducedIn)}`,
          `isSupportedOnWeb: ${e.isSupportedOnWeb}`,
          `triggers: ${JSON.stringify(e.triggers)}`,
        ];
        if (e.removedIn) parts.push(`removedIn: ${JSON.stringify(e.removedIn)}`);
        if (e.frozen) parts.push(`frozen: true`);
        return `  ${JSON.stringify(e.type)}: { ${parts.join(", ")} },`;
      })
      .join("\n")
    + `\n};\n`;
  return banner + header + body;
}

function emitManifest(entries: RegistryEntry[]): string {
  // Language-neutral JSON manifest. Downstream tools read this instead of
  // parsing TypeScript. Versioning and schemaVersion live at the top so
  // consumers can detect a breaking shape change.
  //
  // schemaVersion stays at 1 because the new fields (introducedIn, removedIn,
  // frozen) are backward-compatible additions — consumers that don't know
  // about them (e.g. the current tools/gen-go-registry.ts which hard-checks
  // schemaVersion === 1) continue to work. Bump schemaVersion only when a
  // shape change would actually break existing consumers.
  const manifest = {
    $schema: "https://orcagateway.com/schemas/widget-registry.json",
    schemaVersion: 1,
    generatedBy: "open-source/schema/gen-widget-registry.ts",
    widgets: entries.map((e) => {
      const out: Record<string, unknown> = {
        type: e.type,
        kind: e.kind,
        childMode: e.childMode,
        slots: e.slots,
        props: e.props,
        introducedIn: e.introducedIn,
        isSupportedOnWeb: e.isSupportedOnWeb,
        triggers: e.triggers,
      };
      if (e.removedIn) out.removedIn = e.removedIn;
      if (e.frozen) out.frozen = true;
      return out;
    }),
  };
  return JSON.stringify(manifest, null, 2) + "\n";
}

// ── Run ─────────────────────────────────────────────────────────────────────

function main() {
  // @ts-expect-error Bun-specific API
  const repoRoot = join(import.meta.dir, "..");
  const componentsDir = join(repoRoot, "engine/src/components");
  const tsOut = join(repoRoot, "engine/src/core/widget-registry-gen.ts");
  const manifestOut = join(repoRoot, "schema/widget-registry.json");

  const files = walkTsFiles(componentsDir);
  const entries: RegistryEntry[] = [];
  for (const f of files) {
    const entry = scrapeWidget(f);
    if (entry) entries.push(entry);
  }

  if (entries.length === 0) {
    console.error("✘  No widgets found — refusing to write empty registry.");
    process.exit(1);
  }

  // Sort by wire type name so regenerated files have a stable byte layout.
  entries.sort((a, b) => a.type.localeCompare(b.type));

  try {
    mkdirSync(dirname(tsOut), { recursive: true });
    writeFileSync(tsOut, emitTS(entries));
    writeFileSync(manifestOut, emitManifest(entries));
  } catch (err) {
    console.error("✘  Failed to write registry files:", err);
    process.exit(1);
  }

  console.log(`✔  widget registry: ${entries.length} widgets`);
  // @ts-expect-error Bun-specific API
  console.log(`   → ${relative(process.cwd(), tsOut)}`);
  // @ts-expect-error Bun-specific API
  console.log(`   → ${relative(process.cwd(), manifestOut)}`);

  const structures = entries.filter((e) => e.kind === "structure");
  console.log(`   (${structures.length} structure widgets, ${entries.length - structures.length} non-structure)`);
}

main();
