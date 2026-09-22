# ``ChronoPT``

Natural-language date and time parsing for Brazilian Portuguese.

## Overview

ChronoPT finds dates and times in text written the way people write notes in
Brazilian Portuguese: "amanhã no almoço", "sexta às 14h", "dia 30 à noite".

```swift
let reminder = ChronoPT.interpret("comprar pão amanhã no almoço")
// reminder?.date is tomorrow at 12:00
// reminder?.text is "amanhã"
```

Use ``ChronoPT/interpret(_:reference:calendar:)`` when the whole text is one
note and you want one date for it. Use ``ChronoPT/parse(_:reference:calendar:)``
to get every expression in the text, in order.

The parser is deterministic. It doesn't use the network, a language model or
`NSDataDetector`, so the same text with the same reference date and calendar
always gives the same result.

### Reference date and calendar

Relative expressions ("amanhã", "daqui 2 horas") are computed from
`reference`. Weekdays, midnight and the time zone come from `calendar`. Pass
both explicitly in tests and on servers:

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
let results = ChronoPT.parse(text, reference: now, calendar: calendar)
```

### Dates without a time

When the text gives only a day, ``ParsedResult/date`` is noon of that day and
``ParsedResult/hasTime`` is `false`. Noon keeps the date away from the
midnight shifts of daylight saving time.

## Topics

### Parsing

- ``ChronoPT/interpret(_:reference:calendar:)``
- ``ChronoPT/parse(_:reference:calendar:)``

### Results

- ``ParsedResult``
