import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface BlurViewProps {
  child?: Widget;
  /** Horizontal blur sigma. Default 10. */
  blurX?: Valueable<number>;
  /** Vertical blur sigma. Default 10. */
  blurY?: Valueable<number>;
  /** Overlay color on top of the blur (e.g. "#FFFFFF80" for frosted glass). */
  overlayColor?: Valueable<string>;
  /** Border radius for clipping. */
  borderRadius?: Valueable<number>;
  actions?: ActionMap;
}

/**
 * A layout widget that applies a Gaussian blur effect to the area
 * behind its child (frosted glass / glassmorphism pattern).
 *
 * Wraps Flutter's `BackdropFilter` with `ClipRRect` and an optional
 * semi-transparent overlay color for the classic blur card effect.
 */
export class BlurView extends SingleChildLayout {
  readonly type = "BlurView";
  private props: Omit<BlurViewProps, "child" | "actions">;

  private constructor(opts: BlurViewProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: BlurViewProps): BlurView {
    return new BlurView(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
