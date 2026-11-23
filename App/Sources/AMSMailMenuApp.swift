import MailMenuCore
import SwiftUI

@main
struct AMSMailMenuApp: App {
    @StateObject private var store = MailStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(unread: store.unreadCount,
                         newestUnread: store.newestUnreadDate,
                         hasProblem: store.problem != nil)
        }
        .menuBarExtraStyle(.window)

        Window("Email", id: "message") {
            MessageWindowView()
                .environmentObject(store)
        }
        .defaultSize(width: 480, height: 560)
        .defaultPosition(.topTrailing)

        Window("Triage", id: "triage") {
            TriageView()
                .environmentObject(store)
        }
        .defaultSize(width: 620, height: 600)

        Settings {
            SettingsView()
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

    var body: some View {
        HStack(spacing: 3) {
            if hasProblem {
                Image(systemName: "exclamationmark.triangle")
            } else if unread == 0 {
                Image(systemName: "envelope")
            } else {
                switch MenuBarStyle(rawValue: style) ?? .blueFill {
                case .blueFill:
                    // Menu bar images are normally drawn in black/white; this one keeps its colour.
                    Image(nsImage: Self.blueEnvelope)
                case .count:
                    Image(systemName: "envelope.fill")
                    Text("\(unread)")
                case .dot:
                    Image(systemName: "envelope.badge")
                }
            }
            if showTime, !hasProblem, unread > 0, let date = newestUnread {
                Text(date.formatted(date: .omitted, time: .shortened))
            }
        }
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
