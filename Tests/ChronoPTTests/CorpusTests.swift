import Testing
@testable import ChronoPT

/// Notes written the way people write them: shopping, health, bills, work,
/// family; without accents, in capitals, with emoji and shorthand. The
/// expected answer is what the person meant, not what the parser happens to
/// return.
@Suite("Corpus of notes")
struct CorpusTests {
    @Test("Notes with a day and a time", arguments: [
        ("Dentista amanhã 15h", [2026, 9, 22], [15, 0]),
        ("Reunião com o time quarta às 10", [2026, 9, 23], [10, 0]),
        ("Buscar as crianças na escola às 17h30", [2026, 9, 21], [17, 30]),
        ("tomar remédio às 8 da noite", [2026, 9, 21], [20, 0]),
        ("Consulta médica sexta-feira de manhã", [2026, 9, 25], [9, 0]),
        ("enviar relatório daqui 2 horas", [2026, 9, 21], [12, 0]),
        ("academia amanhã cedo", [2026, 9, 22], [7, 0]),
        ("jantar com a Ana sábado à noite", [2026, 9, 26], [19, 0]),
        ("prova de matemática dia 30 às 8h", [2026, 9, 30], [8, 0]),
        ("Call com cliente amanhã 9h30", [2026, 9, 22], [9, 30]),
        ("lembrar de regar as plantas hj à noite", [2026, 9, 21], [19, 0]),
        ("cortar o cabelo depois do almoço", [2026, 9, 21], [14, 0]),
        ("feira de ciências 15 de outubro às 14h", [2026, 10, 15], [14, 0]),
        ("reunião de condomínio quinta às 19h", [2026, 9, 24], [19, 0]),
        ("Médico 25/09 às 14:00", [2026, 9, 25], [14, 0]),
        ("Dentista 😬 amanhã às 14h", [2026, 9, 22], [14, 0]),
        ("ir ao banco amanha de manha", [2026, 9, 22], [9, 0]),
        ("entregar o projeto até 30/09 às 18h", [2026, 9, 30], [18, 0]),
        ("chá de bebê sáb às 16h", [2026, 9, 26], [16, 0]),
        ("reunião 1:1 com gestor amanhã às 11", [2026, 9, 22], [11, 0]),
        ("reunião às 14h amanhã", [2026, 9, 22], [14, 0]),
        ("ligar para o RH em meia hora", [2026, 9, 21], [10, 30]),
        ("voo pra Natal sexta às 6h", [2026, 9, 25], [6, 0]),
        ("levar o bolo pro aniversário, às 20h de sábado", [2026, 9, 26], [20, 0]),
        ("reunião remarcada p/ sexta 10h", [2026, 9, 25], [10, 0]),
        ("DENTISTA AMANHA AS 9", [2026, 9, 22], [9, 0])
    ])
    func dayAndTime(_ example: (text: String, day: [Int], time: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == example.day)
        #expect(hm(found.date) == example.time)
        #expect(found.hasTime)
    }

    @Test("Notes with only a day", arguments: [
        ("Pagar conta de luz até sexta", [2026, 9, 25]),
        ("ligar pra mãe no domingo", [2026, 9, 27]),
        ("levar o carro na revisão dia 5", [2026, 10, 5]),
        ("aniversário do João 12/10", [2026, 10, 12]),
        ("pagar IPVA até o fim do mês", [2026, 9, 30]),
        ("entregar trabalho na próxima segunda", [2026, 9, 28]),
        ("trocar óleo do carro em 3 semanas", [2026, 10, 12]),
        ("comprar presente pro dia das crianças", [2026, 10, 12]),
        ("almoço de família no natal", [2026, 12, 25]),
        ("PAGAR CARTÃO DIA 10", [2026, 10, 10]),
        ("Aniversário da vó 3 de novembro", [2026, 11, 3]),
        ("pagar fatura 20/10/2026", [2026, 10, 20]),
        ("Prazo final: 01/10", [2026, 10, 1]),
        ("Lembrar amanhã", [2026, 9, 22])
    ])
    func onlyDay(_ example: (text: String, day: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == example.day)
        #expect(found.hasTime == false)
    }

    @Test("Notes with a period or a range of days", arguments: [
        ("viagem pra praia no fim de semana", [2026, 9, 26], [2026, 9, 27]),
        ("renovar passaporte mês que vem", [2026, 10, 1], [2026, 10, 31]),
        ("férias de 10 a 20 de dezembro", [2026, 12, 10], [2026, 12, 20]),
        ("vacina do cachorro semana que vem", [2026, 9, 28], [2026, 10, 4]),
        ("atendimento segunda a sexta", [2026, 9, 28], [2026, 10, 2]),
        ("plantão seg-sex", [2026, 9, 28], [2026, 10, 2]),
        ("congresso 10/10 a 12/10", [2026, 10, 10], [2026, 10, 12])
    ])
    func period(_ example: (text: String, start: [Int], end: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == example.start)
        #expect(ymd(found.end) == example.end)
    }

    @Test("Agenda-style time ranges", arguments: [
        ("reunião amanhã 14h às 16h", [14, 0], [16, 0]),
        ("amanhã 10h-11h call com fornecedor", [10, 0], [11, 0]),
        ("amanhã 10h–11h", [10, 0], [11, 0]),
        ("amanhã 10:00 - 11:30 revisão", [10, 0], [11, 30]),
        ("mutirão amanhã 9h até 12h", [9, 0], [12, 0])
    ])
    func agendaRange(_ example: (text: String, start: [Int], end: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == [2026, 9, 22])
        #expect(hm(found.date) == example.start)
        #expect(hm(try #require(found.end)) == example.end)
    }

    @Test("A list of times is not a range")
    func listOfTimes() throws {
        let found = try #require(interpret("tomar remédio às 7, às 9 e às 11"))
        #expect(found.end == nil)
    }

    @Test("A class on several days and hours")
    func classSchedule() throws {
        let found = try #require(interpret("curso das 19h às 22h de segunda a quinta"))
        #expect(ymd(found.date) == [2026, 9, 28])
        #expect(hm(found.date) == [19, 0])
        let end = try #require(found.end)
        #expect(ymd(end) == [2026, 10, 1])
        #expect(hm(end) == [22, 0])
    }

    @Test("Notes with no date", arguments: [
        "comprar leite, pão e café",
        "Pedir segunda via do boleto",
        "estudar por 2 horas",
        "ideia: app de receitas",
        "comprar 2 kg de arroz e 3 de feijão",
        "senha do wi-fi: casa2026",
        "livro: Cem anos de solidão",
        "sexta a gente conversa"
    ])
    func noDate(_ text: String) {
        #expect(interpret(text) == nil)
    }
}
