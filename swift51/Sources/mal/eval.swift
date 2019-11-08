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
    case stringEvaluationError(String, AST)
    case fileLoadingError(description: String, filename: String)
    case atomError(String, UUID, [UUID: AST])
    case quasiquoteError(String, AST)
    
    var localizedDescription: String {
        switch self {
        case let .argumentMismatch(description, ast):
            return "\(description) (AST: \(ast))"
        case let .unknownSymbol(symbol, environment):
            return "'\(symbol)' not found (Environment: \(environment))"
        case let .listEvaluationError(description, ast, _):
            return "\(description) (AST: \(ast))"
        case let .defError(description, ast, _):
            return "Error processing def!: \(description) (AST: \(ast))"
        case let .bindingError(description, _):
            return "Error binding to environment: \(description)"
        case let .letError(description, ast, _):
            return "Error processing let*: \(description) (AST: \(ast))"
        case let .fnError(description, ast, _):
            return "Error processing fn*: \(description) (AST: \(ast))"
        case let .stringEvaluationError(description, input):
            return "Error evaluating string: \(description) (Input string: \(input))"
        case let .fileLoadingError(description: description, filename: filename):
            return "Error opening file '\(filename)': \(description)"
        case let .atomError(description, atomID, searchSpace):
            return "Atom \(atomID.uuidString) error: \(description). (Atom space: \(searchSpace))"
        case let .quasiquoteError(description, ast):
            return "Error in quasiquote: \(description) (AST: \(ast))"
        }
    }
}

func EVAL(_ ast: AST, _ environment: Environment) -> Result<AST, EvalError> {
    var ast = ast
    var environment = environment
    while true {
//        print("EVAL")
//        print("ast: \(ast)")
//        print("environment: \(environment.id)")
        switch ast {
        case .list(let list):
            guard list.isEmpty == false else { return .success(ast) }
            switch list.first! {
            case .def: return setInEnvironment(ast, environment)
            case .fn: return runFn(ast, environment)
            case .quote: return runQuote(ast, environment)
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
            case .quasiquote:
                let result = runQuasiquote(ast, environment)
                switch result {
                case .failure: return result
                case .success(let newAST):
                    ast = newAST
                }
            default:
                switch evalAST(ast, environment).flatMap({ apply($0, environment) }) {
                case .failure(let err): return .failure(err)
                case .success(let (newAST, newEnvironment)) where newEnvironment != nil:
                    ast = newAST
                    environment = newEnvironment!
                case .success(let (newAST, _)): return .success(newAST)
                }
            }
        default: return evalAST(ast, environment)
        }
    }
}

func evalAST(_ ast: AST, _ environment: Environment) -> Result<AST, EvalError> {
//    print("evalAST on \(ast)")
//    print("ast: \(ast)")
//    print("environment: \(environment.id)")

    switch ast {
    case .symbol(let symbol):
        guard let lookup = environment[symbol] else { return .failure(.unknownSymbol(symbol, environment)) }
        return .success(lookup)
    case .list(let items):
        return items
            .reduce(.success(.list([]))) { result, elementAST -> Result<AST, EvalError> in
                result.flatMap { resultAST in
                    guard case .list(let resultList) = resultAST else { preconditionFailure("Accumulator should have had a list AST in it!") }
                    return EVAL(elementAST, environment)
                        .map { .list(resultList + [$0]) }
                }
            }
    case .vector(let items):
        return items
            .reduce(.success(.vector([]))) { result, elementAST -> Result<AST, EvalError> in
                result.flatMap { resultAST in
                    guard case .vector(let resultList) = resultAST else { preconditionFailure("Accumulator should have had a vector AST in it!") }
                    return EVAL(elementAST, environment)
                        .map { .vector(resultList + [$0]) }
                }
        }    default: return .success(ast)
    }
}

func extractListContents(_ ast: AST, _ environment: Environment, checkedBy predicate: ([AST]) -> EvalError?) -> Result<[AST], EvalError> {
    guard case let .list(list) = ast else { return .failure(.listEvaluationError("Expected list", ast, environment)) }
    if let error = predicate(list) { return .failure(error) }
    return .success(list)
}

