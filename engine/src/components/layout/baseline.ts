import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface BaselineProps {
  child?: Widget;
  baseline: Valueable<number>;
  baselineType: Valueable<"alphabetic" | "ideographic">;
  actions?: ActionMap;
}

export class Baseline extends SingleChildLayout {
  readonly type = "Baseline";
  private props: Omit<BaselineProps, "child" | "actions">;

  private constructor(opts: BaselineProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: BaselineProps): Baseline {
    return new Baseline(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
