#!/bin/bash
# Runs the rule tests, builds AMS Mail Menu and puts it in ~/Applications, then starts it.
# Stops at the first thing that fails, so a failed build never touches the app that is installed.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$HOME/Applications/AMS Mail Menu.app"
BUILT="$PWD/build/Build/Products/Release/AMS Mail Menu.app"
RUNNING="$APP/Contents/MacOS/"
SERVICE="gui/$(id -u)/com.schabbauer.AMSMailMenu.keeper"
ORDER="$HOME/Library/LaunchAgents/com.schabbauer.AMSMailMenu.keeper.plist"

version() { echo "$(defaults read "$1/Contents/Info" CFBundleShortVersionString) ($(defaults read "$1/Contents/Info" CFBundleVersion))"; }

(cd Core && swift test 2>&1 | grep -E "Executed|error:|failed" | tail -2)
xcodegen generate >/dev/null
xcodebuild -scheme "AMS Mail Menu" -configuration Release -derivedDataPath build build 2>&1 | grep -E "error|BUILD"
codesign --verify --deep --strict "$BUILT"
WANT="$(version "$BUILT")"

# The new app lands next to the old one first: a copy that fails leaves the old app whole.
mkdir -p "$HOME/Applications"
rm -rf "$APP.new"
ditto "$BUILT" "$APP.new"

# A polite stop: the app ends cleanly, so the keeper does not open it again. Wait up to 5 seconds,
# tell the Mac to forget the keeper's old start order, then stop what is left.
pkill -TERM -x "AMS Mail Menu" 2>/dev/null || true
for _ in $(seq 1 25); do
    pgrep -f "$RUNNING" >/dev/null || break
    sleep 0.2
done
launchctl bootout "$SERVICE" 2>/dev/null || true
pkill -KILL -x "AMS Mail Menu" 2>/dev/null || true
sleep 0.5

# Swap in one step, so there is never half an app.
rm -rf "$APP.old"
if [ -d "$APP" ]; then mv "$APP" "$APP.old"; fi
mv "$APP.new" "$APP"
rm -rf "$APP.old"
# Opened by hand: with "Open at login" on, the app writes the keeper's start order and hands itself over.
open -g "$APP"

# Confirm that what runs is what was built.
for _ in $(seq 1 25); do
    pgrep -f "$RUNNING" >/dev/null && break
    sleep 0.2
done
pgrep -f "$RUNNING" >/dev/null || { echo "error: the app did not start"; exit 1; }
HAVE="$(version "$APP")"
[ "$HAVE" = "$WANT" ] || { echo "error: installed $HAVE, built $WANT"; exit 1; }
echo "Installed and running: AMS Mail Menu $HAVE"

# With "Open at login" on, the app must end up as the keeper's copy.
if [ -f "$ORDER" ]; then
    for _ in $(seq 1 12); do
        sleep 0.5
        if launchctl print "$SERVICE" 2>/dev/null | grep -q "state = running"; then echo "running under the keeper"; exit 0; fi
    done
    echo "error: NOT under the keeper"; exit 1
fi
echo "Open at login is off: no keeper"
