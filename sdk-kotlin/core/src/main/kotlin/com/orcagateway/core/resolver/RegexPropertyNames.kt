package com.orcagateway.core.resolver

/**
 * The names Dart 3.12.2's `RegExp` accepts in `\p{…}` and `\P{…}` with
 * `unicode`, exactly those of ECMA-262's tables: a General_Category value by
 * short name, long name or alias, bare or after `General_Category=` or `gc=`;
 * a binary property, bare; `Script=`, `sc=`, `Script_Extensions=` or `scx=`
 * with a script's four-letter code or long name, or Qaai or Qaac. Names, keys
 * and values are case-sensitive. Dart refuses every other name (`IsLatin`,
 * `InGreek`, `Latin`, `L&`, `javaLowerCase`, `script=Latin`, `Gc=Ll`, `ll`,
 * `Script=latin`, `Script=OldItalic`, `Script=Hrkt`), the binary properties
 * ECMA-262 leaves out among them (`Basic_Emoji`, `Changes_When_NFKC_Casefolded`).
 *
 * With each name, the spelling java.util.regex reads as Dart's set, checked
 * against Dart on every code point (JDK 17, 21, 25; the sets differ only
 * where their Unicode versions do): a General_Category value by its short
 * name, a binary property the JVM has by its own name, or a class. A script
 * is Dart's value, but for the two codes the JVM lacks, Qaai and Qaac, which
 * it reads as Inherited and Coptic; one newer than the JVM's Unicode fails to
 * compile. A name without one (Script_Extensions, Cased, Dash, Math,
 * ID_Start …) has none.
 */
internal object RegexPropertyNames {
    /** Whether Dart accepts `\p{name}`. */
    fun accepts(name: String): Boolean {
        val eq = name.indexOf('=')
        if (eq < 0) return name in generalCategory || name in binary
        val value = name.substring(eq + 1)
        return when (name.substring(0, eq)) {
            "General_Category", "gc" -> value in generalCategory
            "Script", "sc", "Script_Extensions", "scx" -> value in scripts
            else -> false
        }
    }

    /**
     * The JVM's spelling of `\p{name}`, or with [negated] of `\P{name}`, for a
     * name Dart [accepts]; null where java.util.regex has none. `Script=` and
     * `sc=` stay as written, the JVM reading the key in any case, but for the
     * values Qaai and Qaac, which it has as Inherited and Coptic.
     */
    fun jvm(name: String, negated: Boolean): String? {
        val eq = name.indexOf('=')
        val value = name.substring(eq + 1)
        val spelling = when (if (eq < 0) null else name.substring(0, eq)) {
            null -> generalCategory[name] ?: binary[name]
            "General_Category", "gc" -> generalCategory[value]
            "Script", "sc" -> name.substring(0, eq + 1) + when (value) {
                "Qaai" -> "Inherited"
                "Qaac" -> "Coptic"
                else -> value
            }
            else -> null
        } ?: return null
        return when {
            spelling.startsWith('[') -> if (negated) "[^" + spelling.substring(1) else spelling
            negated -> "\\P{$spelling}"
            else -> "\\p{$spelling}"
        }
    }

