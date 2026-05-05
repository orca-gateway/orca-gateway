import { InputWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface SliderProps {
  value?: Valueable<number>;
  min?: Valueable<number>;
  max?: Valueable<number>;
  divisions?: Valueable<number>;
  activeColor?: Valueable<string>;
  inactiveColor?: Valueable<string>;
  thumbColor?: Valueable<string>;
  trackHeight?: Valueable<number>;
  label?: Valueable<string>;
  enabled?: Valueable<boolean>;
  actions?: ActionMap;
}

export class Slider extends InputWidget {
  readonly type = "Slider";
  static readonly triggers = ["onChange"] as const;
  private props: Omit<SliderProps, "actions">;

  private constructor(opts: SliderProps = {}) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: SliderProps = {}): Slider {
    return new Slider(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
