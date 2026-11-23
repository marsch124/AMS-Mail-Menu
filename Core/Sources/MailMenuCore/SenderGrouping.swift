import Foundation

/// All shown emails from one sender.
public struct SenderGroup: Identifiable, Equatable {
    public var id: String { key }
    public let key: String
    public let sender: Sender
    /// Newest first.
    public let messages: [MailMessage]

    public var newestDate: Date { messages.first?.dateReceived ?? .distantPast }
    public var unreadCount: Int { messages.filter { !$0.isRead }.count }
}

public enum SenderGrouping {
    /// Takes the newest `limit` emails and groups them by sender.
    /// Groups are ordered by their newest email (newest sender first);
    /// emails inside a group are newest first.
    public static func group(_ messages: [MailMessage], limit: Int) -> [SenderGroup] {
        let newest = Array(
            messages
                .sorted { $0.dateReceived > $1.dateReceived }
                .prefix(max(0, limit))
        )
        var order: [String] = []
        var buckets: [String: [MailMessage]] = [:]
        for message in newest {
            let key = message.sender.groupKey
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(message)
        }
        return order.map { key in
            let list = buckets[key] ?? []
            return SenderGroup(key: key, sender: list[0].sender, messages: list)
        }
    }
}
