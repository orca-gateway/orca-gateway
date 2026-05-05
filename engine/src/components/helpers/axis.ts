export type Axis = "horizontal" | "vertical";

export type MainAxisAlignment = "start" | "end" | "center" | "spaceBetween" | "spaceAround" | "spaceEvenly";
export type CrossAxisAlignment = "start" | "end" | "center" | "stretch" | "baseline";
export type MainAxisSize = "min" | "max";

// Text direction affects how horizontal layouts order children and how text
// lays out inside them. Flutter also uses it to resolve `start`/`end` main-
// and cross-axis alignments on Row/Column.
export type TextDirection = "ltr" | "rtl";

// Vertical direction affects how vertical layouts order children when
// mainAxisAlignment is `start` or `end`. Rare in practice but required for
// parity with Flutter's Column/Row API.
export type VerticalDirection = "up" | "down";

// Text baseline used when CrossAxisAlignment is "baseline" in Column/Row.
export type TextBaseline = "alphabetic" | "ideographic";
