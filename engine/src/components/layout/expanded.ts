import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface ExpandedProps {
  child?: Widget;
  flex?: Valueable<number>;
  actions?: ActionMap;
}

export class Expanded extends SingleChildLayout {
  readonly type = "Expanded";
  private props: Omit<ExpandedProps, "child" | "actions">;

  private constructor(opts: ExpandedProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ExpandedProps): Expanded {
    return new Expanded(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
