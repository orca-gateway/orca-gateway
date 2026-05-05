import { MultiChildLayout, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface TableProps {
  children: Widget[];
  columnWidths?: Valueable<Record<number, number>>;
  defaultColumnWidth?: Valueable<number>;
  border?: Valueable<{ color?: string; width?: number }>;
  actions?: ActionMap;
}

export class Table extends MultiChildLayout {
  readonly type = "Table";
  private props: Omit<TableProps, "children" | "actions">;

  private constructor(opts: TableProps) {
    super();
    this.children = opts.children;
    this.actions = opts.actions;
    const { children: _, actions: _a, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: TableProps): Table {
    return new Table(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
