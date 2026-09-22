# swift-chrono-pt

[![Tests](https://github.com/bertalhia/swift-chrono-pt/actions/workflows/tests.yml/badge.svg)](https://github.com/bertalhia/swift-chrono-pt/actions/workflows/tests.yml)

Natural-language date and time parsing for Brazilian Portuguese, in Swift.

```swift
import ChronoPT

ChronoPT.interpret("comprar pão amanhã no almoço")
// tomorrow, 12:00 — hasTime: true, text: "amanhã"

ChronoPT.parse("dentista sexta às 14h, reunião dia 30 e ligar pro banco amanhã")
// [sexta às 14h] [dia 30] [amanhã]
```

It doesn't use the network, a language model or `NSDataDetector`. It is a
small grammar in the style of [chrono](https://github.com/wanasit/chrono):
rules find pieces of text that name a day or a time, then join a day and a time
that sit next to each other. The same text with the same reference date always
gives the same result, on every OS version.

## What it understands

| Kind | Examples |
|---|---|
| Relative day | hoje, amanhã, depois de amanhã, daqui 2 dias, em três semanas, daqui um mês |
| Weekday | sexta que vem, próxima sexta, nesta quinta, na terça-feira, sábado, quarta da semana que vem |
| Date | 25/09, 25/09/2026, 2026-10-15, 15 de outubro, vinte e três de outubro, 1º de maio, primeiro de janeiro, dia 30, dia quinze, dia primeiro |
| Period | esta semana, semana que vem, fim de semana, este mês, mês que vem, começo do mês que vem, fim do mês, ano que vem |
| Clock time | às 9, 14h, 9h30, 10:30, às 7 e meia, às sete da noite, às vinte e duas horas, 3 da tarde, quinze para as oito, meio-dia e meia, à meia-noite |
| Part of the day | de manhã, à tarde, à noite, de madrugada, cedo, à tardinha, tarde da noite, no fim da tarde |
| Moment | no almoço, na janta, depois do almoço, antes de dormir, ao acordar, no café da manhã, depois do trabalho |
| From now | daqui 2 horas, em meia hora, daqui a 20 minutos |
| Holiday | no natal, véspera de natal, no ano novo, na páscoa, no carnaval, sexta-feira santa, corpus christi, dia de finados, dia das mães, dia dos pais |

Accents are optional: "amanha as 9" and "no almoco" work too.

Some choices the grammar makes on purpose:

- "para a janta" is not a time. Only "na janta" or "no almoço", with a
  preposition of time, set one. "comprar para a janta amanhã" (buy for
  tomorrow's dinner) is tomorrow, with no time.
- Ordinals are not weekdays. "segunda via do boleto" (a duplicate bill)
  and "quinta série" (fifth grade) are not dates. Monday to Friday count only
  with a hint: "na segunda", "segunda-feira", "sexta que vem", or a time right
  after ("quinta às 14h").
- A duration is not a time. "estudar por 2 horas" (study for 2 hours) and
  "trabalhar 8h por dia" (work 8 hours a day) set no time.
- Spoken "às 7" is 19:00, the way people say it; written "7h" is 7:00. A part
  of the day settles it: "de manhã, às 7" and "amanhã de manhã, reunião às 7"
  are 7:00.
- Midnight of a day is the start of the next day.
- A holiday name with another meaning needs a preposition: "no natal" is
  Christmas, "voo para Natal" is the city, and "ovo de páscoa" is chocolate.

Past dates ("ontem", "sexta passada") are not parsed yet.

## Installation

Swift Package Manager:

```swift
.package(url: "https://github.com/bertalhia/swift-chrono-pt.git", from: "0.1.0")
```

```swift
.product(name: "ChronoPT", package: "swift-chrono-pt")
```

iOS 16, macOS 13, watchOS 9, tvOS 16, visionOS 1. Swift 6.

## API

```swift
// Every expression in the text, in order.
ChronoPT.parse(_ text: String, reference: Date = .now, calendar: Calendar = .current) -> [ParsedResult]

// The date of the whole text: the first day, at the time next to it
// or at the first time mentioned anywhere.
ChronoPT.interpret(_ text: String, reference: Date = .now, calendar: Calendar = .current) -> ParsedResult?

struct ParsedResult {
    let range: Range<String.Index>  // in the input text
    let text: String
    let date: Date                  // noon when the text has no time
    let end: Date?                  // periods: "semana que vem"
    let hasTime: Bool
}
```

## Tests

```bash
swift test
```

Every test runs against a fixed reference date: Monday, 21 September 2026,
10:00, São Paulo.

## Em português

Parser de data e hora em linguagem natural para português do Brasil, em
Swift. Determinístico, sem rede e sem `NSDataDetector`. Entende dia relativo,
dia da semana, data, período, horário, parte do dia e refeição ("amanhã no
almoço", "sexta à noite", "depois da janta", "às sete e meia").

## License

MIT. See [LICENSE](LICENSE).
