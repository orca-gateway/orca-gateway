import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface DividerProps {
  thickness?: Valueable<number>;
  color?: Valueable<string>;
  indent?: Valueable<number>;
  endIndent?: Valueable<number>;
  actions?: ActionMap;
}

export class Divider extends PrimitiveWidget {
  readonly type = "Divider";
  private props: Omit<DividerProps, "actions">;

  private constructor(opts: DividerProps = {}) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: DividerProps = {}): Divider {
    return new Divider(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
