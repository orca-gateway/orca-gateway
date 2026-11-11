package com.orcagateway.core.resolver

/**
 * The names Dart 3.12.2's `RegExp` accepts in `\p{…}` and `\P{…}` with
 * `unicode`, exactly those of ECMA-262's tables: a General_Category value by
 * short name, long name or alias, bare or after `General_Category=` or `gc=`;
 * a binary property, bare; `Script=`, `sc=`, `Script_Extensions=` or `scx=`
 * with a value, which the engine reads. Names and keys are case-sensitive.
 * Dart refuses every other name (`IsLatin`, `InGreek`, `Latin`, `L&`,
 * `javaLowerCase`, `script=Latin`, `Gc=Ll`, `ll`), the binary properties
 * ECMA-262 leaves out among them (`Basic_Emoji`, `Changes_When_NFKC_Casefolded`).
 *
 * With each name, the spelling java.util.regex reads as Dart's set, checked
 * against Dart on every code point (JDK 17, 21, 25; the sets differ only
 * where their Unicode versions do): a General_Category value by its short
 * name, a binary property the JVM has by its own name, or a class. A name
 * without one (Script_Extensions, Cased, Dash, Math, ID_Start …) has none.
 */
internal object RegexPropertyNames {
    /** Whether Dart accepts `\p{name}`. */
    fun accepts(name: String): Boolean {
        val eq = name.indexOf('=')
        if (eq < 0) return name in generalCategory || name in binary
        val value = name.substring(eq + 1)
        return when (name.substring(0, eq)) {
            "General_Category", "gc" -> value in generalCategory
            "Script", "sc", "Script_Extensions", "scx" -> value.isNotEmpty()
            else -> false
        }
    }

    /**
     * The JVM's spelling of `\p{name}`, or with [negated] of `\P{name}`, for a
     * name Dart [accepts]; null where java.util.regex has none. `Script=` and
     * `sc=` stay as written: the JVM reads the key in any case.
     */
    fun jvm(name: String, negated: Boolean): String? {
        val eq = name.indexOf('=')
        val value = name.substring(eq + 1)
        val spelling = when (if (eq < 0) null else name.substring(0, eq)) {
            null -> generalCategory[name] ?: binary[name]
            "General_Category", "gc" -> generalCategory[value]
            "Script", "sc" -> name
            else -> null
        } ?: return null
        return when {
            spelling.startsWith('[') -> if (negated) "[^" + spelling.substring(1) else spelling
            negated -> "\\P{$spelling}"
            else -> "\\p{$spelling}"
        }
    }

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