    // Each script's four-letter code and long name (one where they are the same)
    // in ECMA-262's table, of Unicode 16, and the codes it keeps for Inherited
    // and Coptic, Qaai and Qaac: the 336 values Dart takes.
    private val scripts: Set<String> = listOf(
        "Adlm Adlam", "Aghb Caucasian_Albanian", "Ahom", "Arab Arabic", "Armi Imperial_Aramaic", "Armn Armenian",
        "Avst Avestan", "Bali Balinese", "Bamu Bamum", "Bass Bassa_Vah", "Batk Batak", "Beng Bengali",
        "Bhks Bhaiksuki", "Bopo Bopomofo", "Brah Brahmi", "Brai Braille", "Bugi Buginese", "Buhd Buhid",
        "Cakm Chakma", "Cans Canadian_Aboriginal", "Cari Carian", "Cham", "Cher Cherokee", "Chrs Chorasmian",
        "Copt Coptic Qaac", "Cpmn Cypro_Minoan", "Cprt Cypriot", "Cyrl Cyrillic", "Deva Devanagari",
        "Diak Dives_Akuru", "Dogr Dogra", "Dsrt Deseret", "Dupl Duployan", "Egyp Egyptian_Hieroglyphs",
        "Elba Elbasan", "Elym Elymaic", "Ethi Ethiopic", "Gara Garay", "Geor Georgian", "Glag Glagolitic",
        "Gong Gunjala_Gondi", "Gonm Masaram_Gondi", "Goth Gothic", "Gran Grantha", "Grek Greek", "Gujr Gujarati",
        "Gukh Gurung_Khema", "Guru Gurmukhi", "Hang Hangul", "Hani Han", "Hano Hanunoo", "Hatr Hatran",
        "Hebr Hebrew", "Hira Hiragana", "Hluw Anatolian_Hieroglyphs", "Hmng Pahawh_Hmong",
        "Hmnp Nyiakeng_Puachue_Hmong", "Hung Old_Hungarian", "Ital Old_Italic", "Java Javanese", "Kali Kayah_Li",
        "Kana Katakana", "Kawi", "Khar Kharoshthi", "Khmr Khmer", "Khoj Khojki", "Kits Khitan_Small_Script",
        "Knda Kannada", "Krai Kirat_Rai", "Kthi Kaithi", "Lana Tai_Tham", "Laoo Lao", "Latn Latin", "Lepc Lepcha",
        "Limb Limbu", "Lina Linear_A", "Linb Linear_B", "Lisu", "Lyci Lycian", "Lydi Lydian", "Mahj Mahajani",
        "Maka Makasar", "Mand Mandaic", "Mani Manichaean", "Marc Marchen", "Medf Medefaidrin", "Mend Mende_Kikakui",
        "Merc Meroitic_Cursive", "Mero Meroitic_Hieroglyphs", "Mlym Malayalam", "Modi", "Mong Mongolian",
        "Mroo Mro", "Mtei Meetei_Mayek", "Mult Multani", "Mymr Myanmar", "Nagm Nag_Mundari", "Nand Nandinagari",
        "Narb Old_North_Arabian", "Nbat Nabataean", "Newa", "Nkoo Nko", "Nshu Nushu", "Ogam Ogham", "Olck Ol_Chiki",
        "Onao Ol_Onal", "Orkh Old_Turkic", "Orya Oriya", "Osge Osage", "Osma Osmanya", "Ougr Old_Uyghur",
        "Palm Palmyrene", "Pauc Pau_Cin_Hau", "Perm Old_Permic", "Phag Phags_Pa", "Phli Inscriptional_Pahlavi",
        "Phlp Psalter_Pahlavi", "Phnx Phoenician", "Plrd Miao", "Prti Inscriptional_Parthian", "Rjng Rejang",
        "Rohg Hanifi_Rohingya", "Runr Runic", "Samr Samaritan", "Sarb Old_South_Arabian", "Saur Saurashtra",
        "Sgnw SignWriting", "Shaw Shavian", "Shrd Sharada", "Sidd Siddham", "Sind Khudawadi", "Sinh Sinhala",
        "Sogd Sogdian", "Sogo Old_Sogdian", "Sora Sora_Sompeng", "Soyo Soyombo", "Sund Sundanese", "Sunu Sunuwar",
        "Sylo Syloti_Nagri", "Syrc Syriac", "Tagb Tagbanwa", "Takr Takri", "Tale Tai_Le", "Talu New_Tai_Lue",
        "Taml Tamil", "Tang Tangut", "Tavt Tai_Viet", "Telu Telugu", "Tfng Tifinagh", "Tglg Tagalog", "Thaa Thaana",
        "Thai", "Tibt Tibetan", "Tirh Tirhuta", "Tnsa Tangsa", "Todr Todhri", "Toto", "Tutg Tulu_Tigalari",
        "Ugar Ugaritic", "Vaii Vai", "Vith Vithkuqi", "Wara Warang_Citi", "Wcho Wancho", "Xpeo Old_Persian",
        "Xsux Cuneiform", "Yezi Yezidi", "Yiii Yi", "Zanb Zanabazar_Square", "Zinh Inherited Qaai", "Zyyy Common",
        "Zzzz Unknown",
    ).flatMap { it.split(' ') }.toSet()

