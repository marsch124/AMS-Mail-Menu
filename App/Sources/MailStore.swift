import MailMenuCore
import AppKit
import Combine
import Foundation
import os

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
        /// True when the email was archived straight at Gmail: Undo goes there too.
        var atGmail = false
    }

    /// A diary in the Mac's log: counts and times only, never the words of an email.
    private let diary = Logger(subsystem: "com.schabbauer.AMSMailMenu", category: "reading")
    private var timer: Timer?
    private var undoTimer: Timer?
    private let defaults = UserDefaults.standard

    /// For the test picture: a list of invented emails, no reading from Mail, no timer.
    init(sample: [MailMessage]) {
        isSample = true
        groups = SenderGrouping.group(sample, limit: sample.count)
        lastRefresh = Date()
        selectedMessage = sample.first
        selectedContent = Self.sampleText
    }

    /// True for the test pictures: nothing is asked of Mail.
    private var isSample = false
    static let sampleText = "Hello Martin,\n\nthis is an invented email for the test picture. It has a few lines, so the window shows how text looks.\n\nShall we have dinner on Friday? I can book the table for seven.\n\nBest wishes\nAnna"

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
    /// For looking at the warning mark in the real menu bar (check word `warningLook`): shows the
    /// "Mail is closed" warning for 8 seconds without touching Mail or the list, then reads Mail again.
    func showWarningForCheck() {
        problem = .mailNotRunning
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.refresh() }
    }

    func refresh() {
        guard !isLoading else { refreshWanted = true; return }
        let count = max(1, defaults.integer(forKey: SettingsKey.emailCount))
        let preview = defaults.bool(forKey: SettingsKey.showPreview)
        isLoading = true
        let began = Date()
        diary.notice("reading starts")
        // Each inbox is asked for `count` emails; the newest `count` across all inboxes are kept.
        // The first lines of text are NOT read here: Mail opens every email in full for them, which takes
        // seconds per email. The list comes first; the first lines follow one by one (`readNextPreview`).
        MailReader.runInBackground(MailScript.fetchInboxes(perMailbox: count, includePreview: false)) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            let seconds = Date().timeIntervalSince(began)
            switch result {
            case .success(let descriptor):
                self.listed = self.withoutArchivedAtGmail(MailScript.parseInboxes(descriptor))
                self.diary.notice("read \(self.listed.count) emails, \(self.listed.filter { !$0.isRead }.count) unread, in \(seconds, format: .fixed(precision: 1)) s")
                self.listLimit = count
                let here = Set(self.listed.map(\.id))
                self.previewCache = self.previewCache.filter { here.contains($0.key) }
                self.regroup()
                self.problem = nil
                self.lastRefresh = Date()
                if preview { self.readNextPreview() }
            case .failure(let p):
                self.diary.notice("reading failed after \(seconds, format: .fixed(precision: 1)) s: \(p.title, privacy: .public)")
                self.problem = p
                if p == .mailNotRunning { self.groups = [] }
            }
            if self.refreshWanted {
                self.refreshWanted = false
                self.refresh()
            }
        }
    }

    // MARK: - A check on one real email (asked for by the owner, 23 Nov 2026)

    /// Changes nothing: writes into the diary which read emails the inboxes hold (account and time received).
    func reportReadEmails() {
        let read = listed.sorted(by: { $0.dateReceived > $1.dateReceived }).filter(\.isRead)
        diary.notice("report: \(self.listed.count) emails in the inboxes, \(read.count) of them read")
        for message in read {
            diary.notice("report: read email of \(message.accountName, privacy: .public), received \(message.dateReceived.formatted(date: .abbreviated, time: .shortened), privacy: .public)")
        }
    }

    /// Archives the newest email that is already read, then takes it back with Undo, and writes each step
    /// into the diary (never the words of the email). Started by the notice "show" with the word "archiveUndo".
    /// With `onlySubject` (the word "archiveUndoTest"): only the email with exactly that subject, read or not,
    /// and nothing at all if there is none. That is how a test email is tried and no real one.
    func checkArchiveAndUndo(onlySubject: String? = nil) {
        // From everything read from Mail, not only the newest that the list shows.
        let newestFirst = listed.sorted(by: { $0.dateReceived > $1.dateReceived })
        let picked: MailMessage?
        if let onlySubject {
            picked = newestFirst.first(where: { $0.subject == onlySubject })
        } else {
            picked = newestFirst.first(where: { $0.isRead })
        }
        guard let message = picked else {
            diary.notice("check: no such email in the list, nothing done")
            return
        }
        let key = message.messageID
        diary.notice("check: archiving one read email of \(message.accountName, privacy: .public), received \(message.dateReceived.formatted(date: .abbreviated, time: .shortened), privacy: .public)")
        let began = Date()
        actionError = nil
        archive(message)
        waitUntil({ self.undoInfo != nil || self.actionError != nil }, tries: 60) {
            guard let info = self.undoInfo else {
                self.diary.notice("check: archive FAILED: \(self.actionError ?? "no answer in a minute", privacy: .public)")
                return
            }
            self.diary.notice("check: archive done in \(Date().timeIntervalSince(began), format: .fixed(precision: 1)) s, the email is now in \(info.fromBoxes.joined(separator: " or "), privacy: .public)")
            let undoBegan = Date()
            self.undoLast()
            self.waitUntil({ self.workNote == nil }, tries: 90) {
                self.diary.notice("check: undo \(self.actionError == nil ? "done" : "FAILED: " + (self.actionError ?? ""), privacy: .public) in \(Date().timeIntervalSince(undoBegan), format: .fixed(precision: 1)) s")
                let undone = Date()
                self.waitForList(after: undone, tries: 90) {
                    let back = self.listed.contains { $0.messageID == key }
                    self.diary.notice("check: after undo the email is \(back ? "back in the inbox list" : "NOT in the inbox list", privacy: .public); the list has \(self.listed.count) emails")
                }
            }
        }
    }

    private func waitUntil(_ ready: @escaping @MainActor () -> Bool, tries: Int, then: @escaping @MainActor () -> Void) {
        if ready() || tries <= 0 { then(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.waitUntil(ready, tries: tries - 1, then: then)
        }
    }

    private func waitForList(after moment: Date, tries: Int, then: @escaping @MainActor () -> Void) {
        if let last = lastRefresh, last > moment { then(); return }
        guard tries > 0 else { diary.notice("check: the list was not read again in time"); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.waitForList(after: moment, tries: tries - 1, then: then)
        }
    }

    // MARK: - First lines of text

    /// The emails as last read from Mail, before grouping.
    private var listed: [MailMessage] = []
    private var listLimit = 20
    /// First lines already read, by email. Each is read once.
    private var previewCache: [String: String] = [:]
    private var previewRunning = false

    private func regroup() {
        var messages = listed
        for i in messages.indices { messages[i].preview = previewCache[messages[i].id] }
        groups = SenderGrouping.group(messages, limit: listLimit)
    }

    /// Reads the first line of the newest email that has none yet, in the background, then the next.
    private func readNextPreview() {
        guard !previewRunning, defaults.bool(forKey: SettingsKey.showPreview) else { return }
        guard let next = allMessagesNewestFirst.first(where: { previewCache[$0.id] == nil }) else { return }
        previewRunning = true
        let began = Date()
        MailReader.runInBackground(MailScript.fetchContent(of: next)) { [weak self] result in
            guard let self else { return }
            self.previewRunning = false
            let seconds = Date().timeIntervalSince(began)
            switch result {
            case .success: self.diary.notice("first line read in \(seconds, format: .fixed(precision: 1)) s")
            case .failure(let p): self.diary.notice("first line failed after \(seconds, format: .fixed(precision: 1)) s: \(p.title, privacy: .public)")
            }
            switch result {
            case .success(let d):
                self.previewCache[next.id] = MessageLinks.firstLine(of: String((d.stringValue ?? "").prefix(2000)))
            case .failure(.other):
                self.previewCache[next.id] = ""     // this one email cannot be read; do not try it for ever
            case .failure:
                return                               // Mail is closed, busy or not allowed: the next reading starts again
            }
            self.regroup()
            self.readNextPreview()
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
        SelfCheck.closePanel()
        openWindow("message")
        NSApp.activate(ignoringOtherApps: true)
        loadContent(of: message) { [weak self] text in
            if self?.selectedMessage?.id == message.id { self?.selectedContent = text }
        }
        if !message.isRead {
            markRead([message])
            selectedMessage?.isRead = true
        }
    }

    /// The full text of one email, read from Mail by the helper; the window stays free meanwhile.
    func loadContent(of message: MailMessage, then: @escaping @MainActor (String) -> Void) {
        if isSample { then(Self.sampleText); return }
        MailReader.runInBackground(MailScript.fetchContent(of: message)) { result in
            switch result {
            case .success(let d): then(MessageLinks.tidyBody(d.stringValue ?? ""))
            case .failure(let p): then("\(p.title)\n\n\(p.explanation)")
            }
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
    // Every action is done by the helper copy: the window never waits for Mail (an undo took 11 seconds
    // on 23 Nov 2026). The email leaves the list at once; if Mail refuses, the next reading brings it back
    // and the reason shows at the bottom.

    /// What the app is doing for you right now, for the bottom bar ("Archiving…").
    @Published private(set) var workNote: String?

    func markRead(_ messages: [MailMessage]) {
        let unread = messages.filter { !$0.isRead }
        guard !unread.isEmpty else { return }
        let ids = Set(unread.map(\.id))
        for i in listed.indices where ids.contains(listed[i].id) { listed[i].isRead = true }
        regroup()
        perform(MailScript.setRead(unread, read: true))
    }

    func reply(_ message: MailMessage) {
        perform(MailScript.reply(message), refreshAfter: false)
    }

    func archive(_ message: MailMessage) {
        if !isSample, GmailConnection.handles(accountName: message.accountName) {
            archiveAtGmail(message)
            return
        }
        hide(message)
        perform(MailScript.archive(message), note: "Archiving…") { [weak self] result in
            guard case .success(let answer) = result else { return }
            let box = answer.stringValue ?? ""
            self?.showUndo(UndoInfo(message: message, text: "Archived “\(message.subject)”",
                                    fromBoxes: box.isEmpty ? MailScript.archiveMailboxNames : [box]))
        }
    }

    func delete(_ message: MailMessage) {
        hide(message)
        perform(MailScript.delete(message), note: "Deleting…") { [weak self] result in
            guard case .success = result else { return }
            self?.showUndo(UndoInfo(message: message, text: "Deleted “\(message.subject)”",
                                    fromBoxes: MailScript.trashMailboxNames))
        }
    }

    /// Moves an email to one of its account's Mail folders. Offers Undo.
    func file(_ message: MailMessage, toMailboxPath path: String) {
        hide(message)
        perform(MailScript.move(message, toMailboxPath: path), note: "Filing…") { [weak self] result in
            guard case .success = result else { return }
            self?.rememberRecent(path, key: "recentFolders")
            self?.showUndo(UndoInfo(message: message, text: "Filed “\(message.subject)” in \(path)",
                                    fromBoxes: [path]))
        }
    }

    /// Takes an email out of the list at once, before Mail has answered.
    private func hide(_ message: MailMessage) {
        guard !isSample else { return }
        listed.removeAll { $0.id == message.id }
        regroup()
    }

    /// Folder paths of one account, read from Mail once and then kept.
    private var mailboxCache: [String: [String]] = [:]

    func loadMailboxes(for account: String, then: @escaping @MainActor ([String]) -> Void) {
        if isSample { then(["Archive", "Bills", "Family", "Family/Holidays", "Receipts", "Work"]); return }
        if let cached = mailboxCache[account] { then(cached); return }
        MailReader.runInBackground(MailScript.listMailboxes(account: account)) { [weak self] result in
            switch result {
            case .success(let d):
                var seen = Set<String>()
                let names = MailScript.items(of: d).compactMap(\.stringValue).filter { seen.insert($0).inserted }
                self?.mailboxCache[account] = names
                then(names)
            case .failure(let p):
                self?.actionError = "\(p.title). \(p.explanation)"
                then([])
            }
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
        if info.atGmail { putBackAtGmail(info.message); return }
        perform(MailScript.moveBack(info.message, fromAnyOf: info.fromBoxes), note: "Putting the email back…")
    }

    func hideUndo() {
        undoTimer?.invalidate()
        undoInfo = nil
    }

    // MARK: - Straight at Gmail (0.9)
    // Apple Mail never passes a move ordered by another app on to Gmail (tried 23 Nov 2026), so a Gmail
    // email is archived, and put back, at Gmail itself. Mail shows the change when it next checks Gmail.

    /// Emails archived at Gmail, by their Message-ID, and when. Until Mail has caught up they would come
    /// back into the list at the next reading; they are kept out for `gmailQuiet` seconds.
    private var archivedAtGmail: [String: Date] = [:]
    private let gmailQuiet: TimeInterval = 600

    /// The names of the accounts the inboxes belong to, for "Account in Mail" in Settings.
    var accountNames: [String] {
        var seen: [String] = []
        let source = everythingRead.isEmpty ? groups.flatMap(\.messages) : everythingRead
        for name in source.map(\.accountName) where !name.isEmpty && !seen.contains(name) { seen.append(name) }
        return seen
    }

    /// Everything the last reading brought, also what `withoutArchivedAtGmail` keeps out of the list.
    private var everythingRead: [MailMessage] = []

    /// What a reading from Mail may show: not the emails archived at Gmail a moment ago.
    private func withoutArchivedAtGmail(_ messages: [MailMessage]) -> [MailMessage] {
        everythingRead = messages
        let now = Date()
        archivedAtGmail = archivedAtGmail.filter { now.timeIntervalSince($0.value) < gmailQuiet }
        guard !archivedAtGmail.isEmpty else { return messages }
        return messages.filter { archivedAtGmail[$0.messageID] == nil }
    }

    private func archiveAtGmail(_ message: MailMessage) {
        hide(message)
        archivedAtGmail[message.messageID] = Date()
        workNote = "Archiving…"
        let began = Date()
        Task { [weak self] in
            do {
                try await GmailConnection.archive(messageID: message.messageID)
                guard let self else { return }
                self.workNote = nil
                self.actionError = nil
                self.diary.notice("gmail: archived in \(Date().timeIntervalSince(began), format: .fixed(precision: 1)) s")
                self.showUndo(UndoInfo(message: message, text: "Archived “\(message.subject)”", fromBoxes: [], atGmail: true))
            } catch {
                guard let self else { return }
                self.workNote = nil
                self.archivedAtGmail[message.messageID] = nil
                self.actionError = GmailConnection.words(for: error)
                self.diary.notice("gmail: archive FAILED after \(Date().timeIntervalSince(began), format: .fixed(precision: 1)) s: \(String(describing: error), privacy: .public)")
                self.refresh()
            }
        }
    }

    private func putBackAtGmail(_ message: MailMessage) {
        workNote = "Putting the email back…"
        let began = Date()
        Task { [weak self] in
            do {
                try await GmailConnection.putBack(messageID: message.messageID)
                guard let self else { return }
                self.archivedAtGmail[message.messageID] = nil
                self.actionError = nil
                self.diary.notice("gmail: put back in \(Date().timeIntervalSince(began), format: .fixed(precision: 1)) s")
            } catch {
                guard let self else { return }
                self.actionError = GmailConnection.words(for: error)
                self.diary.notice("gmail: put back FAILED after \(Date().timeIntervalSince(began), format: .fixed(precision: 1)) s: \(String(describing: error), privacy: .public)")
            }
            self?.workNote = nil
            self?.refresh()
        }
    }

    private func showUndo(_ info: UndoInfo) {
        undoInfo = info
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.undoInfo = nil }
        }
    }

    private func perform(_ source: String, refreshAfter: Bool = true, note: String? = nil,
                         then: (@MainActor (Result<NSAppleEventDescriptor, MailAccessProblem>) -> Void)? = nil) {
        if isSample { return }
        workNote = note
        MailReader.runInBackground(source) { [weak self] result in
            guard let self else { return }
            if self.workNote == note { self.workNote = nil }
            switch result {
            case .success:
                self.actionError = nil
            case .failure(let p):
                if case .other(let text) = p {
                    self.actionError = text
                } else {
                    self.actionError = "\(p.title). \(p.explanation)"
                }
            }
            then?(result)
            if refreshAfter { self.refresh() }
        }
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
