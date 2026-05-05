import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { AlignmentValue } from "../helpers";

export interface FractionallySizedBoxProps {
  child?: Widget;
  widthFactor?: Valueable<number>;
  heightFactor?: Valueable<number>;
  alignment?: Valueable<AlignmentValue>;
  actions?: ActionMap;
}

export class FractionallySizedBox extends SingleChildLayout {
  readonly type = "FractionallySizedBox";
  private props: Omit<FractionallySizedBoxProps, "child" | "actions">;

  private constructor(opts: FractionallySizedBoxProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: FractionallySizedBoxProps): FractionallySizedBox {
    return new FractionallySizedBox(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
