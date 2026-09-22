import Foundation

/// Time rules: clock times ("às 9", "14h", "10:30", "às sete da noite",
/// "meio-dia e meia"), parts of the day and moments ("de manhã", "no almoço",
/// "depois da janta", "antes de dormir"), and time from now ("daqui 2 horas").
///
/// A meal is a time only with a preposition of time: "no almoço" (at lunch)
/// is 12:00, while "para o almoço" (for lunch) says what a purchase is for and
/// sets no time.
enum TimeRules {
    enum Value: Sendable {
        /// `ambiguous` when the words don't say morning or evening: "às 7".
        /// `minute` is negative for minutes before the hour: "quinze para as
        /// oito" is 8:00 and -15. `needsEnd` for a bare hour that counts only
        /// as the start of a range: "de 9 a 11h".
        case clock(hour: Int, minute: Int, ambiguous: Bool, nextDay: Bool, needsEnd: Bool = false)
        /// Part of the day or moment. `needsDay` when it is not a time on its
        /// own: "chegar cedo".
        case period(hour: Int, needsDay: Bool)
        case fromNow(minutes: Int)

        var isClock: Bool { if case .clock = self { true } else { false } }
        var isPeriod: Bool { if case .period = self { true } else { false } }
    }

    /// The time, already decided.
    enum Resolved: Sendable {
        case at(Clock)
        /// A time range: "das 14h às 16h".
        case between(Clock, until: Clock)
        case fromNow(minutes: Int)
    }

    struct Clock: Sendable {
        let hour: Int
        let minute: Int
        /// Midnight of a day is the start of the next day.
        let nextDay: Bool

