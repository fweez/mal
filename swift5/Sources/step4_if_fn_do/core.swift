typealias EvaluationFunction = ([MalType]) -> MalType
typealias EnvironmentLayer = [MalType: EvaluationFunction]
typealias Environment = [EnvironmentLayer]

func apply(_ f: @escaping (Int, Int) -> Int) -> EvaluationFunction {
    return { values in
        values.reduce(.number(0), { accum, t in
            switch (accum, t) {
            case (.number(let v), .number(let w)): return .number(f(v, w))
            default: fatalError()
            }
        })
    }
}

func apply(_ f: @escaping (Int, Int) -> Bool) -> EvaluationFunction {
    return { values in
        guard values.count == 2 else { fatalError() }
        switch (values[0], values[1]) {
        case (.number(let l), .number(let r)): return .boolean(f(l, r))
        default: fatalError()
        }
    }
}

func apply(_ f: @escaping (MalType) -> MalType) -> EvaluationFunction {
    return { values in
        return f(values.first!)
    }
}

func apply(_ f: @escaping (MalType, MalType) -> MalType) -> EvaluationFunction {
    return { values in
        guard values.count == 2 else { fatalError() }
        return f(values[0], values[1])
    }
}

let ns: EnvironmentLayer = [
    .symbol("+"): apply(+),
    .symbol("*"): apply(*),
    .symbol("/"): apply(/),
    .symbol("-"): apply(-),
    .symbol("<"): apply(<),
    .symbol("<="): apply(<=),
    .symbol(">"): apply(>),
    .symbol(">="): apply(>=),
    .symbol("="): apply { .boolean($0 == $1) },
    .symbol("prn"): apply {
            print("\($0)")
            return MalType.nil
        },
    .symbol("list"): { MalType.list($0) },
    .symbol("list?"): apply {
            switch $0 {
            case .list: return MalType.boolean(true)
            default: return MalType.boolean(false)
            }
        },
    .symbol("empty?"): apply {
            switch $0 {
            case .list(let v) where v.count > 0: return MalType.boolean(true)
            default: return MalType.boolean(false)
            }
        },
    .symbol("count"): apply {
            switch $0 {
            case .list(let v): return MalType.number(v.count)
            default: return MalType.number(0)
            }
        },
    
]

var replEnvironment: Environment = [ns]
