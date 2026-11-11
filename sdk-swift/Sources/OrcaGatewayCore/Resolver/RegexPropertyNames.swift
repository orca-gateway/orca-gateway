extension Regex {
    /// Whether Dart's RegExp, with `unicode`, accepts `name` in `\p{name}` and
    /// `\P{name}`: a General_Category value, bare or after `General_Category=`
    /// or `gc=`; a binary property, bare; or a script value after `Script=`,
    /// `sc=`, `Script_Extensions=` or `scx=`. Keys and names are
    /// case-sensitive, without spaces; Dart refuses every other name
    /// (`IsLatin`, `Latin`, `L&`, `script=Latin`, `ll`, `gc=Lowercase`,
    /// `Script=latin`, `Script=Hrkt`), which ICU may read.
    static func dartAcceptsProperty(_ name: String) -> Bool {
        let scalars = name.unicodeScalars
        guard let equals = scalars.firstIndex(of: "=") else {
            return generalCategories.contains(name) || binaryProperties.contains(name)
        }
        let value = String(scalars[scalars.index(after: equals)...])
        switch String(scalars[..<equals]) {
        case "General_Category", "gc": return generalCategories.contains(value)
        case "Script", "sc", "Script_Extensions", "scx": return scriptValues.contains(value)
        default: return false
        }
    }

    /// The General_Category values Dart 3.12.2 accepts, exactly these
    /// (ECMA-262's table): long and short names and aliases.
    static let generalCategories: Set<String> = [
        "C", "Other", "Cc", "Control", "cntrl", "Cf", "Format", "Cn", "Unassigned", "Co", "Private_Use", "Cs",
        "Surrogate", "L", "Letter", "LC", "Cased_Letter", "Ll", "Lowercase_Letter", "Lm", "Modifier_Letter",
        "Lo", "Other_Letter", "Lt", "Titlecase_Letter", "Lu", "Uppercase_Letter", "M", "Mark",
        "Combining_Mark", "Mc", "Spacing_Mark", "Me", "Enclosing_Mark", "Mn", "Nonspacing_Mark", "N", "Number",
        "Nd", "Decimal_Number", "digit", "Nl", "Letter_Number", "No", "Other_Number", "P", "Punctuation",
        "punct", "Pc", "Connector_Punctuation", "Pd", "Dash_Punctuation", "Pe", "Close_Punctuation", "Pf",
        "Final_Punctuation", "Pi", "Initial_Punctuation", "Po", "Other_Punctuation", "Ps", "Open_Punctuation",
        "S", "Symbol", "Sc", "Currency_Symbol", "Sk", "Modifier_Symbol", "Sm", "Math_Symbol", "So",
        "Other_Symbol", "Z", "Separator", "Zl", "Line_Separator", "Zp", "Paragraph_Separator", "Zs",
        "Space_Separator",
    ]

    /// The binary properties Dart 3.12.2 accepts, exactly these (ECMA-262's
    /// table), long and short names. Not among them, though ICU knows them:
    /// `Changes_When_NFKC_Casefolded` (`CWKCF`), `Basic_Emoji`, `RGI_Emoji`,
    /// `Emoji_Keycap_Sequence`, `IDS_Unary_Operator`, `ID_Compat_Math_Start`.
    static let binaryProperties: Set<String> = [
        "ASCII", "ASCII_Hex_Digit", "AHex", "Alphabetic", "Alpha", "Any", "Assigned", "Bidi_Control", "Bidi_C",
        "Bidi_Mirrored", "Bidi_M", "Case_Ignorable", "CI", "Cased", "Changes_When_Casefolded", "CWCF",
        "Changes_When_Casemapped", "CWCM", "Changes_When_Lowercased", "CWL", "Changes_When_Titlecased", "CWT",
        "Changes_When_Uppercased", "CWU", "Dash", "Default_Ignorable_Code_Point", "DI", "Deprecated", "Dep",
        "Diacritic", "Dia", "Emoji", "Emoji_Component", "EComp", "Emoji_Modifier", "EMod",
        "Emoji_Modifier_Base", "EBase", "Emoji_Presentation", "EPres", "Extended_Pictographic", "ExtPict",
        "Extender", "Ext", "Grapheme_Base", "Gr_Base", "Grapheme_Extend", "Gr_Ext", "Hex_Digit", "Hex",
        "IDS_Binary_Operator", "IDSB", "IDS_Trinary_Operator", "IDST", "ID_Continue", "IDC", "ID_Start", "IDS",
        "Ideographic", "Ideo", "Join_Control", "Join_C", "Logical_Order_Exception", "LOE", "Lowercase",
        "Lower", "Math", "Noncharacter_Code_Point", "NChar", "Pattern_Syntax", "Pat_Syn",
        "Pattern_White_Space", "Pat_WS", "Quotation_Mark", "QMark", "Radical", "Regional_Indicator", "RI",
        "Sentence_Terminal", "STerm", "Soft_Dotted", "SD", "Terminal_Punctuation", "Term", "Unified_Ideograph",
        "UIdeo", "Uppercase", "Upper", "Variation_Selector", "VS", "White_Space", "space", "XID_Continue",
        "XIDC", "XID_Start", "XIDS",
    ]

    /// The script values Dart 3.12.2 accepts, exactly these (ECMA-262's
    /// table), the same after each of the four keys: Unicode's long names and
    /// four-letter codes, and `Qaai` (Inherited) and `Qaac` (Coptic). Not
    /// among them, though ICU knows them: `Hrkt` (`Katakana_Or_Hiragana`),
    /// ISO 15924's codes Unicode does not use (`Jpan`, `Zsym`, `Latf`) and
    /// scripts newer than Dart's Unicode (`Sidetic`, `Tai_Yo`).
    static let scriptValues: Set<String> = [
        "Adlam", "Adlm", "Aghb", "Ahom", "Anatolian_Hieroglyphs", "Arab", "Arabic", "Armenian", "Armi", "Armn",
        "Avestan", "Avst", "Bali", "Balinese", "Bamu", "Bamum", "Bass", "Bassa_Vah", "Batak", "Batk", "Beng", "Bengali",
        "Bhaiksuki", "Bhks", "Bopo", "Bopomofo", "Brah", "Brahmi", "Brai", "Braille", "Bugi", "Buginese", "Buhd",
        "Buhid", "Cakm", "Canadian_Aboriginal", "Cans", "Cari", "Carian", "Caucasian_Albanian", "Chakma", "Cham",
        "Cher", "Cherokee", "Chorasmian", "Chrs", "Common", "Copt", "Coptic", "Cpmn", "Cprt", "Cuneiform", "Cypriot",
        "Cypro_Minoan", "Cyrillic", "Cyrl", "Deseret", "Deva", "Devanagari", "Diak", "Dives_Akuru", "Dogr", "Dogra",
        "Dsrt", "Dupl", "Duployan", "Egyp", "Egyptian_Hieroglyphs", "Elba", "Elbasan", "Elym", "Elymaic", "Ethi",
        "Ethiopic", "Gara", "Garay", "Geor", "Georgian", "Glag", "Glagolitic", "Gong", "Gonm", "Goth", "Gothic", "Gran",
        "Grantha", "Greek", "Grek", "Gujarati", "Gujr", "Gukh", "Gunjala_Gondi", "Gurmukhi", "Guru", "Gurung_Khema",
        "Han", "Hang", "Hangul", "Hani", "Hanifi_Rohingya", "Hano", "Hanunoo", "Hatr", "Hatran", "Hebr", "Hebrew",
        "Hira", "Hiragana", "Hluw", "Hmng", "Hmnp", "Hung", "Imperial_Aramaic", "Inherited", "Inscriptional_Pahlavi",
        "Inscriptional_Parthian", "Ital", "Java", "Javanese", "Kaithi", "Kali", "Kana", "Kannada", "Katakana", "Kawi",
        "Kayah_Li", "Khar", "Kharoshthi", "Khitan_Small_Script", "Khmer", "Khmr", "Khoj", "Khojki", "Khudawadi",
        "Kirat_Rai", "Kits", "Knda", "Krai", "Kthi", "Lana", "Lao", "Laoo", "Latin", "Latn", "Lepc", "Lepcha", "Limb",
        "Limbu", "Lina", "Linb", "Linear_A", "Linear_B", "Lisu", "Lyci", "Lycian", "Lydi", "Lydian", "Mahajani", "Mahj",
        "Maka", "Makasar", "Malayalam", "Mand", "Mandaic", "Mani", "Manichaean", "Marc", "Marchen", "Masaram_Gondi",
        "Medefaidrin", "Medf", "Meetei_Mayek", "Mend", "Mende_Kikakui", "Merc", "Mero", "Meroitic_Cursive",
        "Meroitic_Hieroglyphs", "Miao", "Mlym", "Modi", "Mong", "Mongolian", "Mro", "Mroo", "Mtei", "Mult", "Multani",
        "Myanmar", "Mymr", "Nabataean", "Nag_Mundari", "Nagm", "Nand", "Nandinagari", "Narb", "Nbat", "New_Tai_Lue",
        "Newa", "Nko", "Nkoo", "Nshu", "Nushu", "Nyiakeng_Puachue_Hmong", "Ogam", "Ogham", "Ol_Chiki", "Ol_Onal",
        "Olck", "Old_Hungarian", "Old_Italic", "Old_North_Arabian", "Old_Permic", "Old_Persian", "Old_Sogdian",
        "Old_South_Arabian", "Old_Turkic", "Old_Uyghur", "Onao", "Oriya", "Orkh", "Orya", "Osage", "Osge", "Osma",
        "Osmanya", "Ougr", "Pahawh_Hmong", "Palm", "Palmyrene", "Pau_Cin_Hau", "Pauc", "Perm", "Phag", "Phags_Pa",
        "Phli", "Phlp", "Phnx", "Phoenician", "Plrd", "Prti", "Psalter_Pahlavi", "Qaac", "Qaai", "Rejang", "Rjng",
        "Rohg", "Runic", "Runr", "Samaritan", "Samr", "Sarb", "Saur", "Saurashtra", "Sgnw", "Sharada", "Shavian",
        "Shaw", "Shrd", "Sidd", "Siddham", "SignWriting", "Sind", "Sinh", "Sinhala", "Sogd", "Sogdian", "Sogo", "Sora",
        "Sora_Sompeng", "Soyo", "Soyombo", "Sund", "Sundanese", "Sunu", "Sunuwar", "Sylo", "Syloti_Nagri", "Syrc",
        "Syriac", "Tagalog", "Tagb", "Tagbanwa", "Tai_Le", "Tai_Tham", "Tai_Viet", "Takr", "Takri", "Tale", "Talu",
        "Tamil", "Taml", "Tang", "Tangsa", "Tangut", "Tavt", "Telu", "Telugu", "Tfng", "Tglg", "Thaa", "Thaana", "Thai",
        "Tibetan", "Tibt", "Tifinagh", "Tirh", "Tirhuta", "Tnsa", "Todhri", "Todr", "Toto", "Tulu_Tigalari", "Tutg",
        "Ugar", "Ugaritic", "Unknown", "Vai", "Vaii", "Vith", "Vithkuqi", "Wancho", "Wara", "Warang_Citi", "Wcho",
        "Xpeo", "Xsux", "Yezi", "Yezidi", "Yi", "Yiii", "Zanabazar_Square", "Zanb", "Zinh", "Zyyy", "Zzzz",
    ]
}
