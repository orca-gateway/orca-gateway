import { InputWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface SwitchProps {
  value?: Valueable<boolean>;
  activeColor?: Valueable<string>;
  inactiveColor?: Valueable<string>;
  focusColor?: Valueable<string>;
  hoverColor?: Valueable<string>;
  enabled?: Valueable<boolean>;
  actions?: ActionMap;
}

export class Switch extends InputWidget {
  readonly type = "Switch";
  static readonly triggers = ["onChange"] as const;
  private props: Omit<SwitchProps, "actions">;

  private constructor(opts: SwitchProps = {}) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SwitchProps = {}): Switch {
    return new Switch(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
