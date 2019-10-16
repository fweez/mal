import Foundation

enum Token {
    case lparen
    case rparen
    case number(Int)
    case symbol(String)
    
    init(from input: String) {
        switch input {
        case "(", "[": self = .lparen
        case ")", "]": self = .rparen
        default:
            if let v = Int(input) { self = .number(v) }
            else { self = .symbol(input) }
        }
    }
}

extension Token: CustomStringConvertible {
    var description: String {
        switch self {
        case .lparen: return "("
        case .rparen: return ")"
        case .number(let n): return "NUMBER(\(n))"
        case .symbol(let s): return "SYMBOL(\(s))"
        }
    }
}

func tokenize(_ input: String) -> Result<[Token], ASTError> {
    let pattern = #"[\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`\,;)]*)"#
    do {
        return .success(try NSRegularExpression(pattern: pattern, options: [] as NSRegularExpression.Options)
            .matches(in: input,
                     options: [] as NSRegularExpression.MatchingOptions,
                     range: NSRange(location: 0, length: input.count))
            .compactMap {
                Range($0.range, in: input)
            }
            .map {
                input[$0.lowerBound..<$0.upperBound]
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
            .filter { $0.count > 0 }
            .map { Token(from: $0) })
    } catch {
        return .failure(.tokenizerError(error.localizedDescription))
    }
}
