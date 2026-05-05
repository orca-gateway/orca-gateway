import { StructureWidget, Widget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";

export interface ScaffoldProps {
  body?: Widget;
  appBar?: Widget;
  floatingActionButton?: Widget;
  bottomNavigationBar?: Widget;
  drawer?: Widget;
  endDrawer?: Widget;
  bottomSheet?: Widget;
  persistentFooterButtons?: Widget[];
  backgroundColor?: Valueable<string>;
  resizeToAvoidBottomInset?: Valueable<boolean>;
  actions?: ActionMap;
}

export class Scaffold extends StructureWidget {
  readonly childMode = "none" as const;
  readonly type = "Scaffold";
  private _body?: Widget;
  private _appBar?: Widget;
  private _fab?: Widget;
  private _bottomNav?: Widget;
  private _drawer?: Widget;
  private _endDrawer?: Widget;
  private _bottomSheet?: Widget;
  private _persistentFooterButtons: Widget[];
  private _backgroundColor?: Valueable<string>;
  private _resizeToAvoidBottomInset?: Valueable<boolean>;

  private constructor(opts: ScaffoldProps) {
    super();
    this._body = opts.body;
    this._appBar = opts.appBar;
    this._fab = opts.floatingActionButton;
    this._bottomNav = opts.bottomNavigationBar;
    this._drawer = opts.drawer;
    this._endDrawer = opts.endDrawer;
    this._bottomSheet = opts.bottomSheet;
    this._persistentFooterButtons = opts.persistentFooterButtons ?? [];
    this._backgroundColor = opts.backgroundColor;
    this._resizeToAvoidBottomInset = opts.resizeToAvoidBottomInset;
    this.actions = opts.actions;
  }

  static new(opts: ScaffoldProps): Scaffold {
    return new Scaffold(opts);
  }

  getSlotWidgets(): { name: string; widget: Widget }[] {
    const slots: { name: string; widget: Widget }[] = [];
    if (this._appBar) slots.push({ name: "appBar", widget: this._appBar });
    if (this._body) slots.push({ name: "body", widget: this._body });
    if (this._fab) slots.push({ name: "floatingActionButton", widget: this._fab });
    if (this._bottomNav) slots.push({ name: "bottomNavigationBar", widget: this._bottomNav });
    if (this._drawer) slots.push({ name: "drawer", widget: this._drawer });
    if (this._endDrawer) slots.push({ name: "endDrawer", widget: this._endDrawer });
    if (this._bottomSheet) slots.push({ name: "bottomSheet", widget: this._bottomSheet });
    for (let i = 0; i < this._persistentFooterButtons.length; i++) {
      slots.push({ name: `persistentFooterButton_${i}`, widget: this._persistentFooterButtons[i] });
    }
    return slots;
  }

  getProps(): Record<string, unknown> {
    const p: Record<string, unknown> = {};
    if (this._backgroundColor) p.backgroundColor = this._backgroundColor;
    if (this._resizeToAvoidBottomInset !== undefined) {
      p.resizeToAvoidBottomInset = this._resizeToAvoidBottomInset;
    }
    return p;
  }
}
