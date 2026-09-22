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
        ("fim do mês", [2026, 9, 30]),
        ("vinte e três de outubro", [2026, 10, 23]),
        ("trinta e um de dezembro", [2026, 12, 31]),
        ("dezesseis de novembro", [2026, 11, 16]),
        ("dia quinze", [2026, 10, 15]),
        ("dia dois", [2026, 10, 2]),
        ("até dia vinte e oito", [2026, 9, 28]),
        ("15 de dez", [2026, 12, 15]),
        ("dez de dez", [2026, 12, 10])
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

    @Test("Holidays, fixed and counted from Easter", arguments: [
        ("ceia no natal", [2026, 12, 25]),
        ("véspera de natal", [2026, 12, 24]),
        ("festa no réveillon", [2026, 12, 31]),
        ("viajar no ano novo", [2027, 1, 1]),
        ("feriado de tiradentes", [2027, 4, 21]),
        ("no dia do trabalho", [2027, 5, 1]),
        ("dia da independência", [2027, 9, 7]),
        ("presente pro dia das crianças", [2026, 10, 12]),
        ("dia de finados", [2026, 11, 2]),
        ("proclamação da república", [2026, 11, 15]),
        ("dia da consciência negra", [2026, 11, 20]),
        ("jantar no dia dos namorados", [2027, 6, 12]),
        ("quarta-feira de cinzas", [2027, 2, 10]),
        ("na sexta-feira santa", [2027, 3, 26]),
        ("almoço na páscoa", [2027, 3, 28]),
        ("corpus christi", [2027, 5, 27]),
        ("ligar pra mãe no dia das mães", [2027, 5, 9]),
        ("dia dos pais", [2027, 8, 8])
    ])
    func holiday(_ example: (text: String, day: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == example.day)
        #expect(found.hasTime == false)
    }

    @Test("Carnival runs from Saturday to Tuesday")
    func carnival() throws {
        let found = try #require(interpret("viajar no carnaval"))
        #expect(ymd(found.date) == [2027, 2, 6])
        #expect(ymd(found.end) == [2027, 2, 9])
    }

    @Test("A holiday that is already here counts from today")
    func holidayToday() throws {
        let found = try #require(interpret("no natal", reference: reference(2026, 12, 25)))
        #expect(ymd(found.date) == [2026, 12, 25])
        let carnival = try #require(interpret("no carnaval", reference: reference(2027, 2, 7)))
        #expect(ymd(carnival.date) == [2027, 2, 7])
        #expect(ymd(carnival.end) == [2027, 2, 9])
    }

    @Test("A holiday name with another meaning needs a preposition", arguments: [
        "comprar ovo de páscoa",
        "fantasia de carnaval",
        "livro sobre consciência negra",
        "igreja nossa senhora aparecida"
    ])
    func holidayNameWithoutPreposition(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test("Natal the city is not Christmas")
    func natalCity() throws {
        let found = try #require(interpret("voo para Natal amanhã"))
        #expect(ymd(found.date) == [2026, 9, 22])
    }

    @Test("A day range sets the first and the last day", arguments: [
        ("de segunda a sexta", [2026, 9, 28], [2026, 10, 2]),
        ("da segunda à sexta", [2026, 9, 28], [2026, 10, 2]),
        ("entre segunda e quarta", [2026, 9, 28], [2026, 9, 30]),
        ("de hoje até sexta", [2026, 9, 21], [2026, 9, 25]),
        ("de amanhã até o dia 30", [2026, 9, 22], [2026, 9, 30]),
        ("do dia 10 ao dia 15", [2026, 10, 10], [2026, 10, 15]),
        ("do dia 10 ao dia 15 de novembro", [2026, 11, 10], [2026, 11, 15]),
        ("de 10 a 15 de outubro", [2026, 10, 10], [2026, 10, 15]),
        ("entre 3 e 5 de maio", [2027, 5, 3], [2027, 5, 5]),
        ("de 10/10 a 15/10", [2026, 10, 10], [2026, 10, 15]),
        ("de 28 de dezembro a 3 de janeiro", [2026, 12, 28], [2027, 1, 3])
    ])
    func dayRange(_ example: (text: String, start: [Int], end: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(found.text == example.text)
        #expect(ymd(found.date) == example.start)
        #expect(ymd(found.end) == example.end)
        #expect(found.hasTime == false)
    }

    @Test("\"E\" closes a range only after \"entre\"", arguments: [
        ("do dia 10 e dia 15", [2026, 10, 10]),
        ("de 10 e 15 de outubro", [2026, 10, 15])
    ])
    func notADayRange(_ example: (text: String, day: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == example.day)
        #expect(found.end == nil)
    }

    @Test("A day range with a time range runs from the first start to the last end")
    func dayAndTimeRange() throws {
        let found = try #require(interpret("plantão de segunda a sexta das 9 às 18"))
        #expect(found.text == "de segunda a sexta das 9 às 18")
        #expect(ymd(found.date) == [2026, 9, 28])
        #expect(hm(found.date) == [9, 0])
        let end = try #require(found.end)
        #expect(ymd(end) == [2026, 10, 2])
        #expect(hm(end) == [18, 0])
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
        "tirar um dia de folga",
        "não é um mar de rosas",
        "comprar de 10 a 15 laranjas",
        "comprar 2 pacotes de arroz"
    ])
    func noDate(_ text: String) {
        #expect(interpret(text) == nil)
        #expect(parse(text).isEmpty)
    }
}
