import type { BoolExpr, Value } from "./value";

// ── Action Types ────────────────────────────────────────────

export type Action =
  | NavigateAction
  | GoBackAction
  | SwitchTabAction
  | OpenDrawerAction
  | OpenDialogAction
  | CloseDialogAction
  | SetStateAction
  | ClearStateAction
  | PersistStateAction
  | ServerActionRef
  | ShowSnackbarAction
  | ShowToastAction
  | UpdateComponentAction
  | DeleteComponentAction
  | AddComponentAction
  | CopyToClipboardAction
  | ShareAction
  | OpenUrlAction
  | ActionGroup
  | ConditionalAction
  | AnimateForwardAction
  | AnimateReverseAction
  | RefetchPageAction
  | UpdateSubPageAction
  | LifecycleAction
  | DebugLogAction
  | OnceAction
  | AlwaysAction
  | CustomAction;

// Navigation
export interface NavigateAction {
  type: "navigate";
  route: string | Value;
  params?: Record<string, Value>;
  replace?: boolean;
}

export interface GoBackAction {
  type: "goBack";
}

export interface SwitchTabAction {
  type: "switchTab";
  tabId: string;
}

export interface OpenDrawerAction {
  type: "openDrawer";
}

export interface OpenDialogAction {
  type: "openDialog";
  dialogId: string;
  heightFactor?: number;
}

export interface CloseDialogAction {
  type: "closeDialog";
}

// State
export interface SetStateAction {
  type: "setState";
  scope: "page" | "app";
  key: string;
  value: Value;
}

export interface ClearStateAction {
  type: "clearState";
  scope: "page" | "app";
  key: string;
}

export interface PersistStateAction {
  type: "persistState";
  scope: "page" | "app";
  key: string;
  storage: "local" | "session";
}

// Server
export interface ServerActionRef {
  type: "serverAction";
  id: string;
  params?: Record<string, Value>;
}

// UI
export interface ShowSnackbarAction {
  type: "showSnackbar";
  message: string | Value;
  duration?: number;
  action?: string;
}

export interface ShowToastAction {
  type: "showToast";
  message: string | Value;
}

export interface UpdateComponentAction {
  type: "updateComponent";
  id: string;
  props: Record<string, unknown>;
}

export interface DeleteComponentAction {
  type: "deleteComponent";
  id: string;
}

export interface AddComponentAction {
  type: "addComponent";
  parentId: string;
  node: unknown;
  position?: number;
}

// Device
export interface CopyToClipboardAction {
  type: "copyToClipboard";
  text: string | Value;
}

export interface ShareAction {
  type: "share";
  title: string;
  message: string | Value;
  url?: string;
}

export interface OpenUrlAction {
  type: "openUrl";
  url: string | Value;
}

// Animation
export interface AnimateForwardAction {
  type: "animateForward";
  animationId: string;
}

export interface AnimateReverseAction {
  type: "animateReverse";
  animationId: string;
}

// Page refresh
export interface RefetchPageAction {
  type: "refetchPage";
}

// SubPage
export interface UpdateSubPageAction {
  type: "updateSubPage";
  subPageId: string | Value;
  pageId: string | Value;
  params?: Record<string, Value>;
  mode: "replace" | "join" | Value;
}

// Lifecycle
export interface LifecycleAction {
  type: "lifecycle";
  action: Action;
  onLoading?: Action | Action[];
  onSuccess?: Action | Action[];
  onError?: Action | Action[];
  onComplete?: Action | Action[];
}

// Diagnostics
//
// `DebugLog` is a client-side action that writes a structured log entry to
// the SDK's diagnostic sink (Flutter: `dart:developer` + `debugPrint`). It
// never reaches the server. Every field is optional so authors can fire a
// bare `DebugLog()` as a breadcrumb or pass the full bag to dump state +
// event payload + request info alongside a message.
//
// Each payload field accepts either a static scalar OR a `Value`, so
// authors can reference pageState / appState / V.event(...) inside
// `message` or `data`:
//
//   actions: {
//     onChange: DebugLog({
//       level: "info",
//       tag: "checkout",
//       message: "Qty changed",
//       data: { qty: V.event("value"), cartTotal: V.pageState("total") },
//       includeState: true,
//       includeEvent: true,
//     }),
//   }
export type DebugLogLevel = "debug" | "info" | "warn" | "error";

export interface DebugLogAction {
  type: "debugLog";
  /** Severity. Default: "debug". */
  level?: DebugLogLevel;
  /** Short, human-readable summary. Supports Value references. */
  message?: string | Value;
  /** Logger namespace / category (e.g. "checkout", "auth"). */
  tag?: string;
  /** Structured payload. Either a single Value or a map of named Values. */
  data?: Value | Record<string, Value | string | number | boolean | null>;
  /** When true, append current pageState + appState snapshot. */
  includeState?: boolean;
  /** When true, append the event payload (if this action fires from an input callback). */
  includeEvent?: boolean;
  /** When true, append RequestInfo (platform, locale, appVersion, etc.). */
  includeRequest?: boolean;
  /** When true, print a stack trace to the console alongside the entry. */
  includeStackTrace?: boolean;
}

