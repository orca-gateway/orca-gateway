extension Regex {
    /// Whether Dart's RegExp, with `unicode`, accepts `name` in `\p{name}` and
    /// `\P{name}`: a General_Category value, bare or after `General_Category=`
    /// or `gc=`; a binary property, bare; or `Script=`, `sc=`,
    /// `Script_Extensions=` or `scx=` with a value. Keys and names are
    /// case-sensitive, without spaces; Dart refuses every other name
    /// (`IsLatin`, `Latin`, `L&`, `script=Latin`, `ll`, `gc=Lowercase`). The
    /// script's value is left to ICU, which knows every script Dart does but
    /// reads the value loosely (`Script=latin`, which Dart refuses).
    static func dartAcceptsProperty(_ name: String) -> Bool {
        let scalars = name.unicodeScalars
        guard let equals = scalars.firstIndex(of: "=") else {
            return generalCategories.contains(name) || binaryProperties.contains(name)
        }
        let value = String(scalars[scalars.index(after: equals)...])
        switch String(scalars[..<equals]) {
        case "General_Category", "gc": return generalCategories.contains(value)
        case "Script", "sc", "Script_Extensions", "scx": return !value.isEmpty
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
}
