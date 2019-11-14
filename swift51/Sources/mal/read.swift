import Foundation
import FunctionalUtilities

var parsers: [Parser<AST, [Token]>] = []
let anyAST = Parser<AST, [Token]> { input -> AST? in
    for p in parsers {
        if let match = p.run(&input) {
            return match
        }
    }
    return nil
}

func READ(_ input: String) -> Result<AST, ASTError> {
    if parsers.count == 0 { constructParsers() }
    switch tokenize(input) {
    case .failure(let err): return .failure(err)
    case .success(let tokens):
        var tokens = tokens[...]
        if let match = anyAST.run(&tokens) { return .success(match) }
        else { return .failure(.tokenizerError("Didn't match at \(tokens)")) }
    }
}

func wrapInListWithCall(_ calling: AST) -> (Void, AST) -> AST {
    return { _, ast in
        AST.list([calling, ast])
    }
}

let symbol = Parser<AST, [Token]> { input in
    guard case .symbol = input.first, case .symbol(let s) = input.removeFirst() else { return nil }
    switch s {
    case "nil": return .nil
    case "true": return .bool(true)
    case "false": return .bool(false)
    case "def!": return .def
    case "let*": return .let
    case "do": return .do
    case "if": return .if
    case "fn*": return .fn
    case "quote": return .quote
    case "quasiquote": return .quasiquote
    case "unquote": return .unquote
    case "splice-unquote": return .spliceunquote
    case "defmacro!": return .defmacro
    case "macroexpand": return .macroexpand
    default: return .symbol(s)
    }
}
    
let number = Parser<AST, [Token]> { input in
    guard case .number = input.first, case .number(let i) = input.removeFirst() else { return nil }
    return .integer(i)
}

let string = Parser<AST, [Token]> { input in
    guard case .string = input.first, case .string(let s) = input.removeFirst() else { return nil }
    return .string(s)
}

func constructParsers() {
    parsers.append(contentsOf: [
        zip(
            literal(.lparen),
            zeroOrMore(anyAST),
            literal(.rparen))
            .map { _, asts, _ in
                AST.list(asts)
            },
        zip(
            literal(.tick),
            anyAST)
            .map(wrapInListWithCall(.quote)),
        zip(
            literal(.backtick),
            anyAST)
            .map(wrapInListWithCall(.quasiquote)),
        zip(
            literal(.twiddle),
            anyAST)
            .map(wrapInListWithCall(.unquote)),
        zip(
            literal(.twiddleAt),
            anyAST)
            .map(wrapInListWithCall(.spliceunquote)),
        number,
        string,
        symbol
    ])
}
