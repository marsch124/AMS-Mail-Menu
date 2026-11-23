import Foundation

/// One email as read from Apple Mail.
public struct MailMessage: Identifiable, Equatable, Hashable {
    /// Stable key inside this app: account + mailbox + Mail's numeric id.
    public var id: String { "\(accountName)|\(mailboxName)|\(mailID)" }

    /// Mail's own numeric message id (used to find the message again for actions).
    public let mailID: Int
    /// The RFC 822 Message-ID header, without angle brackets (used for message:// links).
    public let messageID: String
    public let accountName: String
    public let mailboxName: String
    public let sender: Sender
    public let subject: String
    public let dateReceived: Date
    public var isRead: Bool
    /// First line of the text, only filled when that setting is on.
    public var preview: String?
}

/// A sender as shown by Mail, e.g. `Anna Example <anna@example.com>`.
public struct Sender: Equatable, Hashable {
    public let name: String
    public let address: String

    /// What to show in the list: the name if there is one, else the address.
    public var displayName: String { name.isEmpty ? address : name }

    /// Key used to group emails: the lower-cased address, or the name if no address.
    public var groupKey: String {
        let a = address.lowercased()
        return a.isEmpty ? name.lowercased() : a
    }

    /// Parses Mail's sender text. Handles `Name <addr>`, `"Name" <addr>`, `<addr>` and `addr`.
    public static func parse(_ raw: String) -> Sender {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = text.lastIndex(of: "<"),
           let close = text.lastIndex(of: ">"),
           open < close {
            let address = String(text[text.index(after: open)..<close])
                .trimmingCharacters(in: .whitespaces)
            var name = String(text[..<open]).trimmingCharacters(in: .whitespaces)
            if name.count >= 2, name.hasPrefix("\""), name.hasSuffix("\"") {
                name = String(name.dropFirst().dropLast())
            }
            return Sender(name: name, address: address)
        }
        if text.contains("@") {
            return Sender(name: "", address: text)
        }
        return Sender(name: text, address: "")
    }
}
