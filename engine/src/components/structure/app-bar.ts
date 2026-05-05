import { StructureWidget, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface AppBarProps {
  title?: Widget;
  leading?: Widget;
  actions?: Widget[];
  backgroundColor?: Valueable<string>;
  elevation?: Valueable<number>;
  centerTitle?: Valueable<boolean>;
  toolbarHeight?: Valueable<number>;
  leadingWidth?: Valueable<number>;
  automaticallyImplyLeading?: Valueable<boolean>;
  shadowColor?: Valueable<string>;
  actionTriggers?: ActionMap;
}

export class AppBar extends StructureWidget {
  readonly childMode = "none" as const;
  readonly type = "AppBar";
  private _title?: Widget;
  private _leading?: Widget;
  private _actions: Widget[];
  private _backgroundColor?: Valueable<string>;
  private _elevation?: Valueable<number>;
  private _centerTitle?: Valueable<boolean>;
  private _toolbarHeight?: Valueable<number>;
  private _leadingWidth?: Valueable<number>;
  private _automaticallyImplyLeading?: Valueable<boolean>;
  private _shadowColor?: Valueable<string>;

  private constructor(opts: AppBarProps) {
    super();
    this._title = opts.title;
    this._leading = opts.leading;
    this._actions = opts.actions ?? [];
    this._backgroundColor = opts.backgroundColor;
    this._elevation = opts.elevation;
    this._centerTitle = opts.centerTitle;
    this._toolbarHeight = opts.toolbarHeight;
    this._leadingWidth = opts.leadingWidth;
    this._automaticallyImplyLeading = opts.automaticallyImplyLeading;
    this._shadowColor = opts.shadowColor;
    this.actions = opts.actionTriggers;
  }

  static new(opts: AppBarProps): AppBar {
    return new AppBar(opts);
  }

  getSlotWidgets(): { name: string; widget: Widget }[] {
    const slots: { name: string; widget: Widget }[] = [];
    if (this._title) slots.push({ name: "title", widget: this._title });
    if (this._leading) slots.push({ name: "leading", widget: this._leading });
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
    if (this._toolbarHeight !== undefined) p.toolbarHeight = this._toolbarHeight;
    if (this._leadingWidth !== undefined) p.leadingWidth = this._leadingWidth;
    if (this._automaticallyImplyLeading !== undefined) {
      p.automaticallyImplyLeading = this._automaticallyImplyLeading;
    }
    if (this._shadowColor) p.shadowColor = this._shadowColor;
    return p;
  }
}
