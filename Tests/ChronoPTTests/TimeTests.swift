import Testing
@testable import ChronoPT

@Suite("Hora")
struct TimeTests {
    @Test("Relógio, parte do dia e refeição viram hora marcada", arguments: [
        ("comprar coca cola amanha no almoco", 12, 0),
        ("amanhã na janta", 19, 0),
        ("amanhã no jantar", 19, 0),
        ("amanhã depois do almoço", 14, 0),
        ("amanhã antes do almoço", 11, 0),
        ("amanhã na hora da janta", 19, 0),
        ("amanhã depois da janta", 21, 0),
        ("amanhã antes de dormir", 22, 0),
        ("amanhã cedo", 7, 0),
        ("amanhã logo cedo", 7, 0),
        ("amanhã de manhã cedo", 7, 0),
        ("amanhã de madrugada", 5, 0),
        ("amanhã de manhã", 9, 0),
        ("amanhã no café da manhã", 8, 0),
        ("amanhã ao meio-dia", 12, 0),
        ("amanhã ao meio-dia e meia", 12, 30),
        ("amanhã à tarde", 15, 0),
        ("amanhã de tarde", 15, 0),
        ("amanhã no lanche da tarde", 16, 0),
        ("amanhã à tardinha", 18, 0),
        ("amanhã no fim da tarde", 18, 0),
        ("amanhã à noite", 19, 0),
        ("amanhã tarde da noite", 23, 0),
        ("amanhã às 9", 9, 0),
        ("amanhã às 7 e meia", 19, 30),
        ("amanhã às 7 da manhã", 7, 0),
        ("amanhã de manhã às 7", 7, 0),
        ("amanhã às sete", 19, 0),
        ("amanhã às sete da noite", 19, 0),
        ("amanhã às dez e meia", 10, 30),
        ("amanhã às 3 da tarde", 15, 0),
        ("amanhã às 7h", 7, 0),
        ("amanhã às 9h30", 9, 30),
        ("amanhã 14h", 14, 0),
        ("amanhã às 20:15", 20, 15),
        ("amanha as 11 hrs", 11, 0)
    ])
    func hora(_ example: (text: String, hour: Int, minute: Int)) throws {
        let found = try #require(interpret(example.text))
        #expect(found.hasTime)
        #expect(ymd(found.date) == [2026, 9, 22])
        #expect(hm(found.date) == [example.hour, example.minute])
    }

    @Test("Meia-noite de um dia é o começo do seguinte")
    func meiaNoite() throws {
        let today = try #require(interpret("hoje à meia-noite"))
        #expect(ymd(today.date) == [2026, 9, 22])
        #expect(hm(today.date) == [0, 0])
        let tomorrow = try #require(interpret("amanhã à meia-noite"))
        #expect(ymd(tomorrow.date) == [2026, 9, 23])
        let spoken = try #require(interpret("às 12 da noite"))
        #expect(ymd(spoken.date) == [2026, 9, 22])
        #expect(hm(spoken.date) == [0, 0])
    }

    @Test("Sem dia, é hoje nesse horário, ou amanhã se já passou")
    func semDia() throws {
        let before = try #require(interpret("comprar pão no almoço"))
        #expect(before.hasTime)
        #expect(ymd(before.date) == [2026, 9, 21])
        #expect(hm(before.date) == [12, 0])
        #expect(before.text == "no almoço")

        let afternoon = segunda.addingTimeInterval(3 * 3600)
        let after = try #require(interpret("comprar pão no almoço", reference: afternoon))
        #expect(ymd(after.date) == [2026, 9, 22])
    }

    @Test("Hora sem dia, de vários jeitos", arguments: [
        ("ligar pro João de tarde", 15),
        ("tomar remédio à noite", 19),
        ("tomar remédio ao acordar", 7),
        ("estudar depois do trabalho", 18),
        ("ligar às sete da noite", 19),
        ("reunião às 19h", 19),
        ("3 da tarde", 15)
    ])
    func semDiaVariasFormas(_ example: (text: String, hour: Int)) throws {
        let found = try #require(interpret(example.text))
        #expect(found.hasTime)
        #expect(hm(found.date).first == example.hour)
        #expect(found.date > segunda)
    }

    @Test("Daqui a pouco conta a partir de agora")
    func aPartirDeAgora() throws {
        #expect(try #require(interpret("daqui 2 horas")).date == segunda.addingTimeInterval(2 * 3600))
        #expect(try #require(interpret("em meia hora")).date == segunda.addingTimeInterval(30 * 60))
        #expect(try #require(interpret("daqui a 20 minutos")).date == segunda.addingTimeInterval(20 * 60))
    }

    @Test("Número solto, duração e 'cedo' sozinho não são hora", arguments: [
        "estudar por 2 horas",
        "comprar uma caneta",
        "chegar cedo"
    ])
    func naoEhHora(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test("Para a janta é finalidade, não hora")
    func finalidadeNaoEhHora() throws {
        #expect(interpret("comprar para a janta") == nil)
        let found = try #require(interpret("comprar para a janta amanhã"))
        #expect(found.hasTime == false)
        #expect(found.text == "amanhã")
    }

    @Test("Parte do dia vale também em período e dia do mês")
    func periodoComDia() throws {
        let nextWeek = try #require(interpret("semana que vem de manhã"))
        #expect(nextWeek.hasTime)
        #expect(ymd(nextWeek.date) == [2026, 9, 28])
        #expect(hm(nextWeek.date) == [9, 0])
        #expect(ymd(nextWeek.end) == [2026, 10, 4])

        let day30 = try #require(interpret("dia 30 à noite"))
        #expect(ymd(day30.date) == [2026, 9, 30])
        #expect(hm(day30.date) == [19, 0])
    }
}
