import XCTest
@testable import MailMenuCore

// All addresses and names here are invented examples.

final class SenderTests: XCTestCase {
    func testNameAndAddress() {
        let s = Sender.parse("Anna Example <anna@example.com>")
        XCTAssertEqual(s.name, "Anna Example")
        XCTAssertEqual(s.address, "anna@example.com")
        XCTAssertEqual(s.displayName, "Anna Example")
    }

    func testQuotedName() {
        let s = Sender.parse("\"Example, Ben\" <ben@example.org>")
        XCTAssertEqual(s.name, "Example, Ben")
        XCTAssertEqual(s.address, "ben@example.org")
    }

    func testAddressOnly() {
        let s = Sender.parse("news@example.net")
        XCTAssertEqual(s.name, "")
        XCTAssertEqual(s.address, "news@example.net")
        XCTAssertEqual(s.displayName, "news@example.net")
        XCTAssertEqual(Sender.parse("<news@example.net>").address, "news@example.net")
    }

    func testGroupKeyIgnoresCase() {
        XCTAssertEqual(Sender.parse("A <Anna@Example.com>").groupKey,
                       Sender.parse("Anna <anna@example.com>").groupKey)
    }
}

final class GroupingTests: XCTestCase {
    private func msg(_ id: Int, _ sender: String, minutesAgo: Double) -> MailMessage {
        MailMessage(mailID: id, messageID: "m\(id)@example.com", accountName: "iCloud",
                    mailboxName: "INBOX", sender: Sender.parse(sender), subject: "Subject \(id)",
                    dateReceived: Date(timeIntervalSince1970: 1_000_000 - minutesAgo * 60),
                    isRead: false, preview: nil)
    }

    func testNewestSenderFirstAndNewestMessageFirst() {
        let messages = [
            msg(1, "Anna <anna@example.com>", minutesAgo: 50),
            msg(2, "Ben <ben@example.com>", minutesAgo: 10),
            msg(3, "Anna <anna@example.com>", minutesAgo: 5),
            msg(4, "Cara <cara@example.com>", minutesAgo: 30),
        ]
        let groups = SenderGrouping.group(messages, limit: 10)
        XCTAssertEqual(groups.map(\.key), ["anna@example.com", "ben@example.com", "cara@example.com"])
        XCTAssertEqual(groups[0].messages.map(\.mailID), [3, 1])
    }

    func testLimitKeepsOnlyNewest() {
        let messages = (1...10).map { msg($0, "S\($0) <s\($0)@example.com>", minutesAgo: Double($0)) }
        let groups = SenderGrouping.group(messages, limit: 3)
        XCTAssertEqual(groups.flatMap(\.messages).map(\.mailID), [1, 2, 3])
    }

    func testUnreadCount() {
        var m = msg(1, "A <a@example.com>", minutesAgo: 1)
        m.isRead = true
        let groups = SenderGrouping.group([m, msg(2, "A <a@example.com>", minutesAgo: 2)], limit: 5)
        XCTAssertEqual(groups[0].unreadCount, 1)
    }
}

final class LinkTests: XCTestCase {
    func testAppleMailURL() {
        let url = MessageLinks.appleMailURL(messageID: "abc.123@mail.example.com")
        XCTAssertEqual(url?.absoluteString, "message://%3Cabc.123@mail.example.com%3E")
    }

    func testAppleMailURLStripsBracketsAndEncodes() {
        let url = MessageLinks.appleMailURL(messageID: "<a b/c%d@example.com>")
        XCTAssertEqual(url?.absoluteString, "message://%3Ca%20b%2Fc%25d@example.com%3E")
        XCTAssertNil(MessageLinks.appleMailURL(messageID: "  "))
    }

    func testFirstLine() {
        XCTAssertEqual(MessageLinks.firstLine(of: "\n\n  Hello there  \nSecond"), "Hello there")
        XCTAssertEqual(MessageLinks.firstLine(of: String(repeating: "x", count: 200), maxLength: 10).count, 10)
    }
}

final class ScriptTests: XCTestCase {
    func testEscape() {
        XCTAssertEqual(MailScript.escape("A \"B\" \\C"), "A \\\"B\\\" \\\\C")
    }

    func testScriptsCompile() {
        // Compiling needs no access to Mail; it only checks the AppleScript grammar.
        let message = MailMessage(mailID: 7, messageID: "x@example.com", accountName: "Ex \"Acct\"",
                                  mailboxName: "INBOX", sender: Sender.parse("a@example.com"),
                                  subject: "", dateReceived: Date(), isRead: false, preview: nil)
        for source in [MailScript.fetchInboxes(perMailbox: 20, includePreview: true),
                       MailScript.fetchInboxes(perMailbox: 5, includePreview: false),
                       MailScript.fetchContent(of: message),
                       MailScript.setRead([message, message], read: true),
                       MailScript.delete(message),
                       MailScript.archive(message),
                       MailScript.moveBack(message, fromAnyOf: MailScript.trashMailboxNames),
                       MailScript.reply(message),
                       MailScript.listMailboxes(account: "iCloud"),
                       MailScript.move(message, toMailboxPath: "Travel/2026")] {
            var error: NSDictionary?
            let script = NSAppleScript(source: source)
            XCTAssertNotNil(script)
            XCTAssertTrue(script?.compileAndReturnError(&error) ?? false, "\(String(describing: error))\n\(source)")
        }
    }

