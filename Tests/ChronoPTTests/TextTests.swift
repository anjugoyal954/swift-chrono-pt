import Testing
@testable import ChronoPT

@Suite("Trecho do texto")
struct TextTests {
    @Test("Dia e hora colados saem juntos; separados, fica só o dia")
    func trecho() throws {
        #expect(try #require(interpret("dentista amanhã às 9")).text == "amanhã às 9")
        #expect(try #require(interpret("amanhã, no almoço")).text == "amanhã, no almoço")
        #expect(try #require(interpret("às 9 amanhã")).text == "às 9 amanhã")
        #expect(try #require(interpret("amanhã de manhã às 7")).text == "amanhã de manhã às 7")
        #expect(try #require(interpret("dia 25/09")).text == "dia 25/09")
    }

    @Test("Separados, a hora ainda vale para o dia")
    func separados() throws {
        let found = try #require(interpret("amanhã comprar pão no almoço"))
        #expect(found.text == "amanhã")
        #expect(found.hasTime)
        #expect(hm(found.date) == [12, 0])
    }

    @Test("O trecho aponta para o texto original, com acento e maiúscula")
    func trechoOriginal() throws {
        let text = "Reunião AMANHÃ às 9, sala 2"
        let found = try #require(ChronoPT.interpret(text, reference: segunda, calendar: saoPaulo))
        #expect(text[found.range] == "AMANHÃ às 9")
    }

    @Test("Várias datas no mesmo texto, na ordem")
    func variasDatas() {
        let found = parse("dentista sexta às 14h, reunião dia 30 e ligar pro banco amanhã")
        #expect(found.map(\.text) == ["sexta às 14h", "dia 30", "amanhã"])
        #expect(found.map { ymd($0.date) } == [[2026, 9, 25], [2026, 9, 30], [2026, 9, 22]])
        #expect(found.map(\.hasTime) == [true, false, false])
    }

    @Test("Hora solta vira expressão própria")
    func horaSolta() {
        let found = parse("amanhã comprar pão no almoço")
        #expect(found.map(\.text) == ["amanhã", "no almoço"])
    }
}
