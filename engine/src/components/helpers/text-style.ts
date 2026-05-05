import type { Valueable } from "../../types/value";

export type FontWeight = "w100" | "w200" | "w300" | "w400" | "w500" | "w600" | "w700" | "w800" | "w900" | "bold" | "normal";
export type TextDecoration = "none" | "underline" | "overline" | "lineThrough";

export interface TextStyleData {
  fontSize?: Valueable<number>;
  fontWeight?: Valueable<FontWeight>;
  fontFamily?: Valueable<string>;
  fontStyle?: Valueable<"normal" | "italic">;
  color?: Valueable<string>;
  backgroundColor?: Valueable<string>;
  letterSpacing?: Valueable<number>;
  wordSpacing?: Valueable<number>;
  height?: Valueable<number>;
  decoration?: Valueable<TextDecoration>;
  decorationColor?: Valueable<string>;
  decorationStyle?: Valueable<"solid" | "double" | "dotted" | "dashed" | "wavy">;
  overflow?: "clip" | "fade" | "ellipsis" | "visible";
}

export function TextStyle(opts: TextStyleData): TextStyleData {
  return opts;
}
