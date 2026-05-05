import { InputWidget } from "../../types/widget";
import type { ActionMap } from "../../types/action";
import type { Valueable } from "../../types/value";
import type {
  InputType,
  TextStyleData,
  TextInputAction,
  TextInputDecorationData,
} from "../helpers";

export interface TextFieldProps {
  value?: Valueable<string>;
  placeholder?: Valueable<string>;
  inputType?: Valueable<InputType>;
  obscureText?: Valueable<boolean>;
  maxLines?: Valueable<number>;
  maxLength?: Valueable<number>;
  enabled?: Valueable<boolean>;
  style?: Valueable<TextStyleData>;
  autofocus?: Valueable<boolean>;
  readOnly?: Valueable<boolean>;
  textInputAction?: Valueable<TextInputAction>;
  autocorrect?: Valueable<boolean>;
  enableSuggestions?: Valueable<boolean>;
  decoration?: Valueable<TextInputDecorationData>;
  actions?: ActionMap;
}

export class TextField extends InputWidget {
  readonly type = "TextField";
  static readonly triggers = ["onChange"] as const;
  private props: Omit<TextFieldProps, "actions">;

  private constructor(opts: TextFieldProps = {}) {
    super();
    this.actions = opts.actions;
    const { actions: _, ...rest } = opts;
    this.props = rest;
  }

  static new(opts: TextFieldProps = {}): TextField {
    return new TextField(opts);
  }

  getProps(): Record<string, unknown> {
    return { ...this.props };
  }
}
