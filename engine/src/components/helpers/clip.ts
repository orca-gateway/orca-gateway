// Mirrors Flutter's Clip enum — controls how a widget clips its children:
// - "none": no clipping
// - "hardEdge": aliased clip (fastest, jagged edges)
// - "antiAlias": anti-aliased clip (smooth but slower)
// - "antiAliasWithSaveLayer": highest quality, offscreen save layer
export type Clip = "none" | "hardEdge" | "antiAlias" | "antiAliasWithSaveLayer";
