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

let anyWhitespace: Parser<Void, String> = optionalPrefix(while: { $0.isWhitespace })
    .flatMap { _ in always(()) }

let sign: Parser<Substring, String> = optionalPrefix(while: { $0 == "-" })
let numbers: Parser<Substring, String> = optionalPrefix(while: { $0.isNumber })
let numberParser = zip(
    anyWhitespace,
    sign,
    numbers)
    .flatMap { _, sgn, n in Parser<Int, String> { _ in Int(String(sgn + n)) } }
    .map { Token.number($0) }

let symbolInitial: Parser<Substring, String> = hasPrefix(while: { $0.isLetter || "+-/*".contains($0) })
let symbolTrailing: Parser<Substring, String> = optionalPrefix(while: { !($0.isWhitespace || "[]{}('\"`,;)".contains($0)) })

let symbolParser = zip(
    anyWhitespace,
    symbolInitial,
    symbolTrailing
).map { Token.symbol(String($0.1 + $0.2)) }

let stringContents = Parser<Substring, String> { input in
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
    return prefix
}

let doubleQuote = "\""
let stringParser = zip(
    anyWhitespace,
    literal(doubleQuote),
    stringContents,
    literal(doubleQuote)
).map { _, _, s, _ in Token.string(String(s)) }

let commentContents: Parser<Substring, String> = optionalPrefix(while: { $0.isNewline == false })
let commentParser: Parser<Token, String> = zip(
    anyWhitespace,
    literal(";"),
    commentContents
).flatMap { _ in always(.none) }

func trimmedLiteral(_ prefix: String, _ token: Token) -> Parser<Token, String> {
    return zip(anyWhitespace, literal(prefix)).flatMap { _ in always(token) }
}

func tokenize(_ input: String) -> Result<[Token], ASTError> {
    var parsedInput = input[...]
    let anyToken = oneOf([
        trimmedLiteral("(", .lparen),
        trimmedLiteral(")", .rparen),
        trimmedLiteral("[", .lsquare),
        trimmedLiteral("]", .rsquare),
        trimmedLiteral("'", .tick),
        trimmedLiteral("`", .backtick),
        trimmedLiteral("~@", .twiddleAt),
        trimmedLiteral("~", .twiddle),
        numberParser,
        symbolParser,
        stringParser,
        commentParser,
    ])
    let tokenizer = zeroOrMore(anyToken, separatedBy: anyWhitespace)
    guard let matches = tokenizer.run(&parsedInput) else { return .failure(.tokenizerError("Could not parse, stopped at \(parsedInput.prefix(20))")) }
    guard parsedInput.count == 0 else { return .failure(.tokenizerError("Unparsed text remained after tokenizing: \"\(parsedInput)\"")) }
    return .success(matches.filter { $0 != .none })
}
