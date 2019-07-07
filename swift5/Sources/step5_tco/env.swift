import FunctionalUtilities

typealias EvaluationFunction = (_ parameters: MalType, _ values: MalType, _ enclosingEnvironment: Environment) throws -> MalType

class Environment {
    let outer: Environment?
    var aliases: [MalType: MalType] = [:]
    
    init(outer: Environment?) {
        self.outer = outer
    }
    
    convenience init(outer: Environment?, aliases: [MalType: MalType]) {
        self.init(outer: outer)
        self.aliases = aliases
    }
}

extension Environment: CustomStringConvertible {
    var description: String {
        return """
        aliases: \(aliases)
        -----
        outer:
        \(outer?.description ?? "<none>")
        """
    }
}

enum EnvironmentError: Error {
    case badBinding
}

func set(in environment: Environment, key: MalType, value: MalType) -> Environment {
    environment.aliases[key] = value
    return environment
}

func get(in environment: Environment?, key: MalType) -> MalType? {
    guard let environment = environment else { return nil }
    return environment.aliases[key] ?? get(in: environment.outer, key: key)
}

func set(in outer: Environment, binds: MalType, exprs: MalType) throws -> Environment {
    let newEnvironment = Environment(outer: outer)
    switch (binds, exprs) {
    case (.list(let b), .list(let e)):
        return zip(b, e)
            .reduce(newEnvironment, { (accum: Environment, t: (bind: MalType, expr: MalType)) -> Environment in
                return set(in: accum, key: t.bind, value: t.expr)
            })
    default: throw EnvironmentError.badBinding
    }
}
