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
        // A line of signs that show nothing is not a first line.
        XCTAssertEqual(MessageLinks.firstLine(of: "\u{FFFC}\u{200C}\u{00A0} \u{200C}\nReal words"), "Real words")
        XCTAssertEqual(MessageLinks.firstLine(of: "\u{200B}\u{FEFF}"), "")
    }

    func testAnEmailsTextHasNoRowsOfEmptyLines() {
        XCTAssertEqual(MessageLinks.tidyBody("\n\n\nHello\n\n\n\u{00A0}\nSecond part\nnext line\n\n"), "Hello\n\nSecond part\nnext line")
        XCTAssertEqual(MessageLinks.tidyBody("One\nTwo"), "One\nTwo")
        XCTAssertEqual(MessageLinks.tidyBody("\n \n"), "")
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

    /// 0.9: through Apple Mail a Gmail email is never moved (a move there never reaches Gmail); the script
    /// stops with plain words, and never uses the command that made Apple Mail crash on 23 Nov 2026.
    func testGmailArchiveThroughMailStopsWithPlainWords() {
        let message = MailMessage(mailID: 7, messageID: "x@example.com", accountName: "Gmail",
                                  mailboxName: "INBOX", sender: Sender.parse("a@example.com"),
                                  subject: "", dateReceived: Date(), isRead: true, preview: nil)
        let source = MailScript.archive(message)
        XCTAssertTrue(source.contains("is in {\"All Mail\", \"[Gmail]/All Mail\", \"Alle Nachrichten\"} then error \"Archiving a Gmail email needs the Gmail connection."))
        XCTAssertTrue(source.contains("number 9005"))
        XCTAssertFalse(source.contains("deleted status"))
    }

    /// A scripted mail server: gives the answers in order and keeps what the app sent.
    final class ScriptedServer: IMAPLineTransport {
        var answers: [String]
        var sent: [String] = []
        init(_ answers: [String]) { self.answers = answers }
        func send(_ line: String) async throws { sent.append(line) }
        func readLine() async throws -> String {
            guard !answers.isEmpty else { throw GmailProblem.noConnection("no more answers") }
            return answers.removeFirst()
        }
    }

    /// 0.9: archiving at Gmail takes exactly the one email out of the inbox and checks that it is gone.
    func testGmailArchiveConversation() async throws {
        let server = ScriptedServer([
            "* OK Gimap ready",
            "* CAPABILITY IMAP4rev1", "a1 OK signed in",
            "* 12 EXISTS", "a2 OK [READ-WRITE] INBOX selected",
            "* SEARCH 4711", "a3 OK SEARCH completed",
            "a4 OK STORE completed",
            "a5 OK EXPUNGE completed",
            "* SEARCH", "a6 OK SEARCH completed",
        ])
        let session = GmailSession(transport: server)
        try await session.signIn(address: "me@example.com", password: "abcd efgh ijkl mnop")
        try await session.archive(messageID: "x1y2z3@example.com")
        XCTAssertEqual(server.sent, [
            "a1 LOGIN \"me@example.com\" \"abcdefghijklmnop\"",
            "a2 SELECT INBOX",
            "a3 UID SEARCH HEADER Message-ID \"<x1y2z3@example.com>\"",
            "a4 UID STORE 4711 +FLAGS.SILENT (\\Deleted)",
            "a5 UID EXPUNGE 4711",
            "a6 UID SEARCH HEADER Message-ID \"<x1y2z3@example.com>\"",
        ])
    }

    /// 0.9: the safety rules of the Gmail connection. An empty mark would match every email in the inbox.
    func testGmailSafetyRules() async throws {
        XCTAssertNil(GmailIMAP.needle(messageID: ""))
        XCTAssertNil(GmailIMAP.needle(messageID: "  <> "))
        XCTAssertEqual(GmailIMAP.needle(messageID: "<abc123@example.com>"), "<abc123@example.com>")
        XCTAssertEqual(GmailIMAP.searchUIDs(in: ["* SEARCH 3 17", "* 5 EXISTS"]), ["3", "17"])
        XCTAssertEqual(GmailIMAP.searchUIDs(in: ["* SEARCH"]), [])
        XCTAssertEqual(GmailIMAP.allMailFolder(in: [
            "* LIST (\\HasNoChildren \\Sent) \"/\" \"[Gmail]/Sent Mail\"",
            "* LIST (\\All \\HasNoChildren) \"/\" \"[Gmail]/All Mail\"",
        ]), "[Gmail]/All Mail")

        // Nothing is sent to change an email when it is not found, when too many match, or with no mark.
        for found in ["* SEARCH", "* SEARCH 1 2 3 4"] {
            let server = ScriptedServer(["* 12 EXISTS", "a1 OK selected", found, "a2 OK done"])
            do {
                try await GmailSession(transport: server).archive(messageID: "x1y2z3@example.com")
                XCTFail("should have stopped")
            } catch {}
            XCTAssertFalse(server.sent.contains { $0.contains("STORE") || $0.contains("EXPUNGE") })
        }
        let silent = ScriptedServer([])
        do { try await GmailSession(transport: silent).archive(messageID: ""); XCTFail("should have stopped") } catch {}
        XCTAssertEqual(silent.sent, [])

        // Undo: found in "All Mail", copied back to the inbox.
        let back = ScriptedServer([
            "* LIST (\\All \\HasNoChildren) \"/\" \"[Gmail]/All Mail\"", "a1 OK listed",
            "a2 OK selected", "* SEARCH 99", "a3 OK done", "a4 OK copied",
        ])
        try await GmailSession(transport: back).putBack(messageID: "x1y2z3@example.com")
        XCTAssertEqual(back.sent.last, "a4 UID COPY 99 INBOX")
        XCTAssertEqual(back.sent[1], "a2 SELECT \"[Gmail]/All Mail\"")

        // A refused sign-in is told as a wrong address or app password.
        let refused = ScriptedServer(["* OK ready", "a1 NO [AUTHENTICATIONFAILED] Invalid credentials (Failure)"])
        do {
            try await GmailSession(transport: refused).signIn(address: "me@example.com", password: "wrong")
            XCTFail("should have been refused")
        } catch { XCTAssertEqual(error as? GmailProblem, .wrongPassword) }
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
        XCTAssertEqual(MailAccessProblem.from(errorNumber: -1712, message: ""), .mailBusy)
        XCTAssertEqual(MailAccessProblem.mailBusy.title, "Apple Mail is busy")
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

final class KeeperTests: XCTestCase {
    func testTheCopyThatStartedFirstStays() {
        let first = OneCopy.Copy(started: 100, pid: 50)
        let second = OneCopy.Copy(started: 101, pid: 40)
        let twin = OneCopy.Copy(started: 100, pid: 60)
        XCTAssertTrue(OneCopy.earlier(than: first, among: [second]).isEmpty)
        XCTAssertEqual(OneCopy.earlier(than: second, among: [first]), [first])
        XCTAssertTrue(OneCopy.earlier(than: first, among: [twin]).isEmpty)
        XCTAssertEqual(OneCopy.earlier(than: twin, among: [first]), [first])
    }

    func testTheKeepersStartOrder() {
        let order = Keeper.plist(executable: "/Applications/X.app/Contents/MacOS/X", bundleID: "com.schabbauer.AMSMailMenu")
        XCTAssertEqual(order["Label"] as? String, "com.schabbauer.AMSMailMenu.keeper")
        XCTAssertEqual(order["ProgramArguments"] as? [String], ["/Applications/X.app/Contents/MacOS/X", "--keeper"])
        XCTAssertEqual(order["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(order["KeepAlive"] as? [String: Bool], ["SuccessfulExit": false])
    }

    func testOnlyACopyOpenedByHandGivesWayToTheKeeper() {
        XCTAssertTrue(Keeper.handsOver(wanted: true, openedByKeeper: false, plain: false, inApplications: true))
        XCTAssertFalse(Keeper.handsOver(wanted: false, openedByKeeper: false, plain: false, inApplications: true))
        XCTAssertFalse(Keeper.handsOver(wanted: true, openedByKeeper: true, plain: false, inApplications: true))
        XCTAssertFalse(Keeper.handsOver(wanted: true, openedByKeeper: false, plain: true, inApplications: true))
        XCTAssertFalse(Keeper.handsOver(wanted: true, openedByKeeper: false, plain: false, inApplications: false))
    }
}

final class MenuBarTimeTests: XCTestCase {
    func testHourWithColonOverMinutesAlwaysTwoDigits() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 8, minute: 9))!
        XCTAssertTrue(MenuBarTime.lines(morning, calendar: calendar) == ("08:", "09"))
        let evening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 21, minute: 45))!
        XCTAssertTrue(MenuBarTime.lines(evening, calendar: calendar) == ("21:", "45"))
    }
}

final class HoverTextTests: XCTestCase {
    func testHoverTextIsTitleAndExplanation() {
        XCTAssertEqual(MailAccessProblem.mailNotRunning.hoverText,
                       "Apple Mail is not open\nThis app reads your emails from Apple Mail. Please open Mail (it may stay hidden).")
        XCTAssertEqual(MailAccessProblem.other("Odd answer").hoverText, "Mail could not be read\nOdd answer")
    }
}
