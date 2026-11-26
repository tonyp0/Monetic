#!/bin/sh
# Runs Monetic's tests on an available iPhone simulator.
#
#   scripts/test.sh          unit tests only (fast — run before every PR)
#   scripts/test.sh ui       UI tests only (not the screenshot tour; see screenshots.sh)
#   scripts/test.sh all      everything, including the demo tour
#
# Set DESTINATION to override the simulator, e.g.
#   DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=18.0' scripts/test.sh
set -eu

cd "$(dirname "$0")/.."

# Picks DESTINATION (and checks Xcode is set up), shared with screenshots.sh.
. scripts/simulator.sh

case "${1:-unit}" in
    unit) only="-only-testing:MoneticTests" ;;
    ui)   only="-only-testing:MoneticUITests -skip-testing:MoneticUITests/ScreenTourUITests" ;;
    all)  only="" ;;
    *)    echo "Usage: scripts/test.sh [unit|ui|all]"; exit 2 ;;
esac

# The seasonal index rules: standard library only, no network or API key.
if [ "${1:-unit}" != ui ]; then
    python3 scripts/research-seasonality/test_validation.py
fi

echo "Testing on: $DESTINATION"
# shellcheck disable=SC2086 # $only is intentionally unquoted so it can be empty
xcodebuild test \
    -project Monetic.xcodeproj \
    -scheme Monetic \
    -destination "$DESTINATION" \
    $only
