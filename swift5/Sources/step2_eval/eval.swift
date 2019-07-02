typealias Environment = [MalType: ([MalType]) -> MalType]

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

var replEnvironment: Environment = [
    .symbol("+"): apply(+),
    .symbol("*"): apply(*),
    .symbol("/"): apply(/),
    .symbol("-"): apply(-)
]

func evaluate(_ input: MalType, environment: Environment) -> MalType {
    switch input {
    case .list(let v) where v.count == 0: return input
    case .list(var v):
        let s = v.removeFirst()
        switch s {
        case .symbol where environment[s] != nil:
            return environment[s]!(v.map { evaluate($0, environment: environment) })
        default: return evalAST(input, environment: environment)
        }
    default: return evalAST(input, environment: environment)
    }
}

func evalAST(_ input: MalType, environment: Environment) -> MalType {
    switch input {
    case .unclosedList: fatalError()
    case .number, .symbol: return input
    case .list(let v):
        return .list(v.map { evaluate($0, environment: environment) })
    }
}
