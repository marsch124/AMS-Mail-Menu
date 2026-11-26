import MailMenuCore
import SwiftUI

/// Where the program starts. The helper copy (`--worker`) does its one job and ends before any window work.
@main
enum Launcher {
    static func main() {
        Worker.runIfAsked()
        AMSMailMenuApp.main()
    }
}

struct AMSMailMenuApp: App {
    @StateObject private var store = MailStore()

    init() {
        SelfCheck.runIfAsked()
        KeeperStartup.begin()
        // A saved place in the menu bar (points from the right edge): just left of Deck Mate (272), right of
        // Tidy Bar's line (302), so the icon always shows and never sits behind the notch.
        let placeKey = "NSStatusItem Preferred Position Item-0"
        if UserDefaults.standard.object(forKey: placeKey) == nil { UserDefaults.standard.set(290, forKey: placeKey) }
        SelfCheck.listenForOpenPanel()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(unread: store.unreadCount,
                         newestUnread: store.newestUnreadDate,
                         hasProblem: store.problem != nil)
                .background(SelfCheck.Hooks().environmentObject(store))
        }
        .menuBarExtraStyle(.window)

        Window("Email", id: "message") {
            MessageWindowView()
                .padding(6)     // the window's round corners would cut into the words otherwise
                .tint(.mailBlue)
                .font(Look.f(13))
                .controlSize(.small)
                .environmentObject(store)
        }
        .defaultSize(width: 480, height: 560)
        .defaultPosition(.topTrailing)

        Window("Triage", id: "triage") {
            TriageView()
                .padding(6)
                .tint(.mailBlue)
                .font(Look.f(13))
                .controlSize(.small)
                .environmentObject(store)
        }
        .defaultSize(width: 800, height: 600)

        Settings {
            SettingsView()
                .tint(.mailBlue)
                .font(Look.f(13))
                .controlSize(.small)
                .environmentObject(store)
        }
    }
}

/// The icon in the menu bar (Martin's drawing 8: blue fill while new mail waits;
/// count or dot can be chosen in Settings; optional time of the newest new email).
struct MenuBarLabel: View {
    let unread: Int
    let newestUnread: Date?
    let hasProblem: Bool
    @AppStorage(SettingsKey.menuBarStyle) private var style = SettingsDefault.menuBarStyle
    @AppStorage(SettingsKey.menuBarShowTime) private var showTime = SettingsDefault.menuBarShowTime

    /// Read so the label is drawn again when the Mac switches between day and night.
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // A menu bar label shows only its first picture, so everything is drawn into one (MenuBarArt.label).
        Image(nsImage: MenuBarArt.label(parts, dark: scheme == .dark))
    }

    private var parts: [MenuBarArt.Part] {
        // The orange envelope with "!" (the owner's pick 2, 26 Nov 2026; before: a black triangle).
        if hasProblem { return [.picture(MenuBarArt.warningMark)] }
        if unread == 0 { return [.picture(MenuBarArt.symbol("envelope", "No new mail"))] }
        var parts: [MenuBarArt.Part]
        switch MenuBarStyle(rawValue: style) ?? .blueFill {
        case .blueFill:
            // Menu bar images are normally drawn in black/white; this one keeps its colour.
            parts = [.picture(Self.blueEnvelope)]
        case .count:
            parts = [.picture(MenuBarArt.symbol("envelope.fill", "New mail")), .word("\(unread)")]
        case .dot:
            parts = [.picture(MenuBarArt.symbol("envelope.badge", "New mail"))]
        }
        // Two small thin lines, "08:" over "09" (the owner's pick A; before: "8:09" in 13 pt).
        if showTime, let date = newestUnread { parts.append(.time(date)) }
        return parts
    }

    static let blueEnvelope: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            .applying(.init(paletteColors: [NSColor(red: 0.04, green: 0.36, blue: 0.77, alpha: 1)]))
        let image = NSImage(systemSymbolName: "envelope.fill", accessibilityDescription: "New mail")?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = false
        return image
    }()
}
