import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

/**
 * FallbackPrompt — the frozen, immutable "something needs your attention"
 * primitive (Epic 25b, task 25b.5).
 *
 * Every SDK version that has ever shipped MUST be able to render this widget
 * with this exact prop shape. That invariant is the universal emergency
 * channel the server uses when a client's capability vector doesn't include
 * a feature the server wants to emit — the server can always fall back to a
 * FallbackPrompt and be confident the client will render it correctly.
 *
 * Consequences:
 *
 *   1. `introducedIn = "1.0.0"` is a deliberate backdate. Even though this
 *      file lands after protocol 1.0 was cut, the widget represents the
 *      initial contract — it must claim v1 so every v1+ client recognizes it.
 *
 *   2. `frozen = true` is propagated into widget-registry.json by the codegen
 *      scraper. The frozen-contract golden test in
 *      engine/test/frozen-contract.test.ts diffs the current getProps()
 *      key set against schema/golden/frozen-widgets.json. Any drift
 *      fails CI — a PR that mutates these props must explicitly update the
 *      golden, which is a visible red flag in code review.
 *
 *   3. Do NOT add new props, remove props, rename props, or tighten types.
 *      If you need a richer variant, introduce a NEW widget at a higher
 *      protocolVersion — do not alter this one.
 *
 * Props:
 *   - title:    short headline   (required)
 *   - body:     longer text       (required)
 *   - ctaLabel: optional button label for an action the user can take
 *   - ctaUrl:   optional URL the CTA navigates to (external link or deep link)
 *   - severity: visual + semantic level — "info" | "warn" | "blocking"
 */

export type FallbackPromptSeverity = "info" | "warn" | "blocking";

export interface FallbackPromptProps {
  title: Valueable<string>;
  body: Valueable<string>;
  ctaLabel?: Valueable<string>;
  ctaUrl?: Valueable<string>;
  severity: Valueable<FallbackPromptSeverity>;
  actions?: ActionMap;
}

export class FallbackPrompt extends PrimitiveWidget {
  readonly type = "FallbackPrompt";

  // Epic 25b, task 25b.7 / 25b.5 — read by gen-widget-registry.ts scraper.
  static readonly introducedIn = "1.0.0";
  static readonly frozen = true;

  private props: Omit<FallbackPromptProps, "actions">;

  private constructor(opts: FallbackPromptProps) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: FallbackPromptProps): FallbackPrompt {
    return new FallbackPrompt(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
