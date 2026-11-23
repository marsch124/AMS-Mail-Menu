# AMS Mail Menu

A small Mac menu bar app, version 0.1 (build 1). It shows your newest emails from Apple Mail, grouped by sender.

**Not yet built on a Mac.** The rules in `Core` pass their tests; the app itself has not been compiled yet (see "State" below).

- The newest emails (number set in Settings) from the Inboxes of all accounts in Apple Mail, grouped by sender, newest sender first.
- Each line: subject and time; Settings can add the first line of text and a coloured dot for the account.
- Click an email to open it: a small window in this app, Apple Mail at that exact email, or Spark (only brings Spark to the front).
- Hover an email, or right-click it: mark as read, reply, archive, delete. "Mark all read" per sender. Undo for 10 seconds after archive or delete.
- **Triage**: one email at a time, one key per decision. **D** delete · **A** archive · **F** file in a Mail folder · **P** to PARAGON · **M** mark as read · **R** reply · **Space** or **→** next · **←** back · **Z** undo · **Esc** close.
- The menu bar icon turns blue while new mail waits (Settings: count or dot instead).
- Apple Mail is read with AppleScript. No passwords are used or stored. Nothing leaves your Mac.

Build: `Tools/install.sh` (needs Xcode and XcodeGen). Rules and tests: `Core` (`swift test`). Details: [Docs/SPEC.md](Docs/SPEC.md).

## Where it lives
The installed app is at `~/Applications/AMS Mail Menu.app`.

## Folders
- `App/` the Mac app (Swift sources, project settings)
- `Core/` the rules (scripts for Apple Mail, grouping by sender, links) and their tests
- `Docs/` the written specification (`SPEC.md`)
- `Tools/` helper scripts

## State (23 Nov 2026)
- `Core` compiles and its 19 tests pass on Linux with a stand-in for the Mac-only AppleScript types. Two tests (do the scripts compile, reading Mail's answer) are only real on a Mac.
- `App` has never been compiled. The Xcode project is not in the repository yet; `Tools/install.sh` makes it from `project.yml` on the first build.
