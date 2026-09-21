import Testing
@testable import ChronoPT

@Suite("Dia")
struct DayTests {
    @Test("Dia citado, em todos os formatos", arguments: [
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
    func dia(_ example: (text: String, day: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == example.day)
        #expect(found.hasTime == false)
        #expect(hm(found.date) == [12, 0])
    }

    @Test("Semana que vem é de segunda a domingo da semana seguinte")
    func semanaQueVem() throws {
        let found = try #require(interpret("revisar contrato semana que vem"))
        #expect(ymd(found.date) == [2026, 9, 28])
        #expect(ymd(found.end) == [2026, 10, 4])
    }

    @Test("Fim de semana é o sábado e o domingo que vêm")
    func fimDeSemana() throws {
        let found = try #require(interpret("arrumar a garagem no fim de semana"))
        #expect(ymd(found.date) == [2026, 9, 26])
        #expect(ymd(found.end) == [2026, 9, 27])
    }

    @Test("Mês que vem é o mês inteiro")
    func mesQueVem() throws {
        let found = try #require(interpret("renovar o seguro mês que vem"))
        #expect(ymd(found.date) == [2026, 10, 1])
        #expect(ymd(found.end) == [2026, 10, 31])
    }

    @Test("Ordinal não vira dia da semana", arguments: [
        "pedir a segunda via do boleto",
        "quinta série",
        "a terça parte"
    ])
    func ordinalNaoEhData(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test("Dia da semana que também é ordinal conta quando vem com hora")
    func ordinalComHora() throws {
        let found = try #require(interpret("consulta quinta às 14h"))
        #expect(ymd(found.date) == [2026, 9, 24])
        #expect(found.hasTime)
    }

    @Test("Data que não existe não vira data", arguments: ["31/02", "29/02/2027", "32 de maio"])
    func dataInvalida(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test("Texto sem data não inventa data", arguments: [
        "comprar café",
        "ideia: gravar vídeo sobre isso",
        "pagar o boleto",
        "comprar 2 pacotes de arroz"
    ])
    func semData(_ text: String) {
        #expect(interpret(text) == nil)
        #expect(parse(text).isEmpty)
    }
}
