func set(in environment: Environment, key: MalType, value: MalType) -> Environment {
    var environment = environment
    let valueFn: EvaluationFunction = { _ in return value }
    guard var local = environment.popLast() else { return [[key: valueFn]] }
    local[key] = valueFn
    return environment + [local]
}

func get(in environment: Environment, key: MalType) -> EvaluationFunction? {
    for layer in environment.reversed() {
        guard let r = layer[key] else { continue }
        return r
    }
    return nil
}

func set(in environment: Environment, binds: MalType, exprs: MalType) -> Environment {
    let newEnvironment = environment + [EnvironmentLayer()]
    switch (binds, exprs) {
    case (.list(let b), .list(let e)):
        return zip(b, e)
            .reduce(newEnvironment, { (accum: Environment, t: (bind: MalType, expr: MalType)) -> Environment in
                return set(in: accum, key: t.bind, value: t.expr)
            })
    default: fatalError()
    }
    
}
