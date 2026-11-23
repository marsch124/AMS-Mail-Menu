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
  AMS Mail Menu has the keeper, Open at login, the guide and What's new since 0.2, and the app icon since 0.3.

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
- The owner allowed Mail on 2026-11-23. NOT checked yet by a click: archive, delete, reply, the message window,
  Triage, send to PARAGON, the Settings window, the keeper with the switch on.
- 0.3 (3), 2026-11-23: app icon (`App/Resources/AppIcon.icns`, `Tools/make_icon.py`); the envelope was added to
  AMS-Icons as hand-drawn icon "envelope" ("Mail", Everyday).
- 0.4 (4), 2026-11-23 14:40: the regular reading runs in a helper copy of the app (`--worker`, see SPEC "Reading
  Mail"): NSAppleScript is only quick on a main thread (1 s; 30-40 s from a background queue — tried, measured,
  dropped). First lines of text are read after the list, one by one, once each (`content` is slow).
  A box Mail refuses as a range is read one email at a time, "Apple Mail is busy" after 30 s, all padding
  removed (owner: "take away all padding. Absolute all padding everywhere"), self-check `--check` / `--probe`.
  Checked with the self-check on his real mail: 24 emails, 6 unread, 2 accounts, 10 sender groups, 0.4 s.
- 0.5 (5), 2026-11-23 15:08: every window checked by Claude itself (owner: "I'm not here to check you"):
  Settings rebuilt without boxes, own tab row, Done; Triage key bar never cut, waits for the first reading;
  email text through `MessageLinks.tidyBody`; main buttons filled blue, Delete red; no bold in the windows.
  How to look: SPEC "Seeing the real windows" and "Checking the real panel without a click". 23 tests.
  NOT done on purpose: archive, delete, mark as read, reply, file, send to PARAGON on a real email (they change
  the owner's mail; ask first).
- A cloud (Linux) session cannot build or start the app. That needs a session on the Mac.
