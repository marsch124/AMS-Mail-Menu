import AppKit
import os
import Foundation
import SwiftUI
import MailMenuCore

/// A check without the menu: `open -n "AMS Mail Menu.app" --args --check <file>` reads the inboxes once,
/// writes how it went into the file (per inbox: account, how many emails; never their words), and quits.
/// It runs as the app itself, so it uses the app's own permission for Mail.
enum SelfCheck {
    /// Fixed timing questions to Mail (`--probe <file>`): how long each kind of question takes.
    static let probes: [(String, String)] = [
        ("accounts", "tell application \"Mail\" to return count of accounts"),
        ("inbox boxes", "tell application \"Mail\" to return count of (mailboxes of inbox)"),
        ("count of box 1", "tell application \"Mail\" to return count of messages of (item 1 of (mailboxes of inbox))"),
        ("ids 1-20 of box 1", "tell application \"Mail\" to return count of (get id of messages 1 thru 20 of (item 1 of (mailboxes of inbox)))"),
        ("subjects 1-20 of box 1", "tell application \"Mail\" to return count of (get subject of messages 1 thru 20 of (item 1 of (mailboxes of inbox)))"),
        ("senders 1-20 of box 1", "tell application \"Mail\" to return count of (get sender of messages 1 thru 20 of (item 1 of (mailboxes of inbox)))"),
        ("dates 1-20 of box 1", "tell application \"Mail\" to return count of (get date received of messages 1 thru 20 of (item 1 of (mailboxes of inbox)))"),
        ("message ids 1-20 of box 1", "tell application \"Mail\" to return count of (get message id of messages 1 thru 20 of (item 1 of (mailboxes of inbox)))"),
        ("read marks 1-20 of box 1", "tell application \"Mail\" to return count of (get read status of messages 1 thru 20 of (item 1 of (mailboxes of inbox)))"),
        ("one email by number", "tell application \"Mail\" to return id of message 1 of (item 1 of (mailboxes of inbox))"),
        ("count of box 2", "tell application \"Mail\" to return count of messages of (item 2 of (mailboxes of inbox))"),
        ("ids 1-20 of box 2", "tell application \"Mail\" to return count of (get id of messages 1 thru 20 of (item 2 of (mailboxes of inbox)))"),
        ("ids 1-20 of the joint inbox", "tell application \"Mail\" to return count of (get id of messages 1 thru 20 of inbox)"),
    ]

    /// `--gmail-look <file>`: looks at the Gmail account without changing anything, to find out why archiving
    /// leaves an email in the inbox. Writes the account kinds, the names of Gmail's mailboxes, and for the one
    /// email the owner named (read, received 19 Nov 2026 at 08:02) its marks. Never the words of an email.
    static let gmailLooks: [(String, String)] = [
        ("accounts", """
            tell application "Mail"
                set out to {}
                repeat with a in accounts
                    set end of out to (name of a) & " | " & (account type of a as text) & " | enabled " & (enabled of a as text)
                end repeat
                return out
            end tell
            """),
        ("mailboxes of Gmail", MailScript.listMailboxes(account: "Gmail")),
        ("the email in the inbox", """
            tell application "Mail"
                set mb to mailbox "INBOX" of account "Gmail"
                set out to {"inbox holds " & (count of messages of mb)}
                repeat with m in messages of mb
                    set d to date received of m
                    set mark to ""
                    if (day of d = 19 and (month of d as integer) = 11 and hours of d = 8 and minutes of d = 2) then set mark to "  <-- the named email"
                    set end of out to "id " & (id of m) & " | read " & (read status of m as text) & " | deleted " & (deleted status of m as text) & " | junk " & (junk mail status of m as text) & " | day " & (day of d) & "." & (month of d as integer) & " " & (hours of d) & ":" & (minutes of d) & mark
                end repeat
                return out
            end tell
            """),
        ("the same email in other mailboxes", """
            tell application "Mail"
                set mb to mailbox "INBOX" of account "Gmail"
                set theKey to ""
                repeat with m in messages of mb
                    set d to date received of m
                    if (day of d = 19 and (month of d as integer) = 11 and hours of d = 8 and minutes of d = 2) then set theKey to message id of m
                end repeat
                if theKey is "" then return {"the named email is not in the inbox"}
                set out to {}
                repeat with b in mailboxes of account "Gmail"
                    try
                        with timeout of 40 seconds
                            set n to count of (messages of b whose message id is theKey)
                        end timeout
                        set end of out to (name of b) & ": " & n & " copy"
                    on error errMsg
                        set end of out to (name of b) & ": could not look (" & errMsg & ")"
                    end try
                end repeat
                return out
            end tell
            """),
    ]

