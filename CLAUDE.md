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
  AMS Mail Menu has none of these yet.

## This project

- Rebuilt in that shape on 2026-11-23 from branch `claude/ams-mail-menu-step1` (old layout, kept).
- `Core`: 19 tests pass on Linux only with a stand-in for `NSAppleEventDescriptor`/`NSAppleScript`
  (not in the repo). On a Mac `swift test` needs no stand-in.
- `App` has never been compiled. No `.xcodeproj` is committed; `Tools/install.sh` generates it.
- A cloud (Linux) session cannot build or start the app. That needs a session on the Mac.
