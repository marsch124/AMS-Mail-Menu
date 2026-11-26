# AMS Mail Menu

A small Mac menu bar app, version 0.9.7 (build 16). It shows your newest emails from Apple Mail, grouped by sender.

- The newest emails (number set in Settings) from the Inboxes of all accounts in Apple Mail, grouped by sender, newest sender first.
- Each line: subject and time; Settings can add the first line of text and a coloured dot for the account.
- Click an email to open it: a small window in this app, Apple Mail at that exact email, or Spark (only brings Spark to the front).
- Hover an email, or right-click it: mark as read, reply, archive, delete. "Mark read" per sender (marks all of that sender's emails as read). Undo for 10 seconds after archive or delete.
- **Triage**: one email at a time, one key per decision. **D** delete · **A** archive · **F** file in a Mail folder · **P** to PARAGON · **M** mark as read · **R** reply · **Space** or **→** next · **←** back · **Z** undo · **Esc** close.
- The menu bar icon turns blue while new mail waits (Settings: count or dot instead).
- Settings has four tabs: Settings (with "Open at login"), Gmail, How it works (the guide, with "Signs in this app") and What's new. The version number shows there.
- While "Open at login" is on, a keeper opens the app again if it ever stops unexpectedly. Only one copy runs.
- Archiving a Gmail email works through a direct connection to Gmail that you set up yourself in Settings (Gmail address and a Google app password, kept in the Mac's Keychain). Without it, Archive on a Gmail email changes nothing and says so. Other accounts archive through Apple Mail.
- Apple Mail is read with AppleScript. Without the Gmail connection nothing leaves your Mac. With it, only Connect, Archive and Undo for a Gmail email talk to Google.
- Click the orange envelope while Mail is closed and the app opens Mail, hidden. A two-finger click on the envelope opens a small menu.

Build: `Tools/install.sh` (needs Xcode and XcodeGen). Rules and tests: `Core` (`swift test`). Details: [Docs/SPEC.md](Docs/SPEC.md).

## Where it lives
The installed app is at `~/Applications/AMS Mail Menu.app`.

## Folders
- `App/` the Mac app (Swift sources, project settings)
- `Core/` the rules (scripts for Apple Mail, grouping by sender, links) and their tests
- `Docs/` the written specification (`SPEC.md`)
- `Tools/` helper scripts

## State (23 Nov 2026)
- Built, installed and started on the Mac on 23 Nov 2026. The 22 tests in `Core` pass there.
- App icon: `App/Resources/AppIcon.icns`, made by `Tools/make_icon.py` from the envelope of the AMS Icon Library.
