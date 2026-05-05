/**
 * Converts a hex color string (RGB, RGBA, RRGGBB, RRGGBBAA, or with #)
 * to Flutter's ARGB format: "0xAARRGGBB".
 *
 * Accepted inputs:
 *   "#RGB"        → "0xFFRRGGBB"
 *   "#RGBA"       → "0xAARRGGBB"
 *   "#RRGGBB"     → "0xFFRRGGBB"
 *   "#RRGGBBAA"   → "0xAARRGGBB"
 *   "0xAARRGGBB"  → "0xAARRGGBB" (passthrough)
 */
export function Color(hex: string): string {
  // Already in Flutter format
  if (hex.startsWith("0x") || hex.startsWith("0X")) {
    return hex;
  }

  let raw = hex.startsWith("#") ? hex.slice(1) : hex;
  raw = raw.toUpperCase();

  switch (raw.length) {
    case 3: {
      // RGB → FFRRGGBB
      const [r, g, b] = raw;
      return `0xFF${r}${r}${g}${g}${b}${b}`;
    }
    case 4: {
      // RGBA → AARRGGBB
      const [r, g, b, a] = raw;
      return `0x${a}${a}${r}${r}${g}${g}${b}${b}`;
    }
    case 6: {
      // RRGGBB → FFRRGGBB
      return `0xFF${raw}`;
    }
    case 8: {
      // RRGGBBAA → AARRGGBB
      const rr = raw.slice(0, 2);
      const gg = raw.slice(2, 4);
      const bb = raw.slice(4, 6);
      const aa = raw.slice(6, 8);
      return `0x${aa}${rr}${gg}${bb}`;
    }
    default:
      return hex;
  }
}

export const Colors = {
  black: Color("#000000"),
  white: Color("#FFFFFF"),
  red: Color("#F44336"),
  pink: Color("#E91E63"),
  purple: Color("#9C27B0"),
  deepPurple: Color("#673AB7"),
  indigo: Color("#3F51B5"),
  blue: Color("#2196F3"),
  lightBlue: Color("#03A9F4"),
  cyan: Color("#00BCD4"),
  teal: Color("#009688"),
  green: Color("#4CAF50"),
  lightGreen: Color("#8BC34A"),
  lime: Color("#CDDC39"),
  yellow: Color("#FFEB3B"),
  amber: Color("#FFC107"),
  orange: Color("#FF9800"),
  deepOrange: Color("#FF5722"),
  brown: Color("#795548"),
  grey: Color("#9E9E9E"),
  blueGrey: Color("#607D8B"),
  transparent: Color("#00000000"),
} as const;
