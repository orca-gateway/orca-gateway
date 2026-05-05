import { StructureWidget, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface BottomNavigationBarProps {
  items: Widget[];
  currentIndex?: Valueable<number>;
  backgroundColor?: Valueable<string>;
  selectedItemColor?: Valueable<string>;
  unselectedItemColor?: Valueable<string>;
  actionTriggers?: ActionMap;
}

export class BottomNavigationBar extends StructureWidget {
  readonly childMode = "none" as const;
  readonly type = "BottomNavigationBar";
  static readonly triggers = ["onChange"] as const;
  private _items: Widget[];
  private _currentIndex?: Valueable<number>;
  private _backgroundColor?: Valueable<string>;
  private _selectedItemColor?: Valueable<string>;
  private _unselectedItemColor?: Valueable<string>;

  private constructor(opts: BottomNavigationBarProps) {
    super();
    this._items = opts.items;
    this._currentIndex = opts.currentIndex;
    this._backgroundColor = opts.backgroundColor;
    this._selectedItemColor = opts.selectedItemColor;
    this._unselectedItemColor = opts.unselectedItemColor;
    this.actions = opts.actionTriggers;
  }

  static new(opts: BottomNavigationBarProps): BottomNavigationBar {
    return new BottomNavigationBar(opts);
  }

  getSlotWidgets(): { name: string; widget: Widget }[] {
    const slots: { name: string; widget: Widget }[] = [];
    for (let i = 0; i < this._items.length; i++) {
      slots.push({ name: `item_${i}`, widget: this._items[i] });
    }
    return slots;
  }

  getProps(): Record<string, unknown> {
    const p: Record<string, unknown> = {};
    if (this._backgroundColor !== undefined) p.backgroundColor = this._backgroundColor;
    if (this._selectedItemColor !== undefined) p.selectedItemColor = this._selectedItemColor;
    if (this._unselectedItemColor !== undefined) p.unselectedItemColor = this._unselectedItemColor;
    if (this._currentIndex !== undefined) p.currentIndex = this._currentIndex;
    return p;
  }
}
