import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { ImageFit, ImageRepeat, AlignmentValue } from "../helpers";

export interface ImageProps {
  src: Valueable<string>;
  fit?: Valueable<ImageFit>;
  width?: Valueable<number>;
  height?: Valueable<number>;
  alt?: Valueable<string>;
  alignment?: Valueable<AlignmentValue>;
  repeat?: Valueable<ImageRepeat>;
  color?: Valueable<string>;
  actions?: ActionMap;
}

export class Image extends PrimitiveWidget {
  readonly type = "Image";
  private props: Omit<ImageProps, "actions">;

  private constructor(opts: ImageProps) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ImageProps): Image {
    return new Image(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
