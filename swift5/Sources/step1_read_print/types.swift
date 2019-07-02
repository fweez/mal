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
    indirect case unclosedList([MalType])
    indirect case list([MalType])
    
    init(from token: Token) {
        switch token {
        case .error, .lparen, .rparen: fatalError()
        case .symbol(let v): self = .symbol(v)
        case .number(let v): self = .number(v)
        }
    }
}

extension MalType: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .symbol(let v):
            return "\(v)"
        case .number(let v):
            return "\(v)"
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
        }
    }
}
