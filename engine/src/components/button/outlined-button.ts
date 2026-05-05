import { ButtonWidget, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface OutlinedButtonProps {
  child?: Widget;
  enabled?: Valueable<boolean>;
  color?: Valueable<string>;
  borderColor?: Valueable<string>;
  splashColor?: Valueable<string>;
  highlightColor?: Valueable<string>;
  autofocus?: Valueable<boolean>;
  actions?: ActionMap;
}

export class OutlinedButton extends ButtonWidget {
  readonly type = "OutlinedButton";
  static readonly triggers = ["onTap", "onLongPress"] as const;
  private props: Omit<OutlinedButtonProps, "child" | "actions">;

  private constructor(opts: OutlinedButtonProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: OutlinedButtonProps): OutlinedButton {
    return new OutlinedButton(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
