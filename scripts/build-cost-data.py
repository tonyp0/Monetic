#!/usr/bin/env python3
"""Builds Monetic/Resources/cost-data.json from the raw per diem datasets.

    scripts/fetch-cost-data.sh          # downloads into data/raw/ (gitignored)
    python3 scripts/build-cost-data.py  # writes Monetic/Resources/cost-data.json

Standard library only. The output depends on nothing but the two input files:
no clock, no network, sorted keys and locations. Running it twice on the same
inputs gives a byte-identical file.

Every number in the output comes from one of these publications:

* GSA per diem rates, FY2027, continental U.S. (effective 2026-10-01).
  Lodging is the maximum nightly rate, M&IE the daily meals and incidentals
  rate. Seasonal rows give different rates for parts of the year.
* U.S. Department of State foreign per diem rates (DSSR 925), all locations,
  publication of 2026-11-01. Each post has its own effective date; seasonal
  posts have one row per season, given as month/day and sometimes wrapping
  past December 31.

Rows with a zero lodging or M&IE rate (a handful of State posts where lodging
is provided) are skipped: they don't describe what a visitor would pay.
"""

import html
import json
import re
import sys
import unicodedata
import zipfile
import xml.etree.ElementTree as ET
from datetime import date, datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
OUTPUT = ROOT / "Monetic" / "Resources" / "cost-data.json"

GSA_FILE = RAW / "gsa-per-diem-fy2027.xlsx"
GSA_URL = "https://www.gsa.gov/system/files/FY2027_PerDiemRates_Validated090126.xlsx"
GSA_PAGE = "https://www.gsa.gov/travel/plan-book/per-diem-rates/per-diem-files"
GSA_EFFECTIVE = "2026-10-01"

STATE_PUBLICATION = "20261101"
STATE_FILE = RAW / f"state-per-diem-{STATE_PUBLICATION}.html"
STATE_URL = "https://allowances.state.gov/web920/per_diem_action.asp"
STATE_PAGE = "https://allowances.state.gov/web920/per_diem.asp"

# Place names, not cost data: lets "austin texas" find a GSA row keyed "TX".
US_STATES = {
    "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California",
    "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware", "DC": "District of Columbia",
    "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho", "IL": "Illinois",
    "IN": "Indiana", "IA": "Iowa", "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana",
    "ME": "Maine", "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
    "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
    "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
    "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma", "OR": "Oregon",
    "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota",
    "TN": "Tennessee", "TX": "Texas", "UT": "Utah", "VT": "Vermont", "VA": "Virginia",
    "WA": "Washington", "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming",
}


def fail(message):
    sys.exit(f"build-cost-data: {message}")


# MARK: - Helpers

