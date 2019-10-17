import Foundation
import FunctionalUtilities

func READ(_ input: String) -> Result<AST, ASTError> {
    tokenize(input)
        .map(Reader.init)
        .flatMap { readForm($0) }
}

struct Reader {
    var tokens: [Token]
    mutating func next() -> Token { tokens.removeFirst() }
    var peek: Token? { tokens.first }
}

func readForm(_ reader: Reader) -> Result<AST, ASTError> {
    var reader = reader
    return readForm(&reader)
}

func readForm(_ reader: inout Reader) -> Result<AST, ASTError> {
    guard let first = reader.peek else { return .success(.empty) }
    switch first {
    case .lparen:
        return readList(&reader)
    default:
        return readAtom(&reader)
    }
}

func readList(_ reader: inout Reader) -> Result<AST, ASTError> {
    _ = reader.next()
    var listContents: [AST] = []
    while true {
        guard let next = reader.peek else { return .failure(ASTError.unexpectedEOL(listContents)) }
        switch next {
        case .rparen:
            _ = reader.next()
            return .success(.list(listContents))
        default:
            let nextAST = readForm(&reader)
            switch nextAST {
            case .success(let ast): listContents.append(ast)
            case .failure(let error): return .failure(error)
            }
        }
    }
}


func readAtom(_ reader: inout Reader) -> Result<AST, ASTError> {
    do {
        return .success(try AST(reader.next()))
    } catch {
        if let error = error as? ASTError {
            return .failure(error)
        }
        fatalError(error.localizedDescription)
    }
}
