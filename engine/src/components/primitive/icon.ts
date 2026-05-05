import { PrimitiveWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import { MaterialIcons } from "../../types/icons";

export interface IconProps {
  /** Material icon name (e.g. "home", "search"). At least one of `name` or `src` is required. */
  name?: Valueable<MaterialIcons>;
  /** Network URL for a raster icon image (PNG/JPEG/WebP). Takes precedence over `name`. */
  src?: Valueable<string>;
  size?: Valueable<number>;
  color?: Valueable<string>;
  actions?: ActionMap;
}

export class Icon extends PrimitiveWidget {
  readonly type = "Icon";
  private props: Omit<IconProps, "actions">;

  private constructor(opts: IconProps) {
    if (!opts.name && !opts.src) {
      throw new Error("Icon requires at least one of `name` or `src`.");
    }
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: IconProps): Icon {
    return new Icon(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
