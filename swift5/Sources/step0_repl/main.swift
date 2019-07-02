import Foundation
import FunctionalUtilities

func READ(_ input: String) -> String{ return input }
func EVAL(_ input: String) -> String { return input }
func PRINT(_ input: String) -> String { return input }

let rep = READ >>> EVAL >>> PRINT

while true {
    print("user> ", separator: "", terminator: "")
    guard let input = readLine(strippingNewline: true) else { break }
    input |>
        rep >>> { print("\($0)") }
}
