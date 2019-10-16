import Foundation
import FunctionalUtilities

enum EvalError: Error {
    case argumentMismatch(String, [AST])
    case unknownSymbol(String, Environment)
    case listEvaluationError(String, AST, Environment)
    case defError(String, AST, Environment)
    case letError(String, AST, Environment)
    case fnError(String, AST, Environment)
    case bindingError(String, Environment)

    var localizedDescription: String {
        switch self {
        case let .argumentMismatch(description, ast):
            return "\(description) (AST: \(ast))"
        case let .unknownSymbol(symbol, environment):
            return "'\(symbol)' not found (Environment: \(environment))"
        case let .listEvaluationError(description, ast, environment):
            return "\(description) (AST: \(ast)) (Environment: \(environment))"
        case let .defError(description, ast, environment):
            return "Error processing def!: \(description) (AST: \(ast)) (Environment: \(environment))"
        case let .bindingError(description, environment):
            return "Error binding to environment: \(description) (Environment: \(environment))"
        case let .letError(description, ast, environment):
            return "Error processing let*: \(description) (AST: \(ast)) (Environment: \(environment))"
        case let .fnError(description, ast, environment):
            return "Error processing fn*: \(description) (AST: \(ast)) (Environment: \(environment))"
        }
    }
}

func EVAL(_ ast: AST, _ environment: Environment) -> Result<AST, EvalError> {
    var ast = ast
    var environment = environment
    while true {
        switch ast {
        case .list(let list):
            guard list.isEmpty == false else { return .success(ast) }
            switch list.first! {
            case .def: return setInEnvironment(ast, environment)
            case .let:
                let result = createEnvironment(ast, environment)
                switch result {
                case .failure(let err): return .failure(err)
                case .success(let (newAST, newEnvironment)):
                    ast = newAST
                    environment = newEnvironment
                }
            case .do:
                let result = runDo(ast, environment)
                switch result {
                case .failure: return result
                case .success(let newAST):
                    ast = newAST
                }
            case .if:
                let result = runIf(ast, environment)
                switch result {
                case .failure: return result
                case .success(let newAST):
                    ast = newAST
                }
            case .fn: return runFn(ast, environment)
            default:
                switch evalAST(ast, environment).flatMap({ apply($0, environment) }) {
                case .failure(let err): return .failure(err)
                case .success(let (newAST, newEnvironment)):
                    ast = newAST
                    environment = newEnvironment
                }
            }
            
        default: return evalAST(ast, environment)
        }
    }
}

func evalAST(_ ast: AST, _ environment: Environment) -> Result<AST, EvalError> {
    switch ast {
    case .symbol(let symbol):
        guard let lookup = environment[symbol] else { return .failure(.unknownSymbol(symbol, environment)) }
        return .success(lookup)
    case .list(let list):
        return list
            .reduce(.success(.list([]))) { result, elementAST -> Result<AST, EvalError> in
                result.flatMap { resultAST in
                    guard case .list(let resultList) = resultAST else { preconditionFailure("Accumulator should have had a list AST in it!") }
                    return EVAL(elementAST, environment)
                        .map { .list(resultList + [$0]) }
                }
            }
    default: return .success(ast)
    }
}

func extractListContents(_ ast: AST, _ environment: Environment, checkedBy predicate: ([AST]) -> EvalError?) -> Result<[AST], EvalError> {
    guard case let .list(list) = ast else { return .failure(.listEvaluationError("Expected list", ast, environment)) }
    if let error = predicate(list) { return .failure(error) }
    return .success(list)
}

func apply(_ ast: AST, _ environment: Environment) -> Result<(AST, Environment), EvalError> {
    return extractListContents(ast, environment) { list in
        guard list.isEmpty == false else { return .listEvaluationError("Expected list to have values in apply", ast, environment) }
        guard case .function = list.first  else { return .listEvaluationError("First value in list was not a function", ast, environment) }
        return nil
    }
    .flatMap { list in
        let args = Array(list.suffix(from: 1))
        guard case let .function(ast: body, params: parameters, environment: environment, fn: applyFn) = list.first! else { preconditionFailure() }
        if let applyFn = applyFn {
            return applyFn(args)
                .map { ($0, environment) }
        } else {
            let bindings = zip(parameters, args)
                .reduce([]) { return $0 + [$1.0, $1.1] }
            return Environment.from(outer: environment, bindings: bindings)
                .map { (body, $0) }
        }
        
    }
}

