import Foundation

class Environment: ExpressibleByDictionaryLiteral {
    var outer: Environment?
    var data: [String: AST] = [:]
    
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
var replEnv: Environment = [
    "+": .function(ast: .nil, params: [], environment: [:], fn: add),
    "-": .function(ast: .nil, params: [], environment: [:], fn: sub),
    "*": .function(ast: .nil, params: [], environment: [:], fn: mul),
    "/": .function(ast: .nil, params: [], environment: [:], fn: div),
    "prn": .function(ast: .nil, params: [], environment: [:], fn: prn),
    "list": .function(ast: .nil, params: [], environment: [:], fn: list),
    "list?": .function(ast: .nil, params: [], environment: [:], fn: isList),
    "empty?": .function(ast: .nil, params: [], environment: [:], fn: isEmpty),
    "count": .function(ast: .nil, params: [], environment: [:], fn: count),
    "=": .function(ast: .nil, params: [], environment: [:], fn: isEqual),
    "<": .function(ast: .nil, params: [], environment: [:], fn: isLessThan),
    "<=": .function(ast: .nil, params: [], environment: [:], fn: isLessThanEqual),
    ">": .function(ast: .nil, params: [], environment: [:], fn: isGreaterThan),
    ">=": .function(ast: .nil, params: [], environment: [:], fn: isGreaterThanEqual),
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

