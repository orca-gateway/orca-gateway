#if canImport(SwiftUI)
import SwiftUI

/// One page with its snackbar and toast overlay. Put it inside a
/// NavigationStack (OrcaApp does) so a Scaffold's AppBar becomes the
/// navigation bar.
@MainActor
public struct OrcaPageView: View {
    @ObservedObject var model: OrcaPageModel

    public init(model: OrcaPageModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if let root = model.renderer.rootId {
                NodeView(id: root, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) { ToastView(model: model) }
        .animation(.easeInOut(duration: 0.2), value: model.toast)
    }
}

/// The snackbar or toast at the bottom; it leaves after its duration.
@MainActor
private struct ToastView: View {
    @ObservedObject var model: OrcaPageModel

    var body: some View {
        if let toast = model.toast {
            let snackbar = toast.style == .snackbar
            Text(toast.message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: snackbar ? .infinity : nil, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: snackbar ? 6 : 22)
                        .fill(Color(white: 0.18)))
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityIdentifier("orca.toast")
                .task(id: toast.id) {
                    try? await Task.sleep(nanoseconds: UInt64(max(0, toast.duration) * 1_000_000_000))
                    if model.toast?.id == toast.id { model.toast = nil }
                }
        }
    }
}

/// Loads a page through OrcaClient and keeps the result.
@MainActor
public final class OrcaPageLoader: ObservableObject {
    public enum Phase {
        case loading
        case loaded(OrcaPageModel)
        case failed(String)
    }

    @Published public private(set) var phase: Phase = .loading
    public let client: OrcaClient
    public let path: String
    private var started = false

    public init(client: OrcaClient, path: String) {
        self.client = client
        self.path = path
    }

    /// Fetch once; `reload()` fetches again.
    public func loadIfNeeded() async {
        guard !started else { return }
        await reload()
    }

    public func reload() async {
        started = true
        phase = .loading
        var client = self.client
        if client.device == DeviceInfo() { client.device = .current() }
        do {
            phase = .loaded(OrcaPageModel(page: try await client.fetchPage(path)))
        } catch OrcaClientError.http(let status, let body) {
            phase = .failed("HTTP \(status): \(body.prefix(200))")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// The root view of an Orca-driven app: one NavigationStack showing the page
/// at `path`, with loading and error states.
///
///     OrcaApp(client: OrcaClient(baseURL: url, appId: "counter", apiKey: "demo-key"))
@MainActor
public struct OrcaApp: View {
    @StateObject private var loader: OrcaPageLoader

    public init(client: OrcaClient, path: String = "home") {
        _loader = StateObject(wrappedValue: OrcaPageLoader(client: client, path: path))
    }

    public var body: some View {
        NavigationStack {
            switch loader.phase {
            case .loading:
                ProgressView()
            case .loaded(let model):
                OrcaPageView(model: model)
            case .failed(let message):
                VStack(spacing: 12) {
                    Text("Could not load this page").font(.headline)
                    Text(message).font(.footnote).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await loader.reload() } }
                }
                .padding(24)
            }
        }
        .task { await loader.loadIfNeeded() }
    }
}

extension DeviceInfo {
    /// This device: screen and safe area in points, OS version, locale and
    /// time zone, for the `x-orca-*` headers.
    @MainActor
    public static func current() -> DeviceInfo {
        var info = DeviceInfo(osVersion: ProcessInfo.processInfo.operatingSystemVersionString)
        let locale = Locale.current
        let language = locale.language.languageCode?.identifier ?? "en"
        info.locale = "\(language)_\(locale.region?.identifier ?? "")"
        info.timezone = TimeZone.current.abbreviation() ?? TimeZone.current.identifier
        #if canImport(UIKit) && !os(watchOS)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first {
            let screen = scene.screen
            info.screenWidth = screen.bounds.width
            info.screenHeight = screen.bounds.height
            info.pixelDensity = screen.scale
            if let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first {
                let insets = window.safeAreaInsets
                info.safeTop = insets.top
                info.safeBottom = insets.bottom
                info.safeLeft = insets.left
                info.safeRight = insets.right
            }
        }
        #endif
        return info
    }
}
#endif
