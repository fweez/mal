import FunctionalUtilities

typealias EvalListValues = (values: [MalType], environment: Environment)
typealias EvalValue = (value: MalType, environment: Environment)

fileprivate func run(_ f: (EvalValue) -> (EvalValue), on values: [MalType], in environment: Environment) -> EvalListValues {
    return values
        .reduce(([], environment), { (accum: EvalListValues, value: MalType) in
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
    
    return (value, input.environment)
        |> evaluate
        >>> { ($0.value, set(in: $0.environment, key: key, value: $0.value)) }
}

fileprivate func generateEnvironment(_ input: EvalValue) -> Environment {
    switch input.value {
    case .list(let bindings):
        return bindings.enumerated()
            .reduce([]) { (accum: [[MalType]], t: (offset: Int, element: MalType)) -> [[MalType]] in
                if t.offset % 2 == 0 {
                    return accum + [[t.element]]
                } else {
                    var accum = accum
                    let l = accum.popLast()!
                    return accum + [l + [t.element]]
                }
            }
            .reduce(input.environment + [[:]]) { (accum: Environment, pair: [MalType]) -> Environment in
                let key = pair.first!
                var (evaluatedValue, evalEnvironment) = evaluate((pair.last!, accum))
                var layer = evalEnvironment.popLast()!
                layer[key] = { _ in evaluatedValue }
                return evalEnvironment + [layer]
        }
        
    default: fatalError()
    }
}

fileprivate func evaluateWithBindings(_ input: EvalListValues) -> EvalValue {
    guard input.values.count == 2 else { fatalError() }
    return (input.values.last!, (input.values.first!, input.environment) |> generateEnvironment)
        |> evaluate
        >>> { ($0.value, input.environment) }
}

fileprivate func ifTest(_ input: EvalListValues) -> EvalValue {
    guard input.values.count >= 2 && input.values.count <= 3 else { fatalError() }
    let test = input.values[0]
    let trueBranch = input.values[1]
    let falseBranch: MalType? = (input.values.count > 2) ? input.values[2] : nil
    
    return (test, input.environment)
        |> evaluate
        >>> { (i: EvalValue) -> EvalValue in
            switch i.value {
            case .nil, .boolean(false):
                guard let falseBranch = falseBranch  else { return (.nil, i.environment) }
                return (falseBranch, i.environment)
            default:
                return (trueBranch, i.environment)
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

fileprivate func evaluateList(_ input: EvalListValues) -> EvalValue {
    var remainingValues = input.values
    let s = remainingValues.removeFirst()
    let f = get(in: input.environment, key: s)
    let processed = (remainingValues, input.environment)
    switch s {
    case .def: return processed |> updateEnvironment
    case .let: return processed |> evaluateWithBindings
    case .if: return processed |> ifTest
    case .fn: return processed |> fn
    case .symbol where f != nil:
        return processed
            |> evaluateValues
            >>> { (f!($0.values), $0.environment) }
    case .do:
        return processed
            |> evalASTValues
            >>> { ($0.values.last!, $0.environment) }
    case .closure, .number, .symbol, .nil, .boolean, .list, .unclosedList: fatalError()
    }
}

func evaluate(_ input: EvalValue) -> EvalValue {
    switch input.value {
    case .list(let v) where v.count == 0: return input
    case .list(let v):
        switch v.first! {
        case .number, .nil, .boolean, .list, .unclosedList: break
        case .def, .let, .if, .fn, .closure, .symbol, .do:
            return (v, input.environment) |> evaluateList
        }
    default: break
    }
    return input |> evalAST
}

func runClosure(_ input: EvalValue) -> EvalValue {
    switch input.value {
    case .list(var values) where values.count > 1:
        switch values.removeFirst() {
        case .closure(parameters: let params, body: let body, environment: let closureEnvironment):
            return (body, set(in: closureEnvironment, binds: params, exprs: .list(values)))
                |> evaluate
                >>> { ($0.value, input.environment) }
        default: break
        }
    default: break
    }
    return input
}

func evalAST(_ input: EvalValue) -> EvalValue {
    switch input.value {
    case .unclosedList: fatalError()
    case .number, .nil, .boolean: return input
    case .symbol:
        return (input.environment.last?[input.value]?([]) ?? input.value, input.environment)
    case .list(let v):
        return (v, input.environment)
            |> evaluateValues
            >>> { (.list($0.values), $0.environment) }
            |> runClosure
    case .def: fatalError()
    case .let: fatalError()
    case .do: fatalError()
    case .if: fatalError()
    case .fn: fatalError()
    case .closure: fatalError()
    }
}

