#!/usr/bin/env python3
"""Drafts a seasonal lodging index for destinations, using Claude with web search.

    export ANTHROPIC_API_KEY=...            # never stored by this script
    python3 scripts/research-seasonality/research.py DOS-MEXICO-CANCUN DOS-FRANCE-PARIS
    python3 scripts/research-seasonality/research.py --all    # everything in destinations.txt

Writes data/seasonality/drafts/<location-id>.json (gitignored). A draft is
never shipped: a person reads it with review.py and approves it into
data/seasonality/approved.json, and only that file reaches the app.

This is the only Monetic code that uses the network or an API key. It isn't
part of scripts/test.sh or CI. Needs the `anthropic` package (see README.md).
"""

import argparse
import json
import os
import sys
from datetime import date

import seasonality as s

MODEL = "claude-opus-5-5"

SCHEMA = {
    "type": "object",
    "properties": {
        "months": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "month": {"type": "integer"},
                    "percent": {"type": "integer"},
                    "reason": {"type": "string"},
                    "sources": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["month", "percent", "reason", "sources"],
                "additionalProperties": False,
            },
        },
        "notes": {"type": "string"},
    },
    "required": ["months", "notes"],
    "additionalProperties": False,
}

INSTRUCTIONS = """You research how hotel prices at a travel destination change through the year, for a budgeting app's trip estimates.

Use web search to find evidence: hotel price indexes, booking-site price calendars, tourism board or statistics office occupancy and rate data, and travel guides that describe high and low seasons with prices.

Answer with the typical hotel price in each month relative to that destination's annual average, as 12 whole-number percentages: 100 means an average month, 135 means 35% above average, 80 means 20% below. Give one entry per month, January (1) to December (12). For each month give a one-line reason and at least one source URL you actually found in your searches and that supports the number. Never cite a URL you didn't see in search results, and never invent a figure. If evidence for a month is thin, say so in its reason and keep its percentage close to its neighbours. Use "notes" for caveats: holidays that move between months (Easter, Lunar New Year), events, or a city that differs from its wider region."""


def validate_answer(answer):
    """Raises SeasonalityError unless the model's answer is one entry per
    month, each with a positive percentage, a reason and an https source."""
    if not isinstance(answer, dict) or not isinstance(answer.get("months"), list):
        raise s.SeasonalityError("answer has no months list")
    months = answer["months"]
    numbers = [m.get("month") if isinstance(m, dict) else None for m in months]
    if any(not isinstance(n, int) or isinstance(n, bool) for n in numbers) or sorted(numbers) != list(range(1, 13)):
        raise s.SeasonalityError("answer must have exactly one entry for each month 1–12")
    for m in months:
        if not isinstance(m.get("percent"), int) or isinstance(m["percent"], bool) or m["percent"] <= 0:
            raise s.SeasonalityError(f"month {m['month']}: percent must be a positive whole number")
        if not isinstance(m.get("reason"), str) or not m["reason"].strip():
            raise s.SeasonalityError(f"month {m['month']}: needs a reason")
        sources = m.get("sources")
        if not isinstance(sources, list) or not sources or any(
                not isinstance(u, str) or not u.startswith("https://") for u in sources):
            raise s.SeasonalityError(f"month {m['month']}: needs at least one https source")
    return sorted(months, key=lambda m: m["month"])


def unique(items):
    return list(dict.fromkeys(items))


def make_draft(location, answer, model, search_results, today):
    """The draft file's contents. Pure, so it can be tested without the API."""
    months = validate_answer(answer)
    raw = [m["percent"] for m in months]
    values, clamped = s.shape(raw)
    cited = unique(u for m in months for u in m["sources"])
    seen = set(search_results)
    return {
        "id": location["id"],
        "name": location["name"],
        "country": location["country"],
        "model": model,
        "researchedAt": today,
        "lodgingPercentByMonth": values,
        "rawPercentByMonth": raw,
        "clamped": clamped,
        "months": [{"month": m["month"], "percent": m["percent"], "reason": m["reason"].strip(),
                    "sources": m["sources"]} for m in months],
        "notes": answer.get("notes", "").strip(),
        "sources": cited,
        # Cited URLs that didn't appear in this run's search results. Not
        # necessarily wrong, but the reviewer should open them first.
        "unverifiedSources": [u for u in cited if u not in seen],
        "searchResults": search_results,
    }


