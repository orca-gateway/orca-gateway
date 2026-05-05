import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { AlignmentValue } from "../helpers";
import { Curve } from "../helpers/curves";

export interface AnimatedAlignProps {
  child?: Widget;
  alignment: Valueable<AlignmentValue>;
  duration: Valueable<number>;
  curve?: Valueable<Curve>;
  widthFactor?: Valueable<number>;
  heightFactor?: Valueable<number>;
  actions?: ActionMap;
}

export class AnimatedAlign extends SingleChildLayout {
  readonly type = "AnimatedAlign";
  private props: Omit<AnimatedAlignProps, "child" | "actions">;

  private constructor(opts: AnimatedAlignProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: AnimatedAlignProps): AnimatedAlign {
    return new AnimatedAlign(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
