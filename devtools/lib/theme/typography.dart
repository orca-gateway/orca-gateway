/// SF Pro Text + SF Mono stacks matching the design prototype.
/// macOS resolves `-apple-system` / "SF Pro Text" natively; no bundled font
/// required. `fs(pt, scale)` applies a global font-scale multiplier for the
/// "Data font size" setting.
library;

const String kSfPro =
    'SF Pro Text'; // macOS + iOS; non-Apple platforms fall back via fontFamilyFallback.
const String kSfMono = 'SF Mono';

const List<String> kSfProFallback = <String>[
  '-apple-system',
  'BlinkMacSystemFont',
  'Helvetica Neue',
  'Helvetica',
  'Arial',
  'sans-serif',
];

const List<String> kSfMonoFallback = <String>[
  'ui-monospace',
  'Menlo',
  'Monaco',
  'Consolas',
  'Liberation Mono',
  'monospace',
];

/// Scale a point size by the user's font-scale setting.
/// Matches `fs(pt, scale)` in the JSX prototype — rounded to 0.1pt.
double fs(double pt, double scale) => (pt * scale * 10).roundToDouble() / 10;
