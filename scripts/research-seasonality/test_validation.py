#!/usr/bin/env python3
"""Tests for the seasonal index rules. Standard library only, no network.

    python3 scripts/research-seasonality/test_validation.py
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import research  # noqa: E402
import review  # noqa: E402
import seasonality as s  # noqa: E402

# TEST DATA ONLY: two made-up places.
LOCATIONS = {
    "ONE": {"id": "ONE", "name": "One Season", "country": "Testland",
            "seasons": [{"start": "01-01", "end": "12-31", "lodgingPerNight": 100, "mealsPerDay": 50}]},
    "TWO": {"id": "TWO", "name": "Two Seasons", "country": "Testland",
            "seasons": [{"start": "01-01", "end": "06-30", "lodgingPerNight": 100, "mealsPerDay": 50},
                        {"start": "07-01", "end": "12-31", "lodgingPerNight": 150, "mealsPerDay": 50}]},
}
GOOD = [120, 130, 135, 110, 90, 85, 95, 95, 80, 85, 85, 90]


def entry(**changes):
    base = {"id": "ONE", "lodgingPercentByMonth": list(GOOD), "sources": ["https://example.invalid/a"],
            "reviewedBy": "A Reviewer", "reviewedAt": "2026-11-25"}
    base.update(changes)
    return base


class NormalizeTests(unittest.TestCase):
    def test_averages_exactly_100(self):
        for raw in ([1] * 12, list(range(1, 13)), [300, 250, 200, 90, 80, 70, 60, 70, 80, 90, 150, 280],
                    [33.3] * 11 + [40]):
            values = s.normalize(raw)
            self.assertEqual(sum(values), 1200, raw)
            self.assertTrue(all(isinstance(v, int) for v in values))

    def test_scale_doesnt_matter(self):
        self.assertEqual(s.normalize([v * 7 for v in GOOD]), GOOD)
        self.assertEqual(s.normalize([1] * 12), [100] * 12)

    def test_rounding_remainder_goes_to_largest_month(self):
        # 1..12 scaled to 1200 is 15.38, 30.77, ... each rounds; the fix-up
        # lands on December, the largest.
        raw = list(range(1, 13))
        rounded = [int(v * 1200 / 78 + 0.5) for v in raw]
        values = s.normalize(raw)
        self.assertEqual(values[:11], rounded[:11])
        self.assertEqual(values[11], rounded[11] + 1200 - sum(rounded))

    def test_rejects_bad_input(self):
        for bad in ([100] * 11, [100] * 13, [100] * 11 + [0], [100] * 11 + [-5], [100] * 11 + [True],
                    [100] * 11 + ["100"]):
            with self.assertRaises(s.SeasonalityError, msg=bad):
                s.normalize(bad)

    def test_shape_clamps_and_flags(self):
        values, clamped = s.shape([1000] + [10] * 11)
        self.assertTrue(clamped)
        self.assertEqual(sum(values), 1200)
        self.assertTrue(all(60 <= v <= 200 for v in values))
        values, clamped = s.shape(GOOD)
        self.assertFalse(clamped)
        self.assertEqual(values, GOOD)


class EntryValidationTests(unittest.TestCase):
    def assertRejected(self, bad, message):
        with self.assertRaises(s.SeasonalityError) as caught:
            s.validate_entry(bad, LOCATIONS)
        self.assertIn(message, str(caught.exception))

    def test_good_entry_passes(self):
        s.validate_entry(entry(), LOCATIONS)
        s.validate_entry(entry(lodgingPercentByMonth=[101] * 12), LOCATIONS)   # average 101: within ±1

    def test_unknown_location(self):
        self.assertRejected(entry(id="NOPE"), "not a location")

    def test_multi_season_location(self):
        self.assertRejected(entry(id="TWO"), "per diem seasons")

    def test_wrong_number_of_values(self):
        self.assertRejected(entry(lodgingPercentByMonth=GOOD[:11]), "exactly 12")
        self.assertRejected(entry(lodgingPercentByMonth=GOOD + [100]), "exactly 12")
        self.assertRejected(entry(lodgingPercentByMonth="100"), "exactly 12")

    def test_values_not_whole_numbers(self):
        self.assertRejected(entry(lodgingPercentByMonth=[100.5] * 12), "whole numbers")

    def test_value_out_of_range(self):
        self.assertRejected(entry(lodgingPercentByMonth=[59] + [104] * 11), "60–200")
        self.assertRejected(entry(lodgingPercentByMonth=[201] + [91] * 11), "60–200")

    def test_average_not_100(self):
        self.assertRejected(entry(lodgingPercentByMonth=[102] * 12), "not 100")
        self.assertRejected(entry(lodgingPercentByMonth=[98] * 12), "not 100")

    def test_needs_https_sources(self):
        self.assertRejected(entry(sources=[]), "source")
        self.assertRejected(entry(sources=["http://example.invalid"]), "source")

    def test_needs_reviewer_and_date(self):
        self.assertRejected(entry(reviewedBy=" "), "reviewer")
        self.assertRejected(entry(reviewedAt="25/11/2026"), "yyyy-MM-dd")

    def test_approved_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "approved.json"
            self.assertEqual(s.load_approved(LOCATIONS, path), [])           # missing file: none
            path.write_text("[]")
            self.assertEqual(s.load_approved(LOCATIONS, path), [])
            path.write_text(json.dumps([entry(), entry()]))
            with self.assertRaises(s.SeasonalityError):
                s.load_approved(LOCATIONS, path)                            # listed twice


class ResearchAnswerTests(unittest.TestCase):
    def answer(self, **month_changes):
        months = [{"month": i + 1, "percent": GOOD[i] * 2, "reason": "Because.",
                   "sources": [f"https://example.invalid/{i}"]} for i in range(12)]
        for index, change in month_changes.items():
            months[int(index[1:])].update(change)
        return {"months": months, "notes": ""}

    def test_draft_from_a_good_answer(self):
        draft = research.make_draft(LOCATIONS["ONE"], self.answer(), "claude-opus-5-5",
                                    ["https://example.invalid/0"], "2026-11-25")
        self.assertEqual(draft["lodgingPercentByMonth"], GOOD)       # normalized from 2× values
        self.assertEqual(draft["rawPercentByMonth"][0], 240)
        self.assertFalse(draft["clamped"])
        self.assertEqual(len(draft["sources"]), 12)
        self.assertEqual(len(draft["unverifiedSources"]), 11)       # only one was in search results
        self.assertEqual(draft["model"], "claude-opus-5-5")

    def test_rejects_answers_off_the_schema(self):
        bad = [
            {"notes": ""},
            {"months": self.answer()["months"][:11], "notes": ""},
            {"months": self.answer()["months"] + [self.answer()["months"][0]], "notes": ""},
            self.answer(m3={"month": 2}),
            self.answer(m0={"month": None}),
            self.answer(m0={"percent": 0}),
            self.answer(m0={"percent": 1.5}),
            self.answer(m0={"reason": " "}),
            self.answer(m0={"sources": []}),
            self.answer(m0={"sources": ["not a url"]}),
        ]
        for answer in bad:
            with self.assertRaises(s.SeasonalityError, msg=answer):
                research.validate_answer(answer)

    def test_approve_records_the_reviewer(self):
        draft = research.make_draft(LOCATIONS["ONE"], self.answer(), "m", [], "2026-11-25")
        entries = review.approve(draft, "  A Reviewer ", [entry()], LOCATIONS, "2026-11-26")
        self.assertEqual(len(entries), 1)                            # replaces the older approval
        self.assertEqual(entries[0]["reviewedBy"], "A Reviewer")
        self.assertEqual(entries[0]["reviewedAt"], "2026-11-26")
        with self.assertRaises(s.SeasonalityError):
            review.approve(draft, " ", [], LOCATIONS, "2026-11-26")


class RealDataTests(unittest.TestCase):
    def test_destinations_are_known_single_season_places(self):
        locations = s.load_locations()
        ids = s.read_destinations()
        self.assertGreaterEqual(len(ids), 30)
        self.assertEqual(len(ids), len(set(ids)))
        for location_id in ids:
            s.check_destination(location_id, locations)

    def test_committed_approvals_are_valid(self):
        s.load_approved(s.load_locations())

    @unittest.skipUnless((s.ROOT / "data" / "raw").exists(), "needs scripts/fetch-cost-data.sh")
    def test_build_refuses_a_bad_approval(self):
        output = s.COST_DATA.read_bytes()
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "approved.json"
            path.write_text(json.dumps([entry(id="DOS-MEXICO-CANCUN", lodgingPercentByMonth=[150] * 12)]))
            result = subprocess.run([sys.executable, str(s.ROOT / "scripts" / "build-cost-data.py")],
                                    env=dict(os.environ, MONETIC_SEASONALITY_APPROVED=str(path)),
                                    capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not 100", result.stderr)
        self.assertEqual(s.COST_DATA.read_bytes(), output)           # nothing written


if __name__ == "__main__":
    unittest.main()