def ask(client, location):
    """One research request, resumed across pause_turn. Returns the parsed
    answer, the model that answered and every URL web search returned."""
    place = location["name"] if location["name"] != "Other areas" else f"{location['country']} (outside its main cities)"
    messages = [{"role": "user", "content": f"Destination: {place}, {location['country']}."}]
    search_results = []
    for _ in range(6):
        response = client.beta.messages.create(
            model=MODEL,
            max_tokens=16000,
            # If a safety classifier declines, the API retries on a fallback
            # model in the same call; `response.model` records who answered.
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
            thinking={"type": "adaptive"},
            output_config={"effort": "high", "format": {"type": "json_schema", "schema": SCHEMA}},
            tools=[{"type": "web_search_20260209", "name": "web_search", "max_uses": 10}],
            system=INSTRUCTIONS,
            messages=messages,
        )
        for block in response.content:
            if block.type == "web_search_tool_result" and isinstance(block.content, list):
                search_results += [r.url for r in block.content if getattr(r, "url", None)]
        if response.stop_reason != "pause_turn":
            break
        # The server paused its search loop; send the turn back to resume it.
        messages = messages + [{"role": "assistant", "content": response.content}]
    if response.stop_reason == "refusal":
        raise s.SeasonalityError("the model declined this request")
    if response.stop_reason != "end_turn":
        raise s.SeasonalityError(f"stopped early ({response.stop_reason})")
    texts = [b.text for b in response.content if b.type == "text"]
    if not texts:
        raise s.SeasonalityError("no answer text")
    try:
        answer = json.loads(texts[-1])
    except json.JSONDecodeError as error:
        raise s.SeasonalityError(f"answer isn't JSON: {error}")
    return answer, response.model, unique(search_results)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("ids", nargs="*", help="cost-data.json location IDs")
    parser.add_argument("--all", action="store_true", help="every ID in destinations.txt")
    args = parser.parse_args()
    ids = s.read_destinations() if args.all else args.ids
    if not ids:
        parser.error("name at least one location ID, or --all")

    locations = s.load_locations()
    try:
        targets = [s.check_destination(i, locations) for i in ids]   # fail before spending anything
    except s.SeasonalityError as error:
        sys.exit(f"research: {error}")

    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        sys.exit("research: set ANTHROPIC_API_KEY in the environment first")
    try:
        import anthropic
    except ImportError:
        sys.exit("research: the anthropic package isn't installed (see README.md)")
    client = anthropic.Anthropic(api_key=key)

    s.DRAFTS.mkdir(parents=True, exist_ok=True)
    failures = 0
    for location in targets:
        print(f"{location['id']}: researching…", flush=True)
        try:
            answer, model, results = ask(client, location)
            draft = make_draft(location, answer, model, results, date.today().isoformat())
        except (s.SeasonalityError, anthropic.APIError) as error:
            failures += 1
            print(f"{location['id']}: rejected, no draft written: {error}", file=sys.stderr)
            continue
        path = s.DRAFTS / f"{location['id']}.json"
        path.write_text(json.dumps(draft, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        flags = []
        if draft["clamped"]:
            flags.append("CLAMPED to 60–200%")
        if draft["unverifiedSources"]:
            flags.append(f"{len(draft['unverifiedSources'])} cited URL(s) not in search results")
        print(f"{location['id']}: wrote {path.relative_to(s.ROOT)}"
              + (f"  [{'; '.join(flags)}]" if flags else ""))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