    func testParseInboxes() {
        func list(_ items: [NSAppleEventDescriptor]) -> NSAppleEventDescriptor {
            let l = NSAppleEventDescriptor.list()
            for (i, item) in items.enumerated() { l.insert(item, at: i + 1) }
            return l
        }
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let box = list([
            NSAppleEventDescriptor(string: "iCloud"),
            NSAppleEventDescriptor(string: "INBOX"),
            list([NSAppleEventDescriptor(int32: 11), NSAppleEventDescriptor(int32: 12)]),
            list([NSAppleEventDescriptor(string: "one@example.com"), NSAppleEventDescriptor(string: "two@example.com")]),
            list([NSAppleEventDescriptor(string: "Anna <anna@example.com>"), NSAppleEventDescriptor(string: "ben@example.com")]),
            list([NSAppleEventDescriptor(string: "Hello"), NSAppleEventDescriptor(string: "Invoice")]),
            list([NSAppleEventDescriptor(date: date), NSAppleEventDescriptor(date: date.addingTimeInterval(-60))]),
            list([NSAppleEventDescriptor(boolean: true), NSAppleEventDescriptor(boolean: false)]),
            list([]),
        ])
        let messages = MailScript.parseInboxes(list([box]))
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].mailID, 11)
        XCTAssertEqual(messages[0].sender.name, "Anna")
        XCTAssertEqual(messages[0].subject, "Hello")
        XCTAssertEqual(messages[0].dateReceived.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1)
        XCTAssertTrue(messages[0].isRead)
        XCTAssertFalse(messages[1].isRead)
        XCTAssertNil(messages[0].preview)
        XCTAssertEqual(messages[1].accountName, "iCloud")
    }

    func testProblemMapping() {
        XCTAssertEqual(MailAccessProblem.from(errorNumber: -1743, message: ""), .permissionDenied)
        XCTAssertEqual(MailAccessProblem.from(errorNumber: -1744, message: ""), .permissionNotYetAsked)
        XCTAssertEqual(MailAccessProblem.from(errorNumber: -600, message: ""), .mailNotRunning)
    }
}

final class AccountKindTests: XCTestCase {
    func testKinds() {
        XCTAssertEqual(AccountKind.from(accountName: "iCloud"), .iCloud)
        XCTAssertEqual(AccountKind.from(accountName: "Google"), .gmail)
        XCTAssertEqual(AccountKind.from(accountName: "My Gmail"), .gmail)
        XCTAssertEqual(AccountKind.from(accountName: "Work"), .other)
    }
}

final class ScriptListTests: XCTestCase {
    func testAppleScriptList() {
        XCTAssertEqual(MailScript.appleScriptList(["A", "B \"x\""]), "{\"A\", \"B \\\"x\\\"\"}")
    }
}

final class ParagonLinkTests: XCTestCase {
    func testTags() {
        XCTAssertEqual(ParagonLink.normalizedTags("family, #trip  ##trip bills"), ["#family", "#trip", "#bills"])
        XCTAssertEqual(ParagonLink.normalizedTags("  "), [])
    }

    func testCaptureURLRoundTrip() throws {
        let mail = MessageLinks.appleMailURL(messageID: "abc.1@example.com")
        let url = try XCTUnwrap(ParagonLink.captureURL(words: "Dinner on Saturday? – Anna & Ben",
                                                       tags: "family #plans",
                                                       target: .note("Projects/Summer cabin.md"),
                                                       mailLink: mail))
        XCTAssertEqual(url.scheme, "amspara")
        XCTAssertEqual(url.host, "capture")
        // Read it back the way PARAGON does (URLComponents.queryItems).
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let text = items.first { $0.name == "text" }?.value
        XCTAssertEqual(text, "Dinner on Saturday? – Anna & Ben #family #plans [Mail](message://%3Cabc.1@example.com%3E)")
        XCTAssertEqual(items.first { $0.name == "target" }?.value, "Projects/Summer cabin.md")
    }

    func testTargets() {
        XCTAssertEqual(ParagonTarget.inbox.queryValue, "inbox")
        XCTAssertEqual(ParagonTarget.today.queryValue, "today")
        XCTAssertEqual(ParagonTarget.note("Projects/Shed.md").label, "Shed")
    }
}
