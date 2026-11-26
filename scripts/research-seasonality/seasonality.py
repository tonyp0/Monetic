"""Shared rules for the seasonal lodging index. Standard library only.

Used by research.py (to shape drafts), review.py (before approving) and
scripts/build-cost-data.py (which refuses to ship anything that breaks them).

An index is 12 whole-number percentages, January first: how a destination's
typical hotel price in that month compares with its annual average. They
average 100, so the index moves cost between months without raising or
lowering the year as a whole.
"""

import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
COST_DATA = ROOT / "Monetic" / "Resources" / "cost-data.json"
DESTINATIONS = Path(__file__).resolve().parent / "destinations.txt"
# The override exists for test_validation.py, which feeds the build bad files.
APPROVED = Path(os.environ.get("MONETIC_SEASONALITY_APPROVED") or ROOT / "data" / "seasonality" / "approved.json")
DRAFTS = ROOT / "data" / "seasonality" / "drafts"

MONTHS = 12
LOW, HIGH = 60, 200
TOTAL = 100 * MONTHS          # 12 values averaging 100
TOLERANCE = MONTHS            # averaging 100 ± 1
DAY = re.compile(r"\d{4}-\d{2}-\d{2}")


class SeasonalityError(ValueError):
    """An index that mustn't ship."""


def normalize(values):
    """Scales positive numbers so they average 100, rounded half up to whole
    numbers; any rounding remainder goes to the largest month (the first one
    on a tie), so the 12 values add up to exactly 1200."""
    if len(values) != MONTHS or any(not isinstance(v, (int, float)) or isinstance(v, bool) or v <= 0
                                    for v in values):
        raise SeasonalityError(f"need {MONTHS} positive numbers, got {values!r}")
    total = sum(values)
    scaled = [int(v * TOTAL / total + 0.5) for v in values]
    largest = scaled.index(max(scaled))
    scaled[largest] += TOTAL - sum(scaled)
    return scaled


def clamp(values):
    """Each month kept within 60–200%. Returns (values, whether any moved)."""
    clamped = [min(max(v, LOW), HIGH) for v in values]
    return clamped, clamped != list(values)


def shape(raw):
    """Normalize, then clamp, repeating until both hold (clamping can move
    the average off 100 and normalizing can push a month back out). Returns
    (values, clamped) where clamped says whether any month hit a limit."""
    values, ever_clamped = normalize(raw), False
    for _ in range(20):
        values, moved = clamp(values)
        ever_clamped |= moved
        if not moved and sum(values) == TOTAL:
            break
        values = normalize(values)
    return values, ever_clamped


def load_locations(path=COST_DATA):
    return {loc["id"]: loc for loc in json.loads(Path(path).read_text(encoding="utf-8"))["locations"]}


def check_destination(location_id, locations):
    """A place the index may be researched for: in the data, one season."""
    location = locations.get(location_id)
    if location is None:
        raise SeasonalityError(f"{location_id}: not a location in cost-data.json")
    if len(location["seasons"]) != 1:
        raise SeasonalityError(f"{location_id}: has {len(location['seasons'])} per diem seasons; "
                          "seasonal per diem rates already price the time of year")
    return location


def read_destinations(path=DESTINATIONS):
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    return [line.split("#")[0].strip() for line in lines if line.split("#")[0].strip()]


def validate_entry(entry, locations):
    """Raises SeasonalityError unless an approved entry is safe to ship."""
    where = entry.get("id", "<no id>") if isinstance(entry, dict) else "<not an object>"
    if not isinstance(entry, dict):
        raise SeasonalityError(f"{where}: entry must be an object")
    check_destination(entry.get("id"), locations)
    values = entry.get("lodgingPercentByMonth")
    if not isinstance(values, list) or len(values) != MONTHS:
        raise SeasonalityError(f"{where}: needs exactly {MONTHS} monthly values")
    if any(not isinstance(v, int) or isinstance(v, bool) for v in values):
        raise SeasonalityError(f"{where}: monthly values must be whole numbers")
    if any(not LOW <= v <= HIGH for v in values):
        raise SeasonalityError(f"{where}: every month must be within {LOW}–{HIGH}%")
    if abs(sum(values) - TOTAL) > TOLERANCE:
        raise SeasonalityError(f"{where}: months average {sum(values) / MONTHS:.2f}, not 100 ± 1")
    sources = entry.get("sources")
    if not isinstance(sources, list) or not sources or any(
            not isinstance(s, str) or not s.startswith("https://") for s in sources):
        raise SeasonalityError(f"{where}: needs at least one https source")
    if not isinstance(entry.get("reviewedBy"), str) or not entry["reviewedBy"].strip():
        raise SeasonalityError(f"{where}: needs a named reviewer")
    if not isinstance(entry.get("reviewedAt"), str) or not DAY.fullmatch(entry["reviewedAt"]):
        raise SeasonalityError(f"{where}: reviewedAt must be yyyy-MM-dd")


def load_approved(locations, path=APPROVED):
    """The approved entries, validated, sorted by ID. A missing file is none."""
    path = Path(path)
    if not path.exists():
        return []
    entries = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(entries, list):
        raise SeasonalityError(f"{path.name}: must be a JSON list")
    ids = [e.get("id") for e in entries if isinstance(e, dict)]
    if len(set(ids)) != len(ids):
        raise SeasonalityError(f"{path.name}: a location is listed twice")
    for entry in entries:
        validate_entry(entry, locations)
    return sorted(entries, key=lambda e: e["id"])
