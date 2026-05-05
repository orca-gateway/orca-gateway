import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface HeroProps {
  child?: Widget;
  tag: Valueable<string>;
  actions?: ActionMap;
}

export class Hero extends SingleChildLayout {
  readonly type = "Hero";
  private props: Omit<HeroProps, "child" | "actions">;

  private constructor(opts: HeroProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: HeroProps): Hero {
    return new Hero(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
