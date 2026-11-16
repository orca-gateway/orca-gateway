#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Flutter `SelectableText` as the builder makes it (PB:350-362): `data`,
/// `style`, `textAlign` and `maxLines` to Material's SelectableText, a
/// read-only EditableText (MUI selectable_text.dart:705-799). Its style is
/// the DefaultTextStyle's merged with its own (`TextStyles.layer`, as a
/// Text's), on the engine base (14, white, regular) under a DTS and on the
/// ambient body style without one, as a Text; textAlign own ?? DTS ??
/// start; maxLines own ?? DTS; Dynamic Type as a Text's
/// (`platformFont(at:)`).
///
/// On iOS a read-only, selectable UITextView (design D6, q2 a): a long
/// press or a double tap selects a word, the handles drag a range, the edit
/// menu copies it. As RenderEditable it is its text plus the 3 point caret
/// margin wide (`_kCaretGap` 1 + cursorWidth 2, FW rendering/editable.dart
/// :25, :1272, read-only too) and wraps 3 points short of its box: the text
/// view's right inset. With maxLines it is that many lines tall whatever the
/// text (minLines ?? maxLines, editable.dart performLayout) and scrolls to
/// the rest, no ellipsis; maxLines 1 is one line that does not wrap and
/// scrolls sideways (EditableText's single line). Without maxLines it fits
/// every line and does not scroll. A selection survives redraws while
/// `data` is the same. Without a DTS the font is the body font at the
/// Dynamic Type size (a style's own fields over it) and a colourless style
/// draws in `UIColor.label`: an ambient SwiftUI font or foreground (an
/// AppBar title's `.headline`, a button's colour) does not reach the UIKit
/// view.
///
/// On macOS (no UITextView) the Text path, `TextNodeView`, with SwiftUI's
/// `.textSelection(.enabled)`: maxLines cuts the text as a Text's does
/// instead of scrolling.
@MainActor
struct SelectableTextView: View {
    let node: ResolvedNode
    #if canImport(UIKit)
    @Environment(\.orcaTight) private var tight
    @Environment(\.layoutDirection) private var direction
    @Environment(\.orcaDefaultTextStyle) private var defaultStyle
    #endif

    var body: some View {
        #if canImport(UIKit)
        let layer = TextStyles.layer(dts: defaultStyle, own: TextStyles.Layer(
            style: node["style"], textAlign: node["textAlign"]?.stringValue, maxLines: node["maxLines"]?.intValue))
        let parsed = TextStyleProps(layer.style)
        let style = defaultStyle == nil ? parsed : parsed.onEngineBase
        // Flutter `height`, as a Text's (TextKit `extraLeading`).
        let extra = style.height == nil ? 0 : style.extraLeading
        let alignment = Props.textAlignment(layer.textAlign.map { .string($0) }, direction: direction)
        SelectableTextField(style: style, data: Props.text(node["data"]), textAlign: layer.textAlign,
                            maxLines: layer.maxLines.flatMap { $0 > 0 ? $0 : nil }, lineSpacing: max(extra, 0))
            .padding(.vertical, extra / 2)
            .background(style.background)
            .frame(maxWidth: tight.contains(.horizontal) ? .infinity : nil,
                   alignment: Props.frameAlignment(alignment))
        #else
        TextNodeView(node: node).textSelection(.enabled)
        #endif
    }
}

#if canImport(UIKit)
/// SelectableTextView's UITextView on iOS.
struct SelectableTextField: UIViewRepresentable {
    /// RenderEditable's `_caretMargin`: `_kCaretGap` 1 + cursorWidth 2.
    static let caretMargin: CGFloat = 3

    let style: TextStyleProps
    let data: String
    let textAlign: String?
    let maxLines: Int?
    let lineSpacing: CGFloat

