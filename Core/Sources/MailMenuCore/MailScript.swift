import Foundation

/// Builds the AppleScript texts sent to Apple Mail, and reads Mail's answers.
public enum MailScript {

    // MARK: - Script texts

    /// Reads the newest `perMailbox` emails of every account's Inbox.
    /// Each property is fetched for the whole range in one go (much faster than one by one).
    /// If new mail arrives while reading, the ids change and the read is repeated (max 3 times).
    public static func fetchInboxes(perMailbox: Int, includePreview: Bool) -> String {
        """
        on readBox(mb, wantPreview, limit)
            tell application "Mail"
                with timeout of 30 seconds
                    set acctName to ""
                    try
                        set acctName to name of account of mb
                    end try
                    set mbName to name of mb
                    -- First the quick way: whole columns at once. Mail refuses this ("Invalid index")
                    -- while it is still loading a mailbox, or when the mailbox changes meanwhile.
                    repeat 2 times
                        try
                            set n to count of messages of mb
                            set k to limit
                            if n < k then set k to n
                            if k = 0 then return {acctName, mbName, {}, {}, {}, {}, {}, {}, {}}
                            set theIDs to id of messages 1 thru k of mb
                            set theMIDs to message id of messages 1 thru k of mb
                            set theSenders to sender of messages 1 thru k of mb
                            set theSubjects to subject of messages 1 thru k of mb
                            set theDates to date received of messages 1 thru k of mb
                            set theReads to read status of messages 1 thru k of mb
                            set thePreviews to {}
                            if wantPreview then
                                repeat with i from 1 to k
                                    set c to ""
                                    try
                                        set c to content of message i of mb
                                        if (length of c) > 400 then set c to text 1 thru 400 of c
                                    end try
                                    set end of thePreviews to c
                                end repeat
                            end if
                            set checkIDs to id of messages 1 thru k of mb
                            if checkIDs = theIDs then
                                return {acctName, mbName, theIDs, theMIDs, theSenders, theSubjects, theDates, theReads, thePreviews}
                            end if
                        on error errMsg number errNum
                            if errNum is -1712 or errNum is -1743 or errNum is -1744 or errNum is -600 or errNum is -609 then error errMsg number errNum
                        end try
                    end repeat
                    -- The slow, sure way: one email at a time, as far as Mail gives them.
                    set theIDs to {}
                    set theMIDs to {}
                    set theSenders to {}
                    set theSubjects to {}
                    set theDates to {}
                    set theReads to {}
                    set thePreviews to {}
                    repeat with i from 1 to limit
                        try
                            set m to message i of mb
                            set a to id of m
                            set b to message id of m
                            set c to sender of m
                            set d to subject of m
                            set e to date received of m
                            set f to read status of m
                            set p to ""
                            if wantPreview then
                                try
                                    set p to content of m
                                    if (length of p) > 400 then set p to text 1 thru 400 of p
                                end try
                            end if
                            set end of theIDs to a
                            set end of theMIDs to b
                            set end of theSenders to c
                            set end of theSubjects to d
                            set end of theDates to e
                            set end of theReads to f
                            if wantPreview then set end of thePreviews to p
                        on error errMsg number errNum
                            if errNum is -1712 or errNum is -1743 or errNum is -1744 or errNum is -600 or errNum is -609 then error errMsg number errNum
                            exit repeat
                        end try
                    end repeat
                    return {acctName, mbName, theIDs, theMIDs, theSenders, theSubjects, theDates, theReads, thePreviews}
                end timeout
            end tell
        end readBox

        tell application "Mail"
            set out to {}
            set boxes to {}
            try
                set boxes to mailboxes of inbox
            end try
            if (count of boxes) = 0 then
                repeat with acct in accounts
                    if enabled of acct then
                        try
                            set end of boxes to mailbox "INBOX" of acct
                        end try
                    end if
                end repeat
            end if
            repeat with mb in boxes
                set end of out to my readBox(mb, \(includePreview ? "true" : "false"), \(max(1, perMailbox)))
            end repeat
            return out
        end tell
        """
    }

    /// Reads the full text of one email (for the small window inside the app).
    public static func fetchContent(of message: MailMessage) -> String {
        """
        tell application "Mail"
            \(findMessage(message))
            return content of m
        end tell
        """
    }

    // MARK: - Actions

