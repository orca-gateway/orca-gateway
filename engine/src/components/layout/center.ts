import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface CenterProps {
  child?: Widget;
  widthFactor?: Valueable<number>;
  heightFactor?: Valueable<number>;
  actions?: ActionMap;
}

export class Center extends SingleChildLayout {
  readonly type = "Center";
  private props: Omit<CenterProps, "child" | "actions">;

  private constructor(opts: CenterProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: CenterProps): Center {
    return new Center(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
