import Foundation

enum ASTError: Error {
    case tokenizerError(String)
    case unexpectedParen
    case unexpectedEOL([AST])

    var localizedDescription: String {
        switch self {
        case .unexpectedParen: return "Unexpected paren"
        case .unexpectedEOL(let list): return "Unexpected end-of-line, list was (\(list))"
        case .tokenizerError(let desc): return "Tokenizer error: \(desc)"
        }
    }
}

extension ASTError: Equatable { }

typealias ASTFunction = ([AST], Environment) -> Result<AST, EvalError>

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
    case string(String)
    case atom(UUID)
    indirect case list([AST])
    indirect case vector([AST])
    indirect case function(ast: AST, params: [AST], environment: Environment, fn: ASTFunction?)
    indirect case builtin(ASTFunction)
    
    init(_ token: Token) throws {
        switch token {
        case .lparen, .rparen, .lsquare, .rsquare: throw ASTError.unexpectedParen
        case .none: throw ASTError.tokenizerError("Attempted to build AST with none")
        case let .number(s): self = .integer(Int(s))
        case .string(let s): self = .string(s)
        case let .symbol(s):
            switch s {
            case "nil": self = .nil
            case "true": self = .bool(true)
            case "false": self = .bool(false)
            case "def!": self = .def
            case "let*": self = .let
            case "do": self = .do
            case "if": self = .if
            case "fn*": self = .fn
            default: self = .symbol(s)
            }
        }
    }
}

extension AST: Equatable {
    static func == (lhs: AST, rhs: AST) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty), (.nil, .nil), (.def, .def), (.let, .let), (.do, .do), (.if, .if), (.fn, .fn), (.builtin, .builtin): return true
        case (.integer(let l), .integer(let r)): return l == r
        case (.symbol(let l), .symbol(let r)): return l == r
        case (.bool(let l), .bool(let r)): return l == r
        case (.list(let l), .list(let r)), (.vector(let l), .vector(let r)):
            if l.count != r.count { return false }
            return zip(l, r).reduce(true) { (equal: Bool, t: (l: AST, r: AST)) in
                if !equal { return equal }
                return l == r
            }
        
        case (.function, .function): return true
        case (.string(let l), .string(let r)): return l == r
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
        case .vector(let l): return "[" + l.map { $0.description }.joined(separator: " ") + "]"
        case let .function(ast: body, params: params, environment: _, fn: _): return "f(\(params)) (\(body))"
        case .builtin: return "#<builtin>"
        case .bool(let b): return "\(b)"
        case .nil: return "nil"
        case .def: return "def!"
        case .let: return "let*"
        case .do: return "do"
        case .if: return "if"
        case .fn: return "fn*"
        case .string(let s): return "\"\(s)\""
        case .atom(let uuid): return "(atom \(atomSpace[uuid] ?? .nil))"
        }
    }
}
