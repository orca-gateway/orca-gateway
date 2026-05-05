import { InputWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface CheckboxProps {
  value?: Valueable<boolean>;
  label?: Valueable<string>;
  activeColor?: Valueable<string>;
  inactiveColor?: Valueable<string>;
  focusColor?: Valueable<string>;
  hoverColor?: Valueable<string>;
  tristate?: Valueable<boolean>;
  enabled?: Valueable<boolean>;
  actions?: ActionMap;
}

export class Checkbox extends InputWidget {
  readonly type = "Checkbox";
  static readonly triggers = ["onChange"] as const;
  private props: Omit<CheckboxProps, "actions">;

  private constructor(opts: CheckboxProps = {}) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: CheckboxProps = {}): Checkbox {
    return new Checkbox(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
