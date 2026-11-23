# Notes for Claude — AMS Mail Menu

## Standing instruction from the owner (2026-11-23)

The owner's words:

> I want you to reuse the code and start from scratch.
> Use GitHub, Xcode etc as you have done for the other apps:
> AMS Deck Mate, AMS Mic Check, AMS Shortcut Overview, AMS Tidy Bar.

Context: said after a cloud session could not build the app (no Mac there) and
proposed that the owner start a separate session on the Mac. The owner answered "NO".

Claude's reading (interpretation, not the owner's words):
- Keep this project in the same shape as those four apps and work the same way.
- Do not hand the owner technical steps to carry out.

## How the four model apps are set up (read 2026-11-23)

- Folders: `App/Sources`, `App/Config/Info.plist`, `App/Resources`; `Core/` is a Swift package
  (rules + tests, `@testable import`); `Docs/SPEC.md`; `Tools/install.sh`; `project.yml` (XcodeGen).
- `project.yml`: bundle id `com.schabbauer.<Name>`, macOS 15.0, Swift 5, signing "Apple Development"
  with the team already used there, hardened runtime off, scheme named like the app, run config Release.
- Build and install happen ON THE MAC: `Tools/install.sh` runs `swift test` in `Core`,
  `xcodegen generate`, `xcodebuild` (Release, `-derivedDataPath build`), copies the app to
  `~/Applications` and starts it. GitHub Actions only runs `swift test --package-path Core` on `macos-15`.
- Commits go to `main` with messages like `0.6.2 (11): what changed`; version and build number are
  raised together in `project.yml`, `Info.plist`, README and SPEC.
- The model apps also have an app icon, a keeper (LaunchAgent that reopens the app) and a guide.
  AMS Mail Menu has the keeper, Open at login, the guide and What's new since 0.2; the app icon is still missing.

## This project

- Rebuilt in that shape on 2026-11-23 from branch `claude/ams-mail-menu-step1` (old layout, kept).
- `Core`: 19 tests pass on Linux only with a stand-in for `NSAppleEventDescriptor`/`NSAppleScript`
  (not in the repo). On a Mac `swift test` needs no stand-in.
- First build on the Mac, 2026-11-23 14:08: the app compiled with no errors and `Tools/install.sh` installed and
  started it. The `.xcodeproj` is committed, as in the model apps.
- 0.2 (2), 2026-11-23 14:12: keeper + Open at login (`App/Sources/Keeper.swift`, rules in Core `KeeperRules.swift`),
  `GuideView`, `WhatsNewView`, Settings in three tabs, 22 tests. Installed and running.
- Menu bar place: the owner's bar is full, a new icon lands off screen. The app saves
  `NSStatusItem Preferred Position Item-0` = 290 at first start (just left of Deck Mate). Seen on screen at x 952.
- NOT checked yet: reading real mail (Mail was closed, the icon showed the warning triangle; the Mac's question
  "may control Mail" is the owner's to answer), the list, Triage, the Settings window, the keeper with the switch on.
- App icon: the AMS icon library has no envelope. It needs a new icon in AMS-Icons first (shared; ask the owner).
- A cloud (Linux) session cannot build or start the app. That needs a session on the Mac.
