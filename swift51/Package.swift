// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Make A LISP",
    products: [
        .library(name: "FunctionalUtilities", targets: ["FunctionalUtilities"]),
        .library(name: "mal", targets: ["mal"]),
    ],
    dependencies: [
        
    ],
    targets: [
        .target(
            name: "FunctionalUtilities",
            dependencies: []),
        .target(
            name: "mal",
            dependencies: ["FunctionalUtilities"]),
        .target(
            name: "malREPL",
            dependencies: ["mal"]),
        .testTarget(
            name: "malTests",
            dependencies: ["mal"]),
    ]
)
