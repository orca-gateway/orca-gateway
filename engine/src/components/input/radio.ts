import { InputWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface RadioProps {
  value?: Valueable<string>;
  groupValue?: Valueable<string>;
  activeColor?: Valueable<string>;
  inactiveColor?: Valueable<string>;
  focusColor?: Valueable<string>;
  hoverColor?: Valueable<string>;
  enabled?: Valueable<boolean>;
  actions?: ActionMap;
}

export class Radio extends InputWidget {
  readonly type = "Radio";
  static readonly triggers = ["onChange"] as const;
  private props: Omit<RadioProps, "actions">;

  private constructor(opts: RadioProps = {}) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: RadioProps = {}): Radio {
    return new Radio(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
