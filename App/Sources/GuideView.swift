import SwiftUI

struct GuideSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

/// "How it works": a plain-words guide to the whole app. A blank line in a body starts a new paragraph.
enum Guide {
    static let howItWorks: [GuideSection] = [
        GuideSection(title: "What this app is for", body: "AMS Mail Menu shows your newest emails from Apple Mail without opening a mail app. You can read them, and deal with them in a few clicks or keys. It lives in the menu bar at the top of the screen and has no Dock icon. Its app icon, a white envelope on blue, shows in the Applications folder.\n\nIt reads Apple Mail on your Mac. It uses no passwords, and nothing leaves your Mac."),

        GuideSection(title: "The first time", body: "The Mac asks once if AMS Mail Menu may control Mail. Say yes. Without it the app cannot read your emails.\n\nThe app never starts Mail by itself. If Mail is closed, the list says so and offers \"Open Mail (hidden)\". If you said no by mistake, the list offers \"Open System Settings\", where you switch Mail on under Automation."),

        GuideSection(title: "The menu bar icon", body: "The icon is an envelope. It sits just left of the Deck Mate icon, among your own app icons. If you cannot see it, your menu bar is full: hold the Command key and drag another icon away to make room.\n\nOutline envelope: no new mail.\n\nBlue envelope: new mail waits. In Settings you can choose instead the envelope with the number of new emails, or the envelope with a dot.\n\nWarning triangle: something is wrong, for example Mail is closed. Click the icon to read what.\n\nNext to the icon you can see the time of the newest new email. You can switch this off in Settings."),

        GuideSection(title: "The list", body: "Click the icon and a list drops down. It shows your newest emails from the inboxes of all your accounts in Apple Mail. The number is set in Settings.\n\nThe emails are grouped by sender. The sender with the newest email is on top. Inside a sender, the newest email is on top.\n\nA sender with new mail is open. A sender without new mail is closed. Click the sender's name to open or close it. What you open or close by hand stays as you left it.\n\nEach line shows the subject and the time. New emails have a subject in full-strength letters. Read emails have a grey one. Nothing in the list is bold. Today you see the time of day, before that the day and the month.\n\nIn Settings you can add the first line of the text under each subject, and a small coloured dot for the account.\n\n\"Mark all read\" in a sender's bar marks all of that sender's emails as read.\n\nThe list checks for new mail by itself, every minute unless you chose another time in Settings. It also checks after every action. The round arrow at the bottom checks at once. \"Checked\" at the bottom left tells you when it last did. While the app reads, it says \"Reading Mail…\" there instead; you can go on using the list meanwhile. Right after Mail starts, the first reading can take a minute."),

        GuideSection(title: "Dealing with one email", body: "Move the mouse over an email line. Four small buttons appear in place of the time: mark as read (only for new mail), reply, archive and delete (red).\n\nRight-click an email for the same actions, and also to open it in the small window, in Apple Mail or in Spark.\n\nArchive moves the email to the archive of its account. Delete moves it to the bin.\n\nAfter archive, delete or filing, a dark bar with \"Undo\" shows for 10 seconds at the bottom. Click Undo and the email goes back.\n\nIf an action does not work, a short message in plain words shows at the bottom with an orange warning triangle. The small cross closes it."),

        GuideSection(title: "Opening an email", body: "Click an email line. What happens depends on Settings:\n\nSmall window in this app (the default): the email opens in its own window, and is marked as read.\n\nApple Mail, at that email: Apple Mail opens at exactly this email.\n\nSpark: Spark comes to the front. Spark cannot be told which email to show, so you have to find it there yourself."),

        GuideSection(title: "The message window", body: "The small window shows the subject, who wrote, which account, when it arrived, and the text.\n\nAt the bottom: Reply (opens Mail's reply window), Archive, Delete, Open in Apple Mail and Spark. Archive and Delete also close the window.\n\n\"Keep on top\" at the top right keeps the window above your other windows. It is on at first.\n\nEscape closes the window."),

        GuideSection(title: "Triage", body: "Triage goes through your emails one at a time, newest first. Open it with the \"Triage\" button at the top right of the list.\n\nYou see one email. You decide with one key. No modifier key is needed. The buttons at the bottom show the same keys.\n\nD: delete.\n\nA: archive.\n\nF: file in a Mail folder. A small window lists the folders of that account, the ones you used lately first. Type to find a folder. Enter takes the first one shown.\n\nP: send to PARAGON. A small window asks for the task words, the tags, and where the task goes: Inbox, Today, or a project or note. The task gets a link back to the email. Then the email is archived.\n\nM: mark as read, and go on.\n\nR: reply.\n\nSpace or the right arrow: next email, without doing anything. The left arrow goes back.\n\nZ: undo the last delete, archive or filing.\n\nEscape: close Triage.\n\nAt the top you see where you are, for example \"3 of 20\". \"Unread only\" shows only new emails. \"Start over\" begins again from the newest. When all emails are done, you see \"All done\" and a Close button."),

        GuideSection(title: "Settings", body: "Open Settings with the gear at the bottom of the list. It has three tabs: Settings, How it works, and What's new. The Settings tab has these parts:\n\nList: how many emails to show (5 to 100, in steps of 5), the first line of text, and the account dot.\n\nMenu bar icon: what the icon does while new mail waits, and the time next to it.\n\nClicking an email opens it in: small window, Apple Mail or Spark.\n\nChecking for new mail: every 30 seconds, 1, 2 or 5 minutes.\n\nStart: \"Open at login\".\n\nThe version number shows at the bottom of the Settings tab."),

        GuideSection(title: "Open at login", body: "While \"Open at login\" is on, the app opens by itself every time you log in to your Mac.\n\nIt also keeps a second start order with the Mac, called the keeper. The keeper opens the app again within about 10 seconds if it ever stops unexpectedly. If you quit the app yourself with the power button, it stays closed until you open it or until the next login.\n\nIf you open the app by hand while \"Open at login\" is on, it hands itself over to the keeper. It closes and comes back about a second later. The icon may blink once.\n\nIn System Settings, General, Login Items & Extensions, AMS Mail Menu shows in two places. Leave both on."),

        GuideSection(title: "Quit", body: "Click the power button at the bottom right of the list."),

        GuideSection(title: "Signs in this app", body: "Each mark or colour means one thing everywhere in the app."),
    ]

