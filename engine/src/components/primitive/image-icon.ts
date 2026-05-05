import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface ImageIconProps {
  src: Valueable<string>;
  size?: Valueable<number>;
  color?: Valueable<string>;
  actions?: ActionMap;
}

export class ImageIcon extends PrimitiveWidget {
  readonly type = "ImageIcon";
  private props: Omit<ImageIconProps, "actions">;

  private constructor(opts: ImageIconProps) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ImageIconProps): ImageIcon {
    return new ImageIcon(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