func setInEnvironment(_ ast: AST, _ environment: Environment) -> Result<AST, EvalError> {
    extractListContents(ast, environment) { list in
        guard list.count == 3 else { return .listEvaluationError("Expected list to have 3 values in def!", ast, environment) }
        guard case .def = list.first else { return .defError("def! not first symbol?!", ast, environment) }
        guard case .symbol(_) = list[1] else { return .defError("expected symbol as first parameter", ast, environment) }
        return nil
    }
    .flatMap { list in
        guard case .symbol(let k) = list[1] else { preconditionFailure() }
        return EVAL(list[2], environment)
            .map { value in
                environment[k] = value
                return value
        }
    }
}

extension Environment {
    static func from(outer: Environment, bindings: [AST]) -> Result<Environment, EvalError> {
        let newEnv: Environment = [:]
        newEnv.outer = outer
        for idx in stride(from: 0, to: bindings.count, by: 2) {
            guard case .symbol(let key) = bindings[idx] else { return .failure(.bindingError("expected symbol, got \(bindings[idx])", newEnv)) }
            let result = EVAL(bindings[idx + 1], newEnv)
            switch result {
            case .success(let value):
                newEnv[key] = value
            case .failure(let err): return .failure(err)
            }
        }
        return .success(newEnv)
    }
}

func createEnvironment(_ ast: AST, _ environment: Environment) -> Result<(AST, Environment), EvalError> {
    extractListContents(ast, environment) { list in
        guard list.count == 3 else { return .listEvaluationError("Expected list to have 3 values in let*", ast, environment) }
        guard case .let = list.first else { return .defError("let* not first symbol?!", ast, environment) }
        guard case .list(let bindings) = list[1] else { return .defError("expected binding list as first parameter", ast, environment) }
        guard bindings.count.isMultiple(of: 2) else { return .defError("expected binding list to have an even number of elements", ast, environment) }
        return nil
    }
    .flatMap { list in
        guard case .list(let bindings) = list[1] else { preconditionFailure() }
        return Environment.from(outer: environment, bindings: bindings)
            .map { (list[2], $0) }
    }
}

func runDo(_ ast: AST, _ environment: Environment) -> Result<AST, EvalError> {
    extractListContents(ast, environment) { list in
        guard list.isEmpty == false else { return .listEvaluationError("Expected list to have values", ast, environment) }
        guard case .do = list.first! else { return .defError("do not first symbol?!", ast, environment) }
        return nil
    }
    .map { list in
        guard list.count > 1 else { return list.first! }
        let toEval = Array(list.prefix(upTo: list.count - 1))
        _ = evalAST(.list(toEval), environment)
            .map { evaluatedList -> AST in
                switch evaluatedList {
                case .list(let l): return l.last ?? .nil
                default: return evaluatedList // FIXME: I have no idea if this is possible, it seems like it's not.
            }
        }
        return list.last!
    }
}

func runIf(_ ast: AST, _ environment: Environment) -> Result<AST, EvalError> {
    extractListContents(ast, environment) { list in
        guard list.count == 3 || list.count == 4 else { return .listEvaluationError("Expected list to have 3 or 4 values", ast, environment) }
        guard case .if = list.first! else { return .defError("if not first symbol?!", ast, environment) }
        return nil
    }
    .flatMap { list in
        return EVAL(list[1], environment)
            .map { condition in
                switch condition {
                case .nil, .bool(false) :
                    if list.count == 4 { return list[3] }
                    else { return .nil }
                default: return list[2]
                }
            }
    }
}

func runFn(_ ast: AST, _ environment: Environment) -> Result<AST, EvalError> {
    extractListContents(ast, environment) { list in
        guard list.count == 3 else { return .listEvaluationError("Expected list to have 3 values", ast, environment) }
        guard case .fn = list.first! else { return .fnError("fn not first symbol?!", ast, environment) }
        guard case .list = list[1] else { return .fnError("fn's first parameter must be a list", ast, environment) }
        return nil
    }
    .map { list -> AST in
        guard case .list(let parameters) = list[1] else { preconditionFailure() }
        let body = list[2]
        return .function(
            ast: body,
            params: parameters,
            environment: environment,
            fn: nil)
    }
}
