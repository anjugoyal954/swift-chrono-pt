import Foundation
import Testing
@testable import ChronoPT

/// The README shows real behavior: its code examples and every example in its
/// table are checked here.
@Suite("README")
struct ReadmeTests {
    @Test("Code examples")
    func codeExamples() throws {
        let reminder = try #require(interpret("comprar pão amanhã no almoço"))
        #expect(ymd(reminder.date) == [2026, 9, 22])
        #expect(hm(reminder.date) == [12, 0])
        #expect(reminder.text == "amanhã no almoço")

        let note = try #require(interpret("amanhã de manhã, reunião às 7"))
        #expect(hm(note.date) == [7, 0])
        #expect(note.hasTime)

        let text = "dentista sexta às 14h, reunião dia 30 e ligar pro banco amanhã"
        let found = parse(text)
        #expect(found.map(\.text) == ["sexta às 14h", "dia 30", "amanhã"])
        #expect(text[found[0].range] == "sexta às 14h")

        let shift = try #require(interpret("plantão de segunda a sexta das 9 às 18"))
        #expect(ymd(shift.date) == [2026, 9, 28])
        #expect(hm(shift.date) == [9, 0])
        let end = try #require(shift.end)
        #expect(ymd(end) == [2026, 10, 2])
        #expect(hm(end) == [18, 0])
    }

    @Test("Accents and capitals are optional")
    func accentsAndCapitals() throws {
        let clock = try #require(interpret("AMANHA as 9"))
        #expect(ymd(clock.date) == [2026, 9, 22])
        #expect(hm(clock.date) == [9, 0])
        #expect(hm(try #require(interpret("amanhã no almoco")).date) == [12, 0])
    }

    @Test("Every example in the table parses")
    func tableExamples() throws {
        let readme = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("README.md")
        let rows = try String(contentsOf: readme, encoding: .utf8)
            .split(separator: "\n")
            .filter { $0.hasPrefix("| ") && !$0.hasPrefix("| Kind") }
            .map { $0.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) } }
        #expect(rows.count == 10)

        for row in rows {
            let (kind, examples) = (row[0], row[1].components(separatedBy: ", "))
            for example in examples {
                switch kind {
                case "Relative day", "Weekday", "Date", "Period", "Holiday":
                    let found = interpret(example)
                    #expect(found?.hasTime == false, "\(kind): \(example)")
                case "Clock time", "Part of the day", "Moment":
                    #expect(interpret("amanhã " + example)?.hasTime == true, "\(kind): \(example)")
                case "From now":
                    #expect(interpret(example)?.hasTime == true, "\(kind): \(example)")
                case "Range":
                    #expect(interpret(example)?.end != nil, "\(kind): \(example)")
                default:
                    Issue.record("Unknown kind in the README table: \(kind)")
                }
            }
        }
    }
}
