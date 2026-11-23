import Foundation

// The direct connection to Gmail (0.9). Apple Mail never passes a move ordered by another app on to Gmail
// (tried 23 Nov 2026), so a Gmail email is archived straight at Gmail, over IMAP.
// Here are the rules and the conversation with the server, with no network in them: the app gives a real
// connection (`GmailConnection.swift`), the tests a scripted one.

/// One line at a time to and from the mail server.
public protocol IMAPLineTransport: AnyObject {
    func send(_ line: String) async throws
    func readLine() async throws -> String
}

/// What can go wrong at Gmail, each with plain words for the screen.
public enum GmailProblem: Error, Equatable {
    /// No address, no app password, or never connected.
    case notSetUp
    /// Google refused the address or the app password.
    case wrongPassword
    /// No internet, or Gmail did not answer.
    case noConnection(String)
    /// The email is not where it was looked for.
    case notFound
    /// More emails than one carry this email's mark; none is touched.
    case tooMany
    /// Gmail said it did the work, but the email is still in the inbox.
    case notArchived
    /// Gmail's "All Mail" folder was not found (needed to put an email back).
    case noAllMail
    /// Gmail said no, in its own words.
    case refused(String)

    public var words: String {
        switch self {
        case .notSetUp:
            return "Archiving a Gmail email needs the Gmail connection. Open Settings and connect Gmail. Nothing was changed."
        case .wrongPassword:
            return "Google did not accept the Gmail address or the app password. Nothing was changed. Check both in Settings, Gmail."
        case .noConnection(let why):
            return "Gmail could not be reached (\(why)). Nothing was changed."
        case .notFound:
            return "The email was not found at Gmail. Nothing was changed."
        case .tooMany:
            return "Gmail found more than one email like this one. Nothing was changed."
        case .notArchived:
            return "Gmail did not archive the email. It is still in your inbox."
        case .noAllMail:
            return "Gmail's “All Mail” folder was not found, so the email could not be put back. It is still archived."
        case .refused(let text):
            return "Gmail refused: \(text). Nothing was changed."
        }
    }
}

public enum GmailIMAP {
    /// The most emails one Message-ID may match before the app refuses to touch any of them.
    public static let mostMatches = 3

    /// Text inside double quotes, safe for an IMAP command.
    public static func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// The mark every email carries (its Message-ID), with its pointed brackets, as the server stores it.
    /// Nil when it is empty or too short to be safe: an empty search text would match EVERY email.
    public static func needle(messageID: String) -> String? {
        var id = messageID.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.hasPrefix("<") { id.removeFirst() }
        if id.hasSuffix(">") { id.removeLast() }
        guard id.count >= 6, !id.contains("\r"), !id.contains("\n") else { return nil }
        return "<\(id)>"
    }

    /// The numbers in the server's answer to a search: "* SEARCH 12 15" gives ["12", "15"].
    public static func searchUIDs(in lines: [String]) -> [String] {
        var out: [String] = []
        for line in lines where line.uppercased().hasPrefix("* SEARCH") {
            let parts = line.split(separator: " ").dropFirst(2)
            out += parts.map(String.init).filter { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
        }
        return out
    }

    /// The name of the folder flagged `\All` in the server's folder list, for example "[Gmail]/All Mail".
    /// A line looks like: * LIST (\HasNoChildren \All) "/" "[Gmail]/All Mail"
    public static func allMailFolder(in lines: [String]) -> String? {
        for line in lines where line.uppercased().hasPrefix("* LIST") {
            guard let open = line.firstIndex(of: "("), let close = line.firstIndex(of: ")"), open < close else { continue }
            let flags = line[line.index(after: open)..<close].split(separator: " ").map { $0.lowercased() }
            guard flags.contains("\\all") else { continue }
            // After the flags: the divider ("/") and then the name.
            let rest = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
            guard let space = rest.firstIndex(of: " ") else { continue }
            var name = rest[rest.index(after: space)...].trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 {
                name = String(name.dropFirst().dropLast())
                    .replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
            }
            if !name.isEmpty { return name }
        }
        return nil
    }
}

/// One conversation with Gmail: sign in, do one thing, sign out.
public final class GmailSession {
    private let transport: IMAPLineTransport
    private var counter = 0

