import Foundation
import FunctionalUtilities

func readString(_ input: String) -> MalType {
    let initialAST: [MalType] = []
    let output = (input |> tokenize)
        .reduce(initialAST, readForm)
    guard output.count == 1 else { fatalError() }
    return output.first!
}

func tokenize(_ input: String) -> [Token] {
    let pattern = #"[\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]*)"#
    return try! NSRegularExpression(pattern: pattern, options: [] as NSRegularExpression.Options)
        .matches(in: input,
                 options: [] as NSRegularExpression.MatchingOptions,
                 range: NSRange(location: 0, length: input.count))
        .compactMap { Range($0.range, in: input) }
        .map { input
            .substring(with: $0)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        .filter { $0.count > 0 }
        .map { Token(from: $0) }
}

func readForm(_ ast: [MalType], _ next: Token) -> [MalType] {
    switch next {
    case .lparen, .rparen: return readList(ast, next)
    default: return readAtom(ast, next)
    }
}

func readList(_ ast: [MalType], _ next: Token) -> [MalType] {
    switch next {
    case .lparen:
        return ast + [.unclosedList([])]
    case .rparen: // end the last list on the ast and merge it with its parent
        var ast = ast
        let this = ast.popLast()!
        let prev = ast.popLast()
        switch (prev, this) {
        case (.some(.unclosedList(let v)), .unclosedList(let w)): return ast + [.unclosedList(v + [.list(w)])]
        case (.none, .unclosedList(let v)): return [.list(v)]
        default: fatalError()
        }
    default: fatalError()
    }
}

func readAtom(_ ast: [MalType], _ next: Token) -> [MalType] {
    let nextMalType = MalType(from: next)
    var ast = ast
    guard let last = ast.popLast() else {  return [nextMalType] }
    switch last {
    case .unclosedList(let v): return ast + [.unclosedList(v + [nextMalType])]
    default: fatalError()
    }
}
