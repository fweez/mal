typealias EvaluationFunction = ([MalType]) -> MalType
typealias EnvironmentLayer = [MalType: EvaluationFunction]
typealias Environment = [EnvironmentLayer]

func apply(_ f: @escaping (Int, Int) -> Int) -> ([MalType]) -> MalType {
    return { values in
        values.reduce(.number(0), { accum, t in
            switch (accum, t) {
            case (.number(let v), .number(let w)): return .number(f(v, w))
            default: fatalError()
            }
        })
    }
}

var replEnvironment: Environment = [[
    .symbol("+"): apply(+),
    .symbol("*"): apply(*),
    .symbol("/"): apply(/),
    .symbol("-"): apply(-)
]]

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
