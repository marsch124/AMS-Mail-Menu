import MailMenuCore
import AppKit
import Combine
import Foundation

/// Holds the emails shown in the menu and refreshes them from Apple Mail.
@MainActor
final class MailStore: ObservableObject {
    @Published private(set) var groups: [SenderGroup] = []
    @Published private(set) var problem: MailAccessProblem?
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var isLoading = false

    /// The email shown in the small window inside the app.
    @Published var selectedMessage: MailMessage?
    @Published var selectedContent: String = ""

    /// Shown as a bar with "Undo" after archive or delete.
    @Published private(set) var undoInfo: UndoInfo?
    /// A plain message when an action did not work.
    @Published var actionError: String?

    struct UndoInfo: Equatable {
        let message: MailMessage
        let text: String
        /// Mailboxes where the email may now be.
        let fromBoxes: [String]
    }

    private var timer: Timer?
    private var undoTimer: Timer?
    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            SettingsKey.emailCount: SettingsDefault.emailCount,
            SettingsKey.showPreview: SettingsDefault.showPreview,
            SettingsKey.showAccount: SettingsDefault.showAccount,
            SettingsKey.menuBarStyle: SettingsDefault.menuBarStyle,
            SettingsKey.menuBarShowTime: SettingsDefault.menuBarShowTime,
            SettingsKey.openTarget: SettingsDefault.openTarget,
            SettingsKey.refreshSeconds: SettingsDefault.refreshSeconds,
        ])
        refresh()
        restartTimer()
    }

    var unreadCount: Int { groups.reduce(0) { $0 + $1.unreadCount } }

    /// When the newest unread email arrived (shown next to the menu bar icon if switched on).
    var newestUnreadDate: Date? {
        groups.flatMap(\.messages).filter { !$0.isRead }.map(\.dateReceived).max()
    }

    func restartTimer() {
        timer?.invalidate()
        let seconds = max(15, defaults.integer(forKey: SettingsKey.refreshSeconds))
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// A check asked for while one is still running: it runs once more when that one ends.
    private var refreshWanted = false

    /// Reads the inboxes in the background; the list stays usable while Mail answers.
    func refresh() {
        guard !isLoading else { refreshWanted = true; return }
        let count = max(1, defaults.integer(forKey: SettingsKey.emailCount))
        let preview = defaults.bool(forKey: SettingsKey.showPreview)
        isLoading = true
        // Each inbox is asked for `count` emails; the newest `count` across all inboxes are kept.
        MailReader.runInBackground(MailScript.fetchInboxes(perMailbox: count, includePreview: preview)) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let descriptor):
                self.groups = SenderGrouping.group(MailScript.parseInboxes(descriptor), limit: count)
                self.problem = nil
                self.lastRefresh = Date()
            case .failure(let p):
                self.problem = p
                if p == .mailNotRunning { self.groups = [] }
            }
            if self.refreshWanted {
                self.refreshWanted = false
                self.refresh()
            }
        }
    }

    // MARK: - Opening an email

    /// Opens an email where Settings says.
    func open(_ message: MailMessage, openWindow: (String) -> Void) {
        let raw = defaults.string(forKey: SettingsKey.openTarget) ?? SettingsDefault.openTarget
        switch OpenTarget(rawValue: raw) ?? .appWindow {
        case .appWindow: openInWindow(message, openWindow: openWindow)
        case .appleMail: openInAppleMail(message)
        case .spark: Self.bringSparkForward()
        }
    }

    /// Shows the email in the small window inside the app and marks it as read.
    func openInWindow(_ message: MailMessage, openWindow: (String) -> Void) {
        selectedMessage = message
        selectedContent = "Loading…"
        openWindow("message")
        NSApp.activate(ignoringOtherApps: true)
        switch MailReader.run(MailScript.fetchContent(of: message)) {
        case .success(let d): selectedContent = d.stringValue ?? ""
        case .failure(let p): selectedContent = "\(p.title)\n\n\(p.explanation)"
        }
        if !message.isRead {
            markRead([message])
            selectedMessage?.isRead = true
        }
    }

    /// The full text of one email, read from Mail.
    func content(of message: MailMessage) -> String {
        switch MailReader.run(MailScript.fetchContent(of: message)) {
        case .success(let d): return d.stringValue ?? ""
        case .failure(let p): return "\(p.title)\n\n\(p.explanation)"
        }
    }

    /// All listed emails, newest first (the order the triage window walks through).
    var allMessagesNewestFirst: [MailMessage] {
        groups.flatMap(\.messages).sorted { $0.dateReceived > $1.dateReceived }
    }

    func openInAppleMail(_ message: MailMessage) {
        if let url = MessageLinks.appleMailURL(messageID: message.messageID) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Actions

    func markRead(_ messages: [MailMessage]) {
        let unread = messages.filter { !$0.isRead }
        guard !unread.isEmpty else { return }
        perform(MailScript.setRead(unread, read: true))
    }

    func reply(_ message: MailMessage) {
        perform(MailScript.reply(message), refreshAfter: false)
    }

    func archive(_ message: MailMessage) {
        if case .success(let result) = perform(MailScript.archive(message)) {
            let box = result.stringValue ?? ""
            showUndo(UndoInfo(message: message, text: "Archived “\(message.subject)”",
                              fromBoxes: box.isEmpty ? MailScript.archiveMailboxNames : [box]))
        }
    }

    func delete(_ message: MailMessage) {
        if case .success = perform(MailScript.delete(message)) {
            showUndo(UndoInfo(message: message, text: "Deleted “\(message.subject)”",
                              fromBoxes: MailScript.trashMailboxNames))
        }
    }

    /// Moves an email to one of its account's Mail folders. Offers Undo.
    func file(_ message: MailMessage, toMailboxPath path: String) {
        if case .success = perform(MailScript.move(message, toMailboxPath: path)) {
            rememberRecent(path, key: "recentFolders")
            showUndo(UndoInfo(message: message, text: "Filed “\(message.subject)” in \(path)",
                              fromBoxes: [path]))
        }
    }

    /// Folder paths of one account, read from Mail once and then kept.
    private var mailboxCache: [String: [String]] = [:]

    func mailboxes(for account: String) -> [String] {
        if let cached = mailboxCache[account] { return cached }
        switch MailReader.run(MailScript.listMailboxes(account: account)) {
        case .success(let d):
            var seen = Set<String>()
            let names = MailScript.items(of: d).compactMap(\.stringValue).filter { seen.insert($0).inserted }
            mailboxCache[account] = names
            return names
        case .failure(let p):
            actionError = "\(p.title). \(p.explanation)"
            return []
        }
    }

    var recentFolders: [String] { defaults.stringArray(forKey: "recentFolders") ?? [] }
    var recentParagonNotes: [String] { defaults.stringArray(forKey: "recentParagonNotes") ?? [] }

    private func rememberRecent(_ value: String, key: String) {
        var list = defaults.stringArray(forKey: key) ?? []
        list.removeAll { $0 == value }
        list.insert(value, at: 0)
        defaults.set(Array(list.prefix(8)), forKey: key)
    }

    /// Hands the email to PARAGON as a task (with #tags and a link back to the email),
    /// then archives it in Mail. Returns false if PARAGON is not installed.
    @discardableResult
    func sendToParagon(_ message: MailMessage, words: String, tags: String, target: ParagonTarget) -> Bool {
        guard let url = ParagonLink.captureURL(words: words, tags: tags, target: target,
                                               mailLink: MessageLinks.appleMailURL(messageID: message.messageID)) else {
            actionError = "The link for PARAGON could not be made."
            return false
        }
        guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else {
            actionError = "PARAGON is not installed on this Mac (no app opens amspara:// links)."
            return false
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open(url, configuration: config)
        if case .note(let path) = target { rememberRecent(path, key: "recentParagonNotes") }
        archive(message)
        return true
    }

    func undoLast() {
        guard let info = undoInfo else { return }
        hideUndo()
        perform(MailScript.moveBack(info.message, fromAnyOf: info.fromBoxes))
    }

    func hideUndo() {
        undoTimer?.invalidate()
        undoInfo = nil
    }

    private func showUndo(_ info: UndoInfo) {
        undoInfo = info
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.undoInfo = nil }
        }
    }

    @discardableResult
    private func perform(_ source: String, refreshAfter: Bool = true) -> Result<NSAppleEventDescriptor, MailAccessProblem> {
        let result = MailReader.run(source)
        switch result {
        case .success:
            actionError = nil
        case .failure(let p):
            if case .other(let text) = p {
                actionError = text
            } else {
                actionError = "\(p.title). \(p.explanation)"
            }
        }
        if refreshAfter { refresh() }
        return result
    }

    /// Spark registers the `readdle-spark://` link type; the app that handles it is opened.
    /// This only brings Spark to the front. It cannot select a given email (see README).
    static func bringSparkForward() {
        guard let probe = URL(string: "readdle-spark://"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: probe) else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
