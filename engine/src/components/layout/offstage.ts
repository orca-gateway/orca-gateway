import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface OffstageProps {
  child?: Widget;
  offstage?: Valueable<boolean>;
  actions?: ActionMap;
}

export class Offstage extends SingleChildLayout {
  readonly type = "Offstage";
  private props: Omit<OffstageProps, "child" | "actions">;

  private constructor(opts: OffstageProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: OffstageProps): Offstage {
    return new Offstage(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