// Fire-mode wrappers
//
// Wrap any Action with `Once(inner)` or `Always(inner)` to control how many
// times it fires when attached to a repeatable trigger (onVisible, onInit,
// onAppForeground, onScrollEnd, etc.). Default for lifecycle triggers is
// documented per-trigger; gesture / input triggers ignore fireMode because
// firing-per-event is their only sensible behavior.
//
// Example:
//   actions: {
//     onVisible: Once(DebugLog({ message: "first shown" })),      // once per mount
//     onScrollEnd: Always(DebugLog({ message: "scroll ended" })), // every end
//   }
//
// The SDK dedupes `Once` actions by (widget-id, trigger, fireMode-id) so
// a subtree rebuilt under the same key won't re-fire. Authors who want
// "once per app lifetime" or "once per key" are expected to track that in
// appState themselves.
export interface OnceAction {
  type: "once";
  action: Action;
}

export interface AlwaysAction {
  type: "always";
  action: Action;
}

// Custom — uses template literal to prevent degrading the Action discriminated union
export interface CustomAction {
  type: `custom:${string}`;
  [key: string]: unknown;
}

// Groups
export interface ActionGroup {
  type: "actionGroup";
  mode: "sequential" | "parallel";
  actions: Action[];
}

export interface ConditionalAction {
  type: "conditionalAction";
  branches: { when: BoolExpr; then: Action }[];
  else?: Action;
}

// ── Action Triggers ─────────────────────────────────────────
//
// Triggers group into four buckets by who fires them:
//
//   1. Widget-specific (declared in each widget class's `static readonly
//      triggers`): onTap, onLongPress, onDoubleTap, onChange, onScrollBegin,
//      onScrolling, onScrollEnd, onRefresh, onAction, onComplete.
//      These fire from Flutter gesture/input/scroll callbacks specific to
//      the widget. See `widget-registry.json` for which triggers each
//      widget supports.
//
//   2. Widget lifecycle (applied to ANY widget by OrcaLifecycleWrapper):
//      - onInit    — once, after the widget's first frame (mount). Fires
//                    from `WidgetsBinding.addPostFrameCallback` in the
//                    lifecycle wrapper's `initState`.
//      - onVisible — CURRENT BEHAVIOR: fires once on mount, identical to
//                    onInit. True viewport-based visibility detection
//                    (fire when the widget enters the scroll viewport) is
//                    tracked as a follow-up and will land with the
//                    `visibility_detector` dep + a conformance fixture.
//                    For fire-frequency control use the Once() / Always()
//                    wrappers — Once() is redundant on the current
//                    behavior (already fires once), but locks your intent
//                    in place for when real visibility lands.
//
//   3. App lifecycle (fire regardless of which widget they're attached to
//      — they hook `WidgetsBindingObserver`): onAppBackground, onAppForeground.
//      The older `onBackground` / `onForeground` names remain supported as
//      aliases so existing code keeps working, but new code should use the
//      `onApp*` form to make scope explicit.
//
//   4. Action-chain (fire based on a wrapped action's result; see
//      `LifecycleAction`): onSuccess, onError, onComplete.

export type ActionTrigger =
  // Widget-specific (see `widget.triggers` in widget-registry.json)
  | "onTap"
  | "onLongPress"
  | "onDoubleTap"
  | "onChange"
  | "onScrollBegin"
  | "onScrolling"
  | "onScrollEnd"
  | "onRefresh"
  | "onAction"
  // Widget lifecycle (universal, applied to any widget)
  | "onVisible"
  | "onInit"
  // App lifecycle (universal, fire on app pause/resume)
  | "onAppBackground"
  | "onAppForeground"
  // Aliases for onAppBackground / onAppForeground — kept for backward
  // compatibility. New code should prefer the `onApp*` names above.
  | "onBackground"
  | "onForeground"
  // Action-chain (fire from inside a LifecycleAction wrapper)
  | "onSuccess"
  | "onError"
  | "onComplete";

export type ActionMap<T extends string | number | symbol = (string & {})> = Partial<Record<ActionTrigger | T, Action>>;

// ── Action Helper Constructors ──────────────────────────────

export function Navigate(route: string | Value, params?: Record<string, Value>): NavigateAction {
  return { type: "navigate", route, params };
}

export function GoBack(): GoBackAction {
  return { type: "goBack" };
}

export function SwitchTab(tabId: string): SwitchTabAction {
  return { type: "switchTab", tabId };
}