    // 🚨 There was a `--gmail-archive-try` here. Its step `set deleted status of m to true` made Apple Mail
    // itself crash (Mail 16.0, macOS 26.6.2, 23 Nov 2026 15:33, in -[MCMessage setIsDeleted:]). It is gone.
    // Never send Mail that command again.

    static func gmailLookIfAsked() {
        let arguments = CommandLine.arguments
        guard let at = arguments.firstIndex(of: "--gmail-look"), at + 1 < arguments.count else { return }
        let file = URL(fileURLWithPath: arguments[at + 1])
        var lines: [String] = []
        for (name, source) in gmailLooks {
            let start = Date()
            lines.append("== \(name)")
            switch MailReader.run(source) {
            case .success(let d):
                let items = MailScript.items(of: d).compactMap(\.stringValue)
                lines.append(contentsOf: items.isEmpty ? [d.stringValue ?? "(nothing)"] : items)
            case .failure(let problem):
                lines.append("problem: \(problem.explanation)")
            }
            lines.append(String(format: "   took %.1f s", Date().timeIntervalSince(start)))
            try? lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        }
        lines.append("done")
        try? lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        exit(0)
    }

    static func probeIfAsked() {
        gmailLookIfAsked()
        let arguments = CommandLine.arguments
        guard let at = arguments.firstIndex(of: "--probe"), at + 1 < arguments.count else { return }
        let file = URL(fileURLWithPath: arguments[at + 1])
        var lines: [String] = []
        for (name, source) in probes {
            let start = Date()
            let answer: String
            switch MailReader.run(source) {
            case .success(let d): answer = "\(d.int32Value)"
            case .failure(let problem): answer = "problem: \(problem.explanation.prefix(60))"
            }
            lines.append(String(format: "%5.1f s  %@ -> %@", Date().timeIntervalSince(start), name, answer))
            try? lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        }
        lines.append("done")
        try? lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        exit(0)
    }

    /// The app's own menu bar button.
    @MainActor
    static func statusButton() -> NSStatusBarButton? {
        func button(in view: NSView?) -> NSStatusBarButton? {
            guard let view else { return nil }
            if let found = view as? NSStatusBarButton { return found }
            for sub in view.subviews { if let found = button(in: sub) { return found } }
            return nil
        }
        for window in NSApp.windows { if let found = button(in: window.contentView) { return found } }
        return nil
    }

    /// The list panel, while it is open.
    @MainActor
    static func openPanel() -> NSWindow? {
        NSApp.windows.first { $0.isVisible && String(describing: type(of: $0)).contains("MenuBarExtra") }
    }

    /// Closes the list panel, the way a click on the menu bar icon does. Called before a window of the app
    /// opens, so the window is not hidden under the list (the owner, 23 Nov 2026: "The triage window is
    /// under the list").
    @MainActor
    static func closePanel() {
        guard openPanel() != nil else { return }
        statusButton()?.performClick(nil)
    }

