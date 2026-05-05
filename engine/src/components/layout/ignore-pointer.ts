import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface IgnorePointerProps {
  child?: Widget;
  ignoring?: Valueable<boolean>;
  actions?: ActionMap;
}

export class IgnorePointer extends SingleChildLayout {
  readonly type = "IgnorePointer";
  private props: Omit<IgnorePointerProps, "child" | "actions">;

  private constructor(opts: IgnorePointerProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: IgnorePointerProps): IgnorePointer {
    return new IgnorePointer(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