    // Each value's names, its short name first: all 80 to the short name.
    private val generalCategory: Map<String, String> = listOf(
        "C Other", "Cc Control cntrl", "Cf Format", "Cn Unassigned", "Co Private_Use", "Cs Surrogate",
        "L Letter", "LC Cased_Letter", "Ll Lowercase_Letter", "Lm Modifier_Letter", "Lo Other_Letter",
        "Lt Titlecase_Letter", "Lu Uppercase_Letter",
        "M Mark Combining_Mark", "Mc Spacing_Mark", "Me Enclosing_Mark", "Mn Nonspacing_Mark",
        "N Number", "Nd Decimal_Number digit", "Nl Letter_Number", "No Other_Number",
        "P Punctuation punct", "Pc Connector_Punctuation", "Pd Dash_Punctuation", "Pe Close_Punctuation",
        "Pf Final_Punctuation", "Pi Initial_Punctuation", "Po Other_Punctuation", "Ps Open_Punctuation",
        "S Symbol", "Sc Currency_Symbol", "Sk Modifier_Symbol", "Sm Math_Symbol", "So Other_Symbol",
        "Z Separator", "Zl Line_Separator", "Zp Paragraph_Separator", "Zs Space_Separator",
    ).flatMap { row -> row.split(' ').let { names -> names.map { it to names[0] } } }.toMap()

    // Each property's names (96), then after "->" the JVM's spelling: a name
    // for `\p{…}`, or a class. The emoji names are the JVM's from JDK 21.
    private val binary: Map<String, String?> = listOf(
        "ASCII -> ASCII",
        "ASCII_Hex_Digit AHex -> [0-9A-Fa-f]",
        "Alphabetic Alpha -> IsAlphabetic",
        "Any -> [\\x{0}-\\x{10FFFF}]",
        "Assigned -> [\\P{Cn}]",
        "Bidi_Control Bidi_C",
        "Bidi_Mirrored Bidi_M -> javaMirrored",
        "Case_Ignorable CI",
        "Cased",
        "Changes_When_Casefolded CWCF",
        "Changes_When_Casemapped CWCM",
        "Changes_When_Lowercased CWL",
        "Changes_When_Titlecased CWT",
        "Changes_When_Uppercased CWU",
        "Dash",
        "Default_Ignorable_Code_Point DI",
        "Deprecated Dep",
        "Diacritic Dia",
        "Emoji -> IsEmoji",
        "Emoji_Component EComp -> IsEmoji_Component",
        "Emoji_Modifier EMod -> IsEmoji_Modifier",
        "Emoji_Modifier_Base EBase -> IsEmoji_Modifier_Base",
        "Emoji_Presentation EPres -> IsEmoji_Presentation",
        "Extended_Pictographic ExtPict -> IsExtended_Pictographic",
        "Extender Ext",
        "Grapheme_Base Gr_Base",
        "Grapheme_Extend Gr_Ext",
        // Not the JVM's IsHex_Digit, which holds every decimal digit.
        "Hex_Digit Hex -> [0-9A-Fa-f\\x{FF10}-\\x{FF19}\\x{FF21}-\\x{FF26}\\x{FF41}-\\x{FF46}]",
        "IDS_Binary_Operator IDSB",
        "IDS_Trinary_Operator IDST",
        "ID_Continue IDC",
        "ID_Start IDS",
        "Ideographic Ideo -> IsIdeographic",
        "Join_Control Join_C -> IsJoin_Control",
        "Logical_Order_Exception LOE",
        "Lowercase Lower -> IsLowercase",
        "Math",
        "Noncharacter_Code_Point NChar -> IsNoncharacter_Code_Point",
        "Pattern_Syntax Pat_Syn",
        "Pattern_White_Space Pat_WS",
        "Quotation_Mark QMark",
        "Radical",
        "Regional_Indicator RI",
        "Sentence_Terminal STerm",
        "Soft_Dotted SD",
        "Terminal_Punctuation Term",
        "Unified_Ideograph UIdeo",
        "Uppercase Upper -> IsUppercase",
        "Variation_Selector VS",
        "White_Space space -> IsWhite_Space",
        "XID_Continue XIDC",
        "XID_Start XIDS",
    ).flatMap { row ->
        val jvm = row.substringAfter(" -> ", "").ifEmpty { null }
        row.substringBefore(" -> ").split(' ').map { it to jvm }
    }.toMap()
}
