import Foundation

/// Day rules: "hoje", "amanhã", "sexta que vem", "25/09", "15 de outubro",
/// "dia 30", "daqui 2 dias", "esta semana", "fim de semana", "ano que vem".
///
/// Past days ("ontem") are left out on purpose: the date becomes a reminder,
/// and a reminder in the past is useless.
///
/// A weekday name that is also an ordinal ("segunda via", "quinta série") only
/// counts with a hint that it is a day: "na segunda", "segunda-feira", "sexta
/// que vem", or a time right after it ("sexta às 10", "quarta à noite").
/// Saturday and Sunday have no other meaning and count on their own.
enum DayRules {
    enum Value: Sendable, Equatable {
        case days(Int)
        case weeks(Int)
        case months(Int)
        /// Weekday as `Calendar` numbers it: 1 is Sunday, 7 is Saturday.
        case weekday(Int, nextWeek: Bool)
        case date(day: Int, month: Int, year: Int?)
        case dayOfMonth(Int)
        case thisWeek
        case nextWeek
        case weekend
        case thisMonth
        case nextMonth
        case startOfNextMonth
        case endOfMonth
        case nextYear
    }

    private struct Candidate {
        let piece: Piece<Value>
        /// Counts only with a time right after it ("quinta às 10").
        let needsTime: Bool
    }

    /// The days mentioned in the text, without overlap, in text order.
    static func expressions(in source: TextSource, times: [TimeRules.Expression]) -> [Piece<Value>] {
        let candidates = candidates(in: source).filter { candidate in
            !candidate.needsTime || times.contains { time in
                time.range.lowerBound >= candidate.piece.range.upperBound
                    && source.onlyConnectors(between: candidate.piece.range, and: time.range)
            }
        }
        return Piece.nonOverlapping(candidates.map(\.piece), in: source)
    }

