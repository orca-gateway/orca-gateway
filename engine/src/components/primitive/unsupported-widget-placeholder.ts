import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

/**
 * UnsupportedWidgetPlaceholder — the honest "this widget cannot run here"
 * card (Epic 38, task 38.2).
 *
 * Semantically different from FallbackPrompt:
 *
 *   - FallbackPrompt is the *unknown-widget* fallback. It fires when a client
 *     receives a component type its SDK build has never heard of (forward
 *     compat, stale cache, etc.). The content is generic because the client
 *     has no metadata.
 *
 *   - UnsupportedWidgetPlaceholder is the *known-but-unusable* fallback. It
 *     fires when the client knows exactly what the widget is, but the current
 *     platform cannot render it — primarily the Flutter Web preview editor
 *     encountering a plugin widget whose author has not shipped a web stub.
 *     Because the client has full metadata (displayName, icon, docsUrl), the
 *     card can be informative: "Google Maps runs only in the compiled mobile
 *     app — open in simulator to preview."
 *
 * Why it exists as a core engine widget at all, given that the SDK can
 * synthesize it at render time:
 *
 *   1. Declarative plugin stubs (Epic 38, Slice B) may want to emit this card
 *      deliberately as part of a multi-node stub tree ("this feature shows X
 *      on mobile; here's the web placeholder plus a note"). For that to work
 *      the encoder has to recognize the type.
 *
 *   2. Conformance fixtures need a named widget they can assert on —
 *      synthesizing it client-side would make the wire format under-specified.
 *
 *   3. Dashboard tooling (missing-widgets screen in Slice C) walks rendered
 *      component trees looking for this wire type to count "unsupported
 *      widget" occurrences per page.
 *
 * Props are intentionally small — this widget should never grow into a
 * general-purpose card. If you need a richer "something is missing" UI, make
 * a new widget; do not bolt props onto this one.
 *
 *   - widgetType: the wire type that was unsupported (e.g. "OrcaGoogleMap").
 *                 Always present — this is the machine-readable key the
 *                 dashboard aggregates on.
 *   - displayName: optional human-readable name ("Google Maps"). When absent
 *                  the SDK falls back to `widgetType`.
 *   - iconName: optional Material icon identifier shown in the card header.
 *   - docsUrl: optional documentation link for the tenant to learn more.
 *   - reason: short tooltip/body text explaining why the widget cannot render.
 *             Defaults are SDK-side so the server does not have to repeat
 *             boilerplate for every occurrence.
 */

export interface UnsupportedWidgetPlaceholderProps {
  widgetType: Valueable<string>;
  displayName?: Valueable<string>;
  iconName?: Valueable<string>;
  docsUrl?: Valueable<string>;
  reason?: Valueable<string>;
  actions?: ActionMap;
}

export class UnsupportedWidgetPlaceholder extends PrimitiveWidget {
  readonly type = "UnsupportedWidgetPlaceholder";

  // Part of the 1.0.0 wire-format baseline alongside every other built-in
  // widget. A client advertising a capability vector that omits this type
  // will trip the safe-degrade path and see a FallbackPrompt — the correct
  // behavior for a client too old (or too stripped-down) to render it.
  static readonly introducedIn = "1.0.0";

  // This widget IS the web-capable substitute, so it trivially supports web.
  // Declaring it explicitly keeps the intent searchable for future readers.
  static readonly isSupportedOnWeb = true;

  private props: Omit<UnsupportedWidgetPlaceholderProps, "actions">;

  private constructor(opts: UnsupportedWidgetPlaceholderProps) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: UnsupportedWidgetPlaceholderProps): UnsupportedWidgetPlaceholder {
    return new UnsupportedWidgetPlaceholder(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
