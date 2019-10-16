precedencegroup ForwardApplication {
    associativity: left
    higherThan: AssignmentPrecedence
}

infix operator |> : ForwardApplication
public func |> <A, B>(a: A, f: (A) throws -> B) rethrows -> B {
    return try f(a)
}

precedencegroup ForwardComposition {
    associativity: left
    higherThan: ForwardApplication
}

infix operator >>>: ForwardComposition
public func >>> <A, B, C>(f: @escaping (A) throws -> B, g: @escaping (B) throws -> C) rethrows -> ((A) throws -> C) {
    return { a in
        try g(try f(a))
    }
}

public func >>> <A, B, C>(f: @escaping (A) -> B, g: @escaping (B) throws -> C) rethrows -> ((A) throws -> C) {
    return { a in
        try g(f(a))
    }
}

public func >>> <A, B, C>(f: @escaping (A) throws -> B, g: @escaping (B) -> C) rethrows -> ((A) throws -> C) {
    return { a in
        try g(f(a))
    }
}

public func >>> <A, B, C>(f: @escaping (A) -> B, g: @escaping (B) -> C) -> ((A) -> C) {
    return { a in
        g(f(a))
    }
}
