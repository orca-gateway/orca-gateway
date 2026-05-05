import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface SpacerProps {
  flex?: Valueable<number>;
  actions?: ActionMap;
}

export class Spacer extends PrimitiveWidget {
  readonly type = "Spacer";
  private props: Omit<SpacerProps, "actions">;

  private constructor(opts: SpacerProps = {}) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SpacerProps = {}): Spacer {
    return new Spacer(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
