// ── State Types ─────────────────────────────────────────────

export type StateScope = "page" | "app";

export interface StateDefinition {
  key: string;
  scope: StateScope;
  initial: unknown;
}

export interface PageState {
  scope: "page";
  data: Record<string, unknown>;
}

export interface AppState {
  scope: "app";
  data: Record<string, unknown>;
}

export type State = PageState | AppState;
