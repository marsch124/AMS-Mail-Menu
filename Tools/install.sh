#!/bin/bash
# Runs the rule tests, builds AMS Mail Menu and puts it in ~/Applications, then starts it.
# Stops at the first thing that fails, so a failed build never touches the app that is installed.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$HOME/Applications/AMS Mail Menu.app"
BUILT="$PWD/build/Build/Products/Release/AMS Mail Menu.app"
RUNNING="$APP/Contents/MacOS/"

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

# Wait until the old app has really quit (up to 5 seconds), then stop what is left.
osascript -e 'tell application id "com.schabbauer.AMSMailMenu" to quit' 2>/dev/null || true
for _ in $(seq 1 25); do
    pgrep -f "$RUNNING" >/dev/null || break
    sleep 0.2
done
pkill -f "$RUNNING" 2>/dev/null || true
sleep 0.5

# Swap in one step, so there is never half an app.
rm -rf "$APP.old"
if [ -d "$APP" ]; then mv "$APP" "$APP.old"; fi
mv "$APP.new" "$APP"
rm -rf "$APP.old"
open "$APP"

# Confirm that what runs is what was built.
for _ in $(seq 1 25); do
    pgrep -f "$RUNNING" >/dev/null && break
    sleep 0.2
done
pgrep -f "$RUNNING" >/dev/null || { echo "error: the app did not start"; exit 1; }
HAVE="$(version "$APP")"
[ "$HAVE" = "$WANT" ] || { echo "error: installed $HAVE, built $WANT"; exit 1; }
echo "Installed and running: AMS Mail Menu $HAVE"
