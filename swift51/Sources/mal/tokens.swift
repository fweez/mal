import Foundation

enum Token {
    case lparen
    case rparen
    case lsquare
    case rsquare
    case tick
    case backtick
    case twiddle
    case twiddleAt
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
        case .tick: return "'"
        case .backtick: return "`"
        case .twiddle: return "~"
        case .twiddleAt: return "~@"
        case .number(let n): return "NUMBER(\(n))"
        case .symbol(let s): return "SYMBOL(\(s))"
        case .string(let s): return "STRING(\(s))"
        case .none: return "NONE"
        }
    }
}

extension Token: Equatable { }

func optionalPrefix(while p: @escaping (Character) -> Bool) -> Parser<Substring, Substring> {
    Parser<Substring, Substring> { str in
        let prefix = str.prefix(while: p)
        str.removeFirst(prefix.count)
        return prefix
    }
}

func hasPrefix(while p: @escaping (Character) -> Bool) -> Parser<Substring, Substring> {
    optionalPrefix(while: p)
        .flatMap { str in
            guard str.count > 0 else { return .never }
            return always(str)
        }
}

let anyWhitespace: Parser<Void, Substring> = optionalPrefix(while: { $0.isWhitespace })
    .flatMap { _ in always(()) }

func literal(_ literalString: String) -> Parser<Void, Substring> {
    let actualLiteral = Parser<Void, Substring> { input in
        guard input.hasPrefix(literalString) else { return nil }
        input.removeFirst(literalString.count)
        return ()
    }
    return zip(anyWhitespace, actualLiteral)
        .flatMap { _ in always(()) }
}

func literal(_ literalString: String, _ token: Token) -> Parser<Token, Substring> {
    literal(literalString).flatMap { _ in always(token) }
}

let sign = optionalPrefix(while: { $0 == "-" })
let numbers = optionalPrefix(while: { $0.isNumber })
let numberParser = zip(
    anyWhitespace,
    sign,
    numbers)
    .flatMap { _, sgn, n in Parser<Int, Substring> { _ in Int(String(sgn + n)) } }
    .map { Token.number($0) }

let symbolInitial = hasPrefix(while: { $0.isLetter || "+-/*".contains($0) })
let symbolTrailing = optionalPrefix(while: { !($0.isWhitespace || "[]{}('\"`,;)".contains($0)) })

let symbolParser = zip(
    anyWhitespace,
    symbolInitial,
    symbolTrailing
).map { Token.symbol(String($0.1 + $0.2)) }

let stringContents = Parser<String, Substring> { input in
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
}

let doubleQuote = "\""
let stringParser = zip(
    anyWhitespace,
    literal(doubleQuote),
    stringContents,
    literal(doubleQuote)
).map { _, _, s, _ in Token.string(s) }

let commentContents = optionalPrefix(while: { $0.isNewline == false })
let commentParser: Parser<Token, Substring> = zip(
    anyWhitespace,
    literal(";"),
    commentContents
).flatMap { _ in always(.none) }

func tokenize(_ input: String) -> Result<[Token], ASTError> {
    var parsedInput = input[...]
    let anyToken = oneOf([
        literal("(", .lparen),
        literal(")", .rparen),
        literal("[", .lsquare),
        literal("]", .rsquare),
        literal("'", .tick),
        literal("`", .backtick),
        literal("~@", .twiddleAt),
        literal("~", .twiddle),
        numberParser,
        symbolParser,
        stringParser,
        commentParser,
    ])
    let tokenizer = zeroOrMore(anyToken, separatedBy: anyWhitespace)
    guard let matches = tokenizer.run(&parsedInput) else { return .failure(.tokenizerError("Could not parse, stopped at \(parsedInput.prefix(20))")) }
    return .success(matches.filter { $0 != .none })
}
