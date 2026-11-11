package com.orcagateway.core.resolver

/**
 * The letters Dart's `i` folds otherwise than java.util.regex or Android's
 * ICU, each with the set of letters it matches, printed by Dart 3.12.2's
 * `RegExp` with `caseSensitive: false`, without and with `unicode` (each
 * letter's one-letter pattern tried on every BMP letter with a case mapping).
 * [RegexSupport.asciiClasses] spells these sets out so that neither engine
 * folds them:
 *
 * - The four letters Unicode folds into ASCII, ſ U+017F, K U+212A, ı U+0131
 *   and İ U+0130, which Dart folds into ASCII only with `u` (ſ and K).
 * - Those that match only themselves without `u` in Dart and fold in both
 *   engines: Å U+212B, Ω U+2126 and ϴ U+03F4, as K does, ẞ U+1E9E and the
 *   Greek letters with iota subscript (U+1F80-1FAF, ᾳ, ᾼ, ῃ, ῌ, ῳ, ῼ).
 * - The letters with a full case folding (ß, the ligatures ﬀ-ﬆ and ﬓ-ﬗ, ŉ,
 *   ǰ, ΐ, ΰ, և, ẖ-ẚ, ὐ, ᾶ, …), which ICU folds to strings ("ss", "ff") and
 *   the JVM one way only (ẞ to ß, not ß to ẞ).
 * - The letters a full folding starts with (a f h i j s t w y, ʼ U+02BC,
 *   Greek α η ι ρ υ ω and their accented forms, Armenian ե մ վ), so that on
 *   ICU no run of letters in a pattern folds into a ligature.
 *
 * With the partners of all these, it is closed: every letter of every set is
 * itself in the table. All are in the BMP.
 */
internal object DartFoldTable {
    /** The table's letters, in code point order. */
    val letters: String by lazy { sets.keys.joinToString("") }

    /** The letters Dart's `i` matches [c] to, [c] included, without or with `u`; null for a letter not in the table. */
    fun set(c: Char, unicode: Boolean): String? = sets[c]?.let { if (unicode) it.second else it.first }

    private val sets: Map<Char, Pair<String, String>> by lazy {
        fun letters(hex: String) = hex.split(' ').joinToString("") { it.toInt(16).toChar().toString() }
        DATA.lines().map(String::trim).filter(String::isNotEmpty).associate { row ->
            val (letter, plain, unicode) = row.split(" | ")
            letters(letter)[0] to (letters(plain) to letters(unicode))
        }
    }

