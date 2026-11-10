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
# Local Macs only: CI images come set up, and the fix needs sudo anyway.
if [ -z "${CI:-}" ] && ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    echo "Xcode hasn't finished its first-launch setup, so simulators are unavailable."
    echo "Run:  sudo xcodebuild -runFirstLaunch   (or open Xcode once), then try again."
    exit 1
fi

if [ -z "${DESTINATION:-}" ]; then
    # Pick the iPhone simulator on the newest iOS this Xcode can actually run.
    # `simctl list` can't be used for this: it also lists runtimes that belong
    # to other installed Xcodes, and its order isn't reliably by version.
    udid=$(xcodebuild -showdestinations -project Monetic.xcodeproj -scheme Monetic 2>/dev/null \
        | grep 'platform:iOS Simulator' \
        | grep 'name:iPhone' \
        | grep 'OS:' \
        | sed -E 's/.*id:([0-9A-F-]+), OS:([0-9.]+),.*/\2 \1/' \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -n 1 \
        | cut -d' ' -f2)
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
