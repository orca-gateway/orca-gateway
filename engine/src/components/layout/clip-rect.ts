import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";

export interface ClipRectProps {
  child?: Widget;
  actions?: ActionMap;
}

export class ClipRect extends SingleChildLayout {
  readonly type = "ClipRect";
  private props: Omit<ClipRectProps, "child" | "actions">;

  private constructor(opts: ClipRectProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ClipRectProps): ClipRect {
    return new ClipRect(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
