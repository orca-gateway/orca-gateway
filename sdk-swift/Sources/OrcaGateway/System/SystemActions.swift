#if canImport(SwiftUI)
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// What `openUrl`, `copyToClipboard` and `share` do on the device. The
/// defaults use the system (UIApplication, UIPasteboard, the share sheet);
/// tests and hosts swap in their own.
@MainActor
public struct SystemActions {
    public var open: (URL) -> Void
    public var copy: (String) -> Void
    /// The text to share and an optional subject (used by mail targets).
    public var share: (String, String?) -> Void
    public var urlPolicy: OrcaURLPolicy

    public init(
        open: @escaping (URL) -> Void, copy: @escaping (String) -> Void,
        share: @escaping (String, String?) -> Void, urlPolicy: OrcaURLPolicy = .standard
    ) {
        self.open = open
        self.copy = copy
        self.share = share
        self.urlPolicy = urlPolicy
    }

    /// Perform one of the three system effects; false for any other effect.
    @discardableResult
    public func perform(_ effect: ActionEffect) -> Bool {
        switch effect.type {
        case "openUrl":
            // Flutter reports the effect, then launches only what the policy
            // allows; a blocked scheme is dropped silently.
            if let url = urlPolicy.url(effect.payload["url"]?.stringValue ?? "") { open(url) }
        case "copyToClipboard":
            copy(effect.payload["text"]?.stringValue ?? "")
        case "share":
            share(effect.payload["text"]?.stringValue ?? "", effect.payload["subject"]?.stringValue)
        default:
            return false
        }
        return true
    }

    /// The device's own handlers.
    public static var live: SystemActions {
        #if canImport(UIKit) && !os(watchOS)
        return SystemActions(
            open: { UIApplication.shared.open($0) },
            copy: { UIPasteboard.general.string = $0 },
            share: { text, subject in presentShareSheet(text: text, subject: subject) })
        #elseif canImport(AppKit)
        return SystemActions(
            open: { NSWorkspace.shared.open($0) },
            copy: { text in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            },
            share: { _, _ in })
        #else
        return SystemActions(open: { _ in }, copy: { _ in }, share: { _, _ in })
        #endif
    }
}

#if canImport(UIKit) && !os(watchOS)
/// The share sheet, from the top view controller of the key window.
@MainActor
private func presentShareSheet(text: String, subject: String?) {
    let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
    if let subject { sheet.setValue(subject, forKey: "subject") }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    guard let top else { return }
    // iPad presents the sheet as a popover, which needs an anchor.
    sheet.popoverPresentationController?.sourceView = top.view
    sheet.popoverPresentationController?.sourceRect = CGRect(
        x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
    top.present(sheet, animated: true)
}
#endif
#endif
