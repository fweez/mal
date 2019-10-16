import Foundation
import FunctionalUtilities

/// Note: print is not a separate function, which lets me have typed errors more easily
public func rep(_ input: String) -> String {
    switch READ(input) {
    case .failure(let readError): return "AST Error: \(readError.localizedDescription)"
    case .success(let ast):
        switch EVAL(ast, replEnv) {
        case .failure(let evalError): return "Eval Error: \(evalError.localizedDescription)"
        case .success(let ast): return ast.description
        }
    }
}
