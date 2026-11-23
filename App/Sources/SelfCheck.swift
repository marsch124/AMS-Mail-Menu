import AppKit
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

    static func probeIfAsked() {
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
            mail(1, "Anna Example <anna@example.com>", "Dinner on Friday?", minutesAgo: 5, read: false, account: "iCloud"),
            mail(2, "Anna Example <anna@example.com>", "Photos from the weekend", minutesAgo: 90, read: true, account: "iCloud"),
            mail(3, "Example Shop <shop@example.com>", "Your order has shipped", minutesAgo: 30, read: false, account: "Gmail"),
            mail(4, "Example Shop <shop@example.com>", "Thank you for your order", minutesAgo: 300, read: false, account: "Gmail"),
            mail(5, "Example Bank <bank@example.com>", "Your monthly statement", minutesAgo: 2000, read: true, account: "iCloud"),
            mail(6, "Example News <news@example.com>", "This week in the news", minutesAgo: 4000, read: true, account: "Gmail"),
        ])
        let host = NSHostingView(rootView: MenuContentView().environmentObject(store))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = host
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let size = host.fittingSize
        window.setContentSize(size)
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
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
