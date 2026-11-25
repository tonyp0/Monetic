#!/bin/sh
# Downloads the raw per diem datasets that scripts/build-cost-data.py reads.
#
#   scripts/fetch-cost-data.sh && python3 scripts/build-cost-data.py
#
# Both are U.S. government publications. The files land in data/raw/, which is
# gitignored: only the generated Monetic/Resources/cost-data.json is committed.
# To move to a newer edition, change the two pinned values below (and the
# matching constants at the top of build-cost-data.py), then rebuild.
set -eu

cd "$(dirname "$0")/.."
mkdir -p data/raw

# GSA per diem rates for the continental U.S., fiscal year 2027
# (effective October 1, 2026). Listed on
# https://www.gsa.gov/travel/plan-book/per-diem-rates/per-diem-files
GSA_URL="https://www.gsa.gov/system/files/FY2027_PerDiemRates_Validated090126.xlsx"

# U.S. Department of State foreign per diem rates, all locations, as published
# on 11/01/2026 (DSSR section 925). The site only serves this table as an HTML
# form result, so the form is posted with that publication date pinned.
STATE_URL="https://allowances.state.gov/web920/per_diem_action.asp"
STATE_PUBLICATION="20261101"

curl -fsSL --retry 2 -A "Monetic data build" -o data/raw/gsa-per-diem-fy2027.xlsx "$GSA_URL"
curl -fsSL --retry 2 -A "Monetic data build" -o "data/raw/state-per-diem-$STATE_PUBLICATION.html" \
    --data "MenuHide=1&CountryCode=0000&PostCode=&PublicationDate=$STATE_PUBLICATION" "$STATE_URL"

ls -l data/raw
