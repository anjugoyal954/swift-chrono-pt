import Foundation

/// As regras de dia: "hoje", "amanhã", "sexta que vem", "25/09", "15 de
/// outubro", "dia 30", "daqui 2 dias", "semana que vem", "fim de semana".
///
/// Dia que já passou ("ontem") fica de fora de propósito: a data vira aviso,
/// e aviso no passado não serve para nada.
///
/// Dia da semana que também é ordinal ("segunda via", "quinta série") só conta
/// com uma pista de que é dia: "na segunda", "segunda-feira", "sexta que vem",
/// ou uma hora logo depois ("sexta às 10", "quarta à noite"). Sábado e domingo
/// não têm outro sentido e contam sozinhos.
enum DayRules {
    enum Value: Sendable, Equatable {
        case days(Int)
        case weeks(Int)
        case months(Int)
        /// Dia da semana no formato do `Calendar`: 1 é domingo, 7 é sábado.
        case weekday(Int, nextWeek: Bool)
        case date(day: Int, month: Int, year: Int?)
        case dayOfMonth(Int)
        case nextWeek
        case weekend
        case nextMonth
        case endOfMonth
    }

    private struct Candidate {
        let piece: Piece<Value>
        /// Precisa de uma hora logo depois para contar ("quinta às 10").
        let needsTime: Bool
    }

    /// Os dias citados no texto, sem sobreposição, na ordem do texto.
    static func expressions(in source: TextSource, times: [TimeRules.Expression]) -> [Piece<Value>] {
        let candidates = candidates(in: source).filter { candidate in
            !candidate.needsTime || times.contains { time in
                time.range.lowerBound >= candidate.piece.range.upperBound
                    && source.onlyConnectors(between: candidate.piece.range, and: time.range)
            }
        }
        return Piece.nonOverlapping(candidates.map(\.piece), in: source)
    }

    // MARK: - Regras

    private static func candidates(in source: TextSource) -> [Candidate] {
        let text = source.normalized
        var found: [Candidate] = []

        func add(_ range: Range<String.Index>, _ value: Value, needsTime: Bool = false) {
            found.append(Candidate(piece: Piece(range: range, value: value), needsTime: needsTime))
        }

        for match in text.matches(of: relativeDay) {
            let days = switch match.output.1 {
            case "depois de amanha": 2
            case "amanha": 1
            default: 0
            }
            add(match.range, .days(days))
        }

        for match in text.matches(of: inAmount) {
            guard let count = SpokenNumber.value(match.output.2) else { continue }
            let unit = match.output.3
            let value: Value = unit.hasPrefix("dia") ? .days(count) : unit.hasPrefix("semana") ? .weeks(count) : .months(count)
            add(match.range, value)
        }

        for match in text.matches(of: weekday) {
            guard let day = weekdays[String(match.output.2)] else { continue }
            let (prefix, feira, next) = (match.output.1, match.output.3, match.output.4)
            let nextWeek = next?.contains("semana") ?? false
            let unambiguous = day == 1 || day == 7 || prefix != nil || feira != nil || next != nil
            add(match.range, .weekday(day, nextWeek: nextWeek), needsTime: !unambiguous)
        }

        for match in text.matches(of: numericDate) {
            guard let day = Int(match.output.1), let month = Int(match.output.2) else { continue }
            add(match.range, .date(day: day, month: month, year: match.output.3.flatMap { year(String($0)) }))
        }

        for match in text.matches(of: isoDate) {
            guard let year = Int(match.output.1), let month = Int(match.output.2), let day = Int(match.output.3) else { continue }
            add(match.range, .date(day: day, month: month, year: year))
        }

        for match in text.matches(of: monthName) {
            guard let day = dayNumber(match.output.1), let month = months[String(match.output.2)] else { continue }
            add(match.range, .date(day: day, month: month, year: match.output.3.flatMap { Int($0) }))
        }

        for match in text.matches(of: dayOfMonth) {
            guard let day = dayNumber(match.output.1) else { continue }
            add(match.range, .dayOfMonth(day))
        }

        for match in text.matches(of: namedPeriod) {
            let value: Value = switch match.output.1 {
            case "semana que vem", "proxima semana": .nextWeek
            case "mes que vem", "proximo mes": .nextMonth
            case "fim do mes", "final do mes": .endOfMonth
            default: .weekend
            }
            add(match.range, value)
        }

        return found
    }

    // Calculadas, não guardadas: `Regex` não é `Sendable`, e constante estática
    // não isolada precisa ser. O literal é conferido na compilação. Fronteira
    // de palavra simples: o texto já chega sem acento e sem pontuação.

    private static var relativeDay: Regex<(Substring, Substring)> {
        #/\b(depois de amanha|amanha|hoje|hj)\b/#.wordBoundaryKind(.simple)
    }

    // "daqui 2 dias", "daqui a três semanas", "em 3 dias", "dentro de um mês"
    private static var inAmount: Regex<(Substring, Substring, Substring, Substring)> {
        #/\b(daqui a|daqui|em|dentro de) (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (dias?|semanas?|mes|meses)\b/#
            .wordBoundaryKind(.simple)
    }

    // "na sexta", "segunda-feira", "sexta que vem", "quarta da semana que vem"
    private static var weekday: Regex<(Substring, Substring?, Substring, Substring?, Substring?)> {
        #/\b(?:(na|no|nesta|neste|esta|este|essa|esse|nessa|nesse|proxima|proximo|ate|toda|todo|pra|para|pro) )?(segunda|terca|quarta|quinta|sexta|sabado|domingo)(-feira| feira)?( que vem| da semana que vem| da proxima semana)?\b/#
            .wordBoundaryKind(.simple)
    }

