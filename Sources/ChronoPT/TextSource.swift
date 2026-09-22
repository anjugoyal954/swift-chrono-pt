import Foundation

/// The text as the rules read it: lowercase, without accents, punctuation
/// turned into spaces, and one character for each character of the original.
/// A position found here is the same position in the writer's text, and
/// "Almoço," matches "almoco".
///
/// Slash, colon and hyphen stay: "25/09", "10:30", "meio-dia".
struct TextSource {
    let original: String
    let normalized: String

    init(_ text: String) {
        original = text
        normalized = String(text.map { character in
            let folded = String(character).folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "pt_BR")
            )
            guard folded.count == 1, let simple = folded.first else { return character }
            return simple.isLetter || simple.isNumber || "/:-".contains(simple) ? simple : " "
        })
    }

    /// The same position in the original text.
    func originalRange(_ range: Range<String.Index>) -> Range<String.Index> {
        let start = normalized.distance(from: normalized.startIndex, to: range.lowerBound)
        let length = length(of: range)
        let lower = original.index(original.startIndex, offsetBy: start)
        return lower..<original.index(lower, offsetBy: length)
    }

    func length(of range: Range<String.Index>) -> Int {
        normalized.distance(from: range.lowerBound, to: range.upperBound)
    }

    /// Where the phrase appears as whole words: "a noite" does not match
    /// inside "da noite".
    func wordRanges(of phrase: String) -> [Range<String.Index>] {
        normalized.ranges(of: phrase).filter { range in
            let before = range.lowerBound > normalized.startIndex ? normalized[normalized.index(before: range.lowerBound)] : nil
            let after = range.upperBound < normalized.endIndex ? normalized[range.upperBound] : nil
            return !Self.isWordCharacter(before) && !Self.isWordCharacter(after)
        }
    }

    /// The word right before the position, for rules that depend on context:
    /// "por 2 horas" is a duration, not a time.
    func word(before index: String.Index) -> String? {
        normalized[..<index].split(whereSeparator: { !Self.isWordCharacter($0) }).last.map(String.init)
    }

    /// The words right after the position: "8h por dia" is a duration.
    func words(after index: String.Index, count: Int) -> [String] {
        normalized[index...].split(whereSeparator: { !Self.isWordCharacter($0) }).prefix(count).map(String.init)
    }

    /// Only spaces and prepositions between the two ranges: "amanhã às 9",
    /// "sexta à noite", "hoje, no almoço".
    func onlyConnectors(between first: Range<String.Index>, and second: Range<String.Index>) -> Bool {
        let (left, right) = first.lowerBound <= second.lowerBound ? (first, second) : (second, first)
        guard left.upperBound <= right.lowerBound else { return true }
        return normalized[left.upperBound..<right.lowerBound]
            .split(whereSeparator: { !Self.isWordCharacter($0) })
            .allSatisfy { Self.connectors.contains(String($0)) }
    }

    private static let connectors: Set<String> = [
        "a", "as", "ao", "de", "do", "da", "no", "na", "pela", "pelo", "e", "la", "por", "volta"
    ]

    private static func isWordCharacter(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character.isLetter || character.isNumber
    }
}

/// A piece of text found by a rule, with its position in the normalized text.
struct Piece<Value: Sendable>: Sendable {
    let range: Range<String.Index>
    let value: Value

    /// Drops overlapping pieces: the one that starts first stays and, on a
    /// tie, the longest. "Depois de amanhã" beats "amanhã"; "de manhã cedo"
    /// beats "de manhã". The result is in text order.
    static func nonOverlapping(_ pieces: [Self], in source: TextSource) -> [Self] {
        let sorted = pieces.sorted { lhs, rhs in
            if lhs.range.lowerBound != rhs.range.lowerBound { return lhs.range.lowerBound < rhs.range.lowerBound }
            return source.length(of: lhs.range) > source.length(of: rhs.range)
        }
        var kept: [Self] = []
        for piece in sorted where !kept.contains(where: { $0.range.overlaps(piece.range) }) {
            kept.append(piece)
        }
        return kept
    }
}

/// Spelled-out numbers, the ones people use for dates and times: "quinze",
/// "vinte e três". A compound is a ten and a unit joined by "e".
enum SpokenNumber {
    static func value(_ text: some StringProtocol) -> Int? {
        if let number = Int(text) { return number }
        let parts = text.split(separator: " e ").map { String($0) }
        switch parts.count {
        case 1:
            return units[parts[0]] ?? teens[parts[0]] ?? tens[parts[0]]
        case 2:
            guard let ten = tens[parts[0]], let unit = units[parts[1]] else { return nil }
            return ten + unit
        default:
            return nil
        }
    }

    private static let units: [String: Int] = [
        "um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5,
        "seis": 6, "sete": 7, "oito": 8, "nove": 9
    ]

    private static let teens: [String: Int] = [
        "dez": 10, "onze": 11, "doze": 12, "treze": 13, "catorze": 14, "quatorze": 14, "quinze": 15,
        "dezesseis": 16, "dezessete": 17, "dezoito": 18, "dezenove": 19
    ]

    private static let tens: [String: Int] = ["vinte": 20, "trinta": 30, "quarenta": 40, "cinquenta": 50]
}
