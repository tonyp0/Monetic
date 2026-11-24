# Trips: Implementation Prompts

These prompts build the "Can I afford this trip?" feature in stages. Each one is a self-contained task for Claude Code (or a developer), meant to land as **one pull request**. Run them in order: each prompt assumes the previous ones have merged.

| # | Prompt | What ships | Needs a server? |
|---|--------|-----------|-----------------|
| 1 | [`01-trip-model-and-tab.md`](01-trip-model-and-tab.md) | `Trip` model, a Trips tab, create/edit/delete a trip with a manual cost | No |
| 2 | [`02-cost-estimator.md`](02-cost-estimator.md) | Daily cost estimate from bundled per diem data + travel style | No |
| 3 | [`03-savings-plan-and-countdown.md`](03-savings-plan-and-countdown.md) | Savings contributions, monthly target, on-track status, countdown | No |
| 4 | [`04-shared-trip-goal.md`](04-shared-trip-goal.md) | Share a trip plan with friends by link; design doc for real sync | No (sync is designed, not built) |
| 5 | [`05-ai-trip-assistant.md`](05-ai-trip-assistant.md) | Natural-language trip entry on device + estimate-vs-actual tracking | No |

Target timeline: 1–3 before late January (spring break planning season), 4 in February, 5 once real trips have been logged.

## How to run one from the terminal

From the repo root:

```sh
claude
```

Then, in the session:

1. Press **Shift+Tab** until the mode reads **plan mode**, so Claude proposes a plan before touching code.
2. Send: `Read docs/prompts/trips/01-trip-model-and-tab.md and follow it.`
3. Review the plan, ask for changes, then approve it.
4. When it finishes, run `scripts/test.sh` yourself and open the PR.

Or non-interactively, for a one-shot run:

```sh
claude -p "Read docs/prompts/trips/01-trip-model-and-tab.md and follow it."
```

Start each prompt in a **fresh session** (`/clear` or a new `claude`), so earlier work doesn't leak in as assumptions. Every prompt ends with a "Done when" list: hold the result to it before merging.

## Rules every prompt shares

These are repeated in each prompt so a prompt can run on its own, but they're collected here for reviewers:

- SwiftUI + SwiftData, iOS 17.0+. No third-party dependencies without asking.
- All visuals come from `Monetic/DesignSystem/` (`Brand`, `BrandComponents`, `CategoryPalette`). No raw SwiftUI default styling, no hard-coded colors.
- The existing monthly budget must keep working exactly as before; existing tests must still pass.
- `Monetic.xcodeproj` does **not** use synchronized folders: every new `.swift` file must be added to the right target in `project.pbxproj`, then confirmed by building.
- Tests use Swift Testing with in-memory `ModelContainer`s and fixed dates (see `MoneticTests/TestSupport.swift`). Never depend on today's date or the device locale.
- Never invent cost data. Numbers shown to users come from a cited dataset or from the user.
