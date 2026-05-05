import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { EdgeInsetsData, BoxDecorationData, AlignmentValue } from "../helpers";
import { Curve } from "../helpers/curves";

export interface AnimatedContainerProps {
  child?: Widget;
  duration: Valueable<number>;
  curve?: Valueable<Curve>;
  padding?: Valueable<EdgeInsetsData>;
  margin?: Valueable<EdgeInsetsData>;
  decoration?: Valueable<BoxDecorationData>;
  width?: Valueable<number>;
  height?: Valueable<number>;
  alignment?: Valueable<AlignmentValue>;
  color?: Valueable<string>;
  actions?: ActionMap;
}

export class AnimatedContainer extends SingleChildLayout {
  readonly type = "AnimatedContainer";
  private props: Omit<AnimatedContainerProps, "child" | "actions">;

  private constructor(opts: AnimatedContainerProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: AnimatedContainerProps): AnimatedContainer {
    return new AnimatedContainer(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
