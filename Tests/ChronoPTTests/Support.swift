import Foundation
@testable import ChronoPT

/// Todos os testes rodam numa segunda-feira, 21/09/2026, às 10h, em São
/// Paulo: a resposta não depende do dia em que o teste roda.
let saoPaulo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    calendar.locale = Locale(identifier: "pt_BR")
    return calendar
}()

let segunda = saoPaulo.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 10))!

func interpret(_ text: String, reference: Date = segunda) -> ParsedResult? {
    ChronoPT.interpret(text, reference: reference, calendar: saoPaulo)
}

func parse(_ text: String, reference: Date = segunda) -> [ParsedResult] {
    ChronoPT.parse(text, reference: reference, calendar: saoPaulo)
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
