import Foundation

/// O texto como as regras leem: minúsculo, sem acento, e pontuação virando
/// espaço, com um caractere para cada caractere do original. Assim a posição
/// achada aqui é a mesma no texto de quem escreveu, e "Almoço," casa com
/// "almoco".
///
/// Ficam a barra, os dois pontos e o hífen: "25/09", "10:30", "meio-dia".
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

    /// A mesma posição no texto original.
    func originalRange(_ range: Range<String.Index>) -> Range<String.Index> {
        let start = normalized.distance(from: normalized.startIndex, to: range.lowerBound)
        let length = length(of: range)
        let lower = original.index(original.startIndex, offsetBy: start)
        return lower..<original.index(lower, offsetBy: length)
    }

    func length(of range: Range<String.Index>) -> Int {
        normalized.distance(from: range.lowerBound, to: range.upperBound)
    }

    /// Onde a frase aparece como palavras inteiras: "a noite" não casa dentro
    /// de "da noite".
    func wordRanges(of phrase: String) -> [Range<String.Index>] {
        normalized.ranges(of: phrase).filter { range in
            let before = range.lowerBound > normalized.startIndex ? normalized[normalized.index(before: range.lowerBound)] : nil
            let after = range.upperBound < normalized.endIndex ? normalized[range.upperBound] : nil
            return !Self.isWordCharacter(before) && !Self.isWordCharacter(after)
        }
    }

    /// A palavra logo antes da posição, para regra que depende do contexto:
    /// "por 2 horas" é duração, não hora.
    func word(before index: String.Index) -> String? {
        normalized[..<index].split(whereSeparator: { !Self.isWordCharacter($0) }).last.map(String.init)
    }

    /// Entre os dois trechos só há espaço e preposição: "amanhã às 9",
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

/// Um trecho achado por uma regra, com a posição no texto normalizado.
struct Piece<Value: Sendable>: Sendable {
    let range: Range<String.Index>
    let value: Value

    /// Tira os trechos sobrepostos: fica o que começa antes e, empatado, o mais
    /// longo. "Depois de amanhã" ganha de "amanhã"; "de manhã cedo", de "de
    /// manhã". O resultado sai na ordem do texto.
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

/// Número por extenso, dos pequenos que se falam em data e hora.
enum SpokenNumber {
    static func value(_ word: some StringProtocol) -> Int? {
        if let number = Int(word) { return number }
        return words[String(word)]
    }

    private static let words: [String: Int] = [
        "um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6,
        "sete": 7, "oito": 8, "nove": 9, "dez": 10, "onze": 11, "doze": 12, "quinze": 15,
        "vinte": 20, "vinte e cinco": 25, "trinta": 30, "quarenta": 40, "quarenta e cinco": 45, "cinquenta": 50
    ]
}
