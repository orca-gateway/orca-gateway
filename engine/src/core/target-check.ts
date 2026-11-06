import type { Platform } from "../types/platform";
import { WIDGET_REGISTRY, type WidgetRegistryEntry } from "./widget-registry-gen";

/** One widget type a page uses that a declared target platform cannot render. */
export interface OffTargetHit {
  readonly type: string;
  readonly missing: readonly Platform[];
}

/**
 * Compare the widget types a page actually emitted against the page's
 * declared `targets`. Unknown types (plugin widgets) are skipped: their
 * support is declared by the plugin manifest, not the core registry.
 * Pure and deterministic; one hit per widget type.
 */
export function findOffTargetWidgets(
  components: ReadonlyArray<{ readonly type: string }>,
  targets: readonly Platform[],
  registry: Readonly<Record<string, WidgetRegistryEntry>> = WIDGET_REGISTRY,
): OffTargetHit[] {
  const seen = new Set<string>();
  const hits: OffTargetHit[] = [];
  for (const node of components) {
    if (seen.has(node.type)) continue;
    seen.add(node.type);
    const entry = registry[node.type];
    if (!entry) continue;
    const missing = targets.filter((t) => !entry.targets.includes(t));
    if (missing.length > 0) hits.push({ type: node.type, missing });
  }
  return hits;
}

const warned = new Set<string>();

/**
 * Log the hits for a page once. Repeated renders of the same page with the
 * same hits stay silent so a hot dev loop is not flooded; a new widget or a
 * new missing platform logs again. Returns true when something was logged.
 */
export function warnOffTargetOnce(
  pageId: string,
  hits: readonly OffTargetHit[],
  log: (message: string) => void = (m) => console.warn(m),
): boolean {
  const fresh = hits.filter((h) => {
    const key = `${pageId}|${h.type}|${h.missing.join(",")}`;
    if (warned.has(key)) return false;
    warned.add(key);
    return true;
  });
  if (fresh.length === 0) return false;
  const list = fresh.map((h) => `${h.type} (not on ${h.missing.join(", ")})`).join("; ");
  log(
    `[orca] page "${pageId}" uses widgets outside its declared targets: ${list}. ` +
      `Those clients will degrade them via the capability vector.`,
  );
  return true;
}

/** Test hook: forget every warning issued so far. */
export function resetOffTargetWarnings(): void {
  warned.clear();
}
