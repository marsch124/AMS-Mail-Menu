# AMS Mail Menu — specification

Version 0.9.7 (16), 26 Nov 2026. Mac only (macOS 15+), menu bar app without a Dock icon.

Status: written from the code, and built and run on the Mac since 23 Nov 2026; see "Not yet checked" for what is still open.

## Purpose
See the newest emails without opening a mail app, and deal with them in a few clicks or keys.

## Overview
- Lives in the menu bar. No Dock icon.
- Reads Apple Mail through AppleScript (`NSAppleScript`, on the main thread). Starts Mail only when the owner clicks the orange envelope while Mail is closed (since 0.9.5, hidden; see "Open Mail on click"); otherwise never.
- Needs the Automation permission for Mail (macOS asks on first use). No passwords and nothing leaves the Mac, unless the Gmail connection is set up (see "Gmail archive"): then the app password sits in the Keychain, and the app talks to Gmail only on Connect, Archive and Undo of a Gmail email.
- Not sandboxed. Signed "Apple Development", same team as the other AMS Mac apps.

## The list
- The newest N emails (Settings, default 20, 5–100) across the Inboxes of all accounts. Each inbox is asked for N; the newest N overall are kept.
- Grouped by sender (lower-cased address, or the name if there is no address). Groups are ordered by their newest email; emails inside a group newest first (`SenderGrouping`).
- A sender is folded open when it has unread mail, unless folded by hand.
- Each line: account dot (iCloud violet, Gmail green, others grey; decided from the account's name), subject, time; optional first line of text (first 400 characters read, first non-empty line, at most 120 characters).
- Refresh every 30 s / 1 / 2 / 5 minutes (default 1 minute, never under 15 s), and after every action.

## Menu bar icon
- No unread mail: outline envelope.
- A problem (for example Mail is closed): the envelope with a small filled badge at its top right with a white "!"; the whole mark is orange (`systemOrange`, not a template image). Before 0.9.3: Apple's warning triangle in the menu bar's own black/white. The owner's pick, 26 Nov 2026: option 2 of 3 (red badge / orange badge / red filled envelope). Orange because in this app orange means only "warning" (the list's warning triangle at the bottom is orange too); red means only delete.
- Hover hint on the warning (0.9.4, 26 Nov 2026; the owner said yes to "show the problem on hover"): resting the pointer on the orange envelope shows the Mac's normal hint with the problem's title, a line break, then its explanation (`MailAccessProblem.hoverText` in Core, tested by `testHoverTextIsTitleAndExplanation`); e.g. "Apple Mail is not open" over "This app reads your emails from Apple Mail. A click on the menu bar envelope opens Mail for you, hidden." The words are the ones the list shows. It is set on the app's own menu bar button (`NSStatusBarButton.toolTip`) whenever the problem changes (`MailStore.problem` didSet → `SelfCheck.statusButton()`) and removed when the problem is gone, so no problem = no hint. The diary writes "hover text: …" each time. Seen with the check word `warningLook`. Before 0.9.4: no hint; the problem could only be read in the list after a click (a click still opens the list).
- Hover hint when all is well (0.9.6, 26 Nov 2026; the owner said yes to "Yes, do 1 too - show new count on hover"): the rule is `MenuBarHint.text(unread:newest:)` in Core, tested by `testHoverWhenAllIsWell`: "22 new emails, newest at 08:47", "1 new email, newest at 08:47", or "No new emails". It is set on the button's `toolTip` whenever the list (`groups`) or the problem changes; the problem's words (above) win while there is a problem. The diary writes "hover text: …" only when the words change. Before 0.9.6 the hint existed only for a problem; with all well there was none.
- Two-finger menu (0.9.6, 26 Nov 2026; the owner's pick "Short menu" of four: short menu / check for mail now / open Triage / open Apple Mail): `App/Sources/IconMenu.swift`. A local event monitor watches for a right mouse press (or Control + left press) on the app's own menu bar button; the entries come from Core `IconMenuEntry`, in order (test `testIconMenuEntriesInOrder`): "Check for new mail now" (reads Mail again at once), "Open Apple Mail" (brings Mail to the front), "Triage" (opens the Triage window), "Settings…", a separator, "Quit AMS Mail Menu". The menu pops up under the icon. A normal click still opens the list. Before 0.9.6 there was no menu on a two-finger click. Check word `iconMenu` shows the menu for 3 seconds, then closes it. Check word `rightClick` (0.9.6) queues a real two-finger click on the icon (`SelfCheck.rightClickIcon`, `NSApp.postEvent`), so the watcher itself is tried; the menu closes by itself after 3 seconds. Seen 26 Nov 2026 09:06: menu under the icon, list stayed shut, menu gone after 3 s.
- Unread mail, by Settings: blue filled envelope (default), filled envelope with the count, or envelope with a dot.
- Optional: the time of the newest unread email next to the icon (default on; Settings switch "Show the time of the newest new email next to the icon", unchanged). Since 0.9.3 it is two stacked lines: the hour with the colon on top, the minutes below ("08:" over "09"), always two digits each, 7.5 pt, light weight, in the menu bar's own colour (template colour: dark by day, white by night). Before: one line such as "8:09" in the menu bar's normal letters, 13 pt. The owner, 26 Nov 2026: "Make the time stamp much smaller and thinner"; pick A of 2 (with the colon); "make the numbers even smaller".

## Opening an email
Settings choose one: a small window in this app (default), Apple Mail at that email (`message://%3C…%3E` link from the Message-ID), or Spark (only brings Spark to the front; Spark cannot be told which email to show).
The small window marks the email as read, has Reply, Archive, Delete, Open in Apple Mail, Spark and "Keep on top" (default on); Escape closes it.

## Actions
- Mark as read (one, or all of a sender), reply (opens Mail's reply window), archive, delete, file in a folder.
- Archive moves the email to the first mailbox of its account found in `MailScript.archiveMailboxNames`; error if none is found.
- After archive, delete or file: an Undo bar for 10 seconds. Undo looks for the email in the mailboxes it may now be in and moves it back.
- A failed action shows a plain message at the bottom of the menu.

## Triage window
One email at a time, newest first; optional "Unread only". Keys without a modifier:
D delete · A archive · F file in a Mail folder · P to PARAGON · M mark as read · R reply · Space or → next · ← back · Z undo · Esc close.
- File: a searchable list of the account's folders, recently used first (8 kept); Enter takes the first shown.
- To PARAGON: opens `amspara://capture?text=…&target=…` (target inbox, today, or a note path), then archives the email. The text is the task words, the #tags, and `[Mail](message://…)` as the link back.

## Problems shown in plain words (`MailAccessProblem`)
Mail not open (since 0.9.5 no button: a click on the icon opens Mail, see below; before 0.9.5 the button "Open Mail (hidden)"), access turned off (button to System Settings → Automation), access not yet asked, anything else with Mail's own message.

### Open Mail on click (0.9.5, 26 Nov 2026; the owner said yes to "Yes, do 2 - open Mail on click")
- Rule `MailAccessProblem.opensMailOnClick`: true only for `mailNotRunning`; every other problem keeps its own button (test `testOnlyClosedMailIsOpenedOnClick`).
- `MailStore.openMailBecauseListOpened()` is called when the list window becomes key (and on first appearance). If Mail is not running: `MailReader.launchMailHidden()` (activates false, hides true, so Mail does not come to the front). If Mail is running: no launch, so a running, visible Mail is never hidden; it only reads again.
- It reads again after 4 s and once more after 10 s (if Mail was slow). Then the emails appear and the icon turns back to the envelope.
- The flag `openingMail` shows "Opening Mail…" in the list in place of the button.
- Diary lines: "click on the icon while Mail is closed: opening Mail (hidden)" or "click on the icon while Mail is closed: Mail is already open, reading again".
- Hover and list words for Mail closed: "This app reads your emails from Apple Mail. A click on the menu bar envelope opens Mail for you, hidden." Before 0.9.5: "...Please open Mail (it may stay hidden)." and a button "Open Mail (hidden)".

## Not yet checked
- Reading real mail on the Mac: the first build started, but no email has been read or acted on in a check yet.
- A real restart of the Mac with the keeper.
- Archive mailbox names for iCloud and Gmail (the list is a guess).
- Nested folder paths in the File picker.
- Whether the blue icon keeps its colour in the menu bar.
- Whether PARAGON makes the `[Mail](message://…)` link clickable.
- Speed of reading with "first line of text" on.

## Reading Mail (0.4)
- Asking Mail is only quick from a program's main thread (measured 23 Nov 2026: about 1 s there, 30 to 40 s from a background thread, because the answers arrive on the main thread). So:
  - The regular reading and the first lines run in a **helper copy of the app** (`Worker`, started with `--worker` by `MailReader.runInBackground`): it gets the script on its input, runs it on its own main thread, hands back Mail's answer packed (`AEFlattenDesc`, in a small JSON envelope) and ends. The app's window stays free; the bottom left says "Reading Mail…"; a reading asked for meanwhile runs once when the first ends. Measured: 1.2 to 1.6 s per reading, 3.3 s in the running app.
  - One action (archive, delete, mark as read, open) runs on the app's main thread and waits for its own answer (`MailReader.run`).
  - `Launcher.main` is where the program starts: the helper does its job there, before any window work.
- Mail itself is sometimes slow (while it fetches new mail a reading took 25 to 45 s). The list then keeps showing what it had.
- A diary in the Mac's log (subsystem `com.schabbauer.AMSMailMenu`, category `reading`): "reading starts", "read N emails, U unread, in X s". Counts and times only.
- Each inbox: first whole columns at once (`… of messages 1 thru k`); if Mail refuses that ("Invalid index": fewer emails than asked, still loading, or changed meanwhile), one email at a time as far as Mail gives them. Seen 23 Nov 2026: inboxes of 18 and 6 emails, one reading 0.4 s; right after Mail started, 75 s.
- The first line of text is not part of the reading: `content` makes Mail open the whole email (seconds each; 24 emails took over a minute, at every check). After the list is shown, `MailStore.readNextPreview` reads one first line at a time in the background, newest first, and keeps it (`previewCache`, until the email leaves the list). Settings says so under the switch.
- "Is Mail open?" (`MailReader.isMailRunning`): the Mac's list of running apps, and when that is empty for an instant (seen twice in two minutes) the process last seen as Mail, if it is still alive and still Mail. Measured after this fix: 20 first lines in under two minutes, 0.3 s each, none failed.
- Every question to Mail gives up after 30 seconds: "Apple Mail is busy" (`MailAccessProblem.mailBusy`, AppleScript -1712); the next regular reading tries again.

## Self-check (0.4, `SelfCheck.swift`)
`open -n "AMS Mail Menu.app" --args --check <file>` reads the inboxes once and writes into the file: how many emails, how many unread, how many per account, how many sender groups, how long it took. Never the words of an email. `--picture <file>` draws the list panel with six invented emails into a PNG (and its size into `<file>.txt`): the way to look at the layout without a click. `--probe <file>` times 13 fixed small questions to Mail. `--check <file> --helper` reads through the helper copy. Both run as the app itself (its own permission for Mail), before the one-copy rule, and quit.

## Layout: no padding (0.4, the owner's word: "take away all padding")
No empty space above or below anything. 4 points at the sides (3 inside the small tags), so letters do not touch an edge. One exception: 6 points around each window (list panel, message window, Triage), because the Mac rounds window corners and they cut into the words otherwise (the owner: "Terrible rounding"). Sender cards: corner 5. The list area is as tall as its emails up to 560 points (`fixedSize`), then it scrolls. Gaps between stacked things: 4 points at most. Rows are as tall as their words.

## Colours: one meaning each (0.8)
The owner's rule: a colour means ONE thing in the whole app. Since 0.8:
- **Blue** (`Color.mailBlue`): the app's own colour: what you can press, headings, and new mail (the envelope in the menu bar, the "N new" tag). Never an account.
- **Violet** (`Color.accountViolet`, day 125/77/209, night 179/143/255): an iCloud account: the dot on an email line, the dot in the heading row, the initials badge in the message window.
- **Green** (`Color.accountGreen`, day 33/140/77, night 92/204/128): a Gmail account, the same three places. Nothing else is green: the "Triage is finished" tick is blue.
- **Grey**: another account; a read email; small words.
- **Orange**: the warning only: the warning triangle at the bottom of the list and, since 0.9.3, the orange envelope with "!" in the menu bar. **Red**: delete only.
Until 0.7 iCloud was blue (it also read as "unread", as in Apple Mail), Gmail orange (the warning's colour), the badge always orange-brown and the finished tick green.

## Letters (0.6)
Every size in the app goes through `Look.f(size, weight)` (`App/Sources/Look.swift`). The sizes written in the screens are those of 0.5; `Look.delta = -2` makes them 2 points smaller, never below 9. The owner chose this on 23 Nov 2026 as option 2 of six shown in one picture ("another smaller and not so intrusive font"): the Mac's own letters, regular weight. List: sender 12, subject 11, first line 10.5, time 10, small words 9. Message window and Triage: subject 14, email text 12. Settings, guide and What's new: 11, headings 12 in blue, not bold. Text without its own size takes `Look.f(13)` from the root of each window; controls are `.small`. `--picture … --look N` (1 = the sizes of 0.5, 2 = this, 3 thin, 4 Avenir Next, 5 rounded, 6 one point smaller) draws a candidate.

## Letters and colour in the list (0.4)
- Nothing in the list is bold (the owner, 23 Nov 2026: "Not bold - it looks terrible"). A new email: subject in the primary text colour; a read one: secondary (grey). Only the panel title "Mail" is bold.
- The app's own colour `Color.mailBlue` (day 10, 92, 196; night 107, 173, 255) for tags, "Mark read", Triage, the bottom buttons, headings in the guide. Never the Mac's highlight colour (his is yellow: unreadable tags).
- First line of text: the first line with something to read; lines made only of signs that show nothing (zero-width signs, no-break spaces, a picture's place U+FFFC) are skipped (`MessageLinks.firstLine`, tested).

## Checking the real panel without a click (0.4)
The running app presses its own menu bar icon when another program posts the notice `com.schabbauer.AMSMailMenu.openPanel` (`SelfCheck.listenForOpenPanel`). Then `screencapture -R 700,0,612,700` shows the real panel with the real emails. `--picture <file> [--dark]` draws the panel with invented emails, by day or by night.

## Place in the menu bar
The icon gets a saved place at first start: 290 points from the right edge (`NSStatusItem Preferred Position Item-0`), just left of Deck Mate (272) and right of Tidy Bar's line (302). Without it the Mac puts a new icon at the far left of a full menu bar, where it is hidden. A place the owner drags it to is kept.

## Settings window (0.5)
480 x 440. At the top the app's own row of four tabs (a segmented picker, not the Mac's tab bar: that one writes the chosen tab in the Mac's highlight colour and leaves an empty band): Settings, Gmail, How it works, What's new. At the bottom the version line ("Version 0.8 (8)") on the left and Done (filled blue; Escape too) on the right. The Settings tab is plain rows without boxes: blue group headings, tick boxes, two menus, three radio buttons, ending with "Start" ("Open at login", off at first). Every change counts at once.

### Opening (0.9.2)
Before (0.2 to 0.9.1): the gear at the bottom of the list opened the Settings window without bringing the app to the front. A Settings window already open behind other programs' windows (open since the afternoon) showed nothing when the gear was pressed, a new one could open behind the window in use, and the list stayed open over it. Now (0.9.2): the gear closes the list, opens Settings and puts the Settings window in front of every other window, also when it was already open behind something. Nothing else changed: same place, same look. The owner: "I cannot access Settings". Code: `SelfCheck.showSettings` (the gear and the notice word `settings` both go this way).

## Triage and message window (0.5)
- The key bar never cuts a word: each button has its fixed size, small controls, and the window cannot be narrower than the bar (761 points); it opens 800 x 600.
- Opened before the first reading is done: "Reading Mail…"; it starts when `lastRefresh` arrives.
- An email's text is read by the helper (`MailStore.loadContent`), shown through `MessageLinks.tidyBody` (no empty lines at start or end, never two in a row; tested).
- Main buttons filled blue (`borderedProminent`): Reply, Send to PARAGON, Close, Done. Delete in the message window red.
- Sheets ("File in a folder", "To PARAGON"): 8 points all round; the folder list is plain rows with hairlines.

## Actions never hold the window (0.5)
Archive, delete, file, mark as read, reply, Undo and the folder list all go through the helper (`MailStore.perform` → `MailReader.runInBackground`). The email leaves the list at once (`hide`); `workNote` shows "Archiving…", "Deleting…", "Filing…" or "Putting the email back…" at the bottom left; if Mail refuses, the next reading brings the email back and the reason shows at the bottom. Undo is offered when Mail has answered, for 10 seconds.

## Tried on real mail, 23 Nov 2026 (with the owner's yes)
- iCloud: one read email archived to "Archive" (3.3 s) and brought back with Undo (11.3 s, then on the main thread). Back in the inbox, checked by its Message-ID.
- 🚨 Gmail, NOT working, and why (looked at with `--gmail-look`, which changes nothing): the account is plain IMAP; every email sits in "INBOX" AND in "All Mail" at once. `move m to mailbox "All Mail"` answers without error (26.7 s) but changes nothing: the email stays in the inbox. Undo then answers "The email could not be found to move it back".
- 🚨🚨 `set deleted status of m to true` (meant as "take it out of the inbox only") made **Apple Mail itself crash** (Mail 16.0, macOS 26.6.2, 23 Nov 2026 15:33:53, abort in `-[MCMessage(ScriptingSupport) setIsDeleted:]`). The email was untouched. Never send Mail that command. The try was removed from the app.
- 0.6 to 0.8: `MailScript.archive` stopped before the move when the archive mailbox is named "All Mail": "Archiving does not work for Gmail yet. Nothing was changed; the email is still in your inbox." (error 9005). **SOLVED in 0.9** by the direct Gmail connection, see "Gmail archive: the direct connection (0.9)". Still open: `archive` returns only the last part of the mailbox name, so Undo could miss a mailbox that sits inside another.
- The check itself: the notice `show` with the word `archiveUndo` archives the newest READ email and undoes it; `report` only lists which read emails the inboxes hold. 🚨 `archiveUndo` changes the owner's mail: only with his yes for that very run.

## Gmail archive: the direct connection (0.9)
History, 23 Nov 2026:
- 0.6 to 0.8: archiving a Gmail email did not work; the app said "Archiving does not work for Gmail yet. Nothing was changed; the email is still in your inbox."
- Tried on a test email "Mail Menu test" (sent to the owner's own Gmail, with his yes): a move ordered by another app through Apple Mail's scripting NEVER reaches Gmail. Moved to "All Mail": nothing happens. Moved to a new label folder "Archived": Mail showed the email there for a few seconds, then it was back in the inbox; Gmail itself still had it in the inbox with no label. So "file in a folder" probably cannot work for a Gmail email either (not tried).
- Proven to work on the same test email: Apple Mail's own menu, Message > Archive (out of the Gmail inbox within seconds) and Edit > "Undo Archive Message" (back in the inbox).
- The owner was offered three ways (the app presses Mail's own Archive; a direct Gmail connection; leave it off) and picked "Connect to Gmail directly".
- In the Gmail account, `mailbox "X" of account "Gmail"` fails (-1728) for ordinary folders; `first mailbox of account "Gmail" whose name is "X"` works (folder names there are whole paths; 924 folders). `findBox` and `resolveBox` in `MailScript` now fall back to that form.
- 🚨 Never send Mail `set deleted status` (it crashed Apple Mail on 23 Nov 2026).
- 🚨 The check words that change mail (`archiveUndo`) need the owner's yes for that very run. New check word `archiveUndoTest`: archives and undoes ONLY the email whose subject is exactly "Mail Menu test", never a real email.

Settings, tab "Gmail" (keys `gmailAddress` and `gmailMailAccount` in the app's settings):
- "Gmail address"; "App password" (a secure field, the letters hidden); "Account in Mail" (which account in Apple Mail is the Gmail one, for example "Gmail"; proposed: the account whose name contains "gmail" or "google"); main blue button "Connect"; after connecting the line "Connected to Gmail" and a button "Disconnect".
- If Google refuses, one plain sentence says why: wrong address or app password; no internet.
- The app password is made at myaccount.google.com/apppasswords (Google account > Security > 2-Step Verification must be on > App passwords), named "AMS Mail Menu", the 16 letters pasted into "App password". It is not the normal Google password.
- The app password lives in the Mac's Keychain, service `com.schabbauer.AMSMailMenu.gmail`. It is sent only to Google (imap.gmail.com, port 993, encrypted). It is never written to a file, a note or the diary.

Archive:
- With the connection on, Archive on an email of the chosen Mail account goes straight to Gmail: the email leaves the Gmail inbox and stays in "All Mail", exactly like Archive in Gmail itself. No label is added. Apple Mail is not involved; Mail shows the change the next time it checks Gmail.
- The email leaves the app's list at once and stays out of it even if Apple Mail has not caught up yet: the app remembers for 10 minutes which emails it archived directly.
- Undo (the dark bar, 10 seconds) puts the email back in the Gmail inbox, again straight at Gmail.
- Without the connection, Archive on a Gmail email changes nothing and says: "Archiving a Gmail email needs the Gmail connection. Open Settings and connect Gmail. Nothing was changed."
- If the email is not found in the Gmail inbox, nothing is changed and the app says so.
- iCloud and other accounts archive as before, through Apple Mail, to "Archive". Delete, file in a folder, mark as read and reply still go through Apple Mail for every account (not tried on a Gmail email).
- Send to PARAGON archives the email afterwards the same way.

How it talks to Gmail: IMAP over TLS with Network.framework (`GmailConnection.swift` in App, the rules in Core `GmailIMAP.swift`).
- Archive: LOGIN, SELECT INBOX, UID SEARCH HEADER Message-ID, UID STORE +FLAGS.SILENT (\Deleted), UID EXPUNGE, then a second search must find nothing (otherwise the archive is reported as not done).
- Undo: LIST "" "[Gmail]/%" to find the folder flagged \All, SELECT it, UID SEARCH HEADER Message-ID, UID COPY to INBOX.

- Tried so far (23 Nov 2026): only against a scripted stand-in server (`testGmailArchiveConversation`, `testGmailSafetyRules`). NOT yet tried at Gmail itself: the owner has to make the app password and connect first. Then: the notice `show` with the word `archiveUndoTest` archives and undoes only the email with the subject "Mail Menu test".

## The list closes for a window (0.6)
Before Triage or the message window opens, the list panel closes (`SelfCheck.closePanel`: a click on the app's own menu bar button, only while the panel is open), so the window is not hidden under it. The owner, 23 Nov 2026: "The triage window is under the list."

## Width of the list
`Look.panelWidth` = 260 points since 0.7 (the owner's pick, option 4 of four shown in one picture; 400 before). The heading row never wraps: when it is too narrow the words "Newest 20" give way (`ViewThatFits`). `--picture … --width N` draws a candidate.

## The Triage button (0.9.1)
Before (0.9): at the top right of the list, Triage was opened by a tray-with-an-arrow symbol plus the word "Triage" in blue letters, 11 points, with no background. Now (0.9.1): a small button, a filled capsule in `Color.mailButtonBlue` (day 10/92/196, the blue of the app icon; night 26/112/224, so white letters read on it) with the word "Triage" in white letters, 10 points, no symbol. It is drawn by hand (not the Mac's own filled button), so it is full colour even when the panel is not the front window. Same place, same action: it opens Triage, and the list closes first (see "The list closes for a window"). The owner: "Make Triage into a small button". The tray symbol is used nowhere in the list any more, and its line in "Signs in this app" (guide) is replaced by one for the small blue button. The button is about 44 points wide (before about 62), so "Newest N" fits in the 260-point heading row again (seen in the real panel, 23 Nov 21:25; `ViewThatFits` still drops it when it does not fit). `--picture … --light` draws the day look when the Mac is on night. Code: `MenuContentView.headerRow`.

## The narrow list (0.7)
260 points wide. A sender's bar: arrow, name (cut with "…" when too long), "Mark read" (tooltip "Mark all emails of this sender as read"; "Mark all read" before, which left the name eight letters), the "N new" tag. No scroll bar (`scrollIndicators(.never)`): a Mac set to always show scroll bars gave it 15 of the 260 points. The heading row drops "Newest N" when it does not fit.

## Seeing the real windows (0.5)
The notice `com.schabbauer.AMSMailMenu.show` with the word `message`, `triage`, `settings`, `pressGear` or `close` makes the running app open (or close) that window (`SelfCheck.Hooks`, behind the menu bar icon); `message` opens the newest email that is already read, so nothing changes in Mail; `pressGear` makes the running app press its own gear button in the open list (found by its identifier `settingsGear`), so the real button can be tried without a mouse; `settings` goes the same way as the gear (`SelfCheck.showSettings`). `warningLook` (0.9.3) shows the menu bar warning mark for 8 seconds without touching Mail or the list, then reads Mail again — photograph the menu bar with `screencapture -x -R <x>,0,70,30`. The menu bar label is ONE picture (`MenuBarArt.label`): a SwiftUI menu bar label shows only its first picture, so a second picture for the time was dropped (seen 26 Nov 2026); envelope, number and time are drawn side by side into one image — a template when nothing in it has its own colour, otherwise the plain parts are painted black by day and white at night. Then `screencapture -l <window number>`. `--picture <file> --view list|message|triage|file|paragon|settings|guide|news [--dark]` draws any screen with invented emails.

## 0.9.7 (16), 26 Nov 2026: wrong texts fixed
Texts only; no behaviour changed. How it works: "no passwords, nothing leaves your Mac" made true for the Gmail connection; "three tabs" now four (Settings, Gmail, How it works, What's new); "part Gmail" now "tab Gmail". README: tabs, "Mark read", what talks to Google, version, "not yet built" line removed. This specification: account colours (violet and green, not blue and orange), Mail started on a click since 0.9.5, Gmail connection and password wording, four tabs, "Mark read", status line.

## How it works and What's new
- How it works (`GuideView`): a guide to every part of the app, ending with "Signs in this app": every mark and colour with its meaning.
- What's new (`WhatsNewView`): every version, newest first.

## Open at login, the keeper, only one copy (`Keeper.swift`, rules in Core `KeeperRules.swift`)
Same design as AMS Mic Check.
- "Open at login" uses the Mac's login list (`SMAppService.mainApp`). The wish is remembered (`wantsOpenAtLogin`) and put right at every start.
- While it is on, the app writes `~/Library/LaunchAgents/com.schabbauer.AMSMailMenu.keeper.plist` (run at load, keep alive unless the app ended cleanly). A copy opened by hand hands itself over to the keeper's copy (`--keeper`). `--plain` never hands over.
- A polite stop (Quit, SIGTERM) is a clean end: the keeper does not open the app again. A sudden stop is not: the keeper opens it again.
- Only in an Applications folder; a copy in a build folder never becomes the keeper's.
- Only one copy: the copy that started first stays, a later one quits at once.
- `Tools/install.sh` stops the app politely, tells the Mac to forget the old start order, installs, opens, and says whether the app runs under the keeper (only when "Open at login" is on).

## App icon
`App/Resources/AppIcon.icns`: a rounded tile (824 of 1024 points, corner 176, as AMS Mic Check) in the app's blue (10, 92, 196 — the blue of the menu bar envelope), with the white hand-drawn envelope "envelope" ("Mail", Everyday) of the AMS Icon Library. Flat, no glow. `Tools/make_icon.py` makes it again from the library's tile `png/app-icon/envelope-1024.png`.
