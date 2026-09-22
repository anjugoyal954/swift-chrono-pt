import Testing
@testable import ChronoPT

@Suite("Robustness")
struct RobustnessTests {
    /// Pieces that look like dates and times, plus accents, emoji, line breaks
    /// and lone combining marks, which change how characters group.
    static let pieces = [
        "amanhã", "às", "9", "14h", "10:30", "dia", "30", "25/09", "2026-10-15", "de", "outubro",
        "sexta", "que vem", "no almoço", "à noite", "quinze para as oito", "vinte e três",
        "daqui", "2", "horas", "por dia", "no natal", "semana", "mês", "e meia", "meio-dia",
        "ÀS", "Amanhã,", "(sexta)", "—", "🇧🇷", "👍🏽", "e\u{301}", "\u{301}", "\n", "\r\n", "\t",
        "ß", "ﬁ", "İ", "٣", "𝟗", "  ", ",", ".", "/", ":", "-"
    ]

    @Test("Random text never crashes, and every range points into the input", arguments: 0..<200)
    func randomText(_ seed: Int) throws {
        var generator = SeededGenerator(seed: UInt64(seed))
        let count = Int.random(in: 1...12, using: &generator)
        let text = (0..<count).map { _ in Self.pieces.randomElement(using: &generator)! }
            .joined(separator: Bool.random(using: &generator) ? " " : "")

        for result in parse(text) {
            #expect(text[result.range] == result.text[...], "\(text.debugDescription)")
        }
        if let result = interpret(text) {
            #expect(text[result.range] == result.text[...], "\(text.debugDescription)")
        }
    }

    @Test("A lone combining mark after a line break keeps positions aligned")
    func combiningMarkAfterLineBreak() throws {
        let text = "\n\u{301}amanhã às 9"
        let found = try #require(interpret(text))
        #expect(text[found.range] == "amanhã às 9")
    }
}

/// SplitMix64: the same seed gives the same text on every run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