        func on(_ day: Date, calendar: Calendar) -> Date? {
            guard let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return nil }
            return nextDay ? calendar.date(byAdding: .day, value: 1, to: time) : time
        }
    }

    /// Every time piece, without overlap, in text order.
    private static func candidates(in source: TextSource) -> [Piece<Value>] {
        let found = clocks(in: source) + minutesToHour(in: source) + noonAndMidnight(in: source)
            + rangeStarts(in: source) + fromNow(in: source) + periods(in: source)
        return Piece.nonOverlapping(found, in: source)
    }

    /// A time mentioned in the text, already decided: adjacent pieces ("de
    /// manhã, às 7", "à noite, lá pelas 8") become a single time.
    struct Expression: Sendable {
        let range: Range<String.Index>
        let value: Resolved
        /// Not a time on its own: "chegar cedo".
        let needsDay: Bool
        /// The pieces the time was decided from.
        let pieces: [Piece<Value>]
    }

    /// The times mentioned in the text, in text order.
    static func expressions(in source: TextSource) -> [Expression] {
        var groups: [[Piece<Value>]] = []
        for piece in candidates(in: source) {
            if let last = groups.last?.last, source.onlyConnectors(between: last.range, and: piece.range) {
                groups[groups.count - 1].append(piece)
            } else {
                groups.append([piece])
            }
        }
        return groups.compactMap { group in
            guard let first = group.first, let last = group.last else { return nil }
            return range(in: group, source: source) ?? resolve(group, range: first.range.lowerBound..<last.range.upperBound)
        }
    }

    /// A group with two clock times joined as a range: "das 14h às 16h", "de
    /// 9 a 11h", "entre 10 e 11h". Its range starts at the opening word.
    private static func range(in group: [Piece<Value>], source: TextSource) -> Expression? {
        guard let first = group.first, let last = group.last else { return nil }
        for index in group.indices.dropFirst() {
            guard case let .clock(hour, minute, ambiguous, nextDay, _) = group[index - 1].value,
                  case let .clock(endHour, endMinute, endAmbiguous, endNextDay, _) = group[index].value,
                  let start = source.rangeStart(from: group[index - 1].range, to: group[index].range) else { continue }
            let period = group.lazy.compactMap { piece -> Int? in
                if case let .period(hour, _) = piece.value { hour } else { nil }
            }.first
            let (from, until) = range(
                from: (hour, minute, ambiguous, nextDay),
                to: (endHour, endMinute, endAmbiguous, endNextDay),
                period: period
            )
            let range = min(start, first.range.lowerBound)..<last.range.upperBound
            return Expression(range: range, value: .between(from, until: until), needsDay: false, pieces: group)
        }
        return nil
    }

    /// The two ends of a time range. A part of the day settles both. Without
    /// one, the start reads as a single time would, unless the end says the
    /// half of the day ("das 7 às 9 da manhã" is 7:00 to 9:00), and an
    /// ambiguous end is the first reading after the start ("das 7 às 9" is
    /// 19:00 to 21:00). An end before the start is on the next day.
    private static func range(from start: ClockPiece, to end: ClockPiece, period: Int?) -> (Clock, Clock) {
        let ends = readings(of: end, period: period)
        let single = minutes(of: start, period: period)
        let from = ends.count == 1 ? readings(of: start, period: period).last { $0 < ends[0] } ?? single : single
        let until = ends.first { $0 > from } ?? ends[0] + 24 * 60
        return (time(minutes: from), time(minutes: until))
    }

    private typealias ClockPiece = (hour: Int, minute: Int, ambiguous: Bool, nextDay: Bool)

    /// Minutes from the start of the day. An ambiguous hour follows the part
    /// of the day or, without one, the way people speak: one to seven is
    /// afternoon or evening ("às 7" is 19:00), eight to eleven is morning.
    private static func minutes(of clock: ClockPiece, period: Int?) -> Int {
        let afternoon = clock.ambiguous && (period.map { $0 >= 12 } ?? (clock.hour <= 7))
        return (clock.hour + (afternoon ? 12 : 0)) * 60 + clock.minute + (clock.nextDay ? 24 * 60 : 0)
    }

    /// Both halves of the day for an ambiguous hour with no part of the day;
    /// one reading otherwise.
    private static func readings(of clock: ClockPiece, period: Int?) -> [Int] {
        guard clock.ambiguous, period == nil else { return [minutes(of: clock, period: period)] }
        let morning = clock.hour * 60 + clock.minute
        return [morning, morning + 12 * 60]
    }

    /// Minutes as a clock time; past midnight is the next day. Minutes before
    /// the hour move back from the named hour: "dez para a meia-noite" is 23:50
    /// of the same day.
    private static func time(minutes: Int) -> Clock {
        Clock(hour: minutes / 60 % 24, minute: minutes % 60, nextDay: minutes >= 24 * 60)
    }

    /// A part of the day next to the day and a clock time said further on make
    /// one time when both fall in the same half of the day: "amanhã de manhã,
    /// reunião às 7" is 7:00, while "amanhã de manhã, jantar às 19h" stays at
    /// 9:00. The range stays the part of the day's.
    static func joining(_ partOfDay: Expression, _ clock: Expression) -> Expression? {
        guard case .at = clock.value,
              partOfDay.pieces.allSatisfy(\.value.isPeriod),
              clock.pieces.allSatisfy(\.value.isClock),
              case .at(let period) = partOfDay.value,
              let joined = resolve(partOfDay.pieces + clock.pieces, range: partOfDay.range),
              case .at(let time) = joined.value,
              (time.hour >= 12) == (period.hour >= 12) else { return nil }
        return joined
    }

    /// Time from now beats everything; a clock time beats a part of the day,
    /// and the part of the day settles a clock time that doesn't say morning
    /// or evening: "de manhã, às 7" is 7:00.
    private static func resolve(_ group: [Piece<Value>], range: Range<String.Index>) -> Expression? {
        var clock: ClockPiece?
        var period: (hour: Int, needsDay: Bool)?

        for piece in group {
            switch piece.value {
            case .fromNow(let minutes):
                return Expression(range: range, value: .fromNow(minutes: minutes), needsDay: false, pieces: group)
            case let .clock(hour, minute, ambiguous, nextDay, needsEnd):
                if clock == nil, !needsEnd { clock = (hour, minute, ambiguous, nextDay) }
            case let .period(hour, needsDay):
                if period == nil { period = (hour, needsDay) }
            }
        }

        if let clock {
            let time = time(minutes: minutes(of: clock, period: period?.hour))
            return Expression(range: range, value: .at(time), needsDay: false, pieces: group)
        }
        if let period {
            return Expression(range: range, value: .at(Clock(hour: period.hour, minute: 0, nextDay: false)), needsDay: period.needsDay, pieces: group)
        }
        return nil
    }

    // MARK: - Clock

    private static func clocks(in source: TextSource) -> [Piece<Value>] {
        source.normalized.matches(of: clock).compactMap { match in
            let (_, prefix, hourText, separator, minuteText, unit, minuteWords, meridiem) = match.output
            let spoken = Int(hourText) == nil
            // A bare number is not a time: it needs "às", "h", ":" or "da tarde".
            // A spelled-out hour needs "às" or "da tarde", because "uma" is also
            // an article.
            let marked = prefix != nil || meridiem != nil || (!spoken && (separator != nil || unit != nil))
            guard marked, let base = SpokenNumber.value(hourText), (0...23).contains(base) else { return nil }
            if prefix == nil, meridiem == nil, isDuration(match.range, in: source) { return nil }

            let minute: Int
            if let minuteText {
                minute = Int(minuteText) ?? 0
            } else if let minuteWords {
                minute = minuteWords == "meia" ? 30 : SpokenNumber.value(minuteWords) ?? 0
            } else {
                minute = 0
            }
            guard (0...59).contains(minute) else { return nil }

            if let meridiem {
                let (hour, nextDay) = clockHour(base, meridiem: meridiem)
                return Piece(range: match.range, value: .clock(hour: hour, minute: minute, ambiguous: false, nextDay: nextDay))
            }
            // Written "7h" or "07:00" is the 24-hour clock; spoken, "às 7"
            // doesn't say morning or evening.
            let written = separator != nil || unit?.first == "h" || hourText.hasPrefix("0")
            let ambiguous = (1...11).contains(base) && !written
            return Piece(range: match.range, value: .clock(hour: base, minute: minute, ambiguous: ambiguous, nextDay: false))
        }
    }

    /// Minutes before the hour: "quinze para as oito" is 7:45. The named hour
    /// decides morning or evening, as in "às oito".
    private static func minutesToHour(in source: TextSource) -> [Piece<Value>] {
        source.normalized.matches(of: minutesTo).compactMap { match in
            let (_, minuteText, unit, hourText, meridiem) = match.output
            // Digits need "min": "de 3 pra 1" is a score.
            guard Int(minuteText) == nil || unit != nil,
                  let minutes = SpokenNumber.value(minuteText), (1...30).contains(minutes) else { return nil }

            let clock: (hour: Int, ambiguous: Bool, nextDay: Bool)
            if hourText.hasPrefix("meio") {
                clock = (12, false, false)
            } else if hourText.hasPrefix("meia") {
                clock = (0, false, true)
            } else {
                guard let named = SpokenNumber.value(hourText), (1...12).contains(named) else { return nil }
                if let meridiem {
                    let (hour, nextDay) = clockHour(named, meridiem: meridiem)
                    clock = (hour, false, nextDay)
                } else {
                    clock = (named, named <= 11, false)
                }
            }
            return Piece(range: match.range, value: .clock(hour: clock.hour, minute: -minutes, ambiguous: clock.ambiguous, nextDay: clock.nextDay))
        }
    }

    /// A bare hour after "de" or "entre", followed by the word that closes a
    /// range: "de 9" in "de 9 a 11h". It counts only with an end.
    private static func rangeStarts(in source: TextSource) -> [Piece<Value>] {
        source.normalized.matches(of: bareRangeStart).compactMap { match in
            guard let hour = SpokenNumber.value(match.output.1), (0...23).contains(hour) else { return nil }
            let value = Value.clock(hour: hour, minute: 0, ambiguous: (1...11).contains(hour), nextDay: false, needsEnd: true)
            return Piece(range: match.range, value: value)
        }
    }

    /// The 24-hour clock for a spoken hour and its part of the day: "7 da
    /// noite" is 19:00, and "12 da noite" is midnight, the start of the next day.
    private static func clockHour(_ base: Int, meridiem: Substring) -> (hour: Int, nextDay: Bool) {
        switch meridiem {
        case "manha", "madrugada": (base == 12 ? 0 : base, false)
        case "tarde": (base < 12 ? base + 12 : base, false)
        default: base == 12 ? (0, true) : (base < 12 ? base + 12 : base, false)
        }
    }

    private static func noonAndMidnight(in source: TextSource) -> [Piece<Value>] {
        source.normalized.matches(of: noonOrMidnight).compactMap { match in
            let (_, prefix, word, minuteWords) = match.output
            // "Meio dia" as two words without "ao" may mean half a day: "meio dia de folga".
            if word == "meio dia", prefix == nil { return nil }
            let minute = minuteWords.map { $0 == "meia" ? 30 : SpokenNumber.value($0) ?? 0 } ?? 0
            let midnight = word.hasPrefix("meia")
            return Piece(range: match.range, value: .clock(hour: midnight ? 0 : 12, minute: minute, ambiguous: false, nextDay: midnight))
        }
    }

    private static func fromNow(in source: TextSource) -> [Piece<Value>] {
        source.normalized.matches(of: inTime).compactMap { match in
            let (_, amount, unit) = match.output
            let hours = unit.hasPrefix("hora")
            let minutes: Int
            if amount == "meia" {
                guard hours else { return nil }
                minutes = 30
            } else {
                guard let count = SpokenNumber.value(amount) else { return nil }
                minutes = hours ? count * 60 : count
            }
            return Piece(range: match.range, value: .fromNow(minutes: minutes))
        }
    }

    /// Hours with duration words around them: "por 2 horas", "há 1h30",
    /// "8h por dia", "8 horas diárias".
    private static func isDuration(_ range: Range<String.Index>, in source: TextSource) -> Bool {
        if let before = source.word(before: range.lowerBound), durationWords.contains(before) { return true }
        let after = source.words(after: range.upperBound, count: 2)
        return rateWords.contains { after.starts(with: $0) }
    }

    private static let durationWords: Set<String> = ["por", "durante", "ha", "faz", "cada", "daqui", "em", "apos", "umas", "uns"]

    private static let rateWords: [[String]] = [
        ["por", "dia"], ["por", "noite"], ["por", "semana"], ["por", "mes"], ["ao", "dia"],
        ["diarias"], ["diarios"], ["semanais"], ["seguidas"], ["seguidos"]
    ]

    // Computed, not stored: `Regex` is not `Sendable`. `RegexCache` keeps each
    // one built per thread. The text arrives without accents or punctuation.

    // "às 9", "14h", "9h30", "10:30", "15:30h", "15h30min", "às 7 e meia", "às sete da noite", "3 da tarde",
    // "às vinte e duas horas", "às oito e trinta e cinco"
    private static var clock: Regex<(Substring, Substring?, Substring, Substring?, Substring?, Substring?, Substring?, Substring?)> {
        RegexCache.regex {
            #/\b(?:(as|ate as|pelas|la pelas|por volta das|a partir das|das) )?(\d{1,2}|vinte e uma|vinte e um|vinte e duas|vinte e dois|vinte e tres|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|duas|uma)(?:(:|h)(\d{2})(?:hs|h|min|m)?\b|( ?(?:hrs|hr|hs|horas|hora|h))\b|\b)(?: e (meia|(?:vinte|trinta|quarenta|cinquenta) e (?:um|uma|dois|duas|tres|quatro|cinco|seis|sete|oito|nove)|vinte|trinta|quarenta|cinquenta|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|cinco|\d{1,2})\b)?(?: (?:da|de|pela) (manha|tarde|noite|madrugada)\b)?/#
                .wordBoundaryKind(.simple)
        }
    }

    // "quinze para as oito", "vinte e cinco pras 9", "10 minutos para as 3 da tarde"
    private static var minutesTo: Regex<(Substring, Substring, Substring?, Substring, Substring?)> {
        RegexCache.regex {
            #/\b(?:(?:as|pelas|la pelas|por volta das|ate as) )?(vinte e cinco|cinco|dez|quinze|vinte|\d{1,2})( min| minutos)? (?:para as|para a|para o|pras|pra as|pra a|pro) (\d{1,2}|uma|duas|tres|quatro|cinco|seis|sete|oito|nove|dez|onze|doze|meio-dia|meio dia|meia-noite|meia noite)\b(?: (?:da|de|pela) (manha|tarde|noite|madrugada)\b)?/#
                .wordBoundaryKind(.simple)
        }
    }

    // "de 9 a 11h", "entre 10 e 11h"
    private static var bareRangeStart: Regex<(Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:de|entre) (\d{1,2}|vinte e uma|vinte e um|vinte e duas|vinte e dois|vinte e tres|vinte|dezenove|dezoito|dezessete|dezesseis|quinze|catorze|quatorze|treze|doze|onze|dez|nove|oito|sete|seis|cinco|quatro|tres|duas|uma)\b(?= (?:a|as|ate|e) )/#
                .wordBoundaryKind(.simple)
        }
    }

    // "ao meio-dia", "meio-dia e meia", "à meia-noite"
    private static var noonOrMidnight: Regex<(Substring, Substring?, Substring, Substring?)> {
        RegexCache.regex {
            #/\b(?:(ao|a|as|pelo|pela|por volta do|por volta da|la pelo|la pela|ate o|ate a) )?(meio-dia|meio dia|meia-noite|meia noite)(?: e (meia|quinze|vinte|trinta|quarenta|cinco|dez|\d{1,2})\b)?\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // "daqui 2 horas", "em meia hora", "daqui a 20 minutos"
    private static var inTime: Regex<(Substring, Substring, Substring)> {
        RegexCache.regex {
            #/\b(?:daqui a|daqui|em|dentro de) (\d{1,3}|uma|um|duas|dois|tres|quatro|cinco|seis|sete|oito|nove|dez|quinze|vinte|trinta|quarenta|cinquenta|meia) (horas?|minutos?|min)\b/#
                .wordBoundaryKind(.simple)
        }
    }

    // MARK: - Parts of the day and moments

    private struct Period {
        let phrases: [String]
        let hour: Int
        var needsDay = false
    }

    /// Lowercase, without accents. The hour is the one a person would expect
    /// on the reminder: lunch at noon, dinner at 19:00, "de madrugada" at 5:00.
    private static let table: [Period] = [
        Period(phrases: ["depois do almoco", "apos o almoco"], hour: 14),
        Period(phrases: ["antes do almoco"], hour: 11),
        Period(phrases: ["na hora do almoco", "no horario do almoco", "no almoco", "ao almoco", "a hora do almoco", "a hora de almoco", "na hora de almoco"], hour: 12),
        Period(phrases: ["depois da janta", "depois do jantar", "apos a janta", "apos o jantar"], hour: 21),
        Period(phrases: ["antes da janta", "antes do jantar"], hour: 18),
        Period(phrases: ["na hora da janta", "na hora do jantar", "na janta", "no jantar", "ao jantar", "a hora do jantar", "a hora de jantar", "na hora de jantar"], hour: 19),
        Period(phrases: ["no cafe da manha", "na hora do cafe", "ao cafe da manha", "ao pequeno-almoco", "no pequeno-almoco", "ao pequeno almoco"], hour: 8),
        Period(phrases: ["no lanche da tarde", "no cafe da tarde", "na hora do lanche"], hour: 16),
        Period(phrases: ["antes de dormir", "na hora de dormir"], hour: 22),
        Period(phrases: ["ao acordar", "quando acordar", "quando eu acordar", "assim que acordar"], hour: 7),
        Period(phrases: ["depois do trabalho", "depois do expediente", "no fim do expediente", "saindo do trabalho"], hour: 18),
        Period(phrases: ["de madrugada", "na madrugada", "pela madrugada"], hour: 5),
        Period(phrases: ["de manha cedo", "de manhazinha", "logo cedo", "bem cedo", "cedinho"], hour: 7),
        Period(phrases: ["cedo"], hour: 7, needsDay: true),
        Period(phrases: ["no meio da manha"], hour: 10),
        Period(phrases: ["no fim da manha", "no final da manha"], hour: 11),
        Period(phrases: ["de manha", "pela manha", "na parte da manha", "esta manha", "essa manha", "nesta manha", "nessa manha"], hour: 9),
        Period(phrases: ["no comeco da tarde", "no inicio da tarde"], hour: 13),
        Period(phrases: ["no meio da tarde"], hour: 15),
        Period(phrases: ["a tarde", "de tarde", "pela tarde", "na parte da tarde", "esta tarde", "essa tarde", "nesta tarde", "nessa tarde"], hour: 15),
        Period(phrases: ["no fim da tarde", "no final da tarde", "no fim de tarde", "ao fim da tarde", "ao final da tarde", "a tardinha", "de tardinha"], hour: 18),
        Period(phrases: ["no fim do dia", "no final do dia", "ao fim do dia", "ao final do dia"], hour: 18),
        Period(phrases: ["a noitinha", "de noitinha", "no comeco da noite", "no inicio da noite"], hour: 19),
        Period(phrases: ["a noite", "de noite", "pela noite", "na parte da noite", "esta noite", "essa noite", "nesta noite", "nessa noite"], hour: 19),
        Period(phrases: ["tarde da noite"], hour: 23)
    ]

    private static func periods(in source: TextSource) -> [Piece<Value>] {
        table.flatMap { period in
            period.phrases.flatMap { phrase in
                source.wordRanges(of: phrase).map {
                    Piece(range: $0, value: .period(hour: period.hour, needsDay: period.needsDay))
                }
            }
        }
    }
}