    /// Mailbox names tried, in order, when archiving. Checked on the Mac at run time;
    /// iCloud normally has "Archive", Gmail in Apple Mail normally shows "All Mail".
    public static let archiveMailboxNames = ["Archive", "Archives", "All Mail", "[Gmail]/All Mail", "Archiv", "Alle Nachrichten"]
    /// The names Apple Mail shows for Gmail's "All Mail". An account whose archive mailbox has one of these
    /// names is a Gmail account: a move there changes nothing, so its emails are archived at Gmail itself.
    public static let gmailAllMailNames = ["All Mail", "[Gmail]/All Mail", "Alle Nachrichten"]
    /// Mailbox names tried, in order, when undoing a delete.
    public static let trashMailboxNames = ["Trash", "Deleted Messages", "Bin", "[Gmail]/Trash", "[Gmail]/Bin", "Papierkorb", "Gelöschte Objekte"]

    /// Marks several emails as read (or unread) in one go.
    public static func setRead(_ messages: [MailMessage], read: Bool) -> String {
        let lines = messages.map { m in
            """
                try
                    \(findMessage(m))
                    set read status of m to \(read ? "true" : "false")
                end try
            """
        }.joined(separator: "\n")
        return "tell application \"Mail\"\n\(lines)\nend tell"
    }

    /// Moves an email to the account's Trash (as Mail's own Delete does).
    public static func delete(_ message: MailMessage) -> String {
        """
        tell application "Mail"
            \(findMessage(message))
            delete m
        end tell
        """
    }

    /// Moves an email to the first archive mailbox that exists in its account.
    /// Returns the name of that mailbox, or fails with error 9002 if none exists.
    public static func archive(_ message: MailMessage) -> String {
        """
        \(findBoxHandler)
        tell application "Mail"
            \(findMessage(message))
            set destBox to my findBox(account "\(escape(message.accountName))", \(appleScriptList(archiveMailboxNames)))
            if destBox is missing value then error "No archive mailbox found in the account “\(escape(message.accountName))”." number 9002
            -- Gmail keeps every email in "All Mail" already, so moving it there changes nothing and the email
            -- stays in the inbox; a move to any other Gmail folder never reaches Gmail either (both seen
            -- 23 Nov 2026). A Gmail email is archived straight at Gmail instead (`GmailSession.archive`);
            -- this script is only reached when that connection is not set up.
            if (name of destBox) is in \(appleScriptList(gmailAllMailNames)) then error "\(escape(GmailProblem.notSetUp.words))" number 9005
            move m to destBox
            return name of destBox
        end tell
        """
    }

    /// Undo: finds the email again by its Message-ID in the given mailboxes and moves it back.
    public static func moveBack(_ message: MailMessage, fromAnyOf names: [String]) -> String {
        """
        \(resolveBoxHandler)
        tell application "Mail"
            set acct to account "\(escape(message.accountName))"
            repeat with n in \(appleScriptList(names))
                try
                    set src to my resolveBox(acct, (n as text))
                    set found to (messages of src whose message id is "\(escape(message.messageID))")
                    if (count of found) > 0 then
                        move (item 1 of found) to mailbox "\(escape(message.mailboxName))" of acct
                        return true
                    end if
                end try
            end repeat
            error "The email could not be found to move it back." number 9003
        end tell
        """
    }

    /// Opens a reply in Apple Mail and brings Mail forward.
    public static func reply(_ message: MailMessage) -> String {
        """
        tell application "Mail"
            \(findMessage(message))
            set r to reply m with opening window
            activate
        end tell
        """
    }

    /// Lists every mailbox of an account as a path, e.g. "Bills" or "Travel/2026".
    public static func listMailboxes(account: String) -> String {
        """
        on collect(boxes, prefix)
            set out to {}
            tell application "Mail"
                repeat with b in boxes
                    set p to name of b
                    if prefix is not "" then set p to prefix & "/" & p
                    set end of out to p
                    try
                        set kids to mailboxes of b
                        if (count of kids) > 0 then set out to out & my collect(kids, p)
                    end try
                end repeat
            end tell
            return out
        end collect

        tell application "Mail"
            return my collect(mailboxes of account "\(escape(account))", "")
        end tell
        """
    }