def slug(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-").upper()


SMALL_WORDS = {"and", "of", "the", "de", "da", "del", "la", "le", "les", "du", "y"}


def tidy_country(raw):
    """State lists most countries in capitals ("BOSNIA AND HERZEGOVINA") and a
    few as "Bahamas, The". Display them as "Bosnia and Herzegovina", "The Bahamas"."""
    name = raw.strip()
    if name.endswith(", The"):
        name = "The " + name[: -len(", The")]
    if name.upper() != name:
        return name  # already mixed case: leave as published
    words = []
    for i, word in enumerate(name.lower().split(" ")):
        if i > 0 and word in SMALL_WORDS:
            words.append(word)
            continue
        # "d'ivoire" -> "d'Ivoire", "people's" -> "People's"
        parts = word.split("'")
        parts = [parts[0][:1].upper() + parts[0][1:]] + [
            (p[:1].upper() + p[1:]) if len(p) > 1 else p for p in parts[1:]
        ]
        words.append("'".join(parts))
    return " ".join(words)


def derived_aliases(name):
    """Alternative names already present in the published name:
    "Jackson / Pinedale" -> Jackson, Pinedale;
    "Los Cabos (Cabo San Lucas and San Jose del Cabo)" -> Los Cabos, Cabo San Lucas, San Jose del Cabo;
    "Playa del Carmen, Quintana Roo" -> Playa del Carmen."""
    aliases = set()
    head, _, paren = name.partition("(")
    for part in re.split(r"\s*/\s*", head):
        part = part.split(",")[0].strip()
        if part:
            aliases.add(part)
    if paren:
        for part in re.split(r"\s*(?:,| and )\s*", paren.rstrip(") ")):
            if part.strip():
                aliases.add(part.strip())
    aliases.discard(name)
    return sorted(aliases)


def whole_dollars(text, where):
    text = text.strip().replace(",", "").replace("$", "")
    try:
        value = float(text)
    except ValueError:
        fail(f"not a number: {text!r} ({where})")
    if value != int(value):
        fail(f"expected whole dollars: {text!r} ({where})")
    return int(value)


def in_season(key, start, end):
    """Inclusive month-day range that may wrap past December 31."""
    if start <= end:
        return start <= key <= end
    return key >= start or key <= end


def check_coverage(location):
    """Every day of a non-leap year must fall in exactly one season."""
    seasons = location["seasons"]
    day = date(2027, 1, 1)
    while day.year == 2027:
        key = day.strftime("%m-%d")
        hits = [s for s in seasons if in_season(key, s["start"], s["end"])]
        if len(hits) != 1:
            fail(f"{location['id']}: {len(hits)} seasons cover {key}")
        day += timedelta(days=1)


def season(start, end, lodging, meals):
    return {"start": start, "end": end, "lodgingPerNight": lodging, "mealsPerDay": meals}


# MARK: - GSA (continental U.S.)

def read_xlsx_rows(path):
    ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    tag = "{%s}t" % ns["m"]
    with zipfile.ZipFile(path) as book:
        strings = [
            "".join(t.text or "" for t in si.iter(tag))
            for si in ET.fromstring(book.read("xl/sharedStrings.xml")).findall("m:si", ns)
        ]
        sheet = ET.fromstring(book.read("xl/worksheets/sheet1.xml"))
    rows = []
    for row in sheet.find("m:sheetData", ns).findall("m:row", ns):
        cells = {}
        for cell in row.findall("m:c", ns):
            column = re.match(r"[A-Z]+", cell.get("r")).group()
            kind, value = cell.get("t"), cell.find("m:v", ns)
            if kind == "inlineStr":
                cells[column] = "".join(t.text or "" for t in cell.iter(tag))
            elif value is None:
                cells[column] = ""
            elif kind == "s":
                cells[column] = strings[int(value.text)]
            else:
                cells[column] = value.text
        rows.append(cells)
    return rows


def gsa_month_day(text, where):
    text = text.strip()
    if re.fullmatch(r"\d+(\.0+)?", text):  # an Excel date serial
        return (date(1899, 12, 30) + timedelta(days=int(float(text)))).strftime("%m-%d")
    for fmt in ("%B %d, %Y", "%m/%d/%Y"):
        try:
            return datetime.strptime(text, fmt).strftime("%m-%d")
        except ValueError:
            pass
    fail(f"unrecognised GSA date {text!r} ({where})")


def build_gsa():
    rows = read_xlsx_rows(GSA_FILE)
    title = rows[0].get("A", "")
    if "FY2027" not in title or "October 1, 2026" not in title:
        fail(f"unexpected GSA title row: {title!r}")
    header = rows[1]
    expected = {"A": "STATE", "B": "DESTINATION", "C": "COUNTY/LOCATION DEFINED",
                "D": "SEASON BEGIN", "E": "SEASON END", "F": "FY27 Lodging Rate", "G": "FY27 M&IE"}
    if any(header.get(k, "").strip() != v for k, v in expected.items()):
        fail(f"unexpected GSA header: {header}")

    groups = {}
    for number, row in enumerate(rows[2:], start=3):
        destination = row.get("B", "").strip()
        if not destination:
            continue
        where = f"GSA row {number}"
        state = row.get("A", "").strip()
        lodging = whole_dollars(row.get("F", ""), where)
        meals = whole_dollars(row.get("G", ""), where)
        if lodging <= 0 or meals <= 0:
            continue
        start = gsa_month_day(row.get("D", ""), where)
        # GSA seasons are listed within one fiscal year; as month/day ranges
        # they repeat every year. End dates are inclusive.
        end = gsa_month_day(row.get("E", ""), where)
        if not state:
            # The "standard CONUS rate" row: applies to every county not listed.
            key = ("", "standard", "")
        else:
            key = (state, destination, row.get("C", "").strip())
        groups.setdefault(key, []).append(season(start, end, lodging, meals))

    locations = []
    used_ids = set()
    for (state, destination, county), seasons in groups.items():
        if state == "":
            loc_id, name, region, region_name = "GSA-US-STANDARD", "Anywhere else in the continental U.S.", None, None
            aliases = ["United States", "USA"]
        else:
            if state not in US_STATES:
                fail(f"unknown state code {state!r}")
            loc_id = f"GSA-{state}-{slug(destination)}"
            if loc_id in used_ids:
                loc_id = f"{loc_id}-{slug(county)}"
            name, region, region_name = destination, state, US_STATES[state]
            aliases = derived_aliases(destination)
        if loc_id in used_ids:
            fail(f"duplicate id {loc_id}")
        used_ids.add(loc_id)
        # A fiscal-year listing starts in October; "10-01 → 09-30" as one
        # season means all year.
        for s in seasons:
            if s["start"] == "10-01" and s["end"] == "09-30":
                s["start"], s["end"] = "01-01", "12-31"
        # GSA ends February on the 28th; Feb 29 is looked up as Feb 28 in the app.
        locations.append({
            "id": loc_id, "name": name, "country": "United States",
            "region": region, "regionName": region_name, "aliases": aliases,
            "source": "gsa", "effective": GSA_EFFECTIVE,
            "seasons": sorted(seasons, key=lambda s: s["start"]),
        })
    return locations


# MARK: - State Department (foreign)

def build_state():
    page = STATE_FILE.read_text(encoding="latin-1")
    selected = re.search(r"<option value='(\d{8})' selected='selected'>", page)
    if not selected or selected.group(1) != STATE_PUBLICATION:
        fail("State file isn't the pinned publication date")
    headers = [html.unescape(re.sub(r"<[^>]+>", "", h)).strip()
               for h in re.findall(r"<th>(.*?)</th>", page, re.S)]
    expected = ["Country Name", "Post Name", "Season Begin", "Season End", "Maximum Lodging Rate",
                "M & IE Rate", "Maximum Per Diem Rate", "Footnote", "Effective Date"]
    if headers[-9:] != expected:
        fail(f"unexpected State columns: {headers}")

    groups = {}
    for number, row in enumerate(re.findall(r"<tr[^>]*>(<td.*?)</tr>", page, re.S), start=1):
        cells = [html.unescape(re.sub(r"<[^>]+>", "", c)).strip()
                 for c in re.findall(r"<td[^>]*>(.*?)</td>", row, re.S)]
        if len(cells) != 9:
            continue
        where = f"State row {number}"
        country, post, begin, end, lodging, meals, _, _, effective = cells
        lodging, meals = whole_dollars(lodging, where), whole_dollars(meals, where)
        if lodging <= 0 or meals <= 0:
            continue
        if not re.fullmatch(r"\d\d/\d\d", begin) or not re.fullmatch(r"\d\d/\d\d", end):
            fail(f"unexpected season {begin}-{end} ({where})")
        month, day, year = effective.split("/")
        key = (country, post)
        group = groups.setdefault(key, {"seasons": [], "effective": []})
        group["seasons"].append(season(begin.replace("/", "-"), end.replace("/", "-"), lodging, meals))
        group["effective"].append(f"{year}-{month}-{day}")

    locations = []
    used_ids = set()
    for (country, post), group in groups.items():
        display_country = tidy_country(country)
        if post == "Other":
            name, aliases = "Other areas", []
        else:
            name, aliases = post, derived_aliases(post)
        loc_id = f"DOS-{slug(country)}-{slug(post)}"
        if loc_id in used_ids:
            fail(f"duplicate id {loc_id}")
        used_ids.add(loc_id)
        locations.append({
            "id": loc_id, "name": name, "country": display_country,
            "region": None, "regionName": None, "aliases": aliases,
            "source": "dos", "effective": max(group["effective"]),
            "seasons": sorted(group["seasons"], key=lambda s: s["start"]),
        })
    return locations


# MARK: - Output

def main():
    for path in (GSA_FILE, STATE_FILE):
        if not path.exists():
            fail(f"missing {path.relative_to(ROOT)} — run scripts/fetch-cost-data.sh first")

    locations = build_gsa() + build_state()
    for location in locations:
        check_coverage(location)
        for s in location["seasons"]:
            if s["lodgingPerNight"] <= 0 or s["mealsPerDay"] <= 0:
                fail(f"{location['id']}: non-positive rate")
        # Drop empty optional fields to keep the file small.
        for field in ("region", "regionName"):
            if location[field] is None:
                del location[field]
        if not location["aliases"]:
            del location["aliases"]
    locations.sort(key=lambda loc: loc["id"])

    data = {
        "meta": {
            "currency": "USD",
            # The newest publication date among the inputs, not the wall
            # clock, so rebuilding the same inputs gives the same bytes.
            "generatedAt": f"{STATE_PUBLICATION[:4]}-{STATE_PUBLICATION[4:6]}-{STATE_PUBLICATION[6:]}",
            "sources": [
                {
                    "id": "gsa",
                    "name": "GSA per diem rates, FY2027 (continental U.S.)",
                    "publisher": "U.S. General Services Administration",
                    "effective": GSA_EFFECTIVE,
                    "url": GSA_URL,
                    "page": GSA_PAGE,
                },
                {
                    "id": "dos",
                    "name": "Foreign per diem rates (DSSR 925), all locations",
                    "publisher": "U.S. Department of State, Office of Allowances",
                    "effective": f"{STATE_PUBLICATION[:4]}-{STATE_PUBLICATION[4:6]}-{STATE_PUBLICATION[6:]}",
                    "url": f"{STATE_URL}?CountryCode=0000&PublicationDate={STATE_PUBLICATION}",
                    "page": STATE_PAGE,
                },
            ],
        },
        "locations": locations,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    OUTPUT.write_text(text, encoding="utf-8")
    by_source = {s: sum(1 for l in locations if l["source"] == s) for s in ("gsa", "dos")}
    print(f"wrote {OUTPUT.relative_to(ROOT)}: {len(locations)} locations "
          f"({by_source['gsa']} GSA, {by_source['dos']} State), {len(text.encode())} bytes")


if __name__ == "__main__":
    main()