    // MARK: - Rules

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
            let (_, dayText, of, monthText, yearText) = match.output
            // A day in words needs "de": "um mar de rosas" is not a date.
            guard Int(dayText) != nil || of != nil,
                  let day = dayNumber(dayText), let month = months[String(monthText)] else { continue }
            add(match.range, .date(day: day, month: month, year: yearText.flatMap { Int($0) }))
        }

        for match in text.matches(of: dayOfMonth) {
            guard let day = dayNumber(match.output.1) else { continue }
            add(match.range, .dayOfMonth(day))
        }

        for match in text.matches(of: namedPeriod) {
            let value: Value = switch match.output.1 {
            case "esta semana", "essa semana", "nesta semana", "nessa semana": .thisWeek
            case "semana que vem", "proxima semana", "essa semana que vem", "esta semana que vem": .nextWeek
            case "este mes", "esse mes", "neste mes", "nesse mes": .thisMonth
            case "mes que vem", "proximo mes": .nextMonth
            case "comeco do mes que vem", "inicio do mes que vem", "comeco do proximo mes", "inicio do proximo mes":
                .startOfNextMonth
            case "fim do mes", "final do mes": .endOfMonth
            case "ano que vem", "proximo ano": .nextYear
            default: .weekend
            }
            add(match.range, value)
        }

        return found
    }

    // Computed, not stored: `Regex` is not `Sendable`, and a nonisolated static
    // constant has to be. The literal is still checked at compile time. Simple
    // word boundaries: the text arrives without accents or punctuation.

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

    // "15 de outubro", "dia 1º de maio", "vinte e três de outubro", "3 out 2027"
    private static var monthName: Regex<(Substring, Substring, Substring?, Substring, Substring?)> {
        #/\b(?:dia )?(\d{1,2}|primeiro|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)(?:o|º)? (de )?(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro|jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\b(?: (?:de )?(\d{4})\b)?/#
            .wordBoundaryKind(.simple)
    }

    // "dia 30", "até dia 5", "dia primeiro", "dia quinze"; "dia 25/09" is left to `numericDate`.
    private static var dayOfMonth: Regex<(Substring, Substring)> {
        #/\bdia (\d{1,2}|primeiro|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)\b(?!/)/#.wordBoundaryKind(.simple)
    }

    private static var namedPeriod: Regex<(Substring, Substring)> {
        #/\b(esta semana que vem|essa semana que vem|esta semana|essa semana|nesta semana|nessa semana|semana que vem|proxima semana|fim de semana|final de semana|fds|este mes|esse mes|neste mes|nesse mes|(?:comeco|inicio) do (?:mes que vem|proximo mes)|mes que vem|proximo mes|fim do mes|final do mes|ano que vem|proximo ano)\b/#
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
        text == "primeiro" ? 1 : SpokenNumber.value(text)
    }

    /// A two-digit year is in this century: "27" is 2027.
    private static func year(_ text: String) -> Int? {
        guard let value = Int(text) else { return nil }
        return text.count == 2 ? 2000 + value : value
    }

    // MARK: - From the mentioned day to a date

    /// The start of the mentioned day and, for a period, the start of its last day.
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
                // Next week runs Monday to Sunday.
                guard let monday = nextMonday(after: today, calendar: calendar) else { return nil }
                return calendar.date(byAdding: .day, value: (weekday + 5) % 7, to: monday).map { ($0, nil) }
            }
            // The next time that weekday comes, not counting today: "sexta"
            // said on a Friday is next week's.
            return calendar.nextDate(after: today, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime)
                .map { ($0, nil) }

        case .date(let day, let month, let year):
            guard (1...12).contains(month), (1...daysInMonth[month - 1]).contains(day) else { return nil }
            if let year {
                let components = DateComponents(year: year, month: month, day: day)
                // The calendar rolls a date that doesn't exist over (29/02 in a
                // common year becomes 01/03); then it is not a date.
                guard let date = calendar.date(from: components),
                      calendar.component(.day, from: date) == day else { return nil }
                return (date, nil)
            }
            // Without a year, the next time that date comes, counting today.
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

        case .thisWeek:
            // From today to Sunday; on a Sunday, just today.
            let weekday = calendar.component(.weekday, from: today)
            guard weekday != 1 else { return (today, nil) }
            return calendar.date(byAdding: .day, value: 8 - weekday, to: today).map { (today, $0) }

        case .nextWeek:
            guard let monday = nextMonday(after: today, calendar: calendar),
                  let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return nil }
            return (monday, sunday)

        case .weekend:
            let weekday = calendar.component(.weekday, from: today)
            // On Saturday it is this weekend; on Sunday, what is left of it.
            if weekday == 1 { return (today, nil) }
            let saturday = weekday == 7
                ? today
                : calendar.nextDate(after: today, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime)
            guard let saturday, let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) else { return nil }
            return (saturday, sunday)

        case .thisMonth:
            // From today to the last day; on the last day, just today.
            guard let last = lastDayOfMonth(today, calendar: calendar) else { return nil }
            return (today, last == today ? nil : last)

        case .nextMonth:
            guard let first = firstDayOfNextMonth(today, calendar: calendar),
                  let last = lastDayOfMonth(first, calendar: calendar) else { return nil }
            return (first, last)

        case .startOfNextMonth:
            return firstDayOfNextMonth(today, calendar: calendar).map { ($0, nil) }

        case .nextYear:
            guard let thisYear = calendar.dateInterval(of: .year, for: today)?.start,
                  let first = calendar.date(byAdding: .year, value: 1, to: thisYear),
                  let last = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: first) else { return nil }
            return (first, last)

        case .endOfMonth:
            return lastDayOfMonth(today, calendar: calendar).map { ($0, nil) }
        }
    }

    private static func firstDayOfNextMonth(_ day: Date, calendar: Calendar) -> Date? {
        guard let thisMonth = calendar.dateInterval(of: .month, for: day)?.start else { return nil }
        return calendar.date(byAdding: .month, value: 1, to: thisMonth)
    }

    private static func lastDayOfMonth(_ day: Date, calendar: Calendar) -> Date? {
        guard let interval = calendar.dateInterval(of: .month, for: day),
              let last = calendar.date(byAdding: .day, value: -1, to: interval.end) else { return nil }
        return calendar.startOfDay(for: last)
    }

    private static let daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    private static func nextMonday(after day: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(after: day, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime)
    }
}
