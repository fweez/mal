import Foundation
import FunctionalUtilities

typealias ASTStack = [MalType]
func readString(_ input: String) -> MalType {
    let initialStack: ASTStack = []
    let output = (input |> tokenize)
        .reduce(initialStack, readForm)
    guard output.count == 1 else { fatalError() }
    return output.first!
}

// Suppress substring(with:) deprecation warning
// The s[range] form does not work in the calls in tokenize(:)!
private protocol Substringable {
    func substring(with: Range<String.Index>) -> String
}
extension String: Substringable { }

func tokenize(_ input: String) -> [Token] {
    let pattern = #"[\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]*)"#
    return try! NSRegularExpression(pattern: pattern, options: [] as NSRegularExpression.Options)
        .matches(in: input,
                 options: [] as NSRegularExpression.MatchingOptions,
                 range: NSRange(location: 0, length: input.count))
        .compactMap { Range($0.range, in: input) }
        .map {
            (input as Substringable)
                .substring(with: $0)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        .filter { $0.count > 0 }
        .map { Token(from: $0) }
}

func readForm(_ stack: ASTStack, _ next: Token) -> ASTStack {
    switch next {
    /// Read List
    case .lparen:
        return stack + [.unclosedList([])]
    case .rparen: // end the last list on the ast and merge it with its parent
        var stack = stack
        let this = stack.popLast()!
        let prev = stack.popLast()
        switch (prev, this) {
        case (.some(.unclosedList(let v)), .unclosedList(let w)):
            return stack + [.unclosedList(v + [.list(w)])]
        case (.none, .unclosedList(let v)): return [.list(v)]
        default: fatalError()
        }
        
    /// Read Atom
    default:
        let nextMalType = MalType(from: next)
        var stack = stack
        guard let last = stack.popLast() else { return [nextMalType] }
        switch last {
        case .unclosedList(let v): return stack + [.unclosedList(v + [nextMalType])]
        default: fatalError()
        }
    }
}
