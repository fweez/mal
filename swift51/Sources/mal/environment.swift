import Foundation
import FunctionalUtilities

class Environment: ExpressibleByDictionaryLiteral {
    var outer: Environment?
    var data: [String: AST] = [:]
    var id = UUID()
    
    typealias Key = String
    typealias Value = AST
    
    required init(dictionaryLiteral elements: (String, AST)...) {
        elements
            .forEach { self[$0] = $1 }
    }
    
    subscript(key: String) -> AST? {
        get { data[key] ?? outer?[key] }
        set { data[key] = newValue }
    }
}

extension Environment: Identifiable { }

extension Environment: CustomStringConvertible {
    var description: String {
        [
            id.uuidString,
            data
                .map({ "\($0): \($1)" })
                .joined(separator: "\n"),
            """
            
            outer:
            ======
            \(outer?.description ?? "nil")
            """
            ].joined(separator: "\n")
    }
}

var replEnv: Environment = [
    "+": .builtin(add),
    "-": .builtin(sub),
    "*": .builtin(mul),
    "/": .builtin(div),
    "prn": .builtin(prn),
    "list": .builtin(list),
    "list?": .builtin(isList),
    "empty?": .builtin(isEmpty),
    "count": .builtin(count),
    "=": .builtin(isEqual),
    "<": .builtin(isLessThan),
    "<=": .builtin(isLessThanEqual),
    ">": .builtin(isGreaterThan),
    ">=": .builtin(isGreaterThanEqual),
    "read-string": .builtin(readString),
    "slurp": .builtin(slurp),
    "str": .builtin(concatenateStrings),
    "eval": .builtin(replEVAL)
]

func map2IntegersToResult(_ list: [AST], _ f: (Int, Int) -> Int) -> Result<AST, EvalError> {
    guard list.count == 2 else {
        return .failure(.argumentMismatch("Expected 2 parameters", list)) }
    guard case let .integer(e1) = list.first!, case let .integer(e2) = list.last! else { return .failure(.argumentMismatch("Expected integers", list)) }
    return .success(.integer(f(e1, e2)))
}

func add(_ list: [AST]) -> Result<AST, EvalError> {
    map2IntegersToResult(list, +)
}

func sub(_ list: [AST]) -> Result<AST, EvalError> {
    map2IntegersToResult(list, -)
}

func mul(_ list: [AST]) -> Result<AST, EvalError> {
    map2IntegersToResult(list, *)
}

func div(_ list: [AST]) -> Result<AST, EvalError> {
    map2IntegersToResult(list, /)
}

func prn(_ list: [AST]) -> Result<AST, EvalError> {
    if let p = list.first { print(p) }
    return .success(.nil)
}

func list(_ list: [AST]) -> Result<AST, EvalError> {
    return .success(.list(list))
}

func isList(_ list: [AST]) -> Result<AST, EvalError> {
    if case .list(_) = list.first { return .success(.bool(true)) }
    else { return .success(.bool(false)) }
}

func isEmpty(_ list: [AST]) -> Result<AST, EvalError> {
    if case .list(let l) = list.first, l.count == 0 { return .success(.bool(true)) }
    else { return .success(.bool(false)) }}

func count(_ list: [AST]) -> Result<AST, EvalError> {
    guard list.isEmpty == false else { return .failure(.argumentMismatch("expected a parameter", list)) }
    if case .list(let l) = list.first { return .success(.integer(l.count)) }
    else { return .success(.integer(0)) }
}

func isEqual(_ list: [AST]) -> Result<AST, EvalError> {
    if list.count != 2 { return .failure(.argumentMismatch("expected 2 arguments", list)) }
    return .success(.bool(list[0] == list[1]))
}

func map2IntegersToResult(_ list: [AST], _ f: (Int, Int) -> Bool) -> Result<AST, EvalError> {
    guard list.count == 2 else {
        return .failure(.argumentMismatch("Expected 2 parameters", list)) }
    guard case let .integer(e1) = list.first!, case let .integer(e2) = list.last! else { return .failure(.argumentMismatch("Expected integers", list)) }
    return .success(.bool(f(e1, e2)))
}

func isLessThan(_ list: [AST]) -> Result<AST, EvalError> {
    return map2IntegersToResult(list, <)
}

func isLessThanEqual(_ list: [AST]) -> Result<AST, EvalError> {
    return map2IntegersToResult(list, <=)
}

func isGreaterThan(_ list: [AST]) -> Result<AST, EvalError> {
    return map2IntegersToResult(list, >)
}

func isGreaterThanEqual(_ list: [AST]) -> Result<AST, EvalError> {
    return map2IntegersToResult(list, >=)
}

func readString(_ list: [AST]) -> Result<AST, EvalError> {
    guard list.count == 1 else { return .failure(.argumentMismatch("Expected 1 parameter", list)) }
    guard case .string(let s) = list.first! else { return .failure(.argumentMismatch("Expected string parameter", list)) }
    switch READ(s) {
    case .failure(let err): return .failure(.stringEvaluationError(err.localizedDescription, list.first!))
    case .success(let ast): return .success(ast)
    }
}

func slurp(_ list: [AST]) -> Result<AST, EvalError> {
    guard list.count == 1 else { return .failure(.argumentMismatch("Expected 1 parameter", list)) }
    guard case .string(let filename) = list.first! else { return .failure(.argumentMismatch("Expected string parameter", list)) }
    do {
        return .success(.string(try String(contentsOfFile: filename, encoding: .utf8)))
    } catch {
        return .failure(.fileLoadingError(description: error.localizedDescription, filename: filename))
    }
}

func concatenateStrings(_ list: [AST]) -> Result<AST, EvalError> {
    return list.reduce(.success(.string(""))) { result, nextAST in
        result.flatMap { resultAST in
            guard case .string(let resultString) = resultAST, case .string(let nextString) = nextAST else { return .failure(.argumentMismatch("Expected string parameters", list)) }
            return .success(.string(resultString + nextString))
        }
    }
}

func replEVAL(_ list: [AST]) -> Result<AST, EvalError> {
    guard list.count == 1 else { return .failure(.argumentMismatch("Expected 1 parameter", list)) }
    print("FIRING REPL'S EVAL")
    return EVAL(list[0], replEnv)
}
