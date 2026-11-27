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
        Release(version: "0.9.9 (18)", date: "27 Nov 2026", items: [
            "Tried on a real email: archiving a Gmail email works. On 27 Nov a test email \"Mail Menu test\" was archived straight at Gmail (9 seconds) and put back with Undo (5 seconds). Gmail itself showed it back in the inbox. Before, this was only tested against a stand-in, because the Gmail connection was not set up yet.",
            "Fixed: the app's own diary now says \"archived at Gmail\" after a Gmail archive. Before, the line ended with an empty place name.",
            "Not tried yet on a Gmail email: delete, filing in a folder, mark as read and reply. They still go through Apple Mail.",
        ]),
        Release(version: "0.9.8 (17)", date: "26 Nov 2026", items: [
            "Only words changed: the sample names and examples no longer use real names. The app works as before.",
            "Changed: the invented email used for the test picture. Before, it began \"Hello Martin\". Now it begins \"Hello Sam\".",
            "Changed: the invented senders in the test pictures. Before, they were \"Anna Example\" with the address anna@example.com. Now they are \"Eva Example\" with eva@example.com."
        ]),
        Release(version: "0.9.7 (16)", date: "26 Nov 2026", items: [
            "Fixed: wrong words in \"How it works\", the README and the written specification. Only words changed; the app works exactly as before.",
            "\"How it works\", part \"What this app is for\": it said \"It uses no passwords, and nothing leaves your Mac.\" That is only true without Gmail. Now it says: without the Gmail connection nothing leaves your Mac; with it, the app password is kept in your Mac's Keychain, and the app talks to Gmail only when you press Connect, and to archive a Gmail email or take that back with Undo.",
            "\"How it works\", part \"Settings\": it said the Settings window has three tabs. Now it says four: Settings, Gmail, How it works and What's new, and it points to \"The Gmail connection\" for the Gmail tab. Also in \"The Gmail connection\": \"Settings, part Gmail\" now says \"Settings, tab Gmail\".",
            "README: it said three tabs; now four. It said the sender button is \"Mark all read\"; now \"Mark read\", as on the button. It said \"Nothing leaves your Mac except this one connection to Google\"; now it says what talks to Google. It said version 0.9.1 (build 10) and \"Not yet built on a Mac\"; now the right version, and that line is gone. It also now mentions the click that opens Mail and the two-finger menu.",
            "Specification: it said the account dots are \"iCloud blue, Gmail orange\"; now \"iCloud violet, Gmail green\", as in the app. It said \"Never starts Mail by itself\"; now it says Mail is started, hidden, only when you click the orange envelope while Mail is closed (since 0.9.5). It said \"No passwords. Nothing leaves the Mac.\"; now it covers the Gmail connection. It said three tabs; now four. It named \"Mark all read\" and \"part Gmail\"; now \"Mark read\" and \"tab Gmail\". Its status line said nothing was tried on a Mac yet; now it says what is true.",
            "Nothing else changed: no new marks, no new colours.",
        ]),
        Release(version: "0.9.6 (15)", date: "26 Nov 2026", items: [
            "New: resting the pointer on the menu bar icon now also shows a hint when all is well. Before (0.9.4 and 0.9.5), the hint showed only when something was wrong. Now it also tells you how many new emails wait: \"22 new emails, newest at 08:47\", or \"1 new email, newest at 08:47\", or \"No new emails\". When something is wrong, the words of the problem show instead, as before. You said yes to this (\"Yes, do 1 too - show new count on hover\").",
            "New: a two-finger click on the menu bar envelope (or a click with the Control key held) now opens a small menu. Before, a two-finger click did nothing. Now the menu has: \"Check for new mail now\" (reads Mail again at once), \"Open Apple Mail\" (brings Mail to the front), \"Triage\" (opens the Triage window), \"Settings…\", a line, and \"Quit AMS Mail Menu\". You chose this one, \"Short menu\", out of four.",
            "A normal click on the envelope still opens the list, as before.",
            "Changed: \"How it works\", parts \"The menu bar icon\" and \"Quit\", and the line for the time next to the icon in \"Signs in this app\" now describe this. There are no new marks.",
            "Nothing else changed: the envelopes, the time next to the icon and the list look and work as before.",
        ]),
        Release(version: "0.9.5 (14)", date: "26 Nov 2026", items: [
            "New: a click on the orange envelope now opens Apple Mail for you, hidden in the background. Before (0.9.3 and 0.9.4), when Mail was closed, a click opened the list with the problem and a button \"Open Mail (hidden)\" that you had to press yourself. Now the click opens the list and opens Mail by itself at the same time. Mail stays hidden: it does not come to the front and does not take over your screen. You said yes to this (\"Yes, do 2 - open Mail on click\").",
            "While Mail starts, the list says \"Opening Mail…\" where the button used to be. The app reads Mail again after 4 seconds, and once more after 10 seconds if Mail was slow. Then your emails appear and the icon turns back to the envelope.",
            "If you opened Mail yourself in the meantime, the app does not touch Mail (so a Mail you are looking at is never hidden); it only reads again.",
            "Only for \"Mail is closed\": other problems, for example access to Mail turned off, still show their own button in the list, as before.",
            "Changed: the words for \"Mail is closed\". Before: \"This app reads your emails from Apple Mail. Please open Mail (it may stay hidden).\" Now: \"This app reads your emails from Apple Mail. A click on the menu bar envelope opens Mail for you, hidden.\" These are also the words in the hint when you rest the pointer on the icon.",
            "Changed: \"How it works\", parts \"The first time\" and \"The menu bar icon\", and the line for the orange envelope in \"Signs in this app\" now describe this.",
            "Nothing else changed: the envelopes, the time next to the icon and the rest of the list look and work as before.",
        ]),
        Release(version: "0.9.4 (13)", date: "26 Nov 2026", items: [
            "New: the orange envelope with the \"!\" now tells you what is wrong when you rest the mouse pointer on it. Before (0.9.3), you had to click the icon and read the list to learn what was wrong (for example that Mail is closed). Now a small hint box, the Mac's normal one, shows the heading of the problem and, below it, what to do. For example: \"Apple Mail is not open\" and under it \"This app reads your emails from Apple Mail. Please open Mail (it may stay hidden).\" The words are the same ones the list shows. You asked for this (\"Yes, show the problem on hover\").",
            "When nothing is wrong, the icon shows no hint, as before. When the problem goes away, the hint goes away too, and when the problem changes, the hint changes with it.",
            "Changed: \"How it works\", part \"The menu bar icon\", and the line for the orange envelope in \"Signs in this app\" now say that resting the pointer on it shows what is wrong, and that a click still opens the list.",
            "Nothing else changed: clicking the icon opens the list as before; the orange envelope, the blue envelope, the outline envelope and the time next to the icon look the same.",
        ]),
        Release(version: "0.9.3 (12)", date: "26 Nov 2026", items: [
            "Changed: the warning mark in the menu bar. Before (0.2 to 0.9.2), when something was wrong (for example Mail is closed), the icon was Apple's warning triangle, drawn in the menu bar's own black or white. Now it is the envelope with a small filled badge at its top right, with a white \"!\" in it, and the whole mark is orange. You chose option 2 of 3 (red badge, orange badge, red filled envelope).",
            "Why orange: in this app orange means only \"warning\". The list already shows an orange warning triangle at the bottom when an action fails. Red stays only for delete. So the menu bar warning and the warning in the list now look alike.",
            "Changed: the time of the newest new email next to the icon is much smaller and thinner. Before, it was one line, for example \"8:09\", in the menu bar's normal letters, 13 points. Now it is two small thin lines, one above the other: the hour with the colon on top and the minutes below (\"08:\" over \"09\"). The letters are 7.5 points, light weight, so the time takes less width and looks calm. You chose option A of 2 (with the colon) and asked for the numbers to be even smaller.",
            "Changed: the time always has two digits for the hour and two for the minutes. Before, 8:09 was written \"8:09\"; now it is \"08:\" over \"09\".",
            "Changed: the time takes the menu bar's own colour, as before: dark on a light menu bar, white on a dark one, by day and by night.",
            "Changed: \"How it works\", part \"The menu bar icon\", and the line for the warning in \"Signs in this app\" now say \"orange envelope with a !\", and describe the two-line time. The line for the orange warning triangle at the bottom of the list says that orange means the warning in both places.",
            "Nothing else changed: the switch in Settings \"Show the time of the newest new email next to the icon\" is where it was and works as before; the blue envelope, the outline envelope and the number and dot choices look the same.",
        ]),
        Release(version: "0.9.2 (11)", date: "23 Nov 2026", items: [
            "Fixed: the gear did not always get you into Settings. Before (0.2 to 0.9.1), if the Settings window was already open behind other windows, pressing the gear showed nothing. And a new Settings window could open behind the window you were working in. Now Settings always comes to the front, in front of every other window.",
            "Fixed: the list stayed open over Settings. Before, it stayed on the screen after you pressed the gear. Now the list closes first, then Settings opens.",
            "Changed: the words in \"How it works\", part \"Settings\", now say that the list closes and Settings comes to the front, also when it was open behind other windows.",
            "Nothing else changed: the gear is in the same place at the bottom of the list and looks the same.",
        ]),
        Release(version: "0.9.1 (10)", date: "23 Nov 2026", items: [
            "Changed: Triage in the list is now a small button. Before (0.9), it was a tray-with-an-arrow symbol and the word \"Triage\" in blue letters, 11 points, with no background. Now it is a small filled blue pill with the word \"Triage\" in white letters, 10 points, and no symbol.",
            "Changed: the tray-with-an-arrow symbol is gone from the list. Before, it was 1 of the marks in \"Signs in this app\"; now that line says \"Small blue button Triage\", and \"How it works\" calls it the small blue Triage button.",
            "Changed: the button is narrower (about 44 points, before about 62), so the small grey words \"Newest 20\" fit in the top row again. Since 0.7 they were left out there for lack of room.",
            "Nothing else changed: the button is in the same place (top right of the list) and does the same thing as before (the list closes, then Triage opens).",
        ]),
        Release(version: "0.9 (9)", date: "23 Nov 2026", items: [
            "New: archiving a Gmail email works. Before (0.6 to 0.8), Archive on a Gmail email changed nothing and said \"Archiving does not work for Gmail yet\". Now the app talks to Gmail directly: the email leaves your Gmail inbox and stays in \"All Mail\", exactly like Archive in Gmail itself. No label is added.",
            "New: Settings has a new part \"Gmail\" with \"Gmail address\", \"App password\" (the letters are hidden), \"Account in Mail\" (which of your accounts in Apple Mail is the Gmail one, for example \"Gmail\"; the app proposes the one with \"gmail\" or \"google\" in its name) and a blue button \"Connect\". After connecting it says \"Connected to Gmail\", with a button \"Disconnect\". If Google refuses, a plain sentence says why: wrong address or app password, or no internet.",
            "New: the app password is made once at myaccount.google.com/apppasswords (2-Step Verification must be on). It is not your normal Google password. \"How it works\" has a new part \"The Gmail connection\" with the steps.",
            "New: the app password is kept in your Mac's Keychain and sent only to Google, encrypted. It is never written to a file, a note or the diary. Apple Mail is not involved in this archive; Mail shows the change the next time it checks Gmail.",
            "New: the email leaves the list at once and stays out of it even if Apple Mail has not caught up yet (the app remembers for 10 minutes which emails it archived).",
            "Changed: Undo (the dark bar, 10 seconds) on a Gmail email puts it back in the Gmail inbox, again straight at Gmail. Before, Undo could not find it.",
            "Changed: without the connection, Archive on a Gmail email still changes nothing, but now says: \"Archiving a Gmail email needs the Gmail connection. Open Settings and connect Gmail. Nothing was changed.\" If the email is not found in the Gmail inbox, nothing is changed and the app says so.",
            "Changed: \"Send to PARAGON\" on a Gmail email now archives the email afterwards the same way.",
            "Changed: iCloud and other accounts archive as before, through Apple Mail, to \"Archive\". Delete, filing in a folder, mark as read and reply still go through Apple Mail for every account (not tried on a Gmail email).",
            "Fixed: Mail's scripting could not find ordinary folders inside the Gmail account (error -1728); the app now finds them in a second way.",
            "Not tried on a real email yet: the Gmail connection needs your app password first. So far the conversation with Gmail was only tested against a stand-in. Tried on a test email on 23 Nov: Apple Mail's own Archive and Undo work for Gmail; a move ordered by this app through Mail does not.",
        ]),
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
