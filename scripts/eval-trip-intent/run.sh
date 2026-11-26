#!/bin/zsh
# Scores "Describe your trip" against Apple's on-device model, using the 31
# sentences in trip-intent-cases.json. Not part of CI: it needs a device (or
# simulator) where Apple Intelligence is available and the model is ready.
#
#   scripts/eval-trip-intent/run.sh                              # default simulator
#   DESTINATION='platform=iOS,id=<device UDID>' scripts/eval-trip-intent/run.sh
#
# A real device needs a development team set for signing in Xcode.
# List devices with: xcrun xctrace list devices
set -euo pipefail
cd "$(dirname "$0")/../.."

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone Air}"
LOG="$(mktemp -t trip-intent-eval)"

set +e
TEST_RUNNER_TRIP_INTENT_EVAL=1 xcodebuild test \
  -project Monetic.xcodeproj -scheme Monetic \
  -destination "$DESTINATION" \
  -only-testing:MoneticTests/TripIntentEvalTests -parallel-testing-enabled NO \
  > "$LOG" 2>&1
result=$?
set -e

grep -h "TRIP-INTENT-EVAL" "$LOG" | sed 's/^.*TRIP-INTENT-EVAL /  /' | awk '!seen[$0]++' || true
echo "Full log: $LOG"
exit $result
