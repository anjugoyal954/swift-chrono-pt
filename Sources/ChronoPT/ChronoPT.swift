import Foundation

/// Natural-language dates and times in Brazilian Portuguese.
///
/// ```swift
/// ChronoPT.interpret("comprar pão amanhã no almoço")   // tomorrow, 12:00
/// ChronoPT.parse("dentista sexta às 14h e reunião dia 30")  // two dates
/// ```
///
/// A small grammar in the style of chrono (github.com/wanasit/chrono): rules
/// find day pieces ("amanhã", "sexta que vem", "dia 30") and time pieces
/// ("às 9", "no almoço", "de madrugada"), then a day and a time are joined.
/// A new case is a new rule in `DayRules` or a new row in the `TimeRules`
/// table, without touching the rest.
///
/// Everything is computed from `reference` and `calendar`: the same text with
/// the same reference always gives the same answer, on any OS version.
public enum ChronoPT {
    /// Every date and time expression in the text, in the order they appear.
    ///
    /// A day and a time next to each other ("amanhã às 9", "sexta à noite")
    /// come out as one expression. A time with no day falls on today, or on
    /// tomorrow if that time has already passed.
    public static func parse(
        _ text: String,
        reference: Date = .now,
        calendar: Calendar = .current,
        options: ParseOptions = ParseOptions()
    ) -> [ParsedResult] {
        let context = Context(text: text, reference: reference, calendar: calendar, options: options)
        var results: [ParsedResult] = []
        var usedTimes = Set<Int>()

        for day in context.days {
            let adjacent = context.times.indices.first { index in
                !usedTimes.contains(index) && context.source.onlyConnectors(between: day.range, and: context.times[index].range)
            }
            if let adjacent { usedTimes.insert(adjacent) }
            if let result = context.combine(day, adjacent.map { context.times[$0] }) {
                results.append(result)
            }
        }
        for index in context.times.indices where !usedTimes.contains(index) {
            if let result = context.combine(nil, context.times[index]) {
                results.append(result)
            }
        }
        return results.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// The date the whole text points to: the first day mentioned, at the
    /// time next to it or, if there is none, at the first time mentioned in
    /// the text. Made for notes and reminders: "amanhã comprar pão no almoço"
    /// is tomorrow at 12:00.
    ///
    /// A part of the day next to the day also settles a clock time said further
    /// on, when both fall in the same half of the day: "amanhã de manhã,
    /// reunião às 7" is tomorrow at 7:00.
    ///
    /// When the day and the time are apart, `range` covers only the day.
    public static func interpret(
        _ text: String,
        reference: Date = .now,
        calendar: Calendar = .current,
        options: ParseOptions = ParseOptions()
    ) -> ParsedResult? {
        let context = Context(text: text, reference: reference, calendar: calendar, options: options)
        guard let day = context.days.first(where: { context.resolve($0) != nil }) else {
            return context.times.lazy.compactMap { context.combine(nil, $0) }.first
        }
        let attached = context.times.first { context.source.onlyConnectors(between: day.range, and: $0.range) }
        let joined = attached.flatMap { attached in
            context.times.lazy.compactMap { TimeRules.joining(attached, $0) }.first
        }
        return context.combine(day, joined ?? attached ?? context.times.first)
    }
}

/// How `parse` and `interpret` read the text.
public struct ParseOptions: Sendable, Equatable {
    /// Read past dates: "ontem", "anteontem", "sexta passada", "na última
    /// sexta", "semana passada", "mês passado", "há 2 dias", "2 horas atrás".
    /// Off by default, since a reminder in the past is useless. A date that
    /// only names a day, such as "dia 15" or "sexta", still means the next one.
    public var allowsPast: Bool

    /// The hour of `date` when the text gives only the day, from 0 to 23.
    /// Noon by default, away from the midnight shifts of daylight saving time.
    public var defaultHour: Int {
        get { hour }
        set { hour = Self.clamped(newValue) }
    }

    private var hour: Int

    public init(allowsPast: Bool = false, defaultHour: Int = 12) {
        self.allowsPast = allowsPast
        self.hour = Self.clamped(defaultHour)
    }

    private static func clamped(_ hour: Int) -> Int {
        min(max(hour, 0), 23)
    }
}

/// How a date repeats.
public enum Recurrence: Sendable, Equatable {
    /// Every day: "todo dia", "todos os dias", "diariamente".
    case daily
    /// On these weekdays every week, in the order the text gives them: "toda
    /// terça", "às segundas e quartas".
    case weekly([Locale.Weekday])
    /// On this day of every month: "todo dia 5", "todo mês no dia 10".
    case monthly(day: Int)
}

/// A date found in the text.
public struct ParsedResult: Sendable, Equatable {
    /// Where the expression is in the input text.
    public let range: Range<String.Index>
    /// The expression as written in the text.
    public let text: String
    /// The start. With no time in the text, it is noon of that day, or
    /// `ParseOptions.defaultHour`.
    public let date: Date
    /// The end, when the expression is a period or a range ("semana que vem",
    /// "de segunda a sexta", "das 14h às 16h").
    public let end: Date?
    /// `false` when the text gave only the day.
    public let hasTime: Bool
    /// How the date repeats, for "toda terça", "todo dia às 8" or "todo dia
    /// 5"; `nil` for a single date. `date` is the next time it happens.
    public let recurrence: Recurrence?
}

/// What `parse` and `interpret` share: the text, read only once.
struct Context {
    let source: TextSource
    let days: [Piece<DayRules.Value>]
    let times: [TimeRules.Expression]
    let reference: Date
    let calendar: Calendar
    let options: ParseOptions

