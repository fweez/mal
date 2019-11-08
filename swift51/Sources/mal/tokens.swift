import Foundation

enum Token {
    case lparen
    case rparen
    case lsquare
    case rsquare
    case number(Int)
    case symbol(String)
    case string(String)
    case none
}

extension Token: CustomStringConvertible {
    var description: String {
        switch self {
        case .lparen: return "("
        case .rparen: return ")"
        case .lsquare: return "["
        case .rsquare: return "]"
        case .number(let n): return "NUMBER(\(n))"
        case .symbol(let s): return "SYMBOL(\(s))"
        case .string(let s): return "STRING(\(s))"
        case .none: return "NONE"
        }
    }
}

extension Token: Equatable { }

struct Parser<A> {
    let run: (inout Substring) -> A?
}

extension Parser {
    func map<B>(_ f: @escaping (A) -> B) -> Parser<B> {
        Parser<B> { str -> B? in
            self.run(&str).map(f)
        }
    }
    
    func flatMap<B>(_ f: @escaping (A) -> Parser<B>) -> Parser<B> {
        Parser<B> { input -> B? in
            let original = input
            let matchA = self.run(&input)
            guard let matchB = matchA.map(f)?.run(&input) else {
                input = original
                return nil
            }
            return matchB
        }
    }
}

func zip<A, B>(_ a: Parser<A>, _ b: Parser<B>) -> Parser<(A, B)> {
    Parser<(A, B)> { str -> (A, B)? in
        let orig = str
        guard let matchA = a.run(&str) else { return nil }
        guard let matchB = b.run(&str) else {
            str = orig
            return nil
        }
        return (matchA, matchB)
    }
}

func zip<A, B, C>(_ a: Parser<A>, _ b: Parser<B>, _ c: Parser<C>) -> Parser<(A, B, C)> {
    zip(a, zip(b, c)).map { a, bc in (a, bc.0, bc.1) }
}


let whitespace = Parser<Void> { input in
    let wsPrefix = input.prefix(while: { $0.isWhitespace })
    input.removeFirst(wsPrefix.count)
    return ()
}

func literal(_ literalString: String) -> Parser<Void> {
    let actualLiteral = Parser<Void> { input in
        guard input.hasPrefix(literalString) else { return nil }
        input.removeFirst(literalString.count)
        return ()
    }
    return zip(whitespace, actualLiteral).map { _, _ in () }
}

func literal(_ literalString: String, _ token: Token) -> Parser<Token> {
    literal(literalString).map { _ in token }
}

let numberParser = zip(
    whitespace,
    Parser<Int> { input in
        let orig = input
        let sgn = literal("-").run(&input).map { _ in -1 } ?? 1
        let prefix = input.prefix(while: { $0.isNumber })
        guard let match = Int(prefix) else {
            input = orig
            return nil
        }
        input.removeFirst(prefix.count)
        return sgn * match
    }
).map { Token.number($0.1) }

let symbolParser = zip(
    whitespace,
    Parser<String> { input in
        let orig = input
        let p1 = input.prefix(while: { $0.isLetter || "+-/*".contains($0) })
        input.removeFirst(p1.count)
        let p2 = input.prefix(while: { !($0.isWhitespace || "[]{}('\"`,;)".contains($0)) })
        input.removeFirst(p2.count)
        let s = String(p1 + p2)
        guard s.count > 0 else { return nil }
        return s
    }
).map { Token.symbol($0.1) }

let doubleQuote = "\""
let stringParser = zip(
    literal(doubleQuote),
    Parser<String> { input in
        var escaped = false
        let prefix = input.prefix(while: { c in
            if escaped {
                escaped = false
                return true
            }
            if c == "\\" {
                escaped = true
                return true
            }
            return c != doubleQuote.first!
        })
        input.removeFirst(prefix.count)
        return String(prefix)
    },
    literal(doubleQuote)
).map { Token.string($0.1) }

let commentParser: Parser<Token> = zip(
    literal(";"),
    Parser<Void> { input in
        input.removeFirst(input.prefix(while: { $0.isNewline == false }).count)
    }
).flatMap { _ in
    Parser<Token> { _ in return Token.none }
}

func tokenize(_ input: String) -> Result<[Token], ASTError> {
    var parsedInput = input[...]
    let parsers = [
        literal("(", .lparen),
        literal(")", .rparen),
        literal("[", .lsquare),
        literal("]", .rsquare),
        numberParser,
        symbolParser,
        stringParser,
        commentParser,
    ]
    var output: [Token] = []
    while parsedInput.count > 0 {
        var match: Token? = nil
        for parser in parsers {
            if let m = parser.run(&parsedInput) {
                match = m
                break
            }
        }
        guard let m = match else {
            break
        }
        switch m {
        case .none: break
        default: output.append(m)
        }
    }
    if parsedInput.count > 0 {
        return .failure(ASTError.tokenizerError("Could not parse, stopped at character \(input.count - parsedInput.count), near \(parsedInput.prefix(20))"))
    }
    return .success(output)
}
