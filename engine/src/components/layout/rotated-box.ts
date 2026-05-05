import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface RotatedBoxProps {
  child?: Widget;
  quarterTurns: Valueable<number>;
  actions?: ActionMap;
}

export class RotatedBox extends SingleChildLayout {
  readonly type = "RotatedBox";
  private props: Omit<RotatedBoxProps, "child" | "actions">;

  private constructor(opts: RotatedBoxProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: RotatedBoxProps): RotatedBox {
    return new RotatedBox(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
