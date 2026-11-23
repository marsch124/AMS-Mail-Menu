import Foundation
import MailMenuCore
import Network
import Security

// The direct connection to Gmail (0.9): the real network line, the Keychain, and the three things the app
// asks of Gmail. The conversation itself and its rules are in Core (`GmailIMAP.swift`).
// The app password is read from the Keychain only at the moment it is sent to Google; it is never written
// to a file, the settings or the diary.

/// An encrypted line to Gmail's mail server.
final class GmailLine: IMAPLineTransport, @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.schabbauer.AMSMailMenu.gmail")
    private var buffer = Data()

    init() {
        connection = NWConnection(host: "imap.gmail.com", port: 993, using: .tls)
    }

    func open() async throws {
        try await withCheckedThrowingContinuation { (waiting: CheckedContinuation<Void, Error>) in
            var answered = false
            connection.stateUpdateHandler = { [connection] state in
                guard !answered else { return }
                switch state {
                case .ready:
                    answered = true
                    waiting.resume()
                case .failed(let error), .waiting(let error):
                    answered = true
                    connection.cancel()
                    waiting.resume(throwing: GmailProblem.noConnection(Self.plain(error)))
                case .cancelled:
                    answered = true
                    waiting.resume(throwing: GmailProblem.noConnection("the connection was closed"))
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ line: String) async throws {
        let data = Data((line + "\r\n").utf8)
        try await withCheckedThrowingContinuation { (waiting: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    waiting.resume(throwing: GmailProblem.noConnection(Self.plain(error)))
                } else {
                    waiting.resume()
                }
            })
        }
    }

    func readLine() async throws -> String {
        let lineEnd = Data([13, 10])
        while true {
            if let end = buffer.range(of: lineEnd) {
                let line = String(decoding: buffer[buffer.startIndex..<end.lowerBound], as: UTF8.self)
                buffer = Data(buffer[end.upperBound...])
                return line
            }
            let more: Data = try await withCheckedThrowingContinuation { waiting in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, _, error in
                    if let data, !data.isEmpty {
                        waiting.resume(returning: data)
                    } else if let error {
                        waiting.resume(throwing: GmailProblem.noConnection(Self.plain(error)))
                    } else {
                        waiting.resume(throwing: GmailProblem.noConnection("Gmail closed the connection"))
                    }
                }
            }
            buffer.append(more)
        }
    }

    func close() {
        connection.cancel()
    }

    private static func plain(_ error: NWError) -> String {
        switch error {
        case .dns: return "no internet, or Gmail's address was not found"
        case .tls: return "the encrypted line could not be set up"
        default: return "no internet, or Gmail did not answer"
        }
    }
}

/// The app password in the Mac's Keychain.
enum GmailKeychain {
    static let service = "com.schabbauer.AMSMailMenu.gmail"

    private static func query(_ address: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: address]
    }

    @discardableResult
    static func save(address: String, password: String) -> Bool {
        remove(address: address)
        var item = query(address)
        item[kSecValueData as String] = Data(password.utf8)
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func password(for address: String) -> String? {
        var item = query(address)
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var found: AnyObject?
        guard SecItemCopyMatching(item as CFDictionary, &found) == errSecSuccess, let data = found as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func remove(address: String) {
        SecItemDelete(query(address) as CFDictionary)
    }
}

enum GmailConnection {
    /// How long Gmail gets for one whole conversation.
    static let patience: UInt64 = 30

    private static var defaults: UserDefaults { .standard }

    /// True when the connection is set up and this Mail account is the one it is for.
    static func handles(accountName: String) -> Bool {
        defaults.bool(forKey: SettingsKey.gmailConnected)
            && !accountName.isEmpty
            && defaults.string(forKey: SettingsKey.gmailMailAccount) == accountName
    }

    /// "Connect": signs in and looks at the inbox, changing nothing. Keeps the app password only if Google
    /// accepts it.
    static func connect(address: String, password: String, mailAccount: String) async throws {
        try await talk(address: address, password: password) { session in
            try await session.lookAtInbox()
        }
        guard GmailKeychain.save(address: address, password: password) else {
            throw GmailProblem.refused("the Mac's Keychain did not take the app password")
        }
        defaults.set(address, forKey: SettingsKey.gmailAddress)
        defaults.set(mailAccount, forKey: SettingsKey.gmailMailAccount)
        defaults.set(true, forKey: SettingsKey.gmailConnected)
    }

    /// "Disconnect": forgets the app password and the connection.
    static func disconnect() {
        if let address = defaults.string(forKey: SettingsKey.gmailAddress) {
            GmailKeychain.remove(address: address)
        }
        defaults.set(false, forKey: SettingsKey.gmailConnected)
    }

    static func archive(messageID: String) async throws {
        try await talkWithSavedPassword { try await $0.archive(messageID: messageID) }
    }

    static func putBack(messageID: String) async throws {
        try await talkWithSavedPassword { try await $0.putBack(messageID: messageID) }
    }

    private static func talkWithSavedPassword(_ work: @escaping (GmailSession) async throws -> Void) async throws {
        guard defaults.bool(forKey: SettingsKey.gmailConnected),
              let address = defaults.string(forKey: SettingsKey.gmailAddress), !address.isEmpty,
              let password = GmailKeychain.password(for: address) else {
            throw GmailProblem.notSetUp
        }
        try await talk(address: address, password: password, work)
    }

    /// One conversation: open the line, sign in, do the work, sign out. Gives up after `patience` seconds.
    private static func talk(address: String, password: String,
                             _ work: @escaping (GmailSession) async throws -> Void) async throws {
        let line = GmailLine()
        defer { line.close() }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await line.open()
                let session = GmailSession(transport: line)
                try await session.signIn(address: address, password: password)
                try await work(session)
                await session.signOut()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: patience * 1_000_000_000)
                line.close()
                throw GmailProblem.noConnection("Gmail did not answer in \(patience) seconds")
            }
            try await group.next()
            group.cancelAll()
        }
    }

    /// Plain words for whatever went wrong.
    static func words(for error: Error) -> String {
        (error as? GmailProblem)?.words ?? "Gmail could not be reached. Nothing was changed."
    }
}
