import Foundation

enum ASTError: Error {
    case tokenizerError(String)
    case unexpectedParen
    case unexpectedEOL

    var localizedDescription: String {
        switch self {
        case .unexpectedParen: return "Unexpected paren"
        case .unexpectedEOL: return "Unexpected end-of-line"
        case .tokenizerError(let desc): return "Tokenizer error: \(desc)"
        }
    }
}

enum AST {
    case empty
    case `nil`
    case def
    case `let`
    case `do`
    case `if`
    case fn
    case integer(Int)
    case symbol(String)
    case bool(Bool)
    indirect case list([AST])
    indirect case function(ast: AST, params: [AST], environment: Environment, fn: (([AST]) -> Result<AST, EvalError>)?)
    
    init(_ token: Token) throws {
        switch token {
        case .lparen, .rparen: throw ASTError.unexpectedParen
        case let .number(s): self = .integer(Int(s))
        case let .symbol(s) where s == "nil": self = .nil
        case let .symbol(s) where s == "true": self = .bool(true)
        case let .symbol(s) where s == "false": self = .bool(false)
        case let .symbol(s) where s == "def!": self = .def
        case let .symbol(s) where s == "let*": self = .let
        case let .symbol(s) where s == "do": self = .do
        case let .symbol(s) where s == "if": self = .if
        case let .symbol(s) where s == "fn*": self = .fn
        case let .symbol(s): self = .symbol(s)
        }
    }
}

extension AST: Equatable {
    static func == (lhs: AST, rhs: AST) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty), (.nil, .nil), (.def, .def), (.let, .let), (.do, .do), (.if, .if), (.fn, .fn): return true
        case (.integer(let l), .integer(let r)): return l == r
        case (.symbol(let l), .symbol(let r)): return l == r
        case (.bool(let l), .bool(let r)): return l == r
        case (.list(let l), .list(let r)):
            if l.count != r.count { return false }
            return zip(l, r).reduce(true) { (equal: Bool, t: (l: AST, r: AST)) in
                if !equal { return equal }
                return l == r
            }
        case (.function, .function): return true
        default: return false
        }
    }
}

extension AST: CustomStringConvertible {
    var description: String {
        switch self {
        case .empty: return ""
        case .integer(let i): return "\(i)"
        case .symbol(let s): return s
        case .list(let l): return "(" + l.map { $0.description }.joined(separator: " ") + ")"
        case .function: return "#<func>"
        case .bool(let b): return "\(b)"
        case .nil: return "nil"
        case .def: return "def!"
        case .let: return "let*"
        case .do: return "do"
        case .if: return "if"
        case .fn: return "fn*"
        }
    }
}
