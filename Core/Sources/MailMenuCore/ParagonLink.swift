import Foundation

/// Where a task lands in PARAGON (its `target=` in the capture link).
public enum ParagonTarget: Equatable, Hashable {
    case inbox
    case today
    /// A note path inside the vault, e.g. "Projects/Shed.md".
    case note(String)

    public var queryValue: String {
        switch self {
        case .inbox: return "inbox"
        case .today: return "today"
        case .note(let path): return path
        }
    }

    public var label: String {
        switch self {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .note(let path):
            let last = path.split(separator: "/").last.map(String.init) ?? path
            return last.hasSuffix(".md") ? String(last.dropLast(3)) : last
        }
    }
}

/// Builds PARAGON's capture link: amspara://capture?text=…&target=…
/// PARAGON reads #tags from the text. Its `url=` parameter only keeps http, https and mailto links,
/// so the link back to the email (message://…) is written into the text as a markdown link instead.
public enum ParagonLink {
    public static func normalizedTags(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" })
            .map { word -> String in
                let w = word.trimmingCharacters(in: .whitespaces)
                let bare = w.hasPrefix("#") ? String(w.drop(while: { $0 == "#" })) : w
                return bare.isEmpty ? "" : "#" + bare
            }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    /// The task text: the words, the tags, then a link back to the email.
    public static func taskText(words: String, tags: String, mailLink: URL?) -> String {
        var parts = [words.trimmingCharacters(in: .whitespacesAndNewlines)]
        parts.append(contentsOf: normalizedTags(tags))
        if let mailLink { parts.append("[Mail](\(mailLink.absoluteString))") }
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    public static func captureURL(words: String, tags: String, target: ParagonTarget, mailLink: URL?) -> URL? {
        var components = URLComponents()
        components.scheme = "amspara"
        components.host = "capture"
        components.queryItems = [
            URLQueryItem(name: "text", value: taskText(words: words, tags: tags, mailLink: mailLink)),
            URLQueryItem(name: "target", value: target.queryValue),
        ]
        return components.url
    }

    /// Suggested task words for an email.
    public static func suggestedWords(for message: MailMessage) -> String {
        let subject = message.subject.isEmpty ? "(no subject)" : message.subject
        return "\(subject) – \(message.sender.displayName)"
    }
}
