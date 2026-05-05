import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type {
  MainAxisAlignment,
  CrossAxisAlignment,
  MainAxisSize,
  TextDirection,
  VerticalDirection,
  TextBaseline,
} from "../helpers";

export interface RowProps {
  children: Widget[];
  gap?: Valueable<number>;
  mainAxisAlignment?: Valueable<MainAxisAlignment>;
  crossAxisAlignment?: Valueable<CrossAxisAlignment>;
  mainAxisSize?: Valueable<MainAxisSize>;
  textDirection?: Valueable<TextDirection>;
  verticalDirection?: Valueable<VerticalDirection>;
  textBaseline?: Valueable<TextBaseline>;
  actions?: ActionMap;
}

export class Row extends MultiChildLayout {
  readonly type = "Row";
  private props: Omit<RowProps, "children" | "actions">;

  private constructor(opts: RowProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: RowProps): Row {
    return new Row(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
