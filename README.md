# swift-chrono-pt

Datas e horas em linguagem natural, em português do Brasil, para Swift.

```swift
import ChronoPT

ChronoPT.interpret("comprar pão amanhã no almoço")
// amanhã, 12:00 — hasTime: true, text: "amanhã"

ChronoPT.parse("dentista sexta às 14h, reunião dia 30 e ligar pro banco amanhã")
// [sexta às 14h] [dia 30] [amanhã]
```

Não usa rede, não usa modelo, não depende do `NSDataDetector`. É uma gramática
pequena, no formato do [chrono](https://github.com/wanasit/chrono): regras que
acham pedaços de dia e de hora, e depois juntam os dois. O mesmo texto, com a
mesma data de referência, dá sempre a mesma resposta, em qualquer versão do
sistema.

## O que entende

| Tipo | Exemplos |
|---|---|
| Dia relativo | hoje, amanhã, depois de amanhã, daqui 2 dias, em três semanas, daqui um mês |
| Dia da semana | sexta que vem, próxima sexta, nesta quinta, na terça-feira, sábado, quarta da semana que vem |
| Data | 25/09, 25/09/2026, 2026-10-15, 15 de outubro, 1º de maio, primeiro de janeiro, dia 30, dia primeiro |
| Período | semana que vem, fim de semana, mês que vem, fim do mês |
| Relógio | às 9, 14h, 9h30, 10:30, às 7 e meia, às sete da noite, 3 da tarde, meio-dia e meia, à meia-noite |
| Parte do dia | de manhã, à tarde, à noite, de madrugada, cedo, à tardinha, tarde da noite, no fim da tarde |
| Momento | no almoço, na janta, depois do almoço, antes de dormir, ao acordar, no café da manhã, depois do trabalho |
| A partir de agora | daqui 2 horas, em meia hora, daqui a 20 minutos |

Sem acento também: "amanha as 9", "no almoco".

Alguns cuidados que a gramática já toma:

- **"para a janta" não é hora.** Só "na janta", "no almoço", com preposição de
  quando. "comprar para a janta amanhã" é amanhã, sem hora.
- **Ordinal não vira dia.** "segunda via do boleto" e "quinta série" não são
  datas. Segunda a sexta só contam com pista: "na segunda", "segunda-feira",
  "sexta que vem" ou uma hora logo depois ("quinta às 14h").
- **Duração não é hora.** "estudar por 2 horas" não marca 14h.
- **"às 7" falado é 19h**, como no relógio de quem fala; "7h" escrito é 7h. "de
  manhã, às 7" é 7h.
- **Meia-noite** de um dia é o começo do dia seguinte.

## Instalação

Swift Package Manager:

```swift
.package(url: "https://github.com/bertalhia/swift-chrono-pt.git", from: "0.1.0")
```

```swift
.product(name: "ChronoPT", package: "swift-chrono-pt")
```

iOS 16, macOS 13, watchOS 9, tvOS 16, visionOS 1.

## API

```swift
// Todas as expressões, na ordem do texto.
ChronoPT.parse(_ text: String, reference: Date = .now, calendar: Calendar = .current) -> [ParsedResult]

// A data do texto inteiro: o primeiro dia, na hora colada nele ou na primeira hora citada.
ChronoPT.interpret(_ text: String, reference: Date = .now, calendar: Calendar = .current) -> ParsedResult?

struct ParsedResult {
    let range: Range<String.Index>  // no texto recebido
    let text: String
    let date: Date                  // sem hora no texto: meio-dia
    let end: Date?                  // período: "semana que vem"
    let hasTime: Bool
}
```

## Testes

```bash
swift test
```

Todo teste roda numa data fixa (segunda, 21/09/2026, 10h, São Paulo).

## English

Natural-language date and time parser for Brazilian Portuguese, in Swift.
Deterministic, offline, no `NSDataDetector`. Understands relative days,
weekdays, dates, periods, clock times, parts of the day and meals ("amanhã no
almoço", "sexta à noite", "depois da janta", "às sete e meia").

## Licença

MIT. Veja [LICENSE](LICENSE).
