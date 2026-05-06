import { StructureWidget, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface SliverAppBarProps {
  title?: Widget;
  leading?: Widget;
  actions?: Widget[];
  flexibleSpace?: Widget;
  backgroundColor?: Valueable<string>;
  elevation?: Valueable<number>;
  centerTitle?: Valueable<boolean>;
  floating?: Valueable<boolean>;
  pinned?: Valueable<boolean>;
  snap?: Valueable<boolean>;
  expandedHeight?: Valueable<number>;
  collapsedHeight?: Valueable<number>;
  actionTriggers?: ActionMap;
}

export class SliverAppBar extends StructureWidget {
  readonly childMode = "none" as const;
  readonly type = "SliverAppBar";
  private _title?: Widget;
  private _leading?: Widget;
  private _actions: Widget[];
  private _flexibleSpace?: Widget;
  private _backgroundColor?: Valueable<string>;
  private _elevation?: Valueable<number>;
  private _centerTitle?: Valueable<boolean>;
  private _floating?: Valueable<boolean>;
  private _pinned?: Valueable<boolean>;
  private _snap?: Valueable<boolean>;
  private _expandedHeight?: Valueable<number>;
  private _collapsedHeight?: Valueable<number>;

  private constructor(opts: SliverAppBarProps) {
    super();
    this._title = opts.title;
    this._leading = opts.leading;
    this._actions = opts.actions ?? [];
    this._flexibleSpace = opts.flexibleSpace;
    this._backgroundColor = opts.backgroundColor;
    this._elevation = opts.elevation;
    this._centerTitle = opts.centerTitle;
    this._floating = opts.floating;
    this._pinned = opts.pinned;
    this._snap = opts.snap;
    this._expandedHeight = opts.expandedHeight;
    this._collapsedHeight = opts.collapsedHeight;
    this.actions = opts.actionTriggers;
  }

  static new(opts: SliverAppBarProps): SliverAppBar {
    return new SliverAppBar(opts);
  }

  getSlotWidgets(): { name: string; widget: Widget }[] {
    const slots: { name: string; widget: Widget }[] = [];
    if (this._title) slots.push({ name: "title", widget: this._title });
    if (this._leading) slots.push({ name: "leading", widget: this._leading });
    if (this._flexibleSpace) slots.push({ name: "flexibleSpace", widget: this._flexibleSpace });
    for (let i = 0; i < this._actions.length; i++) {
      slots.push({ name: `action_${i}`, widget: this._actions[i] });
    }
    return slots;
  }

  getProps(): Record<string, unknown> {
    const p: Record<string, unknown> = {};
    if (this._backgroundColor) p.backgroundColor = this._backgroundColor;
    if (this._elevation !== undefined) p.elevation = this._elevation;
    if (this._centerTitle !== undefined) p.centerTitle = this._centerTitle;
    if (this._floating !== undefined) p.floating = this._floating;
    if (this._pinned !== undefined) p.pinned = this._pinned;
    if (this._snap !== undefined) p.snap = this._snap;
    if (this._expandedHeight !== undefined) p.expandedHeight = this._expandedHeight;
    if (this._collapsedHeight !== undefined) p.collapsedHeight = this._collapsedHeight;
    return p;
  }
}
