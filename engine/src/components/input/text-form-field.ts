import { InputWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type { InputType, TextStyleData } from "../helpers";

export interface TextFormFieldProps {
  value?: Valueable<string>;
  placeholder?: Valueable<string>;
  inputType?: Valueable<InputType>;
  obscureText?: Valueable<boolean>;
  maxLines?: Valueable<number>;
  maxLength?: Valueable<number>;
  enabled?: Valueable<boolean>;
  style?: Valueable<TextStyleData>;
  validator?: Valueable<string>;
  actions?: ActionMap;
}

export class TextFormField extends InputWidget {
  readonly type = "TextFormField";
  static readonly triggers = ["onChange"] as const;
  private props: Omit<TextFormFieldProps, "actions">;

  private constructor(opts: TextFormFieldProps = {}) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: TextFormFieldProps = {}): TextFormField {
    return new TextFormField(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
