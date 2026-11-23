# Notes for Claude — AMS Mail Menu

## Standing instruction from the owner (2026-11-23)

The owner's words:

> I want you to reuse the code and start from scratch.
> Use GitHub, Xcode etc as you have done for the other apps:
> AMS Deck Mate, AMS Mic Check, AMS Shortcut Overview, AMS Tidy Bar.

Context: said after a cloud session could not build the app (no Mac there) and
proposed that the owner start a separate session on the Mac. The owner answered "NO".

Claude's reading (interpretation, not the owner's words):
- Set this project up anew, the same way as those four apps (repositories
  marsch124/AMS-Deck-Mate, AMS-Mic-Check, AMS-Shortcut-Overview, AMS-Tidy-Bar):
  look at their project layout, GitHub workflows and delivery first, then copy that pattern.
- Reuse the existing Swift code from branch `claude/ams-mail-menu-step1`
  (`AMSMailMenu/`, `MailMenuCore/`, `MailMenuCoreTests/`) instead of rewriting it.
- Do not hand the owner technical steps to carry out.

## State of the existing code (checked 2026-11-23, commit 482f075)

- `MailMenuCore/` compiles with Swift 6.0 on Linux; its 19 unit tests pass there, but with a
  stand-in for the Mac-only AppleScript types, so the two AppleScript tests are not truly verified.
- `AMSMailMenu/` (SwiftUI/AppKit) has never been compiled.
- The hand-written `AMSMailMenu.xcodeproj` has never been opened by Xcode.
