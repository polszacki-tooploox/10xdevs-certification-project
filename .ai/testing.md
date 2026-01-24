## Principles
- Test **domain rules** heavily; keep UI tests minimal but high-signal.
- Prefer **fast unit tests** over slow end-to-end tests.
- Make the brew flow state machine **deterministic and testable** (time should be injectable/mocked).

## What to unit test (XCTest)
- **Scaling rules** (dose/yield edits, rounding behavior, guardrail warnings)
- **Recipe validation rules** (invalid recipes blocked; clear validation error outputs)
- **Brew session state machine** (next step, pause/resume, restart safeguards, completion)
- **Post-brew hint mapping** (taste tag → hint)
- **Sync decision logic** (only: “when to sync” and “how to resolve conflicts” at a behavioral level, not CloudKit internals)

## What to UI test (XCUITest) — minimal set
- Happy path: select recipe → confirm inputs → start brew → complete → save log
- Guardrails: restart confirmation/press-hold flow; prevent accidental exit warning
- Accessibility smoke: key brew screen elements exist and are tappable with large controls

## Guidelines
- No snapshot testing unless it stays trivial.
- Keep view models thin; push logic into `Domain/` to keep tests stable.
- Use test helpers/builders for common domain scenarios (recipes, steps, brew sessions).