    func makeUIView(context: Context) -> LineTextView {
        let view = LineTextView()
        view.isEditable = false
        view.isSelectable = true
        view.dataDetectorTypes = []
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: Self.caretMargin)
        view.textContainer.lineFragmentPadding = 0
        return view
    }

    func updateUIView(_ view: LineTextView, context: Context) {
        let text = attributed(data, context)
        // Setting the text moves the selection to its end. Flutter keeps it
        // while `data` is the same (SelectableText's didUpdateWidget makes a
        // new controller only for new data): an equal text is not set again,
        // a new style keeps the selection, new data starts over.
        if !view.attributedText.isEqual(to: text) {
            let kept = view.attributedText.string == text.string ? view.selectedRange : nil
            view.attributedText = text
            if let kept { view.selectedRange = kept }
        }
        view.isScrollEnabled = maxLines != nil
        // maxLines 1: the line runs on, as EditableText lays a single line
        // out without a width, and the view scrolls along it.
        view.lineWidth = maxLines == 1 ? ceil(Self.extent(text).width) : nil
    }

    /// One line at its own width plus the caret margin when it fits, else
    /// the width offered; as tall as every line (an empty text: one), or
    /// with maxLines as that many lines.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView view: LineTextView, context: Context) -> CGSize? {
        let line = ceil(Self.extent(attributed(data, context)).width) + Self.caretMargin
        let width = min(proposal.width ?? line, line)
        if let lines = maxLines ?? (data.isEmpty ? 1 : nil) {
            let blank = attributed(Array(repeating: " ", count: lines).joined(separator: "\n"), context)
            return CGSize(width: width, height: ceil(Self.extent(blank).height))
        }
        let free = CGFloat.greatestFiniteMagnitude
        return CGSize(width: width, height: ceil(view.sizeThatFits(CGSize(width: width, height: free)).height))
    }

    /// `string` in the style at the environment's Dynamic Type size, the
    /// label colour when the style has none, aligned as `textAlign` says in
    /// the layout direction (start: left in left-to-right).
    func attributed(_ string: String, _ context: Context) -> NSMutableAttributedString {
        let rightToLeft = context.environment.layoutDirection == .rightToLeft
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = switch textAlign {
        case "left": .left
        case "right": .right
        case "center": .center
        case "justify": .justified
        case "end": rightToLeft ? .left : .right
        default: rightToLeft ? .right : .left
        }
        paragraph.baseWritingDirection = rightToLeft ? .rightToLeft : .leftToRight
        paragraph.lineSpacing = lineSpacing
        let font = style.platformFont(at: UIContentSizeCategory(context.environment.dynamicTypeSize))
        let text = style.attributed(string, paragraph: paragraph, font: font)
        if style.color == nil {
            text.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: text.length))
        }
        return text
    }

    /// The text's laid-out size at an unlimited width: its longest line.
    static func extent(_ text: NSAttributedString) -> CGSize {
        let free = CGFloat.greatestFiniteMagnitude
        return text.boundingRect(with: CGSize(width: free, height: free), options: .usesLineFragmentOrigin,
                                 context: nil).size
    }
}

/// SelectableTextField's text view. With `lineWidth` its text stays on one
/// line that wide and the view scrolls sideways along it: a UITextView
/// otherwise wraps at its own width when it is resized and keeps its
/// content as wide as itself.
final class LineTextView: UITextView {
    /// The one line's text width; nil: the text wraps at the view's width.
    var lineWidth: CGFloat? {
        didSet {
            guard lineWidth != oldValue else { return }
            textContainer.widthTracksTextView = lineWidth == nil
            if lineWidth == nil {
                let width = max(bounds.width - textContainerInset.left - textContainerInset.right, 0)
                textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
            }
            contentSize = CGSize(width: bounds.width, height: contentSize.height)
            setNeedsLayout()
        }
    }

    override var contentSize: CGSize {
        get { super.contentSize }
        set {
            let line = lineWidth.map { $0 + textContainerInset.left + textContainerInset.right } ?? 0
            super.contentSize = CGSize(width: max(newValue.width, line), height: newValue.height)
        }
    }

    override func layoutSubviews() {
        holdLine()
        super.layoutSubviews()
        holdLine()
    }

    /// The container back at the line's width, and the content as wide.
    private func holdLine() {
        guard let lineWidth else { return }
        textContainer.widthTracksTextView = false
        if textContainer.size.width != lineWidth {
            textContainer.size = CGSize(width: lineWidth, height: .greatestFiniteMagnitude)
        }
        if contentSize.width < lineWidth + textContainerInset.left + textContainerInset.right {
            contentSize = contentSize
        }
    }
}
#endif
#endif
