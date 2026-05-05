import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface CircularProgressIndicatorProps {
  color?: Valueable<string>;
  strokeWidth?: Valueable<number>;
  value?: Valueable<number>;
  actions?: ActionMap;
}

export class CircularProgressIndicator extends PrimitiveWidget {
  readonly type = "CircularProgressIndicator";
  private props: Omit<CircularProgressIndicatorProps, "actions">;

  private constructor(opts: CircularProgressIndicatorProps = {}) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: CircularProgressIndicatorProps = {}): CircularProgressIndicator {
    return new CircularProgressIndicator(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
