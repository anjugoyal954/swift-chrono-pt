import Testing
@testable import ChronoPT

@Suite("Days")
struct DayTests {
    @Test("A day in every supported format", arguments: [
        ("dentista hoje", [2026, 9, 21]),
        ("aniversário da Ana amanhã", [2026, 9, 22]),
        ("depois de amanhã", [2026, 9, 23]),
        ("reunião sexta que vem", [2026, 9, 25]),
        ("próxima sexta", [2026, 9, 25]),
        ("nesta quinta", [2026, 9, 24]),
        ("entrega na terça-feira", [2026, 9, 22]),
        ("no sábado", [2026, 9, 26]),
        ("domingo", [2026, 9, 27]),
        ("na segunda", [2026, 9, 28]),
        ("quarta da semana que vem", [2026, 9, 30]),
        ("25/09", [2026, 9, 25]),
        ("dia 25/09/2026", [2026, 9, 25]),
        ("5/1/27", [2027, 1, 5]),
        ("2026-10-15", [2026, 10, 15]),
        ("reunião dia 15 de outubro", [2026, 10, 15]),
        ("3 nov", [2026, 11, 3]),
        ("1º de maio", [2027, 5, 1]),
        ("primeiro de janeiro", [2027, 1, 1]),
        ("dia primeiro", [2026, 10, 1]),
        ("pagar o aluguel até dia 30", [2026, 9, 30]),
        ("consulta dia 5", [2026, 10, 5]),
        ("prazo dia 21", [2026, 9, 21]),
        ("ligar pro banco daqui 2 dias", [2026, 9, 23]),
        ("entregar em três dias", [2026, 9, 24]),
        ("pagar daqui a um dia", [2026, 9, 22]),
        ("daqui uma semana", [2026, 9, 28]),
        ("em duas semanas", [2026, 10, 5]),
        ("daqui um mês", [2026, 10, 21]),
        ("fim do mês", [2026, 9, 30])
    ])
    func day(_ example: (text: String, day: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == example.day)
        #expect(found.hasTime == false)
        #expect(hm(found.date) == [12, 0])
    }

    @Test("\"Semana que vem\" is Monday to Sunday of the following week")
    func nextWeek() throws {
        let found = try #require(interpret("revisar contrato semana que vem"))
        #expect(ymd(found.date) == [2026, 9, 28])
        #expect(ymd(found.end) == [2026, 10, 4])
    }

    @Test("\"Fim de semana\" is the coming Saturday and Sunday")
    func weekend() throws {
        let found = try #require(interpret("arrumar a garagem no fim de semana"))
        #expect(ymd(found.date) == [2026, 9, 26])
        #expect(ymd(found.end) == [2026, 9, 27])
    }

    @Test("\"Mês que vem\" is the whole next month")
    func nextMonth() throws {
        let found = try #require(interpret("renovar o seguro mês que vem"))
        #expect(ymd(found.date) == [2026, 10, 1])
        #expect(ymd(found.end) == [2026, 10, 31])
    }

    @Test("Named periods run from their first to their last day", arguments: [
        ("terminar o relatório esta semana", [2026, 9, 21], [2026, 9, 27]),
        ("nesta semana", [2026, 9, 21], [2026, 9, 27]),
        ("essa semana que vem", [2026, 9, 28], [2026, 10, 4]),
        ("pagar a fatura este mês", [2026, 9, 21], [2026, 9, 30]),
        ("nesse mês", [2026, 9, 21], [2026, 9, 30]),
        ("trocar de carro ano que vem", [2027, 1, 1], [2027, 12, 31]),
        ("no próximo ano", [2027, 1, 1], [2027, 12, 31])
    ])
    func namedPeriod(_ example: (text: String, start: [Int], end: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == example.start)
        #expect(ymd(found.end) == example.end)
        #expect(found.hasTime == false)
    }

    @Test("The start of next month is its first day, not the whole month", arguments: [
        "renovar no começo do mês que vem",
        "início do próximo mês"
    ])
    func startOfNextMonth(_ text: String) throws {
        let found = try #require(interpret(text))
        #expect(ymd(found.date) == [2026, 10, 1])
        #expect(found.end == nil)
    }

    @Test("\"Esta semana\" on a Sunday is just that day")
    func thisWeekOnSunday() throws {
        let sunday = monday.addingTimeInterval(6 * 86_400)
        let found = try #require(interpret("esta semana", reference: sunday))
        #expect(ymd(found.date) == [2026, 9, 27])
        #expect(found.end == nil)
    }

    @Test("An ordinal is not a weekday", arguments: [
        "pedir a segunda via do boleto",
        "quinta série",
        "a terça parte"
    ])
    func ordinalIsNotADay(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test("A weekday that is also an ordinal counts when a time follows")
    func ordinalWithTime() throws {
        let found = try #require(interpret("consulta quinta às 14h"))
        #expect(ymd(found.date) == [2026, 9, 24])
        #expect(found.hasTime)
    }

    @Test("A date that does not exist is not a date", arguments: ["31/02", "29/02/2027", "32 de maio"])
    func invalidDate(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test("Text without a date gives no date", arguments: [
        "comprar café",
        "ideia: gravar vídeo sobre isso",
        "pagar o boleto",
        "comprar 2 pacotes de arroz"
    ])
    func noDate(_ text: String) {
        #expect(interpret(text) == nil)
        #expect(parse(text).isEmpty)
    }
}
