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
    "eval": .builtin(replEVAL),
    "atom": .builtin(atom),
    "atom?": .builtin(isAtom),
    "deref": .builtin(deref),
    "reset!": .builtin(reset),
    "swap!": .builtin(swap),
    "cons": .builtin(cons),
    "concat": .builtin(concat),
]

public func initializationScript() {
    [
        #"(def! load-file (fn* (f) (eval (read-string (str "(do " (slurp f) " nil)")))))"#
    ]
        .forEach(rep >>> { print($0) })
}

func checkLengthOf(_ list: [AST], is count: Int) -> Result<Void, EvalError> {
    guard list.count == count else { return .failure(.argumentMismatch("Expected \(count) parameters", list)) }
    return .success(())
}

func map2IntegersToResult(_ list: [AST], _ f: (Int, Int) -> Int) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 2).flatMap {
        guard case let .integer(e1) = list.first!, case let .integer(e2) = list.last! else { return .failure(.argumentMismatch("Expected integers", list)) }
        return .success(.integer(f(e1, e2)))
    }
}

func add(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    map2IntegersToResult(list, +)
}

func sub(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    map2IntegersToResult(list, -)
}

func mul(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    map2IntegersToResult(list, *)
}

func div(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    map2IntegersToResult(list, /)
}

func prn(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    if let p = list.first { print(p) }
    return .success(.nil)
}

func list(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    return .success(.list(list))
}

func isList(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    if case .list(_) = list.first { return .success(.bool(true)) }
    else { return .success(.bool(false)) }
}

func isEmpty(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    if case .list(let l) = list.first, l.count == 0 { return .success(.bool(true)) }
    else { return .success(.bool(false)) }}

func count(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    guard list.isEmpty == false else { return .failure(.argumentMismatch("expected a parameter", list)) }
    if case .list(let l) = list.first { return .success(.integer(l.count)) }
    else { return .success(.integer(0)) }
}

func isEqual(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 2).map { .bool(list[0] == list[1]) }
}

func map2IntegersToResult(_ list: [AST], _ f: (Int, Int) -> Bool) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 2).flatMap {
        guard case let .integer(e1) = list.first!, case let .integer(e2) = list.last! else { return .failure(.argumentMismatch("Expected integers", list)) }
        return .success(.bool(f(e1, e2)))
    }
}

func isLessThan(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    return map2IntegersToResult(list, <)
}

func isLessThanEqual(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    return map2IntegersToResult(list, <=)
}

func isGreaterThan(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    return map2IntegersToResult(list, >)
}

func isGreaterThanEqual(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    return map2IntegersToResult(list, >=)
}

func readString(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 1).flatMap {
        guard case .string(let s) = list.first! else { return .failure(.argumentMismatch("Expected string parameter", list)) }
        switch READ(s) {
        case .failure(let err): return .failure(.stringEvaluationError(err.localizedDescription, list.first!))
        case .success(let ast): return .success(ast)
        }
    }
}

func slurp(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 1).flatMap {
        guard case .string(let filename) = list.first! else { return .failure(.argumentMismatch("Expected string parameter", list)) }
        do {
            let s = try String(contentsOfFile: filename, encoding: .utf8)
            return .success(.string(s))
        } catch {
            return .failure(.fileLoadingError(description: error.localizedDescription, filename: filename))
        }
    }
}

func concatenateStrings(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    list.reduce(.success(.string(""))) { result, nextAST in
        result.flatMap { resultAST in
            guard case .string(let resultString) = resultAST else { preconditionFailure() }
            return .success(.string(resultString + nextAST.description))
        }
    }
}

var atomSpace: [UUID: AST] = [:]

func replEVAL(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 1).flatMap { EVAL(list[0], replEnv) }
}

func atom(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 1).map {
        let atomID = UUID()
        atomSpace[atomID] = list.first!
        return .atom(atomID)
    }
}

func isAtom(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 1).map {
        guard case .atom = list.first else { return .bool(false) }
        return .bool(true)
    }
}

func deref(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 1).flatMap {
        guard case .atom(let atomID) = list.first! else { return .failure(.argumentMismatch("Expected atom", list)) }
        guard let value = atomSpace[atomID] else { return .failure(.atomError("Unknown atom!?", atomID, atomSpace)) }
        return .success(value)
    }
}

func reset(_ list: [AST], _: Environment) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 2).flatMap {
        guard case .atom(let atomID) = list.first! else { return .failure(.argumentMismatch("Expected atom", list)) }
        atomSpace[atomID] = list.last!
        return .success(list.last!)
    }
}

func swap(_ list: [AST], _ environment: Environment) -> Result<AST, EvalError> {
    guard list.count >= 2 else { return .failure(.argumentMismatch("Expected 2 or more parameters", list)) }
    guard case .atom(let atomID) = list.first!, let atomValue = atomSpace[atomID] else { return .failure(.argumentMismatch("Expected atom as first parameter", list)) }
    var newValueCalculation = Array(list.suffix(from: 1))
    newValueCalculation.insert(atomValue, at: 1)
    let evaluated = EVAL(.list(newValueCalculation), environment)
    switch evaluated {
    case .success(let evaluatedValue):
        atomSpace[atomID] = evaluatedValue
        fallthrough
    case .failure: return evaluated
    }
}

func cons(_ list: [AST], _ environment: Environment) -> Result<AST, EvalError> {
    checkLengthOf(list, is: 2).flatMap {
        guard case .list(let listArg) = list.last! else { return .failure(.argumentMismatch("Expected list as parameter 2", list)) }
        return .success(.list([list.first!] + listArg))
    }
}

func concat(_ list: [AST], _ environment: Environment) -> Result<AST, EvalError> {
    list.reduce(.success(.list([]))) { accum, next -> Result<AST, EvalError> in
        guard case .list(let nextContents) = next else { return .failure(.argumentMismatch("Expected list parameters", list)) }
        return accum.map { accumAST in
            guard case .list(let accumContents) = accumAST else { preconditionFailure() }
            return .list(accumContents + nextContents)
        }
    }
}
