import FunctionalUtilities

func runBuiltin(_ f: @escaping (Int, Int) -> Int) -> EvaluationFunction {
    return { values, _ in
        return values
            |> extractListValues
            >>> { (values: [MalType]) -> MalType in
                guard values.count > 1 else { return .number(0) }
                let first = values.first!
                guard values.count > 2 else { return first }
                
                return values.suffix(from: 1)
                    .reduce(first, { accum, t in
                        switch (accum, t) {
                        case (.number(let v), .number(let w)): return .number(f(v, w))
                        default: fatalError()
                        }
                    })
            }
    }
}

func runBuiltin(_ f: @escaping (Int, Int) -> Bool) -> EvaluationFunction {
    return { values, _ in
        let values = values |> extractListValues
        guard values.count == 2 else { fatalError() }
        switch (values[0], values[1]) {
        case (.number(let l), .number(let r)): return .boolean(f(l, r))
        default: fatalError()
        }
    }
}

func runBuiltin(_ f: @escaping (MalType) -> MalType) -> EvaluationFunction {
    return { values, _ in
        let values = values |> extractListValues
        return f(values.first!)
    }
}

func runBuiltin(_ f: @escaping (MalType?) -> MalType) -> EvaluationFunction {
    return { values, _ in
        let values = values |> extractListValues
        return f(values.first)
    }
}

func runBuiltin(_ f: @escaping (MalType, MalType) -> MalType) -> EvaluationFunction {
    return { values, _ in
        let values = values |> extractListValues
        guard values.count == 2 else { fatalError() }
        return f(values[0], values[1])
    }
}

let ns: Environment = Environment(
    outer: nil,
    functions: [
        .symbol("+"): runBuiltin(+),
        .symbol("*"): runBuiltin(*),
        .symbol("/"): runBuiltin(/),
        .symbol("-"): runBuiltin(-),
        .symbol("<"): runBuiltin(<),
        .symbol("<="): runBuiltin(<=),
        .symbol(">"): runBuiltin(>),
        .symbol(">="): runBuiltin(>=),
        .symbol("="): runBuiltin { .boolean($0 == $1) },
        .symbol("prn"): runBuiltin { (input: MalType?) -> MalType in
            if let v = input { print("\(v)") }
            return MalType.nil
        },
        .symbol("list"): { v, _ in v |> extractListValues >>> MalType.list },
        .symbol("list?"): runBuiltin { (input: MalType) -> MalType in
            switch input {
            case .list: return MalType.boolean(true)
            default: return MalType.boolean(false)
            }
        },
        .symbol("empty?"): runBuiltin { (input: MalType) -> MalType in
            switch input {
            case .list(let v) where v.count > 0: return MalType.boolean(true)
            default: return MalType.boolean(false)
            }
        },
        .symbol("count"): runBuiltin { (input: MalType) -> MalType in
            switch input {
            case .list(let v): return MalType.number(v.count)
            default: return MalType.number(0)
            }
        },
    ],
    aliases: [:])

var replEnvironment: Environment = ns
