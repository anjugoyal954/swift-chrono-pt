import Foundation
import Testing
@testable import ChronoPT

@Suite("Recurrence")
struct RecurrenceTests {
    @Test("Repeating notes give the next time and how they repeat", arguments: [
        ("tirar o lixo toda terça às 20h", [2026, 9, 22], [20, 0], Recurrence.weekly([.tuesday])),
        ("reunião toda segunda às 9", [2026, 9, 28], [9, 0], .weekly([.monday])),
        ("toda segunda às 18h", [2026, 9, 21], [18, 0], .weekly([.monday])),
        ("todas as sextas às 19h", [2026, 9, 25], [19, 0], .weekly([.friday])),
        ("academia às segundas e quartas às 7h", [2026, 9, 23], [7, 0], .weekly([.monday, .wednesday])),
        ("inglês nas terças e quintas às 19h", [2026, 9, 22], [19, 0], .weekly([.tuesday, .thursday])),
        ("todo dia às 8", [2026, 9, 22], [8, 0], .daily),
        ("tomar remédio todos os dias às 22h", [2026, 9, 21], [22, 0], .daily)
    ])
    func withTime(_ example: (text: String, day: [Int], time: [Int], recurrence: Recurrence)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == example.day)
        #expect(hm(found.date) == example.time)
        #expect(found.recurrence == example.recurrence)
    }

    @Test("Repeating days with no time", arguments: [
        ("todo sábado", [2026, 9, 26], Recurrence.weekly([.saturday])),
        ("regar as plantas diariamente", [2026, 9, 21], .daily),
        ("pagar aluguel todo dia 5", [2026, 10, 5], .monthly(day: 5)),
        ("todo mês no dia 10", [2026, 10, 10], .monthly(day: 10))
    ])
    func dayOnly(_ example: (text: String, day: [Int], recurrence: Recurrence)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == example.day)
        #expect(found.hasTime == false)
        #expect(found.recurrence == example.recurrence)
    }

    @Test("A single day does not repeat", arguments: ["amanhã", "na segunda", "sexta às 10", "dia 5"])
    func single(_ text: String) throws {
        #expect(try #require(interpret(text)).recurrence == nil)
    }

    @Test("Plural weekday words need \"às\", \"nas\" or \"todas as\"")
    func pluralWithoutPreposition() {
        #expect(interpret("segundas intenções") == nil)
    }
}
