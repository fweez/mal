//
//  types.swift
//  step1_read_print
//
//  Created by Ryan Forsythe on 7/1/19.
//

import Foundation

enum Token {
    case error
    case lparen
    case rparen
    case number(Int)
    case symbol(String)
    
    init(from input: String) {
        switch input {
        case "(", "[": self = .lparen
        case ")", "]": self = .rparen
        default:
            if let v = Int(input) { self = .number(v) }
            else { self = .symbol(input) }
        }
    }
}

enum MalType {
    case number(Int)
    case symbol(String)
    case def
    case `let`
    case `nil`
    case `do`
    case `if`
    case fn
    case boolean(Bool)
    
    indirect case unclosedList([MalType])
    indirect case list([MalType])
    indirect case closure(parameters: MalType, body: MalType, environment: Environment)
    
    init(from token: Token) {
        switch token {
        case .error, .lparen, .rparen: fatalError()
        case .symbol(let v):
            for type in MalType.haveAssociatedStrings {
                if type.associatedString == v {
                    self = type
                    return
                }
            }
            switch v {
            case "true": self = .boolean(true)
            case "false": self = .boolean(false)
            default: self = .symbol(v)
            }
        case .number(let v): self = .number(v)
        }
    }
    
    static let haveAssociatedStrings: [MalType] = [.def, .let, .nil, .do, .if, .fn]
    
    var associatedString: String? {
        switch self {
        case .number, .symbol, .boolean, .unclosedList, .list: return nil
        case .def: return "def!"
        case .let: return "let*"
        case .nil: return "nil"
        case .do: return "do"
        case .if: return "if"
        case .fn: return "fn*"
        case .closure: return "#<function>"
        }
    }
}

extension MalType: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .def, .let, .nil, .do, .if, .fn, .closure: return associatedString!
        case .symbol(let v): return "\(v)"
        case .number(let v): return "\(v)"
        case .list(let values):
            return "(" + values
                .map { (t: MalType) -> String in t.debugDescription }
                .joined(separator: " ")
                + ")"
        case .unclosedList(let values):
            return "(" + values
                .map { (t: MalType) -> String in t.debugDescription }
                .joined(separator: " ")
                + " unbalanced"
        case .boolean(let b): return "\(b)"
        }
    }
}

extension MalType: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(debugDescription)
    }
}

extension MalType: Equatable {
    static func ==(lhs: MalType, rhs: MalType) -> Bool {
        switch (lhs, rhs) {
        case (.list(let r), .list(let l)): return r == l
        case (.number(let r), .number(let l)): return r == l
        case (.symbol(let r), .symbol(let l)): return r == l
        case (.nil, .nil): return true
            
        default: return false
        }
    }
}
