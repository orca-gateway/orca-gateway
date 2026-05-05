import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface FlexibleProps {
  child?: Widget;
  flex?: Valueable<number>;
  fit?: Valueable<"tight" | "loose">;
  actions?: ActionMap;
}

export class Flexible extends SingleChildLayout {
  readonly type = "Flexible";
  private props: Omit<FlexibleProps, "child" | "actions">;

  private constructor(opts: FlexibleProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: FlexibleProps): Flexible {
    return new Flexible(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
