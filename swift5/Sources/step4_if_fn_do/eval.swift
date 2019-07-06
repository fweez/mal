import FunctionalUtilities

typealias EvalListValues = (values: [MalType], environment: Environment)
typealias EvalValue = (value: MalType, environment: Environment)

fileprivate func run(_ f: (EvalValue) -> (EvalValue), on values: [MalType], in environment: Environment) -> EvalListValues {
    return values
        .reduce(([], environment), { (accum: EvalListValues, value: MalType) -> EvalListValues in
            let (evaluatedValue, newEnvironment) = f((value, accum.environment))
            return (accum.values + [evaluatedValue], newEnvironment)
        })
}

fileprivate func evaluateValues(_ input: EvalListValues) -> EvalListValues {
    return run(evaluate, on: input.values, in: input.environment)
}

fileprivate func evalASTValues(_ input: EvalListValues) -> EvalListValues {
    return run(evalAST, on: input.values, in: input.environment)
}

fileprivate func updateEnvironment(_ input: EvalListValues) -> EvalValue {
    guard input.values.count == 2 else { fatalError() }
    let key = input.values.first!
    let value = input.values.last!
    
    return (value, input.environment) as EvalValue
        |> evaluate
        |> { ($0.value, set(in: $0.environment, key: key, value: $0.value)) }
}

fileprivate func generateEnvironment(_ input: EvalValue) -> Environment {
    return (input.value |> extractListValues)
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
    .reduce(Environment(outer: input.environment)) { (accum: Environment, pair: [MalType]) -> Environment in
            let key = pair.first!
            return (pair.last!, accum)
                |> evaluate
                |> { set(in: $0.environment, key: key, value: $0.value) }
    }
}

fileprivate func evaluateWithBindings(_ input: EvalListValues) -> EvalValue {
    guard input.values.count == 2 else { fatalError() }
    return (value: input.values.last!, environment: (input.values.first!, input.environment) |> generateEnvironment)
        |> evaluate
        |> { ($0.value, input.environment) }
}

fileprivate func ifTest(_ input: EvalListValues) -> EvalValue {
    guard input.values.count == 2 || input.values.count == 3 else { fatalError() }
    let test = input.values[0]
    let trueBranch = input.values[1]
    let falseBranch: MalType? = (input.values.count == 3) ? input.values[2] : nil
    
    return (test, input.environment)
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

fileprivate func fn(_ input: EvalListValues) -> EvalValue {
    guard input.values.count == 2 else { fatalError() }
    let params = input.values[0]
    let body = input.values[1]
    return (MalType.closure(parameters: params, body: body, environment: input.environment), input.environment)
}

fileprivate func runDo(_ input: EvalListValues) -> EvalValue {
    return input
        |> evaluateValues
        >>> { ($0.values.last!, $0.environment) as EvalValue } 
}

fileprivate func closure(_ input: EvalValue) -> EvalValue {
    return input
        |> evalAST
        >>> { (evaluated: EvalValue) -> EvalValue in
            switch evaluated.value {
            case .list(let evaluatedValues):
                let closure = evaluatedValues.first!
                switch closure {
                case .closure(parameters: let params, body: let body, environment: let closureEnv):
                    let closed = set(in: closureEnv, binds: params, exprs: .list(Array(evaluatedValues[1...])))
                    print("Evaluating " + body.debugDescription)
                    print("In environment: " + closed.description)
                    return (body, closed)
                        |> evaluate
                        >>> { ($0.value, evaluated.environment) }
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

func apply(_ input: EvalValue) -> EvalValue {
    let unevaluatedValues = input.value |> extractListValues
    let first = unevaluatedValues.first!
    let remaining = Array(unevaluatedValues[1...])
    let toProcess = (remaining, input.environment)
    let f: EvaluationFunction? = get(in: input.environment, key: first)
    
    switch first {
    case .symbol where f != nil:
        return toProcess
            |> { (input: EvalListValues) -> EvalValue in
                print("evaluating function for \(first)")
                print("in environment:")
                print(input.environment.description)
                return (
                    input
                        |> listify
                        >>> evaluate
                        >>> f!,
                    input.environment)
            }
    case .symbol:
        return input |> closure
    case .def: return toProcess |> updateEnvironment
    case .let: return toProcess |> evaluateWithBindings
    case .if: return toProcess |> ifTest
    case .fn: return toProcess |> fn
    case .do: return toProcess |> runDo
    default: return input |> closure
    }
}

func evaluate(_ input: EvalValue) -> EvalValue {
    switch input.value {
    case .list(let v) where v.count == 0: return input
    case .list: return input |> apply
    default: return input |> evalAST
    }
}

func evalAST(_ input: EvalValue) -> EvalValue {
    switch input.value {
    case .unclosedList: fatalError()
    case .symbol:
        return (get(in: input.environment, key: input.value) as MalType? ?? input.value, input.environment)
    case .list(let v):
        return (v, input.environment)
            |> evaluateValues
            >>> listify
    default: return input
    }
}

