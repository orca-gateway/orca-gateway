import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";

export interface GestureDetectorProps {
  child?: Widget;
  actions?: ActionMap;
}

export class GestureDetector extends SingleChildLayout {
  readonly type = "GestureDetector";
  static readonly triggers = ["onTap", "onLongPress", "onDoubleTap"] as const;
  private props: Omit<GestureDetectorProps, "child" | "actions">;

  private constructor(opts: GestureDetectorProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: GestureDetectorProps): GestureDetector {
    return new GestureDetector(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
