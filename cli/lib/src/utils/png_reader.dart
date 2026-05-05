import 'dart:io';
import 'dart:typed_data';

/// Pixel dimensions parsed from a PNG header.
class PngDimensions {
  final int width;
  final int height;

  const PngDimensions(this.width, this.height);
}

/// Reads the pixel dimensions of a PNG file by parsing only the IHDR chunk.
///
/// Returns `null` when the file does not exist, is not a valid PNG (bad
/// signature), or is truncated before IHDR. The caller distinguishes
/// "missing" from "invalid format" by checking [File.existsSync] first.
///
/// Why implement this inline instead of pulling the `image` package: PNG's
/// IHDR chunk is always at byte offsets 16–23 (width as big-endian uint32 at
/// 16–19, height at 20–23) right after the 8-byte signature and the 4-byte
/// length prefix + 4-byte "IHDR" tag. Parsing only the first 24 bytes of the
/// file is enough to answer "is this a PNG and what size is it", and it
/// keeps the CLI free of optional dependencies. See
/// https://www.w3.org/TR/png-3/#11IHDR.
PngDimensions? readPngDimensions(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;

  final RandomAccessFile raf;
  try {
    raf = file.openSync();
  } catch (_) {
    return null;
  }
  try {
    final bytes = raf.readSync(24);
    if (bytes.length < 24) return null;

    // PNG signature: 89 50 4E 47 0D 0A 1A 0A
    const signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return null;
    }

    // After the signature the first chunk is always IHDR (it is the only
    // mandatory first chunk per the PNG spec). Width and height are stored
    // as big-endian uint32 at offsets 16 and 20. Using ByteData with a
    // proper ByteBuffer view handles the endianness read explicitly.
    final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
    final width = byteData.getUint32(16);
    final height = byteData.getUint32(20);
    return PngDimensions(width, height);
  } catch (_) {
    return null;
  } finally {
    try {
      raf.closeSync();
    } catch (_) {
      // Best effort.
    }
  }
}
