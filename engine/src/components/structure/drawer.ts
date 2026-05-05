import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface DrawerProps {
  child?: Widget;
  backgroundColor?: Valueable<string>;
  elevation?: Valueable<number>;
  width?: Valueable<number>;
  actions?: ActionMap;
}

export class Drawer extends SingleChildLayout {
  readonly type = "Drawer";
  private props: Omit<DrawerProps, "child" | "actions">;

  private constructor(opts: DrawerProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: DrawerProps): Drawer {
    return new Drawer(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
