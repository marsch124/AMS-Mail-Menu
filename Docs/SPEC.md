# AMS Mail Menu — specification

Version 0.4 (4), 23 Nov 2026. Mac only (macOS 15+), menu bar app without a Dock icon.

Status: written from the code. Nothing here has been tried on a Mac yet; see "Not yet checked".

## Purpose
See the newest emails without opening a mail app, and deal with them in a few clicks or keys.

## Overview
- Lives in the menu bar. No Dock icon.
- Reads Apple Mail through AppleScript (`NSAppleScript`, on the main thread). Never starts Mail by itself.
- Needs the Automation permission for Mail (macOS asks on first use). No passwords. Nothing leaves the Mac.
- Not sandboxed. Signed "Apple Development", same team as the other AMS Mac apps.

## The list
- The newest N emails (Settings, default 20, 5–100) across the Inboxes of all accounts. Each inbox is asked for N; the newest N overall are kept.
- Grouped by sender (lower-cased address, or the name if there is no address). Groups are ordered by their newest email; emails inside a group newest first (`SenderGrouping`).
- A sender is folded open when it has unread mail, unless folded by hand.
- Each line: account dot (iCloud blue, Gmail orange, others grey; decided from the account's name), subject, time; optional first line of text (first 400 characters read, first non-empty line, at most 120 characters).
- Refresh every 30 s / 1 / 2 / 5 minutes (default 1 minute, never under 15 s), and after every action.

## Menu bar icon
- No unread mail: outline envelope. A problem: warning triangle.
- Unread mail, by Settings: blue filled envelope (default), filled envelope with the count, or envelope with a dot.
- Optional: the time of the newest unread email next to the icon (default on).

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
Mail not open (button "Open Mail (hidden)"), access turned off (button to System Settings → Automation), access not yet asked, anything else with Mail's own message.

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
- Every question to Mail gives up after 30 seconds: "Apple Mail is busy" (`MailAccessProblem.mailBusy`, AppleScript -1712); the next regular reading tries again.

## Self-check (0.4, `SelfCheck.swift`)
`open -n "AMS Mail Menu.app" --args --check <file>` reads the inboxes once and writes into the file: how many emails, how many unread, how many per account, how many sender groups, how long it took. Never the words of an email. `--picture <file>` draws the list panel with six invented emails into a PNG (and its size into `<file>.txt`): the way to look at the layout without a click. `--probe <file>` times 13 fixed small questions to Mail. `--check <file> --helper` reads through the helper copy. Both run as the app itself (its own permission for Mail), before the one-copy rule, and quit.

## Layout: no padding (0.4, the owner's word: "take away all padding")
No empty space above or below anything. 4 points at the sides (3 inside the small tags), so letters do not touch an edge. One exception: 6 points around each window (list panel, message window, Triage), because the Mac rounds window corners and they cut into the words otherwise (the owner: "Terrible rounding"). Sender cards: corner 5. The list area is as tall as its emails up to 560 points (`fixedSize`), then it scrolls. Gaps between stacked things: 4 points at most. Rows are as tall as their words.

## Place in the menu bar
The icon gets a saved place at first start: 290 points from the right edge (`NSStatusItem Preferred Position Item-0`), just left of Deck Mate (272) and right of Tidy Bar's line (302). Without it the Mac puts a new icon at the far left of a full menu bar, where it is hidden. A place the owner drags it to is kept.

## Settings window
Three tabs, 480 x 560: Settings, How it works, What's new. The Settings tab ends with the section "Start" ("Open at login", off at first) and the version line ("Version 0.4 (4)").

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