    /// Moves an email to a mailbox of its account, given as a path ("Travel/2026").
    public static func move(_ message: MailMessage, toMailboxPath path: String) -> String {
        """
        \(resolveBoxHandler)
        tell application "Mail"
            \(findMessage(message))
            set destBox to my resolveBox(account "\(escape(message.accountName))", "\(escape(path))")
            move m to destBox
            return name of destBox
        end tell
        """
    }

    /// AppleScript handler: the mailbox at a path like "Travel/2026" (tries the whole name first,
    /// then walks the folders one by one).
    public static let resolveBoxHandler = """
        on resolveBox(acct, thePath)
            tell application "Mail"
                try
                    set b to mailbox thePath of acct
                    get name of b
                    return b
                end try
                -- A Gmail account in Apple Mail (seen 23 Nov 2026): `mailbox "X" of acct` fails with -1728
                -- although the folder is there; asking by `whose name is` finds it, also for a whole path.
                try
                    set b to first mailbox of acct whose name is thePath
                    get name of b
                    return b
                end try
                set AppleScript's text item delimiters to "/"
                set parts to text items of thePath
                set AppleScript's text item delimiters to ""
                set b to mailbox (item 1 of parts) of acct
                repeat with i from 2 to count of parts
                    set b to mailbox (item i of parts) of b
                end repeat
                return b
            end tell
        end resolveBox
        """

    /// AppleScript handler: first mailbox of `acct` whose name is in `names`, or missing value.
    public static let findBoxHandler = """
        on findBox(acct, names)
            tell application "Mail"
                repeat with n in names
                    try
                        set b to mailbox (n as text) of acct
                        get name of b
                        return b
                    end try
                    -- Gmail folders are only found this way (see resolveBox).
                    try
                        set b to first mailbox of acct whose name is (n as text)
                        get name of b
                        return b
                    end try
                end repeat
            end tell
            return missing value
        end findBox
        """

    public static func appleScriptList(_ items: [String]) -> String {
        "{" + items.map { "\"\(escape($0))\"" }.joined(separator: ", ") + "}"
    }

    /// AppleScript lines that set `m` to the given message.
    public static func findMessage(_ message: MailMessage) -> String {
        let box = "mailbox \"\(escape(message.mailboxName))\" of account \"\(escape(message.accountName))\""
        return "set m to first message of \(box) whose id is \(message.mailID)"
    }

    /// Makes text safe to put inside an AppleScript string in double quotes.
    public static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Reading Mail's answer

    /// Turns Mail's answer to `fetchInboxes` into messages.
    public static func parseInboxes(_ result: NSAppleEventDescriptor) -> [MailMessage] {
        var messages: [MailMessage] = []
        for box in items(of: result) {
            let parts = items(of: box)
            guard parts.count >= 8 else { continue }
            let account = parts[0].stringValue ?? ""
            let mailbox = parts[1].stringValue ?? ""
            let ids = items(of: parts[2])
            let mids = items(of: parts[3])
            let senders = items(of: parts[4])
            let subjects = items(of: parts[5])
            let dates = items(of: parts[6])
            let reads = items(of: parts[7])
            let previews = parts.count > 8 ? items(of: parts[8]) : []
            let count = [ids.count, mids.count, senders.count, subjects.count, dates.count, reads.count].min() ?? 0
            for i in 0..<count {
                let preview: String? = i < previews.count
                    ? MessageLinks.firstLine(of: previews[i].stringValue ?? "")
                    : nil
                messages.append(MailMessage(
                    mailID: Int(ids[i].int32Value),
                    messageID: mids[i].stringValue ?? "",
                    accountName: account,
                    mailboxName: mailbox,
                    sender: Sender.parse(senders[i].stringValue ?? ""),
                    subject: subjects[i].stringValue ?? "",
                    dateReceived: dates[i].dateValue ?? .distantPast,
                    isRead: reads[i].booleanValue,
                    preview: preview
                ))
            }
        }
        return messages
    }

    /// The items of an AppleScript list (1-based in AppleScript, 0-based here).
    /// A single value that is not a list is treated as a list of one.
    /// The Apple Event type code for a list ('list').
    public static let listType: UInt32 = 0x6C69_7374

    public static func items(of descriptor: NSAppleEventDescriptor) -> [NSAppleEventDescriptor] {
        guard descriptor.descriptorType == listType else { return [descriptor] }
        let n = descriptor.numberOfItems
        guard n > 0 else { return [] }
        return (1...n).compactMap { descriptor.atIndex($0) }
    }
}