    public init(transport: IMAPLineTransport) {
        self.transport = transport
    }

    /// Sends one command and reads up to the server's final word on it.
    /// Returns the lines in between; throws when the server says NO or BAD.
    @discardableResult
    func command(_ text: String) async throws -> [String] {
        counter += 1
        let tag = "a\(counter)"
        try await transport.send("\(tag) \(text)")
        var lines: [String] = []
        while true {
            let line = try await transport.readLine()
            if line.hasPrefix(tag + " ") {
                let rest = line.dropFirst(tag.count + 1)
                if rest.uppercased().hasPrefix("OK") { return lines }
                throw GmailProblem.refused(String(rest))
            }
            lines.append(line)
        }
    }

    /// Reads the server's greeting and signs in. The app password may be pasted with its spaces.
    public func signIn(address: String, password: String) async throws {
        _ = try await transport.readLine()
        let secret = password.replacingOccurrences(of: " ", with: "")
        do {
            try await command("LOGIN \(GmailIMAP.quoted(address.trimmingCharacters(in: .whitespaces))) \(GmailIMAP.quoted(secret))")
        } catch GmailProblem.refused {
            throw GmailProblem.wrongPassword
        }
    }

    /// Only looks: opens the inbox, changes nothing. Used by "Connect".
    public func lookAtInbox() async throws {
        try await command("EXAMINE INBOX")
    }

    /// Archives the email with this Message-ID: it leaves the inbox and stays in "All Mail".
    public func archive(messageID: String) async throws {
        guard let needle = GmailIMAP.needle(messageID: messageID) else { throw GmailProblem.notFound }
        let search = "UID SEARCH HEADER Message-ID \(GmailIMAP.quoted(needle))"
        try await command("SELECT INBOX")
        let uids = GmailIMAP.searchUIDs(in: try await command(search))
        guard !uids.isEmpty else { throw GmailProblem.notFound }
        guard uids.count <= GmailIMAP.mostMatches else { throw GmailProblem.tooMany }
        let set = uids.joined(separator: ",")
        try await command("UID STORE \(set) +FLAGS.SILENT (\\Deleted)")
        // Gmail usually takes the email out of the inbox at once; then this has nothing left to do.
        _ = try? await command("UID EXPUNGE \(set)")
        let left = GmailIMAP.searchUIDs(in: try await command(search))
        guard left.isEmpty else { throw GmailProblem.notArchived }
    }

    /// Undo: finds the email in "All Mail" and puts it back in the inbox.
    public func putBack(messageID: String) async throws {
        guard let needle = GmailIMAP.needle(messageID: messageID) else { throw GmailProblem.notFound }
        var folder = GmailIMAP.allMailFolder(in: try await command("LIST \"\" \"[Gmail]/%\""))
        if folder == nil {
            folder = GmailIMAP.allMailFolder(in: try await command("LIST \"\" \"[Google Mail]/%\""))
        }
        guard let folder else { throw GmailProblem.noAllMail }
        try await command("SELECT \(GmailIMAP.quoted(folder))")
        let uids = GmailIMAP.searchUIDs(in: try await command("UID SEARCH HEADER Message-ID \(GmailIMAP.quoted(needle))"))
        guard !uids.isEmpty else { throw GmailProblem.notFound }
        guard uids.count <= GmailIMAP.mostMatches else { throw GmailProblem.tooMany }
        try await command("UID COPY \(uids.joined(separator: ",")) INBOX")
    }

    /// A polite goodbye; it does not matter if the server has already gone.
    public func signOut() async {
        _ = try? await command("LOGOUT")
    }
}
