import FunctionalUtilities

typealias EvaluationFunction = (_ values: MalType, _ enclosingEnvironment: Environment) -> MalType

class Environment {
    let outer: Environment?
    var functions: [MalType: EvaluationFunction] = [:]
    var aliases: [MalType: MalType] = [:]
    
    init(outer: Environment?) {
        self.outer = outer
    }
    
    convenience init(outer: Environment?, functions: [MalType: EvaluationFunction], aliases: [MalType: MalType]) {
        self.init(outer: outer)
        self.functions = functions
        self.aliases = aliases
    }
}

extension Environment: CustomStringConvertible {
    var description: String {
        return """
        functions: \(functions)
        aliases: \(aliases)
        -----
        outer:
        \(outer?.description ?? "<none>")
        """
    }
    
    
}

func set(in environment: Environment, key: MalType, value: MalType) -> Environment {
    switch value {
    case .closure(parameters: let params, body: let body, environment: let closureEnvironment):
        environment.functions[key] = { (values: MalType, enclosingEnvironment: Environment) -> MalType in
            (body, set(in: closureEnvironment, binds: params, exprs: values))
                |> evaluate
                |> { (v: EvalValue) -> MalType in v.value }
        }
    default:
        environment.aliases[key] = value
    }
    return environment
}

func get(in environment: Environment?, key: MalType) -> EvaluationFunction? {
    guard let environment = environment else { return nil }
    return environment.functions[key] ?? get(in: environment.outer, key: key)
}

func get(in environment: Environment?, key: MalType) -> MalType? {
    guard let environment = environment else { return nil }
    return environment.aliases[key] ?? get(in: environment.outer, key: key)
}

func set(in outer: Environment, binds: MalType, exprs: MalType) -> Environment {
    let newEnvironment = Environment(outer: outer)
    switch (binds, exprs) {
    case (.list(let b), .list(let e)):
        return zip(b, e)
            .reduce(newEnvironment, { (accum: Environment, t: (bind: MalType, expr: MalType)) -> Environment in
                return set(in: accum, key: t.bind, value: t.expr)
            })
    default: fatalError()
    }
}
