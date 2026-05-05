import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface AnimatedSwitcherProps {
  child?: Widget;
  duration: Valueable<number>;
  actions?: ActionMap;
}

export class AnimatedSwitcher extends SingleChildLayout {
  readonly type = "AnimatedSwitcher";
  private props: Omit<AnimatedSwitcherProps, "child" | "actions">;

  private constructor(opts: AnimatedSwitcherProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: AnimatedSwitcherProps): AnimatedSwitcher {
    return new AnimatedSwitcher(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