    /// Opens Settings in front of every other window: closes the list, opens the window, brings the app
    /// forward, and lifts the window itself (an app without a Dock icon is not always let forward, and a
    /// Settings window that is already open behind other windows would stay there). `open` is the
    /// screen's own `openSettings`.
    @MainActor
    static func showSettings(_ open: @escaping () -> Void) {
        closePanel()
        open()
        NSApp.activate(ignoringOtherApps: true)
        // The window may be made a moment after `open`; lift it now and twice more.
        for delay in [0.0, 0.15, 0.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let window = settingsWindow() else { return }
                if window.isMiniaturized { window.deminiaturize(nil) }
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    /// The Settings window, open or not yet shown.
    @MainActor
    static func settingsWindow() -> NSWindow? {
        NSApp.windows.first { $0.styleMask.contains(.titled) && $0.title.hasSuffix("Settings") }
    }

    /// Where the gear sits in the open list (the list's own points, from its top left corner), noted by
    /// the list itself, so a check can click it.
    @MainActor static var gearFrame: CGRect = .zero

    /// For checks: clicks the real gear in the open list, with a mouse press and release sent to the list.
    @MainActor
    /// A two-finger click on the app's own menu bar icon, queued like a real one (check word `rightClick`),
    /// so the watcher in `IconMenu` is tried, not only the menu. `IconMenu` closes the menu after 3 seconds.
    static func rightClickIcon() -> Bool {
        guard let button = statusButton(), let window = button.window else { return false }
        let spot = button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil)
        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown, location: spot, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
        else { return false }
        IconMenu.shared.closeNextAfter = 3
        NSApp.postEvent(event, atStart: false)
        return true
    }

    @MainActor
    static func pressGear() -> Bool {
        guard let panel = openPanel(), let content = panel.contentView, gearFrame.width > 0 else { return false }
        let spot = NSPoint(x: gearFrame.midX, y: content.bounds.height - gearFrame.midY)
        for kind in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(
                with: kind, location: spot, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
            else { return false }
            // Queued, not sent: a press that is sent waits inside the button for a release that never comes.
            NSApp.postEvent(event, atStart: false)
        }
        return true
    }

    /// For checks: another program on this Mac can ask the running app to press its own menu bar icon
    /// (the notice "com.schabbauer.AMSMailMenu.openPanel"), so the real panel can be photographed.
    static func listenForOpenPanel() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.schabbauer.AMSMailMenu.openPanel"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                func button(in view: NSView?) -> NSStatusBarButton? {
                    guard let view else { return nil }
                    if let found = view as? NSStatusBarButton { return found }
                    for sub in view.subviews { if let found = button(in: sub) { return found } }
                    return nil
                }
                for window in NSApp.windows {
                    if let found = button(in: window.contentView) { found.performClick(nil); return }
                }
            }
        }
    }

    /// The notice "com.schabbauer.AMSMailMenu.show" with the word message, triage or settings opens that
    /// window of the running app (the message window with the newest email that is already read, so
    /// nothing changes in Mail). Sits unseen behind the menu bar icon.
    struct Hooks: View {
        @EnvironmentObject private var store: MailStore
        @Environment(\.openWindow) private var openWindow
        @Environment(\.openSettings) private var openSettings

        var body: some View {
            Color.clear.frame(width: 0, height: 0)
                // The two-finger menu on the icon (0.9.6): what its entries do.
                .onAppear {
                    IconMenu.shared.install(
                        checkNow: { store.refresh() },
                        openTriage: {
                            openWindow(id: "triage")
                            NSApp.activate(ignoringOtherApps: true)
                        },
                        openSettings: { SelfCheck.showSettings { openSettings() } })
                }
                .onReceive(DistributedNotificationCenter.default().publisher(
                    for: Notification.Name("com.schabbauer.AMSMailMenu.show"))) { notice in
                    switch notice.object as? String {
                    case "message":
                        if let read = store.allMessagesNewestFirst.first(where: { $0.isRead }) {
                            store.openInWindow(read) { openWindow(id: $0) }
                        }
                    case "windows":
                        for window in NSApp.windows where window.isVisible {
                            Logger(subsystem: "com.schabbauer.AMSMailMenu", category: "reading")
                                .notice("window: \(String(describing: type(of: window)), privacy: .public) \(window.title, privacy: .public)")
                        }
                    case "triage":
                        SelfCheck.closePanel()
                        openWindow(id: "triage")
                        NSApp.activate(ignoringOtherApps: true)
                    case "settings":
                        SelfCheck.showSettings { openSettings() }
                    case "pressGear":
                        // The real gear in the open list (open the list first with the notice openPanel).
                        let pressed = SelfCheck.pressGear()
                        Logger(subsystem: "com.schabbauer.AMSMailMenu", category: "reading")
                            .notice("gear pressed: \(pressed, privacy: .public)")
                    case "gmail":
                        // The Settings window on its Gmail tab, to look at the real window.
                        SelfCheck.showSettings { openSettings() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(name: SettingsView.showTab, object: "gmail")
                        }
                    case "report":
                        store.reportReadEmails()
                    case "warningLook":
                        store.showWarningForCheck()
                    case "rightClick":
                        let posted = SelfCheck.rightClickIcon()
                        Logger(subsystem: "com.schabbauer.AMSMailMenu", category: "reading")
                            .notice("two-finger click posted: \(posted, privacy: .public)")
                    case "iconMenu":
                        // The two-finger menu under the icon, closed again by itself after 3 seconds.
                        DispatchQueue.main.async { IconMenu.shared.show(closingAfter: 3) }
                    case "archiveUndo":
                        store.checkArchiveAndUndo()
                    case "archiveUndoTest":
                        // Only the test email with this exact subject; no real email is ever picked.
                        store.checkArchiveAndUndo(onlySubject: "Mail Menu test")
                    case "close":
                        for window in NSApp.windows where window.isVisible && window.styleMask.contains(.titled) {
                            window.close()
                        }
                    default:
                        break
                    }
                }
        }
    }

    /// `--picture <file>`: draws the list with invented emails into a PNG, to check the layout without a click.
    @MainActor
    static func pictureIfAsked() {
        let arguments = CommandLine.arguments
        guard let at = arguments.firstIndex(of: "--picture"), at + 1 < arguments.count else { return }
        _ = NSApplication.shared
        func mail(_ n: Int, _ from: String, _ subject: String, minutesAgo: Double, read: Bool, account: String) -> MailMessage {
            MailMessage(mailID: n, messageID: "sample-\(n)@example.com", accountName: account, mailboxName: "INBOX",
                        sender: Sender.parse(from), subject: subject, dateReceived: Date().addingTimeInterval(-60 * minutesAgo),
                        isRead: read, preview: "This is the first line of the invented email number \(n).")
        }
        let store = MailStore(sample: [
            mail(1, "Anna Example via Example Groups <anna@example.com>", "Dinner on Friday at the new place by the harbour?", minutesAgo: 5, read: false, account: "iCloud"),
            mail(2, "Anna Example via Example Groups <anna@example.com>", "Photos from the weekend are ready to download", minutesAgo: 90, read: true, account: "iCloud"),
            mail(3, "Example Shop <shop@example.com>", "Your order 48213 has shipped and is on its way", minutesAgo: 30, read: false, account: "Gmail"),
            mail(4, "Example Shop <shop@example.com>", "Thank you for your order, here is your receipt", minutesAgo: 300, read: false, account: "Gmail"),
            mail(5, "Example Bank <bank@example.com>", "Your monthly statement", minutesAgo: 2000, read: true, account: "iCloud"),
            mail(6, "Example News <news@example.com>", "This week in the news", minutesAgo: 4000, read: true, account: "Gmail"),
        ])
        if let l = arguments.firstIndex(of: "--look"), l + 1 < arguments.count { Look.choose(Int(arguments[l + 1]) ?? 1) }
        if let w = arguments.firstIndex(of: "--width"), w + 1 < arguments.count, let width = Double(arguments[w + 1]) { Look.panelWidth = width }
        var which = "list"
        if let v = arguments.firstIndex(of: "--view"), v + 1 < arguments.count { which = arguments[v + 1] }
        let first = store.allMessagesNewestFirst[0]
        // Each screen as its window shows it: the same edge and colour as in the app. nil = as tall as its content.
        let screens: [String: (AnyView, CGSize?)] = [
            "list": (AnyView(MenuContentView()), nil),
            "message": (AnyView(MessageWindowView().padding(6)), CGSize(width: 480, height: 560)),
            "triage": (AnyView(TriageView().padding(6)), nil),
            "file": (AnyView(FilePicker(message: first) { _ in }), nil),
            "paragon": (AnyView(ParagonSheet(message: first) { _ in }), nil),
            "settings": (AnyView(SettingsView()), nil),
            "gmail": (AnyView(SettingsView(tab: "gmail")), nil),
            "guide": (AnyView(GuideView().padding(.horizontal, 4).frame(width: 480)), nil),
            "news": (AnyView(WhatsNewView().padding(.horizontal, 4).frame(width: 480)), nil),
        ]
        guard let (screen, fixed) = screens[which] else { exit(2) }
        let host = NSHostingView(rootView: screen.tint(.mailBlue).font(Look.f(13)).controlSize(which == "list" ? .regular : .small)
            .environmentObject(store)
            .background(Color(nsColor: .windowBackgroundColor)))
        if arguments.contains("--dark") { host.appearance = NSAppearance(named: .darkAqua) }
        if arguments.contains("--light") { host.appearance = NSAppearance(named: .aqua) }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = host
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let size = fixed ?? host.fittingSize
        window.setContentSize(size)
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        if let image = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: image)
            try? image.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: arguments[at + 1]))
        }
        try? "size \(Int(size.width)) x \(Int(size.height))".write(toFile: arguments[at + 1] + ".txt", atomically: true, encoding: .utf8)
        exit(0)
    }

    static func runIfAsked() {
        MainActor.assumeIsolated { pictureIfAsked() }
        probeIfAsked()
        let arguments = CommandLine.arguments
        guard let at = arguments.firstIndex(of: "--check"), at + 1 < arguments.count else { return }
        let file = URL(fileURLWithPath: arguments[at + 1])
        var lines: [String] = []
        let start = Date()
        let source = MailScript.fetchInboxes(perMailbox: 20, includePreview: false)
        let answer = arguments.contains("--helper") ? MailReader.runInWorker(source) : MailReader.run(source)
        switch answer {
        case .success(let descriptor):
            let messages = MailScript.parseInboxes(descriptor)
            var perAccount: [String: Int] = [:]
            for message in messages { perAccount[message.accountName, default: 0] += 1 }
            lines.append("read: \(messages.count) emails, \(messages.filter { !$0.isRead }.count) unread")
            for (account, count) in perAccount.sorted(by: { $0.key < $1.key }) { lines.append("inbox \(account): \(count)") }
            lines.append("senders: \(SenderGrouping.group(messages, limit: 20).count) groups")
        case .failure(let problem):
            lines.append("problem: \(problem.title) — \(problem.explanation)")
        }
        lines.append(String(format: "took %.1f s", Date().timeIntervalSince(start)))
        try? lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        exit(0)
    }
}
