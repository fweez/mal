import Foundation
import FunctionalUtilities

func runBuiltin(_ f: @escaping (Int, Int) -> Int) -> EvaluationFunction {
    return { _, values, _ in
        let values = values |> extractListValues
        guard values.count == 2 else { fatalError() }
        switch (values[0], values[1]) {
        case (.number(let l), .number(let r)): return .number(f(l, r))
        default: fatalError()
        }
    }
}

func runBuiltin(_ f: @escaping (Int, Int) -> Bool) -> EvaluationFunction {
    return { _, values, _ in
        let values = values |> extractListValues
        guard values.count == 2 else { fatalError() }
        switch (values[0], values[1]) {
        case (.number(let l), .number(let r)): return .boolean(f(l, r))
        default: fatalError()
        }
    }
}

func runBuiltin(_ f: @escaping (MalType) -> MalType) -> EvaluationFunction {
    return { _, values, _ in
        let values = values |> extractListValues
        return f(values.first!)
    }
}

func runBuiltin(_ f: @escaping (MalType?) -> MalType) -> EvaluationFunction {
    return { _, values, _ in
        let values = values |> extractListValues
        return f(values.first)
    }
}

func runBuiltin(_ f: @escaping (MalType, MalType) -> MalType) -> EvaluationFunction {
    return { _, values, _ in
        let values = values |> extractListValues
        guard values.count == 2 else { fatalError() }
        return f(values[0], values[1])
    }
}

func toTwoParamFn(_ body: @escaping EvaluationFunction) -> MalType {
    return .fn(parameters: .list([.symbol("__l"), .symbol("__r")]), function: body, environment: Environment(outer: nil))
}

func toOneParamFn(_ body: @escaping EvaluationFunction) -> MalType {
    return .fn(parameters: .list([.symbol("__x")]), function: body, environment: Environment(outer: nil))
}


let ns: Environment = Environment(
    outer: nil,
    aliases: [
        .symbol("+"): runBuiltin(+) |> toTwoParamFn,
        .symbol("*"): runBuiltin(*) |> toTwoParamFn,
        .symbol("/"): runBuiltin(/) |> toTwoParamFn,
        .symbol("-"): runBuiltin(-) |> toTwoParamFn,
        .symbol("<"): runBuiltin(<) |> toTwoParamFn,
        .symbol("<="): runBuiltin(<=) |> toTwoParamFn,
        .symbol(">"): runBuiltin(>) |> toTwoParamFn,
        .symbol(">="): runBuiltin(>=) |> toTwoParamFn,
        .symbol("="): runBuiltin { .boolean($0 == $1) } |> toTwoParamFn,
        .symbol("prn"): runBuiltin { (input: MalType?) -> MalType in
            if let v = input { print("\(v)") }
            return MalType.nil
        } |> toOneParamFn,
        .symbol("list"): { _, v, _ in v |> extractListValues >>> MalType.list }  |> toOneParamFn,
        .symbol("list?"): runBuiltin { (input: MalType) -> MalType in
            switch input {
            case .list: return MalType.boolean(true)
            default: return MalType.boolean(false)
            }
        } |> toOneParamFn,
        .symbol("empty?"): runBuiltin { (input: MalType) -> MalType in
            switch input {
            case .list(let v) where v.count > 0: return MalType.boolean(true)
            default: return MalType.boolean(false)
            }
        } |> toOneParamFn,
        .symbol("count"): runBuiltin { (input: MalType) -> MalType in
            switch input {
            case .list(let v): return MalType.number(v.count)
            default: return MalType.number(0)
            }
        } |> toOneParamFn,
    ])
var replEnvironment: Environment = ns
