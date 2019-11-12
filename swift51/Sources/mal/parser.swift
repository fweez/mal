import Foundation

protocol ParserProtocol {
    associatedtype Output
    associatedtype Seq: Collection
    
    var run: (inout Seq.SubSequence) -> Output? { get }
}
struct Parser<A, B>: ParserProtocol where B: Collection {
    typealias Output = A
    typealias Seq = B
    
    let run: (inout B.SubSequence) -> A?
}

extension Parser {
    func map<B>(_ f: @escaping (A) -> B) -> Parser<B, Seq> {
        Parser<B, Seq> { str -> B? in
            self.run(&str).map(f)
        }
    }
    
    func flatMap<B>(_ f: @escaping (A) -> Parser<B, Seq>) -> Parser<B, Seq> {
        Parser<B, Seq> { input -> B? in
            let original = input
            let matchA = self.run(&input)
            guard let matchB = matchA.map(f)?.run(&input) else {
                input = original
                return nil
            }
            return matchB
        }
    }
}

func zip<A, B, Seq>(_ a: Parser<A, Seq>, _ b: Parser<B, Seq>) -> Parser<(A, B), Seq> {
    Parser<(A, B), Seq> { str -> (A, B)? in
        let orig = str
        guard let matchA = a.run(&str) else { return nil }
        guard let matchB = b.run(&str) else {
            str = orig
            return nil
        }
        return (matchA, matchB)
    }
}

func zip<A, B, C, Seq>(_ a: Parser<A, Seq>, _ b: Parser<B, Seq>, _ c: Parser<C, Seq>) -> Parser<(A, B, C), Seq> {
    zip(a, zip(b, c)).map { a, bc in (a, bc.0, bc.1) }
}

func zip<A, B, C, D, Seq>(_ a: Parser<A, Seq>, _ b: Parser<B, Seq>, _ c: Parser<C, Seq>, _ d: Parser<D, Seq>) -> Parser<(A, B, C, D), Seq> {
    zip(a, zip(b, c, d)).map { a, bcd in (a, bcd.0, bcd.1, bcd.2) }
}


func always<A, Seq>(_ a: A) -> Parser<A, Seq> {
    return Parser<A, Seq> { _ in a }
}

extension Parser {
    static var never: Parser {
        return Parser { _ in nil }
    }
}

func zeroOrMore<A, Seq>(_ p: Parser<A, Seq>, separatedBy s: Parser<Void, Seq>) -> Parser<[A], Seq> {
    return Parser<[A], Seq> { input in
        var original = input
        var matches: [A] = []
        while let match = p.run(&input) {
            original = input
            matches.append(match)
            if s.run(&input) == nil { return matches }
        }
        input = original
        return matches
    }
}

func zeroOrMore<A, Seq>(_ p: Parser<A, Seq>) -> Parser<[A], Seq> {
    return Parser<[A], Seq> { input in
        var matches: [A] = []
        while let match = p.run(&input) {
            matches.append(match)
        }
        return matches
    }
}

func oneOf<A, Seq>(_ parsers: [Parser<A, Seq>]) -> Parser<A, Seq> {
    return Parser<A, Seq> { str -> A? in
        for p in parsers {
            if let match = p.run(&str) { return match }
        }
        return nil
    }
}

func optionalPrefix<A>(while p: @escaping (A.Element) -> Bool) -> Parser<A.SubSequence, A> where A: Collection {
    Parser<A.SubSequence, A> { input in
        let prefix = input.prefix(while: p)
        input.removeFirst(prefix.count)
        return prefix
    }
}

func hasPrefix<A>(while p: @escaping (A.Element) -> Bool) -> Parser<A.SubSequence, A> where A: Collection {
    optionalPrefix(while: p)
        .flatMap { str in
            guard str.count > 0 else { return .never }
            return always(str)
    }
}

extension Collection where Element: Equatable {
    func hasPrefix<A>(_ seq: A) -> Bool where A: Collection, A.Element == Self.Element {
        guard self.count >= seq.count else { return false }
        for (offset, elt) in seq.enumerated() {
            let idx = self.index(self.startIndex, offsetBy: offset)
            guard elt == self[idx] else { return false }
        }
        return true
    }
}

func literal<A>(_ literalSequence: A) -> Parser<Void, A> where A: Collection, A.Element: Equatable {
    return Parser<Void, A> { input in
        guard input.hasPrefix(literalSequence) else { return nil }
        input.removeFirst(literalSequence.count)
        return ()
    }
}

func literal<A>(_ literal: A.Element) -> Parser<Void, A> where A: Collection, A.Element: Equatable {
    return Parser<Void, A> { input in
        guard input.first == literal else { return nil }
        input.removeFirst()
        return ()
    }
}

func literal<A, B>(_ literalSequence: A, _ produces: B) -> Parser<B, A> where A: Collection, A.Element: Equatable {
    literal(literalSequence).flatMap { _ in always(produces) }
}

func literal<A, B>(_ l: A.Element, _ produces: B) -> Parser<B, A> where A: Collection, A.Element: Equatable {
    literal(l).flatMap { _ in always(produces) }
}


