import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface SizedBoxProps {
  child?: Widget;
  width?: Valueable<number>;
  height?: Valueable<number>;
  actions?: ActionMap;
}

export class SizedBox extends SingleChildLayout {
  readonly type = "SizedBox";
  private props: Omit<SizedBoxProps, "child" | "actions">;

  private constructor(opts: SizedBoxProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SizedBoxProps): SizedBox {
    return new SizedBox(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
