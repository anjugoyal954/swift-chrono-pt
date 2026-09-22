import Foundation
import Testing
@testable import ChronoPT

@Suite("Known components")
struct ComponentsTests {
    static let starts: [(text: String, known: Set<Calendar.Component>)] = [
        ("25/09", [.day, .month]),
        ("25/09/2027", [.day, .month, .year]),
        ("dia 30", [.day]),
        ("amanhã", [.day, .month, .year]),
        ("daqui 2 semanas", [.day, .month, .year]),
        ("sexta às 10", [.day, .month, .year, .weekday, .hour, .minute]),
        ("amanhã de manhã", [.day, .month, .year, .hour]),
        ("às 9", [.hour, .minute]),
        ("no almoço", [.hour]),
        ("daqui 2 horas", [.day, .month, .year, .hour, .minute]),
        ("15 de outubro às 14h", [.day, .month, .hour, .minute]),
        ("mês que vem", [.month, .year]),
        ("ano que vem", [.year]),
        ("fim do mês", [.day, .month, .year]),
        ("no natal", [.day, .month]),
        ("toda terça às 20h", [.weekday, .hour, .minute]),
        ("todo dia 5", [.day]),
        ("todo dia", [])
    ]

    @Test("The text fixes some components; the reference fills the rest", arguments: starts)
    func start(_ example: (text: String, known: Set<Calendar.Component>)) throws {
        let found = try #require(interpret(example.text))
        #expect(found.start.knownComponents == example.known)
        #expect(found.start.hasTime == example.known.contains(.hour))
    }

    static let ranges: [(text: String, start: Set<Calendar.Component>, end: Set<Calendar.Component>)] = [
        ("de 10 a 15 de outubro", [.day, .month], [.day, .month]),
        ("do dia 10 ao dia 15 de novembro", [.day, .month], [.day, .month]),
        ("de hoje até o dia 30", [.day, .month, .year], [.day]),
        ("das 14h às 16h", [.hour, .minute], [.hour, .minute]),
        ("semana que vem", [.day, .month, .year], [.day, .month, .year]),
        ("de segunda a sexta das 9 às 18", [.day, .month, .year, .weekday, .hour, .minute], [.day, .month, .year, .weekday, .hour, .minute])
    ]

    @Test("Each end of a range has its own components", arguments: ranges)
    func range(_ example: (text: String, start: Set<Calendar.Component>, end: Set<Calendar.Component>)) throws {
        let found = try #require(interpret(example.text))
        #expect(found.start.knownComponents == example.start)
        #expect(try #require(found.end).knownComponents == example.end)
    }

    @Test("The end of a period with a time has the time too")
    func periodEndWithTime() throws {
        let found = try #require(interpret("semana que vem de manhã"))
        #expect(try #require(found.end).hasTime)
    }
}
