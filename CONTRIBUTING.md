# Contributing

The goal is the most reliable natural-language date parser for Brazilian
Portuguese in Swift. Reliability comes before coverage: every new case comes
with tests, and no existing case may break.

Open work is tracked in [issues](https://github.com/bertalhia/swift-chrono-pt/issues).
Bug reports are most useful with the exact text, the reference date and time
zone, the result you got and the result you expected.

## Rules

- Deterministic: no `NSDataDetector`, language model or network. Every result
  comes from `reference` and `calendar`: the same text with the same reference
  always gives the same answer.
- New cases fit the structure. A new case is a new rule in `DayRules`, a
  new row in the `TimeRules` table, or a new merge step in `ChronoPT.swift`.
  If a case needs an exception inside another rule, change the structure
  instead.
- Every case has a test, run against the fixed reference date in
  `Tests/ChronoPTTests/Support.swift` (Monday, 21 September 2026, 10:00, São
  Paulo). Negative cases too: "segunda via do boleto" is not a date.
- The text is read once. `TextSource` removes accents, case and
  punctuation while keeping one character for each character of the original,
  so every position a rule finds maps back to the text the user wrote.
- Swift 6 with strict concurrency. `Regex` is not `Sendable`, so regexes
  live in computed properties, not in static constants.
- Swift Testing, not XCTest.
- English for code, comments, documentation, test names and commit
  messages. Input examples stay in Portuguese.

## Layout

| File | What it does |
|---|---|
| `ChronoPT.swift` | Public API (`parse`, `interpret`, `ParsedResult`) and the merge of a day with a time |
| `TextSource.swift` | Normalized text with a position map; `Piece` and overlap removal; spelled-out numbers |
| `DayRules.swift` | Day rules and date arithmetic |
| `TimeRules.swift` | Clock times, parts of the day, moments, "daqui a"; merges adjacent pieces into one time |

## Running the tests

```bash
swift test
```

## Versioning

Semantic versioning through git tags, which Swift Package Manager reads. While
the version is `0.x`, a minor release (`0.2.0`) may break the API and a patch
release (`0.1.1`) may not.

## Pull requests

Keep each pull request to one topic, with tests for every case it adds or
changes, and make sure `swift test` passes.
