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

    /// First non-empty line of an email's text, shortened.
    public static func firstLine(of text: String, maxLength: Int = 120) -> String {
        let line = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        if line.count <= maxLength { return line }
        return String(line.prefix(maxLength - 1)) + "…"
    }
}
