import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface LimitedBoxProps {
  child?: Widget;
  maxWidth?: Valueable<number>;
  maxHeight?: Valueable<number>;
  actions?: ActionMap;
}

export class LimitedBox extends SingleChildLayout {
  readonly type = "LimitedBox";
  private props: Omit<LimitedBoxProps, "child" | "actions">;

  private constructor(opts: LimitedBoxProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: LimitedBoxProps): LimitedBox {
    return new LimitedBox(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