    // "25/09", "dia 25/09/2026", "5/1/27"
    private static var numericDate: Regex<(Substring, Substring, Substring, Substring?)> {
        #/\b(?:dia )?(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?\b/#.wordBoundaryKind(.simple)
    }

    // "2026-10-15"
    private static var isoDate: Regex<(Substring, Substring, Substring, Substring)> {
        #/\b(\d{4})-(\d{1,2})-(\d{1,2})\b/#.wordBoundaryKind(.simple)
    }

    // "15 de outubro", "dia 1º de maio", "primeiro de janeiro", "3 out 2027"
    private static var monthName: Regex<(Substring, Substring, Substring, Substring?)> {
        #/\b(?:dia )?(\d{1,2}|primeiro)(?:o|º)? (?:de )?(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro|jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\b(?: (?:de )?(\d{4})\b)?/#
            .wordBoundaryKind(.simple)
    }

    // "dia 30", "até dia 5", "dia primeiro"; "dia 25/09" fica para a data com barra.
    private static var dayOfMonth: Regex<(Substring, Substring)> {
        #/\bdia (\d{1,2}|primeiro)\b(?!/)/#.wordBoundaryKind(.simple)
    }

    private static var namedPeriod: Regex<(Substring, Substring)> {
        #/\b(semana que vem|proxima semana|fim de semana|final de semana|fds|mes que vem|proximo mes|fim do mes|final do mes)\b/#
            .wordBoundaryKind(.simple)
    }

    private static let weekdays = [
        "domingo": 1, "segunda": 2, "terca": 3, "quarta": 4, "quinta": 5, "sexta": 6, "sabado": 7
    ]

    private static let months = [
        "janeiro": 1, "jan": 1, "fevereiro": 2, "fev": 2, "marco": 3, "mar": 3, "abril": 4, "abr": 4,
        "maio": 5, "mai": 5, "junho": 6, "jun": 6, "julho": 7, "jul": 7, "agosto": 8, "ago": 8,
        "setembro": 9, "set": 9, "outubro": 10, "out": 10, "novembro": 11, "nov": 11, "dezembro": 12, "dez": 12
    ]

    private static func dayNumber(_ text: Substring) -> Int? {
        text == "primeiro" ? 1 : Int(text)
    }

    /// Ano de dois dígitos é deste século: "27" é 2027.
    private static func year(_ text: String) -> Int? {
        guard let value = Int(text) else { return nil }
        return text.count == 2 ? 2000 + value : value
    }

    // MARK: - Do dia citado à data

    /// O começo do dia citado e, quando é período, o começo do último dia.
    static func resolve(_ value: Value, reference: Date, calendar: Calendar) -> (start: Date, end: Date?)? {
        let today = calendar.startOfDay(for: reference)

        switch value {
        case .days(let count):
            return calendar.date(byAdding: .day, value: count, to: today).map { ($0, nil) }

        case .weeks(let count):
            return calendar.date(byAdding: .day, value: 7 * count, to: today).map { ($0, nil) }

        case .months(let count):
            return calendar.date(byAdding: .month, value: count, to: today).map { ($0, nil) }

        case .weekday(let weekday, let nextWeek):
            if nextWeek {
                // Na semana que vem, de segunda a domingo.
                guard let monday = nextMonday(after: today, calendar: calendar) else { return nil }
                return calendar.date(byAdding: .day, value: (weekday + 5) % 7, to: monday).map { ($0, nil) }
            }
            // A próxima vez que o dia chega, sem contar hoje: "sexta", dito
            // numa sexta, é a da semana que vem.
            return calendar.nextDate(after: today, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime)
                .map { ($0, nil) }

        case .date(let day, let month, let year):
            guard (1...12).contains(month), (1...daysInMonth[month - 1]).contains(day) else { return nil }
            if let year {
                let components = DateComponents(year: year, month: month, day: day)
                // O calendário completa data que não existe (29/02 em ano comum
                // vira 1º/03); aí não é data.
                guard let date = calendar.date(from: components),
                      calendar.component(.day, from: date) == day else { return nil }
                return (date, nil)
            }
            // Sem ano, a próxima vez que a data chega, contando hoje.
            return calendar.nextDate(
                after: today.addingTimeInterval(-1),
                matching: DateComponents(month: month, day: day),
                matchingPolicy: .strict
            ).map { ($0, nil) }

        case .dayOfMonth(let day):
            guard (1...31).contains(day) else { return nil }
            return calendar.nextDate(
                after: today.addingTimeInterval(-1),
                matching: DateComponents(day: day),
                matchingPolicy: .strict
            ).map { ($0, nil) }

        case .nextWeek:
            guard let monday = nextMonday(after: today, calendar: calendar),
                  let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return nil }
            return (monday, sunday)

        case .weekend:
            let weekday = calendar.component(.weekday, from: today)
            // No sábado é este fim de semana; no domingo, só o que sobrou dele.
            if weekday == 1 { return (today, nil) }
            let saturday = weekday == 7
                ? today
                : calendar.nextDate(after: today, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime)
            guard let saturday, let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) else { return nil }
            return (saturday, sunday)

        case .nextMonth:
            guard let thisMonth = calendar.dateInterval(of: .month, for: today)?.start,
                  let first = calendar.date(byAdding: .month, value: 1, to: thisMonth),
                  let last = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: first) else { return nil }
            return (first, last)

        case .endOfMonth:
            guard let interval = calendar.dateInterval(of: .month, for: today),
                  let last = calendar.date(byAdding: .day, value: -1, to: interval.end) else { return nil }
            return (calendar.startOfDay(for: last), nil)
        }
    }

    private static let daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    private static func nextMonday(after day: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(after: day, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime)
    }
}
