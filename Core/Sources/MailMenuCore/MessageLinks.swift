import Foundation

public enum MessageLinks {
    /// A `message://` link that makes Apple Mail open this exact email.
    /// Format: message://%3C<Message-ID>%3E (the angle brackets are encoded).
    public static func appleMailURL(messageID: String) -> URL? {
        var id = messageID.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.hasPrefix("<") { id.removeFirst() }
        if id.hasSuffix(">") { id.removeLast() }
        guard !id.isEmpty else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~@!$&'()*+,;=:")
        guard let encoded = id.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "message://%3C\(encoded)%3E")
    }

    /// Signs that take room but show nothing: many emails begin with a row of them (a picture's place,
    /// a hidden lead-in for the mail app's own list).
    static let invisible = CharacterSet.whitespaces.union(CharacterSet(charactersIn:
        "\u{00A0}\u{00AD}\u{034F}\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}\u{2007}\u{202F}\u{2060}\u{FEFF}\u{FFFC}"))

    /// First line of an email's text that has something to read, shortened.
    public static func firstLine(of text: String, maxLength: Int = 120) -> String {
        let line = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: invisible) }
            .first { !$0.isEmpty } ?? ""
        if line.count <= maxLength { return line }
        return String(line.prefix(maxLength - 1)) + "…"
    }
}