    init(text: String, reference: Date, calendar: Calendar, options: ParseOptions) {
        source = TextSource(text)
        let times = TimeRules.expressions(in: source)
        let days = DayRules.expressions(in: source, times: times)
        if options.allowsPast {
            self.times = times
            self.days = days
        } else {
            // Past words still claim their text, so "sexta passada" never reads
            // as next Friday; then they drop out, with any time next to them.
            let past = days.filter(\.value.isPast)
            self.days = days.filter { !$0.value.isPast }
            self.times = times.filter { [source] time in
                !time.isPast && !past.contains { source.onlyConnectors(between: $0.range, and: time.range) }
            }
        }
        self.reference = reference
        self.calendar = calendar
        self.options = options
    }

    func resolve(_ day: Piece<DayRules.Value>, from reference: Date? = nil) -> (start: Date, end: Date?)? {
        DayRules.resolve(day.value, reference: reference ?? self.reference, calendar: calendar)
    }

    /// Joins a day and a time; either one may be missing. A repeating date is
    /// the next time it happens: "toda segunda às 9" said on a Monday at 10:00
    /// is next Monday.
    func combine(_ day: Piece<DayRules.Value>?, _ time: TimeRules.Expression?) -> ParsedResult? {
        guard let day, day.value.recurrence != nil,
              let found = combine(day, time, from: reference), found.date < reference else {
            return combine(day, time, from: reference)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference))
        return tomorrow.flatMap { combine(day, time, from: $0) } ?? found
    }

    private func combine(_ day: Piece<DayRules.Value>?, _ time: TimeRules.Expression?, from dayReference: Date) -> ParsedResult? {
        if let day {
            guard let days = resolve(day, from: dayReference) else { return nil }
            let recurrence = day.value.recurrence
            guard let time else {
                guard let start = dayOnly(days.start) else { return nil }
                return result(start, end: days.end.flatMap(dayOnly), hasTime: false, range: day.range, recurrence: recurrence)
            }
            let date: Date?
            let end: Date?
            switch time.value {
            case .fromNow(let minutes):
                date = reference.addingTimeInterval(Double(minutes) * 60)
                end = nil
            case .at(let clock):
                date = clock.on(days.start, calendar: calendar)
                end = days.end.flatMap { clock.on($0, calendar: calendar) }
            case .between(let start, let until):
                date = start.on(days.start, calendar: calendar)
                end = until.on(days.end ?? days.start, calendar: calendar)
            }
            guard let date else { return nil }
            // A day and a time next to each other come out together; apart, only the day.
            let range = source.onlyConnectors(between: day.range, and: time.range)
                ? min(day.range.lowerBound, time.range.lowerBound)..<max(day.range.upperBound, time.range.upperBound)
                : day.range
            return result(date, end: end, hasTime: true, range: range, recurrence: recurrence)
        }

        guard let time, !time.needsDay else { return nil }
        switch time.value {
        case .fromNow(let minutes):
            return result(reference.addingTimeInterval(Double(minutes) * 60), end: nil, hasTime: true, range: time.range)
        case .at(let clock):
            guard let day = upcomingDay(for: clock), let date = clock.on(day, calendar: calendar) else { return nil }
            return result(date, end: nil, hasTime: true, range: time.range)
        case .between(let start, let until):
            guard let day = upcomingDay(for: start), let date = start.on(day, calendar: calendar) else { return nil }
            return result(date, end: until.on(day, calendar: calendar), hasTime: true, range: time.range)
        }
    }

    /// Time only: today, or tomorrow if that time has passed.
    private func upcomingDay(for clock: TimeRules.Clock) -> Date? {
        guard let today = clock.on(reference, calendar: calendar) else { return nil }
        return today > reference ? reference : calendar.date(byAdding: .day, value: 1, to: reference)
    }

    /// A day with no time: noon, or `ParseOptions.defaultHour`.
    private func dayOnly(_ day: Date) -> Date? {
        calendar.date(bySettingHour: options.defaultHour, minute: 0, second: 0, of: day)
    }

    private func result(
        _ date: Date,
        end: Date?,
        hasTime: Bool,
        range: Range<String.Index>,
        recurrence: Recurrence? = nil
    ) -> ParsedResult {
        let original = source.originalRange(range)
        return ParsedResult(
            range: original,
            text: String(source.original[original]),
            date: date,
            end: end,
            hasTime: hasTime,
            recurrence: recurrence
        )
    }
}
