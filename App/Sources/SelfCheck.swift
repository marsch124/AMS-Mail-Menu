import Foundation
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

    static func runIfAsked() {
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
