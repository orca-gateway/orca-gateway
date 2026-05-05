import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import { Curve } from "../helpers/curves";

export interface AnimatedOpacityProps {
  child?: Widget;
  opacity: Valueable<number>;
  duration: Valueable<number>;
  curve?: Valueable<Curve>;
  actions?: ActionMap;
}

export class AnimatedOpacity extends SingleChildLayout {
  readonly type = "AnimatedOpacity";
  private props: Omit<AnimatedOpacityProps, "child" | "actions">;

  private constructor(opts: AnimatedOpacityProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: AnimatedOpacityProps): AnimatedOpacity {
    return new AnimatedOpacity(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
