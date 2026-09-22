import Foundation
@testable import ChronoPT

/// Every test runs on Monday, 21 September 2026, at 10:00 in São Paulo, so
/// the answer does not depend on the day the tests run.
let saoPaulo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    calendar.locale = Locale(identifier: "pt_BR")
    return calendar
}()

let monday = saoPaulo.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 10))!

/// Another reference date, at 10:00 in São Paulo.
func reference(_ year: Int, _ month: Int, _ day: Int) -> Date {
    saoPaulo.date(from: DateComponents(year: year, month: month, day: day, hour: 10))!
}

func interpret(_ text: String, reference: Date = monday, options: ParseOptions = ParseOptions()) -> ParsedResult? {
    ChronoPT.interpret(text, reference: reference, calendar: saoPaulo, options: options)
}

func parse(_ text: String, reference: Date = monday, options: ParseOptions = ParseOptions()) -> [ParsedResult] {
    ChronoPT.parse(text, reference: reference, calendar: saoPaulo, options: options)
}

func ymd(_ date: Date?) -> [Int] {
    guard let date else { return [] }
    let parts = saoPaulo.dateComponents([.year, .month, .day], from: date)
    return [parts.year ?? 0, parts.month ?? 0, parts.day ?? 0]
}

func hm(_ date: Date) -> [Int] {
    let parts = saoPaulo.dateComponents([.hour, .minute], from: date)
    return [parts.hour ?? -1, parts.minute ?? -1]
}
