import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface SafeAreaProps {
  child?: Widget;
  top?: Valueable<boolean>;
  bottom?: Valueable<boolean>;
  left?: Valueable<boolean>;
  right?: Valueable<boolean>;
  actions?: ActionMap;
}

export class SafeArea extends SingleChildLayout {
  readonly type = "SafeArea";
  private props: Omit<SafeAreaProps, "child" | "actions">;

  private constructor(opts: SafeAreaProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SafeAreaProps): SafeArea {
    return new SafeArea(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
