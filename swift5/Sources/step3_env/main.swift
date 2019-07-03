import Foundation
import FunctionalUtilities

func READ(_ input: String) -> MalType {
    return input
        |> readString
}

func EVAL(_ input: MalType) -> MalType {
    let (output, newEnvironment) = evaluate(input, environment: replEnvironment)
    replEnvironment = newEnvironment
    return output
}

func PRINT(_ input: MalType) -> String {
    return input.debugDescription
}

let rep = READ >>> EVAL >>> PRINT

while true {
    print("user> ", separator: "", terminator: "")
    guard let input = readLine(strippingNewline: true) else { break }
    input.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) |>
        rep >>> { print("\($0)") }
}
