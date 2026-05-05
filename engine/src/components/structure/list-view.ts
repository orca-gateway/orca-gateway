import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { EdgeInsetsData } from "../helpers";

export interface ListViewProps {
  children: Widget[];
  scrollDirection?: Valueable<"horizontal" | "vertical">;
  padding?: Valueable<EdgeInsetsData>;
  shrinkWrap?: Valueable<boolean>;
  reverse?: Valueable<boolean>;
  primary?: Valueable<boolean>;
  itemExtent?: Valueable<number>;
  separator?: Widget;
  actions?: ActionMap;
}

export class ListView extends MultiChildLayout {
  readonly type = "ListView";
  static readonly triggers = ["onScrollBegin", "onScrolling", "onScrollEnd"] as const;
  private props: Omit<ListViewProps, "children" | "actions">;

  private constructor(opts: ListViewProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: ListViewProps): ListView {
    return new ListView(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
