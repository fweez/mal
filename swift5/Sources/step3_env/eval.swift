import FunctionalUtilities

fileprivate func evaluateValues(_ values: [MalType], _ environment: Environment) -> ([MalType], Environment) {
    return values
        .reduce(([], environment), { (accum: (evaluatedValues: [MalType], currEnvironment: Environment), value: MalType) in
            let (evaluatedValue, newEnvironment) = evaluate(value, environment: accum.currEnvironment)
            return (accum.evaluatedValues + [evaluatedValue], newEnvironment)
        })
}

fileprivate func updateEnvironment(_ values: [MalType], _ environment: Environment) -> (MalType, Environment) {
    guard values.count == 2 else { fatalError() }
    let key = values.first!
    let value = values.last!
    let (evaluatedValue, newEnvironment) = evaluate(value, environment: environment)
    return (evaluatedValue, set(in: newEnvironment, key: key, value: evaluatedValue))
}

fileprivate func evaluateWithBindings(_ values: [MalType], _ environment: Environment) -> (MalType, Environment) {
    guard values.count == 2 else { fatalError() }
    let bindingList = values.first!
    let application = values.last!
    
    let newEnvironment: Environment
    switch bindingList {
    case .list(let bindings):
        newEnvironment = bindings.enumerated()
            .reduce([]) { (accum: [[MalType]], t: (offset: Int, element: MalType)) -> [[MalType]] in
                if t.offset % 2 == 0 {
                    return accum + [[t.element]]
                } else {
                    var accum = accum
                    let l = accum.popLast()!
                    return accum + [l + [t.element]]
                }
            }
            .reduce(environment + [[:]]) { (accum: Environment, pair: [MalType]) -> Environment in
                let key = pair.first!
                var (evaluatedValue, evalEnvironment) = evaluate(pair.last!, environment: accum)
                var layer = evalEnvironment.popLast()!
                layer[key] = { _ in evaluatedValue }
                return evalEnvironment + [layer]
            }
        
    default: fatalError()
    }
    
    let (newValues, _) = evaluate(application, environment: newEnvironment)
    return (newValues, environment)
}

func evaluate(_ input: MalType, environment: Environment) -> (output: MalType, environment: Environment) {
    switch input {
    case .list(let v) where v.count == 0: return (input, environment)
    case .list(var v):
        let s = v.removeFirst()
        let f = get(in: environment, key:s)
        switch s {
        case .defBang: return updateEnvironment(v, environment)
        case .letStar: return evaluateWithBindings(v, environment)
        case .symbol where f != nil:
            let (evaluatedValues, newEnvironment) = evaluateValues(v, environment)
            return (f!(evaluatedValues), newEnvironment)
        default: return evalAST(input, environment: environment)
        }
    default: return evalAST(input, environment: environment)
    }
}

func evalAST(_ input: MalType, environment: Environment) -> (MalType, Environment) {
    switch input {
    case .unclosedList: fatalError()
    case .number: return (input, environment)
    case .symbol:
        return (environment.last?[input]?([]) ?? input, environment)
    case .list(let v):
        let (evaluatedValues, newEnvironment) = evaluateValues(v, environment)
        return (.list(evaluatedValues), newEnvironment)
    case .defBang: fatalError()
    case .letStar: fatalError()
    }
}
