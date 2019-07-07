import Foundation
import FunctionalUtilities

func READ(_ input: String) -> MalType {
    return input
        |> readString
}

func EVAL(_ input: MalType) -> MalType {
    return (input, replEnvironment) |> evaluate
        >>> { $0.value }
}

func PRINT(_ input: MalType) -> String {
    return input.debugDescription
}

let rep = READ >>> EVAL >>> PRINT

func runTests() {
    print("Running my tests")
    let tests: [(test: String, expected: String?)] = [
        ("(- 1 1)", "0"),
        ("(def! sumdown (fn* (N) (if (> N 0) (+ N (sumdown  (- N 1))) 0)))", nil),
        ("(sumdown 1)", "1"),
        ("(sumdown 2)", "3"),
    ]
    
    for (test, expected) in tests {
        let r = rep(test)
        print("\(test) -> \(r)")
        if let e = expected {
            assert(r == e, "Expected \(e)")
        }
    }
}

while true {
    print("user> ", separator: "", terminator: "")
    guard let input = readLine(strippingNewline: true) else { break }
    input.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) |>
        rep >>> { print("\($0)") }
}
