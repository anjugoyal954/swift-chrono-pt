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
///
/// Holiday names with another meaning ("Natal" is also a city, "ovo de
/// páscoa" is chocolate) count only after a preposition: "no natal", "na
/// páscoa", "feriado de tiradentes".
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
        case holiday(Holiday)
        /// The last time that weekday came, before today: "sexta passada".
        case lastWeekday(Int)
        case lastWeek
        case lastMonth
        case lastYear
        case daily
        /// Every so many days, weeks or months: "a cada 15 dias".
        case interval(DateComponents)
        /// Weekdays as `Calendar` numbers them, in the order of the text.
        case weekly([Int])
        case monthly(Int)
        /// From one day to another: "de segunda a sexta", "do dia 10 ao dia 15".
        indirect case range(Value, Value)

        /// A day of the month, with or without the month: "dia 25", "25/09",
        /// "1º de outubro".
        var isDate: Bool {
            switch self {
            case .date, .dayOfMonth: true
            default: false
            }
        }

        /// "ontem", "sexta passada", "há 2 dias": counts only with
        /// `ParseOptions.allowsPast`.
        var isPast: Bool {
            switch self {
            case .days(let count), .weeks(let count), .months(let count): count < 0
            case .lastWeekday, .lastWeek, .lastMonth, .lastYear: true
            case .range(let from, let to): from.isPast || to.isPast
            default: false
            }
        }

        var recurrence: Recurrence? {
            switch self {
            case .daily: .daily
            case .interval(let components): .every(components)
            case .weekly(let weekdays): .weekly(on: Set(weekdays.map { DayRules.localeWeekdays[$0 - 1] }))
            case .monthly(let day): .monthly(day: day)
            default: nil
            }
        }

        /// What the text fixes at the start; see `ParsedDate.knownComponents`.
        /// A count from the reference ("amanhã", "semana que vem") fixes the
        /// whole day; a month or a year period fixes only its month or year.
        var knownComponents: Set<Calendar.Component> {
            switch self {
            case .days, .weeks, .months, .thisWeek, .nextWeek, .weekend, .lastWeek, .endOfMonth:
                [.day, .month, .year]
            case .weekday, .lastWeekday:
                [.day, .month, .year, .weekday]
            case .date(_, _, let year):
                year == nil ? [.day, .month] : [.day, .month, .year]
            case .dayOfMonth, .monthly:
                [.day]
            case .thisMonth, .nextMonth, .startOfNextMonth, .lastMonth:
                [.month, .year]
            case .nextYear, .lastYear:
                [.year]
            case .holiday:
                [.day, .month]
            case .daily, .interval:
                []
            case .weekly:
                [.weekday]
            case .range(let from, _):
                from.knownComponents
            }
        }

        /// What the text fixes at the end: the second day of a range, or the
        /// same as the start for a period.
        var endKnownComponents: Set<Calendar.Component> {
            if case .range(_, let to) = self { to.knownComponents } else { knownComponents }
        }
    }

    /// A holiday: on a fixed date, counted from Easter, or on the second Sunday
    /// of a month.
    enum Holiday: Sendable, Equatable {
        case fixed(month: Int, day: Int)
        /// Days from Easter Sunday; `lastDay` when the holiday lasts several days.
        case easter(offset: Int, lastDay: Int? = nil)
        case secondSunday(month: Int)
    }

    private struct Candidate {
        let piece: Piece<Value>
        /// Counts only with a time right after it ("quinta às 10").
        let needsTime: Bool
    }

    /// The days mentioned in the text, without overlap, in text order.
    static func expressions(in source: TextSource, times: [TimeRules.Expression]) -> [Piece<Value>] {
        let found = candidates(in: source)
        let candidates = (found + ranges(of: found, in: source) + weekdaysWithDates(of: found, in: source)).filter { candidate in
            guard candidate.needsTime else { return true }
            return times.contains { time in
                guard source.onlyConnectors(between: candidate.piece.range, and: time.range) else { return false }
                // A time before the day only counts with "de": "às 10 de
                // quinta" is Thursday, but "às 10 segunda via" is not Monday.
                return time.range.lowerBound >= candidate.piece.range.upperBound
                    || source.word(before: candidate.piece.range.lowerBound) == "de"
            }
        }
        return Piece.nonOverlapping(candidates.map(\.piece), in: source)
    }

    /// Two days joined as a range: "de segunda a sexta", "do dia 10 ao dia
    /// 15", "de hoje até sexta", "segunda a sexta", "seg-sex". The range is the
    /// hint a weekday needs. With no opening word, the first day has to start
    /// right at its number or name.
    private static func ranges(of candidates: [Candidate], in source: TextSource) -> [Candidate] {
        candidates.flatMap { first in
            candidates.compactMap { second in
                let firstWord = source.words(after: first.piece.range.lowerBound, count: 1).first ?? ""
                let bareStart = source.startsWithNumber(first.piece.range) || weekdays[firstWord] != nil
                guard let start = source.rangeStart(from: first.piece.range, to: second.piece.range, bareStart: bareStart) else {
                    return nil
                }
                // A day of the month takes the month of the end: "do dia 10 ao
                // dia 15 de novembro".
                var from = first.piece.value
                if case .dayOfMonth(let day) = from, case let .date(last, month, year) = second.piece.value, day <= last {
                    from = .date(day: day, month: month, year: year)
                }
                let piece = Piece(range: start..<second.piece.range.upperBound, value: Value.range(from, second.piece.value))
                return Candidate(piece: piece, needsTime: false)
            }
        }
    }

    /// A weekday followed by its date: "sexta, dia 25", "segunda-feira, 5/10".
    /// The date decides, and the date is the hint the weekday needs.
    private static func weekdaysWithDates(of candidates: [Candidate], in source: TextSource) -> [Candidate] {
        candidates.flatMap { weekday in
            candidates.compactMap { date in
                guard case .weekday = weekday.piece.value,
                      date.piece.value.isDate,
                      weekday.piece.range.upperBound <= date.piece.range.lowerBound,
                      source.words(in: weekday.piece.range.upperBound..<date.piece.range.lowerBound).isEmpty else { return nil }
                let range = weekday.piece.range.lowerBound..<date.piece.range.upperBound
                return Candidate(piece: Piece(range: range, value: date.piece.value), needsTime: false)
            }
        }
    }

    // MARK: - Rules

    private static func candidates(in source: TextSource) -> [Candidate] {
        let text = source.normalized
        var found: [Candidate] = []

        func add(_ range: Range<String.Index>, _ value: Value, needsTime: Bool = false) {
            found.append(Candidate(piece: Piece(range: range, value: value), needsTime: needsTime))
        }

        for match in text.matches(of: relativeDay) {
            guard let days = relativeDays[String(match.output.1)] else { continue }
            add(match.range, .days(days))
        }

        for match in text.matches(of: inAmount) {
            guard let count = SpokenNumber.value(match.output.2) else { continue }
            add(match.range, amount(count, unit: match.output.3))
        }

        for match in text.matches(of: agoAmount) {
            guard let count = SpokenNumber.value(match.output.1) else { continue }
            add(match.range, amount(-count, unit: match.output.2))
        }

        for match in text.matches(of: amountAgo) {
            guard let count = SpokenNumber.value(match.output.1) else { continue }
            add(match.range, amount(-count, unit: match.output.2))
        }

        for match in text.matches(of: lastWeekday) {
            guard let name = match.output.1 ?? match.output.2, let day = weekdays[String(name)] else { continue }
            add(match.range, .lastWeekday(day))
        }

        for match in text.matches(of: everyDay) {
            add(match.range, .daily)
        }

        for match in text.matches(of: everyInterval) {
            guard let count = SpokenNumber.value(match.output.1) else { continue }
            add(match.range, .interval(components(count, unit: match.output.2)))
        }

        for match in text.matches(of: fromToInterval) {
            // "de 2 em 3 semanas" is not an interval.
            guard let count = SpokenNumber.value(match.output.1), SpokenNumber.value(match.output.2) == count else { continue }
            add(match.range, .interval(components(count, unit: match.output.3)))
        }

        for match in text.matches(of: everyUnit) {
            add(match.range, .interval(components(1, unit: match.output.contains("semana") ? "semana" : "mes")))
        }

        for match in text.matches(of: everyMonth) {
            guard let day = dayNumber(match.output.1), (1...31).contains(day) else { continue }
            add(match.range, .monthly(day))
        }

        for match in text.matches(of: everyWeekday) {
            // The singular goes with "toda" ("toda segunda"), the plural with
            // "todas as", "às" or "nas" ("às segundas e quartas").
            let plural = match.output.1 != "toda" && match.output.1 != "todo"
            let days = match.output.2.split(whereSeparator: { $0 == " " || $0 == "," }).filter { $0 != "e" }.map { word in
                let name = word.split(separator: "-").first.map(String.init) ?? ""
                return name.hasSuffix("s") == plural ? weekdays[plural ? String(name.dropLast()) : name] : nil
            }
            guard !days.isEmpty, !days.contains(nil) else { continue }
            add(match.range, .weekly(days.compactMap { $0 }))
        }

        for match in text.matches(of: weekday) {
            let (prefix, name, feira, next) = (match.output.1, String(match.output.2), match.output.3, match.output.4)
            guard let day = weekdays[name] else { continue }
            let nextWeek = next?.contains("semana") ?? false
            let unambiguous = weekdaysAlone.contains(name) || prefix != nil || feira != nil || next != nil
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

        for match in text.matches(of: dayRangeInMonth) {
            let (_, opening, firstText, closing, lastText, monthText, yearText) = match.output
            // "de 3 e 5 de maio" is two days, not a range.
            guard (opening == "entre") == (closing == "e"),
                  let first = dayNumber(firstText), let last = dayNumber(lastText),
                  let month = months[String(monthText)] else { continue }
            let year = yearText.flatMap { Int($0) }
            add(match.range, .range(.date(day: first, month: month, year: year), .date(day: last, month: month, year: year)))
        }

        for match in text.matches(of: dayOfMonth) {
            guard let day = dayNumber(match.output.1) else { continue }
            add(match.range, .dayOfMonth(day))
        }

        for match in text.matches(of: holidayName) {
            let (_, preposition, name) = match.output
            guard let entry = holidays[String(name)], preposition != nil || !entry.needsPreposition else { continue }
            add(match.range, .holiday(entry.holiday))
        }

        for match in text.matches(of: namedPeriod) {
            let value: Value = switch match.output.1 {
            case "esta semana", "essa semana", "nesta semana", "nessa semana": .thisWeek
            case "semana que vem", "proxima semana", "prox semana", "essa semana que vem", "esta semana que vem": .nextWeek
            case "este mes", "esse mes", "neste mes", "nesse mes": .thisMonth
            case "mes que vem", "proximo mes", "prox mes": .nextMonth
            case "comeco do mes que vem", "inicio do mes que vem", "comeco do proximo mes", "inicio do proximo mes":
                .startOfNextMonth
            case "fim do mes", "final do mes": .endOfMonth
            case "ano que vem", "proximo ano", "prox ano": .nextYear
            case "semana passada": .lastWeek
            case "mes passado": .lastMonth
            case "ano passado": .lastYear
            default: .weekend
            }
            add(match.range, value)
        }

        return found
    }

    // Computed, not stored: `Regex` is not `Sendable`, and a nonisolated static
    // constant has to be. `RegexCache` keeps each one built per thread. The
    // literal is still checked at compile time. Simple word boundaries: the
    // text arrives without accents or punctuation.

    private static var relativeDay: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\b((?:depois|dps) de (?:amanha|amn)|amanha|amn|hoje|hj|antes de ontem|anteontem|ontem)\b/#.wordBoundaryKind(.simple)
        }
    }

    // "daqui 2 dias", "daqui a três semanas", "em 3 dias", "dentro de um mês"
    // "há 2 dias", "faz uma semana"
    private static var agoAmount: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:ha|faz) (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (dias?|semanas?|mes|meses)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "3 dias atrás"
    private static var amountAgo: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (dias?|semanas?|mes|meses) atras\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "sexta passada", "na última sexta", "segunda-feira passada"
    private static var lastWeekday: Regex<(Substring, Substring?, Substring?)> {
        RegexCache.regex {
            #/\b(?:(?:na|no|o|a) )?(?:(?:ultima|ultimo) (segunda|terca|quarta|quinta|sexta|sabado|domingo|seg|qua|qui|sex|sab|dom)(?:-feira| feira)?|(segunda|terca|quarta|quinta|sexta|sabado|domingo|seg|qua|qui|sex|sab|dom)(?:-feira| feira)? (?:passada|passado))\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "a cada 15 dias", "cada 2 meses"
    private static var everyInterval: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:a )?cada (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (dias?|semanas?|mes|meses)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "de 2 em 2 semanas"
    private static var fromToInterval: Regex<(Substring, Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\bde (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) em (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (dias?|semanas?|mes|meses)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "toda semana", "todo mês", "semanalmente", "mensalmente"
    private static var everyUnit: Regex<Substring> {
        RegexCache.regex {
            #/\b(?:toda(?:s as)? semanas?|todo(?:s os)? (?:mes|meses)|semanalmente|mensalmente)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "todo dia", "todos os dias", "diariamente"
    private static var everyDay: Regex<Substring> {
        RegexCache.regex {
            #/\b(?:todo dia|todos os dias|todo santo dia|diariamente)\b/#.wordBoundaryKind(.simple)
        }
    }

    // "todo dia 5", "todo mês no dia 10"
    private static var everyMonth: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:todo mes(?: no)? dia|todos os dias|todo dia) (\d{1,2}|primeiro|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)\b(?!/)/#
                .wordBoundaryKind(.simple)
        }
    }

    // "toda terça", "todas as sextas", "às segundas e quartas", "nas terças e quintas"
    private static var everyWeekday: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(toda|todo|todas as|todos os|as|aos|nas|nos) ((?:(?:segunda|terca|quarta|quinta|sexta)s?(?:-feiras?)?|sabados?|domingos?)(?:(?:,|, e| e) (?:(?:segunda|terca|quarta|quinta|sexta)s?(?:-feiras?)?|sabados?|domingos?))*)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    private static var inAmount: Regex<(Substring, Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(daqui a|daqui|em|dentro de) (\d{1,3}|um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta) (dias?|semanas?|mes|meses)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "na sexta", "segunda-feira", "sexta que vem", "quarta da semana que vem"
    private static var weekday: Regex<(Substring, Substring?, Substring, Substring?, Substring?)> {
        RegexCache.regex {
            #/\b(?:(na|no|nesta|neste|esta|este|essa|esse|nessa|nesse|proxima|proximo|prox|ate|pra|para|pro) )?(segunda|terca|quarta|quinta|sexta|sabado|domingo|seg|qua|qui|sex|sab|dom)(-feira| feira)?( que vem| da semana que vem| da proxima semana)?\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "25/09", "dia 25/09/2026", "5/1/27"
    private static var numericDate: Regex<(Substring, Substring, Substring, Substring?)> {
        RegexCache.regex {
            #/\b(?:dia )?(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?\b/#.wordBoundaryKind(.simple)
        }
    }

    // "2026-10-15"
    private static var isoDate: Regex<(Substring, Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(\d{4})-(\d{1,2})-(\d{1,2})\b/#.wordBoundaryKind(.simple)
        }
    }

    // "15 de outubro", "dia 1º de maio", "vinte e três de outubro", "3 out 2027"
    private static var monthName: Regex<(Substring, Substring, Substring?, Substring, Substring?)> {
        RegexCache.regex {
            #/\b(?:dia )?(\d{1,2}|primeiro|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)(?:o|º)? (de )?(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro|jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\b(?: (?:de )?(\d{4})\b)?/#
                .wordBoundaryKind(.simple)
        }
    }

    // "de 10 a 15 de outubro", "entre 3 e 5 de maio": the first day takes the month of the second
    private static var dayRangeInMonth: Regex<(Substring, Substring, Substring, Substring, Substring, Substring, Substring?)> {
        RegexCache.regex {
            #/\b(de|entre) (\d{1,2}|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)(?:o|º)? (a|ao|ate|e) (\d{1,2}|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)(?:o|º)? de (janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro|jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\b(?: (?:de )?(\d{4})\b)?/#
                .wordBoundaryKind(.simple)
        }
    }

    // "dia 30", "até dia 5", "dia primeiro", "dia quinze"; "dia 25/09" is left to `numericDate`.
    private static var dayOfMonth: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\bdia (\d{1,2}|primeiro|vinte e (?:um|dois|tres|quatro|cinco|seis|sete|oito|nove)|trinta e um|trinta|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|dois|um)\b(?!/)/#.wordBoundaryKind(.simple)
        }
    }

    private static var namedPeriod: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\b(esta semana que vem|essa semana que vem|esta semana|essa semana|nesta semana|nessa semana|semana que vem|proxima semana|prox semana|fim de semana|final de semana|fds|este mes|esse mes|neste mes|nesse mes|(?:comeco|inicio) do (?:mes que vem|proximo mes)|mes que vem|proximo mes|prox mes|fim do mes|final do mes|ano que vem|proximo ano|prox ano|semana passada|mes passado|ano passado)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "no natal", "véspera de natal", "dia de finados", "na sexta-feira santa"
    private static var holidayName: Regex<(Substring, Substring?, Substring)> {
        RegexCache.regex {
            #/\b(?:(no proximo|na proxima|no|na|ate o|ate a|ate|neste|nesta|nesse|nessa|este|esta|esse|essa|feriado de|feriado do|feriado da|dia de|dia do|dia da) )?(vespera de natal|natal|reveillon|virada do ano|ano novo|ano-novo|tiradentes|dia do trabalhador|dia do trabalho|independencia|dia das criancas|nossa senhora aparecida|finados|proclamacao da republica|consciencia negra|dia dos namorados|carnaval|quarta-feira de cinzas|quarta de cinzas|sexta-feira santa|sexta-feira da paixao|sexta santa|pascoa|corpus christi|dia das maes|dia dos pais)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    private struct HolidayName {
        let holiday: Holiday
        var needsPreposition = false
    }

    private static let holidays: [String: HolidayName] = [
        "natal": HolidayName(holiday: .fixed(month: 12, day: 25), needsPreposition: true),
        "vespera de natal": HolidayName(holiday: .fixed(month: 12, day: 24)),
        "reveillon": HolidayName(holiday: .fixed(month: 12, day: 31), needsPreposition: true),
        "virada do ano": HolidayName(holiday: .fixed(month: 12, day: 31)),
        "ano novo": HolidayName(holiday: .fixed(month: 1, day: 1), needsPreposition: true),
        "ano-novo": HolidayName(holiday: .fixed(month: 1, day: 1), needsPreposition: true),
        "tiradentes": HolidayName(holiday: .fixed(month: 4, day: 21), needsPreposition: true),
        "dia do trabalho": HolidayName(holiday: .fixed(month: 5, day: 1)),
        "dia do trabalhador": HolidayName(holiday: .fixed(month: 5, day: 1)),
        "dia dos namorados": HolidayName(holiday: .fixed(month: 6, day: 12)),
        "independencia": HolidayName(holiday: .fixed(month: 9, day: 7), needsPreposition: true),
        "dia das criancas": HolidayName(holiday: .fixed(month: 10, day: 12)),
        "nossa senhora aparecida": HolidayName(holiday: .fixed(month: 10, day: 12), needsPreposition: true),
        "finados": HolidayName(holiday: .fixed(month: 11, day: 2)),
        "proclamacao da republica": HolidayName(holiday: .fixed(month: 11, day: 15)),
        "consciencia negra": HolidayName(holiday: .fixed(month: 11, day: 20), needsPreposition: true),
        "carnaval": HolidayName(holiday: .easter(offset: -50, lastDay: -47), needsPreposition: true),
        "quarta-feira de cinzas": HolidayName(holiday: .easter(offset: -46)),
        "quarta de cinzas": HolidayName(holiday: .easter(offset: -46)),
        "sexta-feira santa": HolidayName(holiday: .easter(offset: -2)),
        "sexta-feira da paixao": HolidayName(holiday: .easter(offset: -2)),
        "sexta santa": HolidayName(holiday: .easter(offset: -2)),
        "pascoa": HolidayName(holiday: .easter(offset: 0), needsPreposition: true),
        "corpus christi": HolidayName(holiday: .easter(offset: 60)),
        "dia das maes": HolidayName(holiday: .secondSunday(month: 5)),
        "dia dos pais": HolidayName(holiday: .secondSunday(month: 8))
    ]

    /// Days, weeks or months, ready for `Calendar.date(byAdding:to:)`.
    private static func components(_ count: Int, unit: some StringProtocol) -> DateComponents {
        if unit.hasPrefix("dia") { DateComponents(day: count) }
        else if unit.hasPrefix("semana") { DateComponents(weekOfYear: count) }
        else { DateComponents(month: count) }
    }

    private static func amount(_ count: Int, unit: Substring) -> Value {
        unit.hasPrefix("dia") ? .days(count) : unit.hasPrefix("semana") ? .weeks(count) : .months(count)
    }

    /// `Calendar` weekday numbers, from 1, as `Locale.Weekday`.
    static let localeWeekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    private static let relativeDays = [
        "ontem": -1, "anteontem": -2, "antes de ontem": -2,
        "hoje": 0, "hj": 0, "amanha": 1, "amn": 1,
        "depois de amanha": 2, "depois de amn": 2, "dps de amanha": 2, "dps de amn": 2
    ]

    /// Abbreviations need the same hint as "segunda" to "sexta", even "sáb" and
    /// "dom" ("o dom de ensinar"). "ter" is left out: it is the verb "to have"
    /// ("para ter certeza", "vou ter às 15 uma reunião"), and no hint tells
    /// the two apart.
    private static let weekdays = [
        "domingo": 1, "segunda": 2, "terca": 3, "quarta": 4, "quinta": 5, "sexta": 6, "sabado": 7,
        "dom": 1, "seg": 2, "qua": 4, "qui": 5, "sex": 6, "sab": 7
    ]

    /// Weekdays with no other meaning, which count on their own.
    private static let weekdaysAlone: Set<String> = ["sabado", "domingo"]

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

        case .lastWeekday(let weekday):
            return calendar.nextDate(
                after: today,
                matching: DateComponents(weekday: weekday),
                matchingPolicy: .nextTime,
                direction: .backward
            ).map { ($0, nil) }

        case .lastWeek:
            // Monday to Sunday of the week before this one.
            let weekday = calendar.component(.weekday, from: today)
            guard let thisMonday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today),
                  let monday = calendar.date(byAdding: .day, value: -7, to: thisMonday),
                  let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return nil }
            return (monday, sunday)

        case .lastMonth:
            guard let thisMonth = calendar.dateInterval(of: .month, for: today)?.start,
                  let first = calendar.date(byAdding: .month, value: -1, to: thisMonth),
                  let last = lastDayOfMonth(first, calendar: calendar) else { return nil }
            return (first, last)

        case .lastYear:
            guard let thisYear = calendar.dateInterval(of: .year, for: today)?.start,
                  let first = calendar.date(byAdding: .year, value: -1, to: thisYear),
                  let last = calendar.date(byAdding: .day, value: -1, to: thisYear) else { return nil }
            return (first, last)

        case .daily, .interval:
            return (today, nil)

        case .weekly(let weekdays):
            // The next of these weekdays, counting today.
            return weekdays.compactMap { weekday in
                calendar.nextDate(
                    after: today.addingTimeInterval(-1),
                    matching: DateComponents(weekday: weekday),
                    matchingPolicy: .nextTime
                )
            }.min().map { ($0, nil) }

        case .monthly(let day):
            return resolve(.dayOfMonth(day), reference: reference, calendar: calendar)

        case .range(let from, let to):
            // The end is the first time `to` comes from the start on: "de
            // segunda a sexta" said on a Monday runs from next Monday to that
            // Friday.
            guard let first = resolve(from, reference: reference, calendar: calendar),
                  var last = resolve(to, reference: reference, calendar: calendar) else { return nil }
            if (last.end ?? last.start) < first.start, let later = resolve(to, reference: first.start, calendar: calendar) {
                last = later
            }
            let end = last.end ?? last.start
            return end > first.start ? (first.start, end) : first

        case .holiday(let holiday):
            // The next time the holiday comes, counting today; one that lasts
            // several days and has started counts from today.
            let year = calendar.component(.year, from: today)
            for year in year...(year + 1) {
                guard let days = days(of: holiday, in: year, calendar: calendar) else { return nil }
                guard (days.end ?? days.start) >= today else { continue }
                let start = max(days.start, today)
                return (start, days.end == start ? nil : days.end)
            }
            return nil
        }
    }

    private static func days(of holiday: Holiday, in year: Int, calendar: Calendar) -> (start: Date, end: Date?)? {
        switch holiday {
        case .fixed(let month, let day):
            return calendar.date(from: DateComponents(year: year, month: month, day: day)).map { ($0, nil) }
        case .easter(let offset, let lastDay):
            guard let easter = easter(in: year, calendar: calendar),
                  let start = calendar.date(byAdding: .day, value: offset, to: easter) else { return nil }
            return (start, lastDay.flatMap { calendar.date(byAdding: .day, value: $0, to: easter) })
        case .secondSunday(let month):
            guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
            let firstSunday = (8 - calendar.component(.weekday, from: first)) % 7
            return calendar.date(byAdding: .day, value: firstSunday + 7, to: first).map { ($0, nil) }
        }
    }

    /// Easter Sunday by the Gregorian computus (Meeus/Jones/Butcher).
    private static func easter(in year: Int, calendar: Calendar) -> Date? {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
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
