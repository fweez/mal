//
//  File.swift
//  
//
//  Created by ryan on 10/14/19.
//

import Foundation
import FunctionalUtilities
import mal

//initializationScript()

while true {
    print("user> ", separator: "", terminator: "")
    guard let input = readLine(strippingNewline: true) else { break }
    input |>
        rep >>> { print("\($0)") }
}

