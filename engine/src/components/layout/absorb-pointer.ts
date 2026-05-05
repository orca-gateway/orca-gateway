import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface AbsorbPointerProps {
  child?: Widget;
  absorbing?: Valueable<boolean>;
  actions?: ActionMap;
}

export class AbsorbPointer extends SingleChildLayout {
  readonly type = "AbsorbPointer";
  private props: Omit<AbsorbPointerProps, "child" | "actions">;

  private constructor(opts: AbsorbPointerProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: AbsorbPointerProps): AbsorbPointer {
    return new AbsorbPointer(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
