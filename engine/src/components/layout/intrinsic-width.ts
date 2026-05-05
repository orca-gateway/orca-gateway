import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface IntrinsicWidthProps {
  child?: Widget;
  stepWidth?: Valueable<number>;
  stepHeight?: Valueable<number>;
  actions?: ActionMap;
}

export class IntrinsicWidth extends SingleChildLayout {
  readonly type = "IntrinsicWidth";
  private props: Omit<IntrinsicWidthProps, "child" | "actions">;

  private constructor(opts: IntrinsicWidthProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: IntrinsicWidthProps): IntrinsicWidth {
    return new IntrinsicWidth(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
