#!/bin/sh
# Captures every main screen in light and dark mode (ScreenTourUITests) and
# exports the screenshots as PNGs.
#
#   scripts/screenshots.sh            → screenshots/<short git SHA>/
#   scripts/screenshots.sh before     → screenshots/before/
#
# Files are named NN-screen-mode.png, e.g. 03-home-top-dark.png.
# DESTINATION overrides the simulator, as in scripts/test.sh.
set -eu

cd "$(dirname "$0")/.."

. scripts/simulator.sh

label=${1:-$(git rev-parse --short HEAD)}
case "$label" in
    ''|*/*|.|..) echo "Label must be a plain name, got: '$label'"; exit 2 ;;
esac
out="screenshots/$label"
work=$(mktemp -d "${TMPDIR:-/tmp}/monetic-screenshots.XXXXXX")
trap 'rm -rf "$work"' EXIT
bundle="$work/ScreenTour.xcresult"

rm -rf "$out"
mkdir -p "$out"

echo "Capturing screens on: $DESTINATION"
status=0
xcodebuild test \
    -project Monetic.xcodeproj \
    -scheme Monetic \
    -destination "$DESTINATION" \
    -only-testing:MoneticUITests/ScreenTourUITests \
    -resultBundlePath "$bundle" \
    || status=$?

if [ ! -d "$bundle" ]; then
    echo "No result bundle was written, so there's nothing to export."
    exit "${status:-1}"
fi

# Export even after a failure: the screens captured before it are still useful.
if xcrun xcresulttool export attachments --help >/dev/null 2>&1; then
    # Xcode 16+: writes the files plus a manifest.json that maps them to names.
    xcrun xcresulttool export attachments --path "$bundle" --output-path "$work/attachments"
    mode=manifest
else
    mode=legacy
fi

python3 -I - "$mode" "$bundle" "$work/attachments" "$out" <<'PY'
import json, os, re, shutil, subprocess, sys

mode, bundle, exported, out = sys.argv[1:5]

def clean(name):
    # "03-home-top-dark_0_1A2B…-…" → "03-home-top-dark"; keep only safe characters.
    name = os.path.splitext(name)[0]
    name = re.sub(r"_\d+_[0-9A-Fa-f-]{36}$", "", name)
    return re.sub(r"[^A-Za-z0-9._-]", "_", name) or "attachment"

def place(src, name):
    # Keep only the tour's own NN-screen-mode shots, not the recordings and
    # snapshots Xcode attaches to a failure.
    if not re.match(r"\d\d-", name):
        return
    ext = os.path.splitext(src)[1] or ".png"
    shutil.copyfile(src, os.path.join(out, clean(name) + ext))

if mode == "manifest":
    with open(os.path.join(exported, "manifest.json")) as f:
        manifest = json.load(f)
    for test in manifest:
        for item in test.get("attachments", []):
            place(os.path.join(exported, item["exportedFileName"]),
                  item.get("suggestedHumanReadableName") or item["exportedFileName"])
    sys.exit(0)

# Older Xcode: walk the result graph to each attachment's payload and export it.
# Xcode 16 needs --legacy for these commands; earlier ones reject the flag.
def tool(*args):
    for legacy in (["--legacy"], []):
        cmd = ["xcrun", "xcresulttool"] + list(args[:1])
        if args[0] in ("get", "export"):
            cmd += ["object"] if legacy else []
        cmd += legacy + list(args[1:])
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout
    raise SystemExit("xcresulttool failed: " + " ".join(args))

def get(ref=None):
    args = ["get", "--format", "json", "--path", bundle]
    if ref:
        args += ["--id", ref]
    return json.loads(tool(*args))

def values(node, key):
    return node.get(key, {}).get("_values", [])

def walk(node, found):
    if isinstance(node, dict):
        # Each test's activities (and their attachments) live behind a summaryRef.
        ref = node.get("summaryRef", {}).get("id", {}).get("_value")
        if ref:
            walk(get(ref), found)
        for attachment in values(node, "attachments"):
            ref = attachment.get("payloadRef", {}).get("id", {}).get("_value")
            name = attachment.get("name", {}).get("_value") or attachment.get("filename", {}).get("_value")
            if ref and name:
                found.append((ref, name))
        for value in node.values():
            walk(value, found)
    elif isinstance(node, list):
        for value in node:
            walk(value, found)

root = get()
found = []
for action in values(root, "actions"):
    ref = action.get("actionResult", {}).get("testsRef", {}).get("id", {}).get("_value")
    if ref:
        walk(get(ref), found)
for ref, name in found:
    if not re.match(r"\d\d-", name):
        continue
    target = os.path.join(out, clean(name) + ".png")
    tool("export", "--type", "file", "--path", bundle, "--id", ref, "--output-path", target)
PY

count=$(find "$out" -type f | wc -l | tr -d ' ')
echo
echo "Wrote $count screenshot(s) to $out/:"
ls "$out"
exit "$status"
