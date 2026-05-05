import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface OpacityProps {
  child?: Widget;
  opacity: Valueable<number>;
  actions?: ActionMap;
}

export class Opacity extends SingleChildLayout {
  readonly type = "Opacity";
  private props: Omit<OpacityProps, "child" | "actions">;

  private constructor(opts: OpacityProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: OpacityProps): Opacity {
    return new Opacity(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
