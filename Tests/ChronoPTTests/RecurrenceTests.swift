import Foundation
import Testing
@testable import ChronoPT

@Suite("Recurrence")
struct RecurrenceTests {
    @Test("Repeating notes give the next time and how they repeat", arguments: [
        ("tirar o lixo toda terça às 20h", [2026, 9, 22], [20, 0], Recurrence.weekly(on: [.tuesday])),
        ("reunião toda segunda às 9", [2026, 9, 28], [9, 0], .weekly(on: [.monday])),
        ("toda segunda às 18h", [2026, 9, 21], [18, 0], .weekly(on: [.monday])),
        ("todas as sextas às 19h", [2026, 9, 25], [19, 0], .weekly(on: [.friday])),
        ("academia às segundas e quartas às 7h", [2026, 9, 23], [7, 0], .weekly(on: [.monday, .wednesday])),
        ("inglês nas terças e quintas às 19h", [2026, 9, 22], [19, 0], .weekly(on: [.tuesday, .thursday])),
        ("todo dia às 8", [2026, 9, 22], [8, 0], .daily),
        ("tomar remédio todos os dias às 22h", [2026, 9, 21], [22, 0], .daily)
    ])
    func withTime(_ example: (text: String, day: [Int], time: [Int], recurrence: Recurrence)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(hm(found.start.date) == example.time)
        #expect(found.recurrence == example.recurrence)
    }

    @Test("Repeating days with no time", arguments: [
        ("todo sábado", [2026, 9, 26], Recurrence.weekly(on: [.saturday])),
        ("regar as plantas diariamente", [2026, 9, 21], .daily),
        ("pagar aluguel todo dia 5", [2026, 10, 5], .monthly(day: 5)),
        ("todo mês no dia 10", [2026, 10, 10], .monthly(day: 10)),
        ("pagar no dia 10 de cada mês", [2026, 10, 10], .monthly(day: 10)),
        ("no dia 5 de todo mês", [2026, 10, 5], .monthly(day: 5))
    ])
    func dayOnly(_ example: (text: String, day: [Int], recurrence: Recurrence)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(found.start.hasTime == false)
        #expect(found.recurrence == example.recurrence)
    }

    @Test("Repeating every few days, weeks or months", arguments: [
        ("regar as plantas a cada 15 dias", [2026, 9, 21], Recurrence.every(DateComponents(day: 15))),
        ("reunião de 2 em 2 semanas às 10h", [2026, 9, 21], .every(DateComponents(weekOfYear: 2))),
        ("toda semana", [2026, 9, 21], .every(DateComponents(weekOfYear: 1))),
        ("todo mês", [2026, 9, 21], .every(DateComponents(month: 1))),
        ("mensalmente", [2026, 9, 21], .every(DateComponents(month: 1))),
        ("semanalmente", [2026, 9, 21], .every(DateComponents(weekOfYear: 1)))
    ])
    func interval(_ example: (text: String, day: [Int], recurrence: Recurrence)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == example.day)
        #expect(found.recurrence == example.recurrence)
    }

    @Test("Intervals of hours and minutes count from now", arguments: [
        ("tomar de 8 em 8 horas", [18, 0], Recurrence.every(DateComponents(hour: 8))),
        ("a cada 6 horas", [16, 0], .every(DateComponents(hour: 6))),
        ("de hora em hora", [11, 0], .every(DateComponents(hour: 1))),
        ("a cada 30 minutos", [10, 30], .every(DateComponents(minute: 30)))
    ])
    func hourInterval(_ example: (text: String, time: [Int], recurrence: Recurrence)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.start.date) == [2026, 9, 21])
        #expect(hm(found.start.date) == example.time)
        #expect(found.start.hasTime)
        #expect(found.recurrence == example.recurrence)
    }

    @Test("Different counts are not an interval")
    func mismatchedInterval() throws {
        #expect(try #require(interpret("de 2 em 3 semanas")).recurrence == nil)
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
