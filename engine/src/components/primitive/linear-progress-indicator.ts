import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface LinearProgressIndicatorProps {
  value?: Valueable<number>;
  color?: Valueable<string>;
  backgroundColor?: Valueable<string>;
  minHeight?: Valueable<number>;
  actions?: ActionMap;
}

export class LinearProgressIndicator extends PrimitiveWidget {
  readonly type = "LinearProgressIndicator";
  private props: Omit<LinearProgressIndicatorProps, "actions">;

  private constructor(opts: LinearProgressIndicatorProps = {}) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: LinearProgressIndicatorProps = {}): LinearProgressIndicator {
    return new LinearProgressIndicator(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
