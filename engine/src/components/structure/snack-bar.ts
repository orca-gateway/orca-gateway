import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface SnackBarProps {
  content: Valueable<string>;
  duration?: Valueable<number>;
  actionLabel?: Valueable<string>;
  backgroundColor?: Valueable<string>;
  actions?: ActionMap;
}

export class SnackBar extends PrimitiveWidget {
  readonly type = "SnackBar";
  static readonly triggers = ["onAction"] as const;
  private props: Omit<SnackBarProps, "actions">;

  private constructor(opts: SnackBarProps) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SnackBarProps): SnackBar {
    return new SnackBar(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
