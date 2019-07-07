import FunctionalUtilities

typealias EvalListValues = (values: [MalType], environment: Environment)
typealias EvalValue = (value: MalType, environment: Environment)

fileprivate func run(_ f: (EvalValue) throws -> (EvalValue), on values: [MalType], in environment: Environment) throws -> EvalListValues {
    return try values
        .reduce(([], environment), { (accum: EvalListValues, value: MalType) throws -> EvalListValues in
            let (evaluatedValue, newEnvironment) = try f((value, accum.environment))
            return (accum.values + [evaluatedValue], newEnvironment)
        })
}

fileprivate func evaluateValues(_ input: EvalListValues) throws -> EvalListValues {
    return try run(evaluate, on: input.values, in: input.environment)
}

fileprivate func evalASTValues(_ input: EvalListValues) throws -> EvalListValues {
    return try run(evalAST, on: input.values, in: input.environment)
}

fileprivate func updateEnvironment(_ input: EvalListValues) throws -> EvalValue {
    guard input.values.count == 2 else { fatalError() }
    let key = input.values.first!
    let value = input.values.last!
    
    return try (value, input.environment) as EvalValue
        |> evaluate
        |> { ($0.value, set(in: $0.environment, key: key, value: $0.value)) }
}

fileprivate func generateEnvironment(_ input: EvalValue) throws -> Environment {
    return try (input.value |> extractListValues)
        .enumerated()
        .reduce([]) { (accum: [[MalType]], t: (offset: Int, element: MalType)) -> [[MalType]] in
            if t.offset % 2 == 0 {
                return accum + [[t.element]]
            } else {
                var accum = accum
                let l = accum.popLast()!
                return accum + [l + [t.element]]
            }
        }
    .reduce(Environment(outer: input.environment)) { (accum: Environment, pair: [MalType]) throws -> Environment in
            let key = pair.first!
            return try (pair.last!, accum)
                |> evaluate
                |> { set(in: $0.environment, key: key, value: $0.value) }
    }
}

fileprivate func evaluateWithBindings(_ input: EvalListValues) throws -> EvalValue {
    guard input.values.count == 2 else { fatalError() }
    return try (value: input.values.last!, environment: (input.values.first!, input.environment) |> generateEnvironment)
        |> evaluate
        |> { ($0.value, input.environment) }
}

fileprivate func ifTest(_ input: EvalListValues) throws -> EvalValue {
    guard input.values.count == 2 || input.values.count == 3 else { fatalError() }
    let test = input.values[0]
    let trueBranch = input.values[1]
    let falseBranch: MalType? = (input.values.count == 3) ? input.values[2] : nil
    
    return try (test, input.environment)
        |> evaluate
        |> { (i: EvalValue) -> EvalValue in
            switch i.value {
            case .nil, .boolean(false):
                guard let falseBranch = falseBranch  else { return (.nil, i.environment) }
                return (falseBranch, i.environment) as EvalValue
            default:
                return (trueBranch, i.environment) as EvalValue
            }
        }
        |> evaluate
}

func debugReturn(_ input: EvalValue) -> EvalValue {
    print("-> \(input.value)")
    return input
}

fileprivate func fn(_ input: EvalListValues) throws -> EvalValue {
    guard input.values.count == 2 else { fatalError() }
    let body = { (parameters: MalType, values: MalType, environment: Environment) -> MalType in
        return try (input.values[1], set(in: environment, binds: parameters, exprs: values))
            |> evaluate
            >>> { $0.0 }
    }
    return (.fn(parameters: input.values[0], function: body, environment: input.environment), input.environment)
}

fileprivate func runDo(_ input: EvalListValues) throws -> EvalValue {
    return try input
        |> evaluateValues
        >>> { ($0.values.last!, $0.environment) as EvalValue } 
}

fileprivate func closure(_ input: EvalValue) throws -> EvalValue {
    return try input
        |> evalAST
        >>> { (evaluated: EvalValue) throws -> EvalValue in
            switch evaluated.value {
            case .list(let evaluatedValues):
                let closure = evaluatedValues.first!
                switch closure {
                case .fn(parameters: let params, function: let f, environment: let closureEnv):
//                    print("Calling \(closure) with values \(Array(evaluatedValues[1...]))")
                    return (try f(params, .list(Array(evaluatedValues[1...])), closureEnv), evaluated.environment)
                default: break
                }
            default: break
            }
            return evaluated
        }
}

func extractListValues(_ list: MalType) -> [MalType] {
    switch list {
    case .list(let v): return v
    default: fatalError()
    }
}

func listify(_ input: EvalListValues) -> EvalValue {
    return (.list(input.values), input.environment)
}

func apply(_ input: EvalValue) throws -> EvalValue {
    let unevaluatedValues = input.value |> extractListValues
    let first = unevaluatedValues.first!
    let remaining = Array(unevaluatedValues[1...])
    let toProcess = (remaining, input.environment)
    
    switch first {
    case .def: return try toProcess |> updateEnvironment
    case .let: return try toProcess |> evaluateWithBindings
    case .if: return try toProcess |> ifTest
    case .do: return try toProcess |> runDo
    case .symbol(let s) where s == "fn*": return try toProcess |> fn
    default:
        return try input |> closure
    }
}

func evaluate(_ input: EvalValue) throws -> EvalValue {
    switch input.value {
    case .list(let v) where v.count == 0: return input
    case .list: return try input |> apply
    default: return try input |> evalAST
    }
}

func evalAST(_ input: EvalValue) throws -> EvalValue {
    switch input.value {
    case .unclosedList: fatalError()
    case .symbol:
        return (get(in: input.environment, key: input.value) as MalType? ?? input.value, input.environment)
    case .list(let v):
        return try (v, input.environment)
            |> evaluateValues
            >>> listify
    default: return input
    }
}

