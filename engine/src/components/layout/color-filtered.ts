import { SingleChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface ColorFilteredProps {
  child?: Widget;
  color?: Valueable<string>;
  blendMode?: Valueable<string>;
  actions?: ActionMap;
}

export class ColorFiltered extends SingleChildLayout {
  readonly type = "ColorFiltered";
  private props: Omit<ColorFilteredProps, "child" | "actions">;

  private constructor(opts: ColorFilteredProps) {
    super();
    this.child = opts.child;
    this.actions = opts.actions;
    const { child: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ColorFilteredProps): ColorFiltered {
    return new ColorFiltered(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