    /// Every mark and colour that means something: the sign and its meaning.
    static let signs: [(sign: String, meaning: String)] = [
        ("Outline envelope in the menu bar", "No new mail."),
        ("Blue envelope in the menu bar", "New mail waits."),
        ("Envelope with a number", "New mail waits; the number is how many (a choice in Settings)."),
        ("Envelope with a dot", "New mail waits (a choice in Settings)."),
        ("Warning triangle in the menu bar", "Something is wrong, for example Mail is closed. Click the icon to read what."),
        ("Time next to the icon", "When the newest new email arrived."),
        ("Subject in full-strength letters", "A new email, not yet read."),
        ("Subject in grey letters", "An email you have read."),
        ("Blue dot", "The email is in an iCloud account."),
        ("Orange dot", "The email is in a Gmail account."),
        ("Grey dot", "The email is in another account."),
        ("Arrow pointing down, before a sender", "The sender is open; its emails show."),
        ("Arrow pointing right, before a sender", "The sender is closed; its emails are hidden."),
        ("Blue tag \"3 new\"", "How many new emails this sender has."),
        ("Grey text \"4 read\"", "This sender has no new mail; the number is how many emails it has in the list."),
        ("Tick on an email line", "Mark as read."),
        ("Arrow turning left on an email line", "Reply."),
        ("Box on an email line", "Archive."),
        ("Red bin", "Delete. Red always means delete."),
        ("Dark bar with a blue \"Undo\"", "The last delete, archive or filing can be taken back for 10 seconds."),
        ("Orange warning triangle at the bottom", "An action did not work; the words say why."),
        ("Cross next to a message", "Closes the message."),
        ("Round arrow at the bottom", "Check for new mail now."),
        ("Gear at the bottom", "Settings."),
        ("Power button at the bottom", "Quit the app."),
        ("Tray with an arrow, \"Triage\"", "Opens Triage, to go through the emails one by one."),
        ("Letter in a small box on a button (D, A, F, P, M, R, Z)", "The key that does the same as the button."),
        ("\"3 of 20\" in Triage", "Where you are among the emails in this round."),
        ("Tick in a circle, \"Already handled\"", "You already dealt with this email in this round of Triage."),
        ("Large green tick in a circle", "Triage is finished; no emails left."),
        ("Round badge with letters in the message window", "The first letters of the sender's name."),
        ("Blue button \"Reply\"", "The main button of the message window."),
    ]
}

/// The guide as a page for a settings screen.
struct GuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Guide.howItWorks) { section in
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title).font(.headline).foregroundStyle(Color.mailBlue)
                    ForEach(Array(section.body.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    if section.title == "Signs in this app" {
                        ForEach(Array(Guide.signs.enumerated()), id: \.offset) { _, row in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(row.sign).font(.callout.weight(.semibold))
                                    .frame(width: 170, alignment: .leading)
                                Text(row.meaning).font(.callout)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("guidePage")
    }
}