export function OpenDrawer(): OpenDrawerAction {
  return { type: "openDrawer" };
}

export function OpenDialog(dialogId: string, heightFactor?: number): OpenDialogAction {
  const a: OpenDialogAction = { type: "openDialog", dialogId };
  if (heightFactor !== undefined) a.heightFactor = heightFactor;
  return a;
}

export function CloseDialog(): CloseDialogAction {
  return { type: "closeDialog" };
}

export function SetState(key: string, value: Value, scope: "page" | "app" = "page"): SetStateAction {
  return { type: "setState", scope, key, value };
}

export function ClearState(key: string, scope: "page" | "app" = "page"): ClearStateAction {
  return { type: "clearState", scope, key };
}

export function ServerAction(id: string, params?: Record<string, Value>): ServerActionRef {
  return { type: "serverAction", id, params };
}

export function CopyToClipboard(text: string | Value): CopyToClipboardAction {
  return { type: "copyToClipboard", text };
}

export function Share(title: string, message: string | Value, url?: string): ShareAction {
  return { type: "share", title, message, url };
}

export function OpenUrl(url: string | Value): OpenUrlAction {
  return { type: "openUrl", url };
}

export function ShowSnackbar(message: string | Value, duration?: number): ShowSnackbarAction {
  return { type: "showSnackbar", message, duration };
}

export function ShowToast(message: string | Value): ShowToastAction {
  return { type: "showToast", message };
}

export function Sequential(...actions: Action[]): ActionGroup {
  return { type: "actionGroup", mode: "sequential", actions };
}

export function Parallel(...actions: Action[]): ActionGroup {
  return { type: "actionGroup", mode: "parallel", actions };
}

export function When(
  branches: { when: BoolExpr; then: Action }[],
  elseAction?: Action,
): ConditionalAction {
  return { type: "conditionalAction", branches, else: elseAction };
}

export function AnimateForward(animationId: string): AnimateForwardAction {
  return { type: "animateForward", animationId };
}

export function AnimateReverse(animationId: string): AnimateReverseAction {
  return { type: "animateReverse", animationId };
}

export interface LifecycleOptions {
  onLoading?: Action | Action[];
  onSuccess?: Action | Action[];
  onError?: Action | Action[];
  onComplete?: Action | Action[];
}

export function Lifecycle(action: Action, options: LifecycleOptions): LifecycleAction {
  return { type: "lifecycle", action, ...options };
}

export function RefetchPage(): RefetchPageAction {
  return { type: "refetchPage" };
}

export function UpdateSubPage(
  subPageId: string | Value,
  pageId: string | Value,
  mode: "replace" | "join" | Value = "replace",
  params?: Record<string, Value>,
): UpdateSubPageAction {
  const a: UpdateSubPageAction = { type: "updateSubPage", subPageId, pageId, mode };
  if (params) a.params = params;
  return a;
}

export function Custom(type: `custom:${string}`, params?: Record<string, unknown>): CustomAction {
  return { type, ...params };
}

/**
 * Build a DebugLog action. All fields are optional — call `DebugLog()` for a
 * breadcrumb, or fill in `{message, data, includeState, ...}` for a full
 * diagnostic dump. Values inside `message` / `data` resolve client-side
 * (V.pageState, V.appState, V.event, …) exactly like anywhere else.
 */
export function DebugLog(opts: Omit<DebugLogAction, "type"> = {}): DebugLogAction {
  return { type: "debugLog", ...opts };
}

/**
 * Wrap an action so it fires at most once per (widget-id, trigger) pair.
 * Re-firing the same trigger on the same node is a no-op. Useful for
 * onVisible / onInit / onAppForeground when the author wants breadcrumb-
 * style "first time only" semantics.
 */
export function Once(action: Action): OnceAction {
  return { type: "once", action };
}

/**
 * Wrap an action so it fires on every trigger invocation, explicitly
 * opting out of any default-dedupe behavior on lifecycle triggers. Pairs
 * with `Once(...)` — use whichever makes the intent clearer at the call site.
 */
export function Always(action: Action): AlwaysAction {
  return { type: "always", action };
}

// ── Version metadata (Epic 25b) ─────────────────────────────
//
// Per-kind protocol version metadata consumed by open-source/schema/gen-sdk-capabilities.ts.
// Empty map = every action kind defaults to "1.0.0". When a new action kind is
// added, put an entry here with the protocol version it was introduced in, e.g.:
//
//   "biometricAuth": { introducedIn: "1.2.0" }
//
// Removal also lives here via an optional `removedIn`. The `CustomAction`
// sentinel (type: string) is not a real kind and is excluded from codegen.
export const ACTION_KIND_VERSIONS: Record<
  string,
  { introducedIn: string; removedIn?: string }
> = {};
