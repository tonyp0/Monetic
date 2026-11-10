#!/bin/sh
# Runs Monetic's tests on an available iPhone simulator.
#
#   scripts/test.sh          unit tests only (fast — run before every PR)
#   scripts/test.sh ui       UI tests only
#   scripts/test.sh all      everything, including the demo tour
#
# Set DESTINATION to override the simulator, e.g.
#   DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=18.0' scripts/test.sh
set -eu

cd "$(dirname "$0")/.."

# After an Xcode update, simulators stay disabled until first-launch setup runs.
if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    echo "Xcode hasn't finished its first-launch setup, so simulators are unavailable."
    echo "Run:  sudo xcodebuild -runFirstLaunch   (or open Xcode once), then try again."
    exit 1
fi

if [ -z "${DESTINATION:-}" ]; then
    # `simctl list` groups devices by runtime, oldest first, so the last iPhone
    # listed is on the newest iOS installed.
    udid=$(xcrun simctl list devices available \
        | grep -E '^ +iPhone' \
        | tail -n 1 \
        | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
    if [ -z "$udid" ]; then
        echo "No iPhone simulator found. Add one in Xcode → Window → Devices and Simulators."
        exit 1
    fi
    DESTINATION="id=$udid"
fi

case "${1:-unit}" in
    unit) only="-only-testing:MoneticTests" ;;
    ui)   only="-only-testing:MoneticUITests" ;;
    all)  only="" ;;
    *)    echo "Usage: scripts/test.sh [unit|ui|all]"; exit 2 ;;
esac

echo "Testing on: $DESTINATION"
# shellcheck disable=SC2086 # $only is intentionally unquoted so it can be empty
xcodebuild test \
    -project Monetic.xcodeproj \
    -scheme Monetic \
    -destination "$DESTINATION" \
    $only
