#!/usr/bin/env python3
"""Reviews seasonal lodging drafts and approves them into the shipped data.

    python3 scripts/research-seasonality/review.py                 # list drafts and what's approved
    python3 scripts/research-seasonality/review.py DOS-MEXICO-CANCUN
    python3 scripts/research-seasonality/review.py --approve DOS-MEXICO-CANCUN --reviewer "Your Name"

Approving copies the draft into data/seasonality/approved.json (committed)
with your name and today's date, after the same checks the build runs. Then
rebuild: python3 scripts/build-cost-data.py. Approving is a person's job:
open the sources before you do.
"""

import argparse
import json
import sys
import textwrap
from datetime import date

import seasonality as s

MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def load_draft(location_id):
    path = s.DRAFTS / f"{location_id}.json"
    if not path.exists():
        sys.exit(f"review: no draft at {path.relative_to(s.ROOT)}; run research.py {location_id} first")
    return json.loads(path.read_text(encoding="utf-8"))


def table(draft):
    """The draft as readable text: one row per month, then notes and flags."""
    lines = [f"{draft['name']}, {draft['country']}  ({draft['id']})",
             f"Researched {draft['researchedAt']} by {draft['model']}", ""]
    lines.append(f"{'Month':<6}{'Index':>6}{'Raw':>6}  Reason / sources")
    for m, value in zip(draft["months"], draft["lodgingPercentByMonth"]):
        reason = textwrap.wrap(m["reason"], 70) or [""]
        lines.append(f"{MONTH_NAMES[m['month'] - 1]:<6}{value:>5}%{m['percent']:>5}%  {reason[0]}")
        lines += [" " * 20 + r for r in reason[1:]]
        lines += [" " * 20 + "↳ " + u for u in m["sources"]]
    lines.append("")
    lines.append(f"Average {sum(draft['lodgingPercentByMonth']) / 12:.2f}% (normalized from the raw answer)")
    if draft.get("notes"):
        lines += ["", "Notes: " + draft["notes"]]
    if draft.get("clamped"):
        lines += ["", "FLAG: some months were clamped to 60–200%; check them against the sources."]
    if draft.get("unverifiedSources"):
        lines += ["", "FLAG: cited but not seen in this run's search results (open these first):"]
        lines += ["  " + u for u in draft["unverifiedSources"]]
    return "\n".join(lines)


def approve(draft, reviewer, approved, locations, today):
    """approved.json's new contents with this draft in it (replacing an older
    approval for the same place). Raises SeasonalityError if it can't ship."""
    entry = dict(draft, reviewedBy=reviewer.strip(), reviewedAt=today)
    s.validate_entry(entry, locations)
    return sorted([e for e in approved if e.get("id") != entry["id"]] + [entry], key=lambda e: e["id"])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("id", nargs="?", help="a draft's location ID to print")
    parser.add_argument("--approve", metavar="ID", help="approve this draft into approved.json")
    parser.add_argument("--reviewer", help="your name, recorded with the approval")
    args = parser.parse_args()

    locations = s.load_locations()
    if args.approve:
        if not args.reviewer or not args.reviewer.strip():
            parser.error("--approve needs --reviewer \"Your Name\"")
        draft = load_draft(args.approve)
        print(table(draft), "\n")
        try:
            approved = s.load_approved(locations)
            entries = approve(draft, args.reviewer, approved, locations, date.today().isoformat())
        except s.SeasonalityError as error:
            sys.exit(f"review: not approved: {error}")
        s.APPROVED.parent.mkdir(parents=True, exist_ok=True)
        s.APPROVED.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Approved {args.approve} as {args.reviewer.strip()}. Now run: python3 scripts/build-cost-data.py")
    elif args.id:
        print(table(load_draft(args.id)))
    else:
        approved = {e["id"] for e in s.load_approved(locations)}
        drafts = sorted(p.stem for p in s.DRAFTS.glob("*.json")) if s.DRAFTS.exists() else []
        print("Drafts:" if drafts else "No drafts yet.")
        for d in drafts:
            print(f"  {d}{'  (approved)' if d in approved else ''}")
        print(f"Approved: {len(approved)}")


if __name__ == "__main__":
    main()
