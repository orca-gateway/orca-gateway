import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";

export interface IntrinsicHeightProps {
  child?: Widget;
  actions?: ActionMap;
}

export class IntrinsicHeight extends SingleChildLayout {
  readonly type = "IntrinsicHeight";
  private props: Omit<IntrinsicHeightProps, "child" | "actions">;

  private constructor(opts: IntrinsicHeightProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: IntrinsicHeightProps): IntrinsicHeight {
    return new IntrinsicHeight(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
