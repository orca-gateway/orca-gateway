import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import { Curve } from "../helpers/curves";

export interface AnimatedBuilderProps {
  children: Widget[];
  animationId?: string;
  duration: Valueable<number>;
  curve?: Valueable<Curve>;
  repeat?: Valueable<boolean>;
  reverse?: Valueable<boolean>;
  autoStart?: Valueable<boolean>;
  actions?: ActionMap;
}

export class AnimatedBuilder extends MultiChildLayout {
  readonly type = "AnimatedBuilder";
  static readonly triggers = ["onComplete"] as const;
  private props: Omit<AnimatedBuilderProps, "children" | "actions">;

  private constructor(opts: AnimatedBuilderProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: AnimatedBuilderProps): AnimatedBuilder {
    return new AnimatedBuilder(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
