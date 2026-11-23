# AMS Mail Menu — specification

Version 0.1 (1), 23 Nov 2026. Mac only (macOS 15+), menu bar app without a Dock icon.

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
- The app has never been compiled or run.
- Archive mailbox names for iCloud and Gmail (the list is a guess).
- Nested folder paths in the File picker.
- Whether the blue icon keeps its colour in the menu bar.
- Whether PARAGON makes the `[Mail](message://…)` link clickable.
- Speed of reading with "first line of text" on.

## Not in this version (compared with the other AMS Mac apps)
No app icon, no "Open at login", no keeper, no "How it works" guide.
