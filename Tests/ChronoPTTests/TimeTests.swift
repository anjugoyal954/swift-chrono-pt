import Testing
@testable import ChronoPT

@Suite("Times")
struct TimeTests {
    @Test("Clock times, parts of the day and meals set a time", arguments: [
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
        ("amanha as 11 hrs", 11, 0),
        ("amanhã às oito e quarenta e cinco", 8, 45),
        ("amanhã às quinze para as oito", 7, 45),
        ("amanhã quinze para as oito", 7, 45),
        ("amanhã vinte para as dez", 9, 40),
        ("amanhã vinte e cinco pras 9", 8, 35),
        ("amanhã quinze para as sete da noite", 18, 45),
        ("amanhã quinze para a uma", 12, 45),
        ("amanhã 10 minutos para as 3 da tarde", 14, 50),
        ("amanhã quinze para o meio-dia", 11, 45),
        ("amanhã dez para a meia-noite", 23, 50),
        ("amanhã às vinte e duas horas", 22, 0),
        ("amanhã às treze horas", 13, 0),
        ("amanhã às dezoito e trinta", 18, 30),
        ("amanhã às oito e trinta e cinco", 8, 35),
        ("amanhã às dezenove e quinze", 19, 15),
        ("amanhã às vinte e uma e quarenta", 21, 40),
        ("amanhã às 15:30h", 15, 30),
        ("amanhã às 15h30m", 15, 30),
        ("amanhã às 15h30min", 15, 30),
        ("amanhã às 15h00", 15, 0),
        ("amanhã pelas 21h00", 21, 0),
        ("amanhã ao pequeno-almoço", 8, 0),
        ("amanhã ao jantar", 19, 0),
        ("amanhã à hora de almoço", 12, 0),
        ("amanhã à hora do jantar", 19, 0),
        ("amanhã ao fim da tarde", 18, 0),
        ("amanhã ao final da tarde", 18, 0),
        ("amanhã ao fim do dia", 18, 0),
        ("amanhã dps do almoço", 14, 0),
        ("amn às 11", 11, 0)
    ])
    func time(_ example: (text: String, hour: Int, minute: Int)) throws {
        let found = try #require(interpret(example.text))
        #expect(found.hasTime)
        #expect(ymd(found.date) == [2026, 9, 22])
        #expect(hm(found.date) == [example.hour, example.minute])
    }

    @Test("Midnight of a day is the start of the next day")
    func midnight() throws {
        let today = try #require(interpret("hoje à meia-noite"))
        #expect(ymd(today.date) == [2026, 9, 22])
        #expect(hm(today.date) == [0, 0])
        let tomorrow = try #require(interpret("amanhã à meia-noite"))
        #expect(ymd(tomorrow.date) == [2026, 9, 23])
        let spoken = try #require(interpret("às 12 da noite"))
        #expect(ymd(spoken.date) == [2026, 9, 22])
        #expect(hm(spoken.date) == [0, 0])
    }

    @Test("With no day, it is today at that time, or tomorrow if it has passed")
    func noDay() throws {
        let before = try #require(interpret("comprar pão no almoço"))
        #expect(before.hasTime)
        #expect(ymd(before.date) == [2026, 9, 21])
        #expect(hm(before.date) == [12, 0])
        #expect(before.text == "no almoço")

        let afternoon = monday.addingTimeInterval(3 * 3600)
        let after = try #require(interpret("comprar pão no almoço", reference: afternoon))
        #expect(ymd(after.date) == [2026, 9, 22])
    }

    @Test("A time with no day, written several ways", arguments: [
        ("ligar pro João de tarde", 15),
        ("tomar remédio à noite", 19),
        ("tomar remédio ao acordar", 7),
        ("estudar depois do trabalho", 18),
        ("ligar às sete da noite", 19),
        ("reunião às 19h", 19),
        ("3 da tarde", 15)
    ])
    func noDayForms(_ example: (text: String, hour: Int)) throws {
        let found = try #require(interpret(example.text))
        #expect(found.hasTime)
        #expect(hm(found.date).first == example.hour)
        #expect(found.date > monday)
    }

    @Test("\"Daqui a\" counts from now")
    func fromNow() throws {
        #expect(try #require(interpret("daqui 2 horas")).date == monday.addingTimeInterval(2 * 3600))
        #expect(try #require(interpret("em meia hora")).date == monday.addingTimeInterval(30 * 60))
        #expect(try #require(interpret("daqui a 20 minutos")).date == monday.addingTimeInterval(20 * 60))
    }