func apply(_ ast: AST, _ environment: Environment) -> Result<(AST, Environment?), EvalError> {
    return extractListContents(ast, environment) { list in
        guard list.isEmpty == false else { return .listEvaluationError("Expected list to have values in apply", ast, environment) }
        switch list.first {
        case .function, .builtin: return nil
        default: return .listEvaluationError("First value in list was not a function or builtin", ast, environment)
        }
    }
    .flatMap { list in
        let args = Array(list.suffix(from: 1))
        switch list.first {
        case let .function(ast: body, params: parameters, environment: environment, fn: _):
            let bindings = zip(parameters, args)
                .reduce([]) { return $0 + [$1.0, $1.1] }
//            print("CREATING ENVIRONMENT FOR FUNCTION ARGUMENTS")
            return Environment.from(outer: environment, bindings: bindings)
                .map { (body, $0) }
        case .builtin(let applyFn): return applyFn(args, environment).map { ($0, nil) }
        default: preconditionFailure()
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
//        print("CREATING ENVIRONMENT FOR LET*")
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

func runQuote(_ ast: AST, _ environment: Environment) -> Result<AST, EvalError> {
    extractListContents(ast, environment) { list in
        guard list.count == 2 else { return .listEvaluationError("Expected list to have 2 values", ast, environment) }
        guard case .quote = list.first! else { return .argumentMismatch("quote not first symbol!?", list) }
        return nil
    }
    .map { $0.last! }
}

func runQuasiquote(_ ast: AST, _ environment: Environment) -> Result<AST, EvalError> {
    extractListContents(ast, environment) { list in
        guard list.count == 2 else { return .listEvaluationError("Expected list to have 2 values", ast, environment) }
        guard case .quasiquote = list.first! else { return .argumentMismatch("quasiquote not first symbol!?", list) }
        return nil
    }
    .flatMap { list -> Result<AST, EvalError> in
        func isPair(_ ast: AST) -> [AST]? {
            guard case .list(let contents) = ast, contents.count > 0 else { return nil }
            return contents
        }
        
        /// if is_pair of ast is false: return a new list containing: a symbol named "quote" and ast.
        let param = list.last!
        guard let qqdItems = isPair(param) else { return .success(.list([.quote, param])) }
        
        /// else if the first element of ast is a symbol named "unquote": return the second element of ast.
        if case .unquote = qqdItems.first! {
            guard qqdItems.count == 2 else { return .failure(.quasiquoteError("expected 1 parameter to unquote", ast)) }
            return .success(qqdItems.last!)
        }
        
        /// if is_pair of the first element of ast is true and the first element of first element of ast (ast[0][0]) is a symbol named "splice-unquote":
        if let firstItemContents = isPair(qqdItems.first!),
            case .spliceunquote = firstItemContents.first! {
            guard firstItemContents.count == 2 else { return .failure(.quasiquoteError("expected 1 parameter to splice-unquote", ast)) }
            /// return a new list containing: a symbol named "concat", the second element of first element of ast (ast[0][1]), and the result of calling quasiquote with the second through last element of ast.
            return runQuasiquote(.list([.quasiquote, .list(Array(qqdItems.suffix(from: 1)))]), environment)
                .map { quasiquotedTail in
                    .list([
                        .symbol("concat"),
                        firstItemContents[1],
                        quasiquotedTail
                    ])
                }
        }
        
        /// otherwise: return a new list containing: a symbol named "cons", the result of calling quasiquote on first element of ast (ast[0]), and the result of calling quasiquote with the second through last element of ast.
        return zip(
            runQuasiquote(.list([.quasiquote, qqdItems.first!]), environment),
            runQuasiquote(.list([.quasiquote, .list(Array(qqdItems.suffix(from: 1)))]), environment))
            .map { qqdFirst, qqdTail in
                .list([
                    .symbol("cons"),
                    qqdFirst,
                    qqdTail
                    ])
            }
    }
}
