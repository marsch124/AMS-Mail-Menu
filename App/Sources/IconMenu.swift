import AppKit
import MailMenuCore
import os

/// The two-finger click (or Control-click) on the menu bar icon: a short menu (the owner's pick of four,
/// 26 Nov 2026). A normal click still opens the list. SwiftUI's menu bar icon has no such click, so the app
/// watches its own clicks and pops the menu up under its own button.
@MainActor
final class IconMenu: NSObject {
    static let shared = IconMenu()

    private var monitor: Any?
    /// For the check word `rightClick`: the next menu closes by itself after this many seconds.
    var closeNextAfter: Double?
    private var checkNow: () -> Void = {}
    private var openTriage: () -> Void = {}
    private var openSettings: () -> Void = {}
    private let diary = Logger(subsystem: "com.schabbauer.AMSMailMenu", category: "reading")

    /// Called once the menu bar icon is there (from `SelfCheck.Hooks`), with what the entries do.
    func install(checkNow: @escaping () -> Void, openTriage: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.checkNow = checkNow
        self.openTriage = openTriage
        self.openSettings = openSettings
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { event in
            let secondary = event.type == .rightMouseDown || event.modifierFlags.contains(.control)
            guard secondary, let button = SelfCheck.statusButton(), event.window === button.window else { return event }
            let seconds = IconMenu.shared.closeNextAfter
            IconMenu.shared.closeNextAfter = nil
            // Shown a moment later, so the click itself is finished before the menu takes over.
            DispatchQueue.main.async { IconMenu.shared.show(closingAfter: seconds) }
            return nil
        }
    }

    /// Pops the menu up under the icon. `closingAfter` closes it by itself (for the check word `iconMenu`).
    func show(closingAfter seconds: Double?) {
        guard let button = SelfCheck.statusButton() else { return }
        SelfCheck.closePanel()
        let menu = NSMenu()
        for entry in IconMenuEntry.layout {
            guard let entry else { menu.addItem(.separator()); continue }
            let item = NSMenuItem(title: entry.title, action: #selector(choose(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry
            menu.addItem(item)
        }
        if let seconds {
            let timer = Timer(timeInterval: seconds, repeats: false) { _ in menu.cancelTracking() }
            RunLoop.main.add(timer, forMode: .common)
        }
        diary.notice("icon menu shown")
        let below = NSPoint(x: 0, y: button.isFlipped ? button.bounds.height + 5 : -5)
        menu.popUp(positioning: nil, at: below, in: button)
    }

    @objc private func choose(_ item: NSMenuItem) {
        guard let entry = item.representedObject as? IconMenuEntry else { return }
        diary.notice("icon menu: \(entry.title, privacy: .public)")
        switch entry {
        case .checkNow: checkNow()
        case .openMail: MailReader.openMailInFront()
        case .triage: openTriage()
        case .settings: openSettings()
        case .quit: NSApp.terminate(nil)
        }
    }
}
