import type { ActionMap } from "./action";

// ── Component Kind ──────────────────────────────────────────

export type ComponentKind = "layout" | "primitive" | "input" | "button" | "structure";
export type ChildMode = "single" | "multi" | "none";

// ── ComponentNode (wire format) ─────────────────────────────

export interface ComponentNode {
  id: string;
  type: string;
  kind: ComponentKind;
  childMode: ChildMode;
  props: Record<string, unknown>;
  children: string[];
  watches: string[];
  actions?: ActionMap;
}
