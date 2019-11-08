import XCTest

import malTests

var tests = [XCTestCaseEntry]()
tests += malTests.allTests()
XCTMain(tests)
