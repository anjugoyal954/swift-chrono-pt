import Foundation

/// Compiled regexes, kept per thread.
///
/// Building a regex costs about 25 times what matching it does, and the rules
/// use more than a dozen on every call. `Regex` is not `Sendable`, so one
/// instance is never shared between threads: each thread keeps the ones it
/// built in its own storage, and nothing crosses from one thread to another.
enum RegexCache {
    static func regex<Output>(
        file: String = #fileID,
        name: String = #function,
        _ build: () -> Regex<Output>
    ) -> Regex<Output> {
        let storage = Thread.current.threadDictionary
        let key = "ChronoPT.RegexCache \(file) \(name)"
        if let cached = storage[key] as? Regex<Output> { return cached }
        let regex = build()
        storage[key] = regex
        return regex
    }
}
