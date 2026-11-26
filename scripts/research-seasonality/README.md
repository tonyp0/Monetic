# Seasonal lodging index

Per diem rates for most foreign destinations are the same all year, so spring
break in Cancún would cost the same as September. This folder drafts a
**seasonal lodging index** for a reviewed list of popular destinations: 12
monthly percentages of the annual average hotel price (Cancún in March might be
135%, in September 80%).

**AI researches, people approve, the app does plain math.**

- `research.py` asks Claude (`claude-opus-5-5`, with web search) for a draft,
  with a one-line reason and at least one cited source URL for every month.
  It's the only Monetic code that uses the network or an API key, and it isn't
  part of `scripts/test.sh` or CI.
- Drafts go to `data/seasonality/drafts/` (gitignored) and never ship.
- A person reads a draft with `review.py` and approves it into
  `data/seasonality/approved.json` (committed), with their name and the date.
- `scripts/build-cost-data.py` copies only approved entries into
  `Monetic/Resources/cost-data.json`. The app never calls a model: it
  multiplies each night's lodging by that month's percentage.

The index applies only to places with a single year-round per diem rate
(places with seasonal per diem rates already price the time of year), and only
to lodging.

## Setup (once)

Python 3 and the Anthropic SDK, for `research.py` only:

```sh
python3 -m venv .venv-research && . .venv-research/bin/activate
pip install anthropic
export ANTHROPIC_API_KEY=...        # read from the environment, never written anywhere
```

`review.py`, the build and the tests need only the standard library.

## Research

```sh
python3 scripts/research-seasonality/research.py DOS-MEXICO-CANCUN DOS-FRANCE-PARIS
python3 scripts/research-seasonality/research.py --all     # every ID in destinations.txt
```

IDs are `cost-data.json` location IDs. The script refuses an unknown or
multi-season ID before calling the API. Each answer must match the schema (12
months, each with a positive whole percentage, a reason and an https source),
or no draft is written. The 12 values are then normalized to average exactly
100 (rounded half up; the largest month absorbs the rounding) and clamped to
60–200%. Drafts flag clamping and any cited URL that wasn't among the search
results, so you know what to check first. Each draft records the model that
answered, the date and every search result URL.

The model can be wrong. Treat a draft as a research assistant's notes.

## Review and approve

```sh
python3 scripts/research-seasonality/review.py                      # drafts, and what's approved
python3 scripts/research-seasonality/review.py DOS-MEXICO-CANCUN    # month, %, reason, sources
python3 scripts/research-seasonality/review.py --approve DOS-MEXICO-CANCUN --reviewer "Your Name"
python3 scripts/build-cost-data.py
```

Open the sources before approving. Approving runs the same checks as the build
and replaces any earlier approval for that place. To withdraw an entry, delete
it from `approved.json` and rebuild.

## Rules the build enforces

An entry in `approved.json` fails the build if its place is unknown or has
more than one per diem season, it doesn't have exactly 12 whole numbers, any
value is outside 60–200, the values don't average 100 ± 1, it has no https
source, or it has no reviewer and `yyyy-MM-dd` review date. With an empty
`approved.json`, `cost-data.json` is byte-identical to a build without the
index.

## Tests

```sh
python3 scripts/research-seasonality/test_validation.py
```

Standard library only, no network. `scripts/test.sh` runs them too.
