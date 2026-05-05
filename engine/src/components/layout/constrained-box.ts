import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { BoxConstraintsData } from "../helpers";

export interface ConstrainedBoxProps {
  child?: Widget;
  constraints: Valueable<BoxConstraintsData>;
  actions?: ActionMap;
}

export class ConstrainedBox extends SingleChildLayout {
  readonly type = "ConstrainedBox";
  private props: Omit<ConstrainedBoxProps, "child" | "actions">;

  private constructor(opts: ConstrainedBoxProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ConstrainedBoxProps): ConstrainedBox {
    return new ConstrainedBox(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
