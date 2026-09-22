import Testing
@testable import ChronoPT

@Suite("Options")
struct OptionsTests {
    static let past = ParseOptions(allowsPast: true)

    @Test("Past dates need allowsPast", arguments: [
        ("pagar ontem", [2026, 9, 20]),
        ("anteontem", [2026, 9, 19]),
        ("antes de ontem", [2026, 9, 19]),
        ("sexta passada", [2026, 9, 18]),
        ("na sexta-feira passada", [2026, 9, 18]),
        ("na última sexta", [2026, 9, 18]),
        ("segunda passada", [2026, 9, 14]),
        ("há 2 dias", [2026, 9, 19]),
        ("3 dias atrás", [2026, 9, 18]),
        ("faz uma semana", [2026, 9, 14]),
        ("há um mês", [2026, 8, 21])
    ])
    func pastDay(_ example: (text: String, day: [Int])) throws {
        #expect(interpret(example.text) == nil)
        let found = try #require(interpret(example.text, options: Self.past))
        #expect(ymd(found.start.date) == example.day)
        #expect(found.start.hasTime == false)
    }

    @Test("Past periods run from their first to their last day", arguments: [
        ("semana passada", [2026, 9, 14], [2026, 9, 20]),
        ("no mês passado", [2026, 8, 1], [2026, 8, 31]),
        ("ano passado", [2025, 1, 1], [2025, 12, 31]),
        ("de ontem até sexta", [2026, 9, 20], [2026, 9, 25]),
        ("fim de semana passado", [2026, 9, 19], [2026, 9, 20])
    ])
    func pastPeriod(_ example: (text: String, start: [Int], end: [Int])) throws {
        #expect(interpret(example.text) == nil)
        let found = try #require(interpret(example.text, options: Self.past))
        #expect(ymd(found.start.date) == example.start)
        #expect(ymd(found.end?.date) == example.end)
    }

    @Test("Past times need allowsPast", arguments: [
        ("ontem à noite", [2026, 9, 20], [19, 0]),
        ("há 2 horas", [2026, 9, 21], [8, 0]),
        ("20 minutos atrás", [2026, 9, 21], [9, 40]),
        ("sexta passada às 10", [2026, 9, 18], [10, 0])
    ])
    func pastTime(_ example: (text: String, day: [Int], time: [Int])) throws {
        #expect(interpret(example.text) == nil)
        let found = try #require(interpret(example.text, options: Self.past))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
    }

    @Test("Without allowsPast, a past day never reads as a future one")
    func pastWordsBlockTheFuture() {
        #expect(interpret("reunião sexta passada às 10") == nil)
        #expect(interpret("na última sexta às 14h") == nil)
        #expect(parse("ontem à noite e amanhã cedo").map(\.text) == ["amanhã cedo"])
    }

    @Test("allowsPast leaves future dates alone")
    func futureWithPast() throws {
        let found = try #require(interpret("amanhã às 9", options: Self.past))
        #expect(ymd(found.start.date) == [2026, 9, 22])
        #expect(hm(found.start.date) == [9, 0])
    }

    @Test("defaultHour sets the time of a day with no time")
    func defaultHour() throws {
        let options = ParseOptions(defaultHour: 9)
        let day = try #require(interpret("pagar amanhã", options: options))
        #expect(hm(day.start.date) == [9, 0])
        #expect(day.start.hasTime == false)
        let week = try #require(interpret("semana que vem", options: options))
        #expect(hm(try #require(week.end?.date)) == [9, 0])
        let clock = try #require(interpret("amanhã às 15h", options: options))
        #expect(hm(clock.start.date) == [15, 0])
    }

    @Test("defaultHour stays between 0 and 23")
    func defaultHourBounds() throws {
        #expect(ParseOptions(defaultHour: 30).defaultHour == 23)
        #expect(ParseOptions(defaultHour: -1).defaultHour == 0)
        let found = try #require(interpret("amanhã", options: ParseOptions(defaultHour: 30)))
        #expect(hm(found.start.date) == [23, 0])
    }
}