    // The letter | Dart's set without `u` | Dart's set with `u`, in hex.
    private const val DATA = """
        0041 | 0041 0061 | 0041 0061
        0046 | 0046 0066 | 0046 0066
        0048 | 0048 0068 | 0048 0068
        0049 | 0049 0069 | 0049 0069
        004A | 004A 006A | 004A 006A
        004B | 004B 006B | 004B 006B 212A
        0053 | 0053 0073 | 0053 0073 017F
        0054 | 0054 0074 | 0054 0074
        0057 | 0057 0077 | 0057 0077
        0059 | 0059 0079 | 0059 0079
        0061 | 0041 0061 | 0041 0061
        0066 | 0046 0066 | 0046 0066
        0068 | 0048 0068 | 0048 0068
        0069 | 0049 0069 | 0049 0069
        006A | 004A 006A | 004A 006A
        006B | 004B 006B | 004B 006B 212A
        0073 | 0053 0073 | 0053 0073 017F
        0074 | 0054 0074 | 0054 0074
        0077 | 0057 0077 | 0057 0077
        0079 | 0059 0079 | 0059 0079
        00C5 | 00C5 00E5 | 00C5 00E5 212B
        00DF | 00DF | 00DF 1E9E
        00E5 | 00C5 00E5 | 00C5 00E5 212B
        0130 | 0130 | 0130
        0131 | 0131 | 0131
        0149 | 0149 | 0149
        017F | 017F | 0053 0073 017F
        01F0 | 01F0 | 01F0
        02BC | 02BC | 02BC
        0345 | 0345 0399 03B9 1FBE | 0345 0399 03B9 1FBE
        0386 | 0386 03AC | 0386 03AC
        0389 | 0389 03AE | 0389 03AE
        038F | 038F 03CE | 038F 03CE
        0390 | 0390 | 0390 1FD3
        0391 | 0391 03B1 | 0391 03B1
        0397 | 0397 03B7 | 0397 03B7
        0398 | 0398 03B8 03D1 | 0398 03B8 03D1 03F4
        0399 | 0345 0399 03B9 1FBE | 0345 0399 03B9 1FBE
        03A1 | 03A1 03C1 03F1 | 03A1 03C1 03F1
        03A5 | 03A5 03C5 | 03A5 03C5
        03A9 | 03A9 03C9 | 03A9 03C9 2126
        03AC | 0386 03AC | 0386 03AC
        03AE | 0389 03AE | 0389 03AE
        03B0 | 03B0 | 03B0 1FE3
        03B1 | 0391 03B1 | 0391 03B1
        03B7 | 0397 03B7 | 0397 03B7
        03B8 | 0398 03B8 03D1 | 0398 03B8 03D1 03F4
        03B9 | 0345 0399 03B9 1FBE | 0345 0399 03B9 1FBE
        03C1 | 03A1 03C1 03F1 | 03A1 03C1 03F1
        03C5 | 03A5 03C5 | 03A5 03C5
        03C9 | 03A9 03C9 | 03A9 03C9 2126
        03CE | 038F 03CE | 038F 03CE
        03D1 | 0398 03B8 03D1 | 0398 03B8 03D1 03F4
        03F1 | 03A1 03C1 03F1 | 03A1 03C1 03F1
        03F4 | 03F4 | 0398 03B8 03D1 03F4
        0535 | 0535 0565 | 0535 0565
        0544 | 0544 0574 | 0544 0574
        054E | 054E 057E | 054E 057E
        0565 | 0535 0565 | 0535 0565
        0574 | 0544 0574 | 0544 0574
        057E | 054E 057E | 054E 057E
        0587 | 0587 | 0587
        1E96 | 1E96 | 1E96
        1E97 | 1E97 | 1E97
        1E98 | 1E98 | 1E98
        1E99 | 1E99 | 1E99
        1E9A | 1E9A | 1E9A
        1E9E | 1E9E | 00DF 1E9E
        1F00 | 1F00 1F08 | 1F00 1F08
        1F01 | 1F01 1F09 | 1F01 1F09
        1F02 | 1F02 1F0A | 1F02 1F0A
        1F03 | 1F03 1F0B | 1F03 1F0B
        1F04 | 1F04 1F0C | 1F04 1F0C
        1F05 | 1F05 1F0D | 1F05 1F0D
        1F06 | 1F06 1F0E | 1F06 1F0E
        1F07 | 1F07 1F0F | 1F07 1F0F
        1F08 | 1F00 1F08 | 1F00 1F08
        1F09 | 1F01 1F09 | 1F01 1F09
        1F0A | 1F02 1F0A | 1F02 1F0A
        1F0B | 1F03 1F0B | 1F03 1F0B
        1F0C | 1F04 1F0C | 1F04 1F0C
        1F0D | 1F05 1F0D | 1F05 1F0D
        1F0E | 1F06 1F0E | 1F06 1F0E
        1F0F | 1F07 1F0F | 1F07 1F0F
        1F20 | 1F20 1F28 | 1F20 1F28
        1F21 | 1F21 1F29 | 1F21 1F29
        1F22 | 1F22 1F2A | 1F22 1F2A
        1F23 | 1F23 1F2B | 1F23 1F2B
        1F24 | 1F24 1F2C | 1F24 1F2C
        1F25 | 1F25 1F2D | 1F25 1F2D
        1F26 | 1F26 1F2E | 1F26 1F2E
        1F27 | 1F27 1F2F | 1F27 1F2F
        1F28 | 1F20 1F28 | 1F20 1F28
        1F29 | 1F21 1F29 | 1F21 1F29
        1F2A | 1F22 1F2A | 1F22 1F2A
        1F2B | 1F23 1F2B | 1F23 1F2B
        1F2C | 1F24 1F2C | 1F24 1F2C
        1F2D | 1F25 1F2D | 1F25 1F2D
        1F2E | 1F26 1F2E | 1F26 1F2E
        1F2F | 1F27 1F2F | 1F27 1F2F
        1F50 | 1F50 | 1F50
        1F52 | 1F52 | 1F52
        1F54 | 1F54 | 1F54
        1F56 | 1F56 | 1F56
        1F60 | 1F60 1F68 | 1F60 1F68
        1F61 | 1F61 1F69 | 1F61 1F69
        1F62 | 1F62 1F6A | 1F62 1F6A
        1F63 | 1F63 1F6B | 1F63 1F6B
        1F64 | 1F64 1F6C | 1F64 1F6C
        1F65 | 1F65 1F6D | 1F65 1F6D
        1F66 | 1F66 1F6E | 1F66 1F6E
        1F67 | 1F67 1F6F | 1F67 1F6F
        1F68 | 1F60 1F68 | 1F60 1F68
        1F69 | 1F61 1F69 | 1F61 1F69
        1F6A | 1F62 1F6A | 1F62 1F6A
        1F6B | 1F63 1F6B | 1F63 1F6B
        1F6C | 1F64 1F6C | 1F64 1F6C
        1F6D | 1F65 1F6D | 1F65 1F6D
        1F6E | 1F66 1F6E | 1F66 1F6E
        1F6F | 1F67 1F6F | 1F67 1F6F
        1F70 | 1F70 1FBA | 1F70 1FBA
        1F74 | 1F74 1FCA | 1F74 1FCA
        1F7C | 1F7C 1FFA | 1F7C 1FFA
        1F80 | 1F80 | 1F80 1F88
        1F81 | 1F81 | 1F81 1F89
        1F82 | 1F82 | 1F82 1F8A
        1F83 | 1F83 | 1F83 1F8B
        1F84 | 1F84 | 1F84 1F8C
        1F85 | 1F85 | 1F85 1F8D
        1F86 | 1F86 | 1F86 1F8E
        1F87 | 1F87 | 1F87 1F8F
        1F88 | 1F88 | 1F80 1F88
        1F89 | 1F89 | 1F81 1F89
        1F8A | 1F8A | 1F82 1F8A
        1F8B | 1F8B | 1F83 1F8B
        1F8C | 1F8C | 1F84 1F8C
        1F8D | 1F8D | 1F85 1F8D
        1F8E | 1F8E | 1F86 1F8E
        1F8F | 1F8F | 1F87 1F8F
        1F90 | 1F90 | 1F90 1F98
        1F91 | 1F91 | 1F91 1F99
        1F92 | 1F92 | 1F92 1F9A
        1F93 | 1F93 | 1F93 1F9B
        1F94 | 1F94 | 1F94 1F9C
        1F95 | 1F95 | 1F95 1F9D
        1F96 | 1F96 | 1F96 1F9E
        1F97 | 1F97 | 1F97 1F9F
        1F98 | 1F98 | 1F90 1F98
        1F99 | 1F99 | 1F91 1F99
        1F9A | 1F9A | 1F92 1F9A
        1F9B | 1F9B | 1F93 1F9B
        1F9C | 1F9C | 1F94 1F9C
        1F9D | 1F9D | 1F95 1F9D
        1F9E | 1F9E | 1F96 1F9E
        1F9F | 1F9F | 1F97 1F9F
        1FA0 | 1FA0 | 1FA0 1FA8
        1FA1 | 1FA1 | 1FA1 1FA9
        1FA2 | 1FA2 | 1FA2 1FAA
        1FA3 | 1FA3 | 1FA3 1FAB
        1FA4 | 1FA4 | 1FA4 1FAC
        1FA5 | 1FA5 | 1FA5 1FAD
        1FA6 | 1FA6 | 1FA6 1FAE
        1FA7 | 1FA7 | 1FA7 1FAF
        1FA8 | 1FA8 | 1FA0 1FA8
        1FA9 | 1FA9 | 1FA1 1FA9
        1FAA | 1FAA | 1FA2 1FAA
        1FAB | 1FAB | 1FA3 1FAB
        1FAC | 1FAC | 1FA4 1FAC
        1FAD | 1FAD | 1FA5 1FAD
        1FAE | 1FAE | 1FA6 1FAE
        1FAF | 1FAF | 1FA7 1FAF
        1FB2 | 1FB2 | 1FB2
        1FB3 | 1FB3 | 1FB3 1FBC
        1FB4 | 1FB4 | 1FB4
        1FB6 | 1FB6 | 1FB6
        1FB7 | 1FB7 | 1FB7
        1FBA | 1F70 1FBA | 1F70 1FBA
        1FBC | 1FBC | 1FB3 1FBC
        1FBE | 0345 0399 03B9 1FBE | 0345 0399 03B9 1FBE
        1FC2 | 1FC2 | 1FC2
        1FC3 | 1FC3 | 1FC3 1FCC
        1FC4 | 1FC4 | 1FC4
        1FC6 | 1FC6 | 1FC6
        1FC7 | 1FC7 | 1FC7
        1FCA | 1F74 1FCA | 1F74 1FCA
        1FCC | 1FCC | 1FC3 1FCC
        1FD2 | 1FD2 | 1FD2
        1FD3 | 1FD3 | 0390 1FD3
        1FD6 | 1FD6 | 1FD6
        1FD7 | 1FD7 | 1FD7
        1FE2 | 1FE2 | 1FE2
        1FE3 | 1FE3 | 03B0 1FE3
        1FE4 | 1FE4 | 1FE4
        1FE6 | 1FE6 | 1FE6
        1FE7 | 1FE7 | 1FE7
        1FF2 | 1FF2 | 1FF2
        1FF3 | 1FF3 | 1FF3 1FFC
        1FF4 | 1FF4 | 1FF4
        1FF6 | 1FF6 | 1FF6
        1FF7 | 1FF7 | 1FF7
        1FFA | 1F7C 1FFA | 1F7C 1FFA
        1FFC | 1FFC | 1FF3 1FFC
        2126 | 2126 | 03A9 03C9 2126
        212A | 212A | 004B 006B 212A
        212B | 212B | 00C5 00E5 212B
        FB00 | FB00 | FB00
        FB01 | FB01 | FB01
        FB02 | FB02 | FB02
        FB03 | FB03 | FB03
        FB04 | FB04 | FB04
        FB05 | FB05 | FB05 FB06
        FB06 | FB06 | FB05 FB06
        FB13 | FB13 | FB13
        FB14 | FB14 | FB14
        FB15 | FB15 | FB15
        FB16 | FB16 | FB16
        FB17 | FB17 | FB17
    """
}