    @Test("A bare number, a duration and a lone \"cedo\" are not times", arguments: [
        "estudar por 2 horas",
        "comprar uma caneta",
        "o jogo virou de 3 pra 1",
        "comprar dezesseis ovos",
        "comprar de 2 a 3 kg",
        "chegar cedo"
    ])
    func notATime(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test("A number of hours per day is a duration, not a time", arguments: [
        "trabalhar 8h por dia",
        "estudar 2 horas por semana",
        "dormir 8h por noite",
        "dormir 8 horas diárias"
    ])
    func hoursPerDay(_ text: String) {
        #expect(interpret(text) == nil)
    }

    @Test("A part of the day next to the day settles a clock time said later", arguments: [
        ("amanhã de manhã, reunião às 7", 7, 0),
        ("amanhã à noite, jantar às 8", 20, 0),
        ("amanhã no almoço, reunião às 13h", 13, 0),
        ("amanhã de madrugada, voo às 3 e meia", 3, 30)
    ])
    func partOfDayThenClock(_ example: (text: String, hour: Int, minute: Int)) throws {
        let found = try #require(interpret(example.text))
        #expect(ymd(found.date) == [2026, 9, 22])
        #expect(hm(found.date) == [example.hour, example.minute])
    }

    @Test("A clock time in the other half of the day leaves the part of the day alone")
    func partOfDayThenOtherHalf() throws {
        let found = try #require(interpret("amanhã de manhã ligar pro João, jantar às 19h"))
        #expect(hm(found.date) == [9, 0])
        #expect(found.text == "amanhã de manhã")
    }

    @Test("A time range sets the start and the end", arguments: [
        ("amanhã das 14h às 16h", [14, 0], [16, 0]),
        ("amanhã das 9 às 11", [9, 0], [11, 0]),
        ("amanhã de 14h a 16h", [14, 0], [16, 0]),
        ("amanhã entre 10 e 11h", [10, 0], [11, 0]),
        ("amanhã entre as 10 e as 11", [10, 0], [11, 0]),
        ("amanhã das 14h30 até as 15h", [14, 30], [15, 0]),
        ("amanhã das 7 às 9 da noite", [19, 0], [21, 0]),
        ("amanhã das 7 às 9 da manhã", [7, 0], [9, 0]),
        ("amanhã das 7 às 9", [19, 0], [21, 0]),
        ("amanhã das 10 às 2", [10, 0], [14, 0]),
        ("amanhã de 2 a 3 da tarde", [14, 0], [15, 0]),
        ("amanhã à noite, das 8 às 10", [20, 0], [22, 0])
    ])
    func timeRange(_ example: (text: String, start: [Int], end: [Int])) throws {
        let found = try #require(interpret(example.text))
        #expect(found.hasTime)
        #expect(ymd(found.date) == [2026, 9, 22])
        #expect(hm(found.date) == example.start)
        let end = try #require(found.end)
        #expect(ymd(end) == [2026, 9, 22])
        #expect(hm(end) == example.end)
    }

    @Test("A time range past midnight ends the next day")
    func overnightRange() throws {
        let found = try #require(interpret("amanhã das 22h às 2h"))
        #expect(ymd(found.date) == [2026, 9, 22])
        #expect(hm(found.date) == [22, 0])
        let end = try #require(found.end)
        #expect(ymd(end) == [2026, 9, 23])
        #expect(hm(end) == [2, 0])
    }

    @Test("A time range with no day is today, or tomorrow if it has started")
    func rangeWithoutDay() throws {
        let later = try #require(interpret("reunião das 14h às 16h"))
        #expect(ymd(later.date) == [2026, 9, 21])
        #expect(hm(try #require(later.end)) == [16, 0])
        let passed = try #require(interpret("academia das 8h às 9h"))
        #expect(ymd(passed.date) == [2026, 9, 22])
        #expect(ymd(passed.end) == [2026, 9, 22])
        #expect(hm(try #require(passed.end)) == [9, 0])
    }

    @Test("Two times joined by \"e\" without \"entre\" are not a range", arguments: [
        "amanhã às 9 e às 10",
        "amanhã de 9h e 10h"
    ])
    func twoTimesAreNotARange(_ text: String) throws {
        let found = try #require(interpret(text))
        #expect(hm(found.date) == [9, 0])
        #expect(found.end == nil)
    }

    @Test("\"Para a janta\" is a purpose, not a time")
    func purposeIsNotATime() throws {
        #expect(interpret("comprar para a janta") == nil)
        let found = try #require(interpret("comprar para a janta amanhã"))
        #expect(found.hasTime == false)
        #expect(found.text == "amanhã")
    }

    @Test("A part of the day also applies to periods and days of the month")
    func partOfDayWithPeriod() throws {
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
