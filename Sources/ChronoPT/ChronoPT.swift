import Foundation

/// Datas e horas em linguagem natural, em português do Brasil.
///
/// ```swift
/// ChronoPT.interpret("comprar pão amanhã no almoço")   // amanhã, 12:00
/// ChronoPT.parse("dentista sexta às 14h e reunião dia 30")  // duas datas
/// ```
///
/// Gramática própria, no formato do chrono (github.com/wanasit/chrono): regras
/// pequenas acham pedaços de dia ("amanhã", "sexta que vem", "dia 30") e de
/// hora ("às 9", "no almoço", "de madrugada"), e depois dia e hora se juntam.
/// Caso novo é uma regra nova em `DayRules` ou uma linha nova na tabela de
/// `TimeRules`, sem mexer no resto.
///
/// Tudo é calculado a partir de `reference` e `calendar`: o mesmo texto, com a
/// mesma referência, dá sempre a mesma resposta, em qualquer versão do sistema.
public enum ChronoPT {
    /// Todas as expressões de data e hora do texto, na ordem em que aparecem.
    ///
    /// Dia e hora colados ("amanhã às 9", "sexta à noite") saem numa expressão
    /// só. Hora sem dia cai hoje, ou amanhã se o horário já passou.
    public static func parse(
        _ text: String,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> [ParsedResult] {
        let context = Context(text: text, reference: reference, calendar: calendar)
        var results: [ParsedResult] = []
        var usedTimes = Set<Int>()

        for day in context.days {
            let adjacent = context.times.indices.first { index in
                !usedTimes.contains(index) && context.source.onlyConnectors(between: day.range, and: context.times[index].range)
            }
            if let adjacent { usedTimes.insert(adjacent) }
            if let result = context.combine(day, adjacent.map { context.times[$0] }) {
                results.append(result)
            }
        }
        for index in context.times.indices where !usedTimes.contains(index) {
            if let result = context.combine(nil, context.times[index]) {
                results.append(result)
            }
        }
        return results.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// A data para a qual o texto inteiro aponta: o primeiro dia citado, na
    /// hora colada nele ou, sem ela, na primeira hora citada no texto. Serve
    /// para anotação e lembrete: "amanhã comprar pão no almoço" é amanhã às 12h.
    ///
    /// Quando dia e hora estão separados, `range` cobre só o dia.
    public static func interpret(
        _ text: String,
        reference: Date = .now,
        calendar: Calendar = .current
    ) -> ParsedResult? {
        let context = Context(text: text, reference: reference, calendar: calendar)
        guard let day = context.days.first(where: { context.resolve($0) != nil }) else {
            return context.times.lazy.compactMap { context.combine(nil, $0) }.first
        }
        let time = context.times.first { context.source.onlyConnectors(between: day.range, and: $0.range) }
            ?? context.times.first
        return context.combine(day, time)
    }
}

/// Uma data achada no texto.
public struct ParsedResult: Sendable, Equatable {
    /// Onde a expressão está no texto recebido.
    public let range: Range<String.Index>
    /// A expressão como está no texto.
    public let text: String
    /// O começo. Sem hora no texto, é o dia ao meio-dia: longe da virada do
    /// dia no horário de verão.
    public let date: Date
    /// O fim, quando a expressão é um período ("semana que vem", "fim de
    /// semana").
    public let end: Date?
    /// `false` quando o texto deu só o dia.
    public let hasTime: Bool
}

/// O que `parse` e `interpret` compartilham: o texto lido uma vez só.
struct Context {
    let source: TextSource
    let days: [Piece<DayRules.Value>]
    let times: [TimeRules.Expression]
    let reference: Date
    let calendar: Calendar

    init(text: String, reference: Date, calendar: Calendar) {
        source = TextSource(text)
        times = TimeRules.expressions(in: source)
        days = DayRules.expressions(in: source, times: times)
        self.reference = reference
        self.calendar = calendar
    }

    func resolve(_ day: Piece<DayRules.Value>) -> (start: Date, end: Date?)? {
        DayRules.resolve(day.value, reference: reference, calendar: calendar)
    }

    /// Junta um dia e uma hora, qualquer um dos dois podendo faltar.
    func combine(_ day: Piece<DayRules.Value>?, _ time: TimeRules.Expression?) -> ParsedResult? {
        if let day {
            guard let days = resolve(day) else { return nil }
            guard let time else {
                guard let start = noon(of: days.start) else { return nil }
                return result(start, end: days.end.flatMap { noon(of: $0) }, hasTime: false, range: day.range)
            }
            let date: Date?
            let end: Date?
            switch time.value {
            case .fromNow(let minutes):
                date = reference.addingTimeInterval(Double(minutes) * 60)
                end = nil
            case .at(let clock):
                date = clock.on(days.start, calendar: calendar)
                end = days.end.flatMap { clock.on($0, calendar: calendar) }
            }
            guard let date else { return nil }
            // Dia e hora colados saem juntos do texto; separados, fica só o dia.
            let range = source.onlyConnectors(between: day.range, and: time.range)
                ? min(day.range.lowerBound, time.range.lowerBound)..<max(day.range.upperBound, time.range.upperBound)
                : day.range
            return result(date, end: end, hasTime: true, range: range)
        }

        guard let time, !time.needsDay else { return nil }
        let date: Date
        switch time.value {
        case .fromNow(let minutes):
            date = reference.addingTimeInterval(Double(minutes) * 60)
        case .at(let clock):
            // Só a hora: hoje nesse horário, ou amanhã se já passou.
            guard let today = clock.on(reference, calendar: calendar) else { return nil }
            date = today > reference ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
        }
        return result(date, end: nil, hasTime: true, range: time.range)
    }

    private func noon(of day: Date) -> Date? {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)
    }

    private func result(_ date: Date, end: Date?, hasTime: Bool, range: Range<String.Index>) -> ParsedResult {
        let original = source.originalRange(range)
        return ParsedResult(range: original, text: String(source.original[original]), date: date, end: end, hasTime: hasTime)
    }
}
