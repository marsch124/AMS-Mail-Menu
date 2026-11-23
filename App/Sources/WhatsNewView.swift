import SwiftUI

/// The version of the running app, read from the bundle.
enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
    /// For example "Version 0.1 (1)".
    static var line: String { "Version \(version) (\(build))" }
}

struct Release: Identifiable {
    let id = UUID()
    let version: String
    let date: String
    let items: [String]
}

enum WhatsNew {
    /// Newest first.
    static let releases: [Release] = [
        Release(version: "0.8 (8)", date: "23 Nov 2026", items: [
            "Changed: blue now means one thing, the app's own colour. It marks what you can press, the headings, and new mail (the envelope in the menu bar and the \"new\" tag). An account is never blue any more.",
            "Changed: the dot of an iCloud account is violet, before blue. A blue dot on every line also looked like \"unread\", as in Apple Mail.",
            "Changed: the dot of a Gmail account is green, before orange. Orange is now only the warning triangle.",
            "Changed: the round badge with the sender's letters in the message window has the colour of the account: violet for iCloud, green for Gmail, grey for others. Before, it was always orange-brown.",
            "Changed: the large tick when Triage is finished is blue, before green, so green means only Gmail.",
            "Changed: Settings says \"iCloud violet, Gmail green\" at the account dot, and \"Signs in this app\" has a line for blue.",
        ]),
        Release(version: "0.7 (7)", date: "23 Nov 2026", items: [
            "Changed: the list is narrower. You chose option 4 of four: 260 points wide, before 400.",
            "Changed: the button in a sender's bar says \"Mark read\", before \"Mark all read\". It still marks all of that sender's emails as read. With the longer words the narrow list showed only eight letters of a sender's name; now it shows about fifteen.",
            "Changed: the list has no scroll bar any more. On your Mac it took 15 of the 260 points. Scroll with two fingers or the mouse wheel.",
            "Changed: in the narrow list the words \"Newest 20\" at the top give way, so the heading row never breaks into two lines. The number is still in Settings.",
        ]),
        Release(version: "0.6 (6)", date: "23 Nov 2026", items: [
            "Changed: smaller, quieter letters in the whole app. You chose option 2 of six. In the list the sender is 12 points (before 14), the subject 11 (before 13), the first line of text 10.5 (before 12.5), the time 10 (before 12). The letters are still the Mac's own, in normal weight.",
            "Changed: the same in the windows. In the message window and in Triage the subject is 14 points (before 19 and 18) and the text of the email 12 (before 14 and 13.5). Settings, How it works and What's new are 11 points (before 13 and 12). Buttons and tick boxes are the Mac's small size to match.",
            "Changed: the list is shorter for the same emails. Six emails from four senders took 263 points before and take 234 now.",
            "Changed: Triage can be 747 points narrow, before 761.",
            "Fixed: Triage, or an email you open, came up underneath the list. The list now closes when one of them opens.",
            "Changed: archiving a Gmail email now says plainly \"Archiving does not work for Gmail yet. Nothing was changed\". Before, it said \"Archived\" although the email stayed in the inbox. iCloud emails archive as before.",
            "Changed: no bold in the headings of How it works and What's new, in the titles of the small windows, in \"Undo\" and in the title of a problem. The blue colour marks a heading. Only the title \"Mail\" of the list is bold.",
        ]),
        Release(version: "0.5 (5)", date: "23 Nov 2026", items: [
            "Checked: the message window, Triage, its two small windows and Settings, each drawn by day and by night and then photographed on the Mac with real mail. What was wrong is fixed below.",
            "Fixed: in Triage the buttons at the bottom were cut off (\"Del…\", \"Arc…\", \"Re…\" twice). All nine now show their whole word, and the window cannot be made narrower than the row of buttons. It opens 800 points wide, before 620.",
            "Fixed: Triage opened before the first reading was done said \"No emails to go through\" and stayed that way. Now it says \"Reading Mail…\" and starts by itself when the emails are there.",
            "Changed: Settings has no boxes and no empty space any more. Before, the Settings tab was 795 points tall in a 560 point window and had to be scrolled. Now everything fits in 440 points without scrolling. Switches are tick boxes.",
            "Changed: the three tabs in Settings are the app's own row. Before, the Mac's tab bar wrote the chosen tab in pale yellow on white and left an empty band above.",
            "New: Done at the bottom right of Settings, in full colour. Escape closes Settings too. The version number sits at the bottom left, on every tab.",
            "Changed: no bold in the message window and in Triage either: subject, sender and the letters on the key buttons.",
            "Changed: the main buttons are in full blue: Reply, Send to PARAGON, Close, Done. Delete in the message window is red.",
            "Changed: the text of an email has no empty lines at its start and never more than one empty line in a row. Many emails come with three or more.",
            "Changed: opening an email, and each email in Triage, no longer holds the window while Mail fetches the text. You see \"Loading…\" for a moment; a heavy email can take a few seconds.",
            "Changed: archive, delete, file in a folder, mark as read and Undo no longer hold the window while Mail works. The email leaves the list at once, and the bottom left says what is going on: \"Archiving…\", \"Deleting…\", \"Filing…\", \"Putting the email back…\". Before, an Undo held the whole app for 11 seconds.",
            "Tried on real mail: one iCloud email was archived and brought back with Undo. It worked.",
            "Not working yet: archiving a Gmail email. Mail says it moved the email to \"All Mail\", but the email stays in the inbox, and Undo then says it cannot find it. Nothing is lost. iCloud is not affected.",
            "Changed: the small windows for \"File in a folder\" and \"To PARAGON\" have a thin edge all round, and the folder list has tight rows instead of the Mac's roomy list.",
        ]),
        Release(version: "0.4 (4)", date: "23 Nov 2026", items: [
            "Fixed: the list took over a minute to show. The cause was the first line of text under each subject: for it, Mail opens every email in full. Before, the list waited for all of them, at every check. Now the list shows in under a second, the first lines follow one by one, and each is read only once.",
            "Fixed: the list froze while Apple Mail answered. Right after Mail starts it can take more than a minute to answer, and all that time nothing in the list could be clicked. Now a small helper copy of the app does the reading, and the list stays usable meanwhile. A reading takes 1 to 3 seconds; while Mail itself is busy fetching mail it can take longer, and the list keeps showing what it had.",
            "New: \"Reading Mail…\" at the bottom left while the app reads. When it is done you see \"Checked\" and the time again.",
            "Fixed: \"Mail could not be read … Invalid index\". It showed when an inbox held fewer emails than the list asks for, or while Mail was still loading. Now the app takes the emails that are there.",
            "New: \"Apple Mail is busy\". If Mail does not answer within 30 seconds, the list says so in plain words and tries again by itself.",
            "Changed: the padding is gone, in every window. Before, there were 8 to 18 points of empty space around the heading, the rows, the cards and the buttons. Now there is none above and below, and 4 points at the sides so letters do not touch an edge. Gaps between rows are 4 points at most, before up to 12.",
            "Changed: one thin edge of 6 points stays around each window, because the Mac rounds the window's corners and they cut into the words without it. The cards of the senders have smaller round corners, 5 points instead of 10.",
            "Fixed: the list is as tall as its emails, up to a limit, and then scrolls. For a moment today it showed no emails at all between the heading and the bottom bar.",
            "Changed: nothing in the list is bold any more. Before, the subjects of new emails, the sender names, \"Mark all read\" and the \"new\" tags were bold. Now a new email has its subject in full-strength letters and a read one in grey.",
            "Changed: the app uses its own blue for the tags, \"Mark all read\", Triage and the buttons at the bottom. Before, it took the Mac's highlight colour, which on your Mac gave pale yellow tags that were hard to read. By night the blue is lighter.",
            "Fixed: an empty second line under some subjects. Many emails begin with signs that show nothing; the first line is now the first one with something to read.",
            "Changed: before the first reading is done the list says \"Reading Mail…\", not \"No emails in your inboxes\".",
            "New: the app can check itself. Started with a special word, it reads the inboxes once and writes down how many emails it found and how long it took. It is used for testing; you do not need it.",
        ]),
        Release(version: "0.3 (3)", date: "23 Nov 2026", items: [
            "New: the app has its own icon. A white hand-drawn envelope on calm blue, the same blue as the envelope in the menu bar while new mail waits. Before, it showed the Mac's plain stand-in icon. You see it in the Applications folder, in Login Items and next to the Mac's questions.",
            "New in the icon library: the envelope, called \"Mail\", under Everyday. It is drawn in the same style as the other icons, so any of your apps can use it.",
        ]),
        Release(version: "0.2 (2)", date: "23 Nov 2026", items: [
            "New: the first version that runs on your Mac. 0.1 was written where no Mac was at hand and had never been started.",
            "New: a fixed place for the menu bar icon, just left of the Deck Mate icon. Before, the Mac put the new icon at the far left of your full menu bar, where it could not be seen.",
            "New: \"Open at login\" in Settings (off at first). While it is on, the app opens at every login.",
            "New: the keeper. While \"Open at login\" is on, a second start order with the Mac opens the app again within about 10 seconds if it ever stops unexpectedly. If you quit it yourself, it stays closed.",
            "New: only one copy of the app can sit in the menu bar. A second copy closes itself at once.",
            "New: Settings now has three tabs: Settings, How it works, What's new.",
            "New: \"How it works\", a guide to the whole app. It ends with \"Signs in this app\": every mark and colour and what it means.",
            "New: \"What's new\", this list.",
            "New: the version number shows at the bottom of the Settings tab.",
            "Not there yet: an app icon. The icon library has no envelope yet.",
        ]),
        Release(version: "0.1 (1)", date: "23 Nov 2026", items: [
            "New: AMS Mail Menu, a small app in the menu bar. It shows your newest emails from Apple Mail, grouped by sender.",
            "New: the list. It shows the newest emails (20 at first, 5 to 100 in Settings) from the inboxes of all your accounts. Senders are ordered by their newest email, and inside a sender the newest email is on top. A sender with new mail is open, one without is closed, and you can open or close any by hand.",
            "New: each email line shows the subject (bold while new) and the time. Settings can add the first line of the text and a small coloured dot for the account: blue for iCloud, orange for Gmail, grey for others.",
            "New: a blue \"3 new\" tag on a sender, or grey \"4 read\" when nothing is new. \"Mark all read\" marks all of one sender's emails as read.",
            "New: the menu bar icon. Outline envelope when nothing is new, blue envelope while new mail waits, warning triangle when something is wrong. Settings can show the number or a dot instead of the blue colour, and can show the time of the newest new email next to the icon.",
            "New: actions on an email. Move the mouse over a line, or right-click it: mark as read, reply, archive, delete. Reply opens the reply window of Apple Mail.",
            "New: Undo for 10 seconds after archive, delete or filing. The email goes back to where it was.",
            "New: a short message in plain words at the bottom when an action does not work.",
            "New: clicking an email opens it in a small window of this app (the default), in Apple Mail at exactly that email, or in Spark. Spark only comes to the front, because it cannot be told which email to show.",
            "New: the message window. Subject, sender, account, date and text. Reply, Archive, Delete, Open in Apple Mail and Spark. Opening marks the email as read. \"Keep on top\" is on at first. Escape closes it.",
            "New: Triage. One email at a time, newest first, one key per decision: D delete, A archive, F file in a Mail folder, P send to PARAGON, M mark as read, R reply, Space or the right arrow next, the left arrow back, Z undo, Escape close. \"Unread only\" and \"Start over\" at the top.",
            "New: filing in a folder. A list of the folders of the email's account, the ones you used lately first. Type to find one. Enter takes the first shown.",
            "New: send to PARAGON. You give the task words and tags, and choose Inbox, Today or a project or note. The task gets a link back to the email. Then the email is archived.",
            "New: the list checks for mail by itself, every 30 seconds, 1, 2 or 5 minutes (1 minute at first), and after every action. The round arrow checks at once.",
            "New: clear help when Mail is closed (\"Open Mail (hidden)\"), when the Mac blocked access (\"Open System Settings\"), or when access was not asked yet. The app never starts Mail on its own.",
            "New: Settings, opened with the gear at the bottom of the list.",
            "Good to know: the app reads Apple Mail with AppleScript. It uses no passwords, and nothing leaves your Mac.",
        ]),
    ]
}

/// The list of versions as a page for a settings screen.
struct WhatsNewView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(WhatsNew.releases) { release in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(release.version) · \(release.date)").font(Look.f(14)).foregroundStyle(Color.mailBlue)
                    ForEach(release.items, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("–").foregroundStyle(.secondary)
                            Text(item).fixedSize(horizontal: false, vertical: true)
                        }
                        .font(Look.f(13))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("newsPage")
    }
}

/// The version number as one small line for the bottom of a settings screen.
struct VersionLine: View {
    var body: some View {
        Text(AppInfo.line)
            .font(Look.f(11))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("settingsVersion")
    }
}
