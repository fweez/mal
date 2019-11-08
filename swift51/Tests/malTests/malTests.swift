import XCTest
import class Foundation.Bundle

import FunctionalUtilities
@testable import mal

final class unitTests: XCTestCase {
    func testParenParser() {
        XCTAssertEqual(tokenize("()"), Result.success([Token.lparen, .rparen]))
        XCTAssertEqual(tokenize("(("), Result.success([Token.lparen, .lparen]))
        XCTAssertEqual(tokenize(" ()"), Result.success([Token.lparen, .rparen]))
        XCTAssertEqual(tokenize(" (     )"), Result.success([Token.lparen, .rparen]))
    }
    
    func testNumberParser() {
        XCTAssertEqual(tokenize("1"), Result.success([Token.number(1)]))
        XCTAssertEqual(tokenize("-1"), Result.success([Token.number(-1)]))
        XCTAssertEqual(tokenize("   -1"), Result.success([Token.number(-1)]))
        XCTAssertEqual(tokenize("(1 2)"), Result.success([Token.lparen, .number(1), .number(2), .rparen]))
        XCTAssertEqual(tokenize("(  1 2)"), Result.success([Token.lparen, .number(1), .number(2), .rparen]))
        XCTAssertEqual(tokenize("(  1 -2)"), Result.success([Token.lparen, .number(1), .number(-2), .rparen]))
        XCTAssertEqual(tokenize("(-  1 2)"), Result.success([Token.lparen, .symbol("-"), .number(1), .number(2), .rparen]))
        XCTAssertEqual(tokenize("(-  -1 2)"), Result.success([Token.lparen, .symbol("-"), .number(-1), .number(2), .rparen]))
    }
    
    func testSymbolParser() {
        XCTAssertEqual(tokenize("(+ 1)"), Result.success([Token.lparen, .symbol("+"), .number(1), .rparen]))
        XCTAssertEqual(tokenize("(- 1)"), Result.success([Token.lparen, .symbol("-"), .number(1), .rparen]))
        XCTAssertEqual(tokenize("(- + 1)"), Result.success([Token.lparen, .symbol("-"), .symbol("+"), .number(1), .rparen]))
        XCTAssertEqual(tokenize("(test 1)"), Result.success([Token.lparen, .symbol("test"), .number(1), .rparen]))
        XCTAssertEqual(tokenize("(test1 1)"), Result.success([Token.lparen, .symbol("test1"), .number(1), .rparen]))
        XCTAssertEqual(tokenize("(t3st 1)"), Result.success([Token.lparen, .symbol("t3st"), .number(1), .rparen]))
        XCTAssertEqual(tokenize("(3test 1)"), Result.success([Token.lparen, .number(3), .symbol("test"), .number(1), .rparen]))
        XCTAssertEqual(tokenize("test!"), Result.success([Token.symbol("test!")]))
        XCTAssertEqual(tokenize("test*"), Result.success([Token.symbol("test*")]))
        XCTAssertEqual(tokenize("(test)"), Result.success([Token.lparen, .symbol("test"), .rparen]))
    }
    
    func testStringParser() {
        XCTAssertEqual(tokenize(#""foo""#), Result.success([Token.string("foo")]))
        XCTAssertEqual(tokenize(#"("foo" "bar")"#), Result.success([Token.lparen, .string("foo"), .string("bar"), .rparen]))
        XCTAssertEqual(tokenize(#""foo\"bar\"""#), Result.success([.string("foo\\\"bar\\\"")]))
    }
    
    func testCommentParser() {
        XCTAssertEqual(tokenize(";test"), Result.success([]))
        XCTAssertEqual(tokenize(";;(1)"), Result.success([]))
        XCTAssertEqual(
            tokenize("""
            ;test
            (1)
            """), Result.success([Token.lparen, .number(1), .rparen]))
        XCTAssertEqual(
            tokenize("""
            (1)
            ;test
            (2)
            """), Result.success([Token.lparen, .number(1), .rparen, .lparen, .number(2), .rparen]))
        XCTAssertEqual(
            tokenize("""
            (1)
            ;test
            (2)
            ;test
            """), Result.success([Token.lparen, .number(1), .rparen, .lparen, .number(2), .rparen]))
        XCTAssertEqual(
            tokenize("""
            (1) ;test
            (2)
            """), Result.success([Token.lparen, .number(1), .rparen, .lparen, .number(2), .rparen]))
    }
}

final class malTests: XCTestCase {
    enum TestInputLine {
        case testDescription(String)
        case input(String)
        case expectedOutput(String)
        case expectedRegex(String)
        case setDeferrable(Bool)
        case setOptional(Bool)
        
        init?(_ input: String) {
            func skip(_ offset: Int) -> String {
                return String(input.suffix(from: input.index(input.startIndex, offsetBy: offset)))
            }
            if input.starts(with: ";; ") {
                let desc = skip(3)
                guard desc.count > 0 else { return nil }
                self = .testDescription(skip(3))
                return
            }
            if input.starts(with: ";;") { return nil }
            if input.starts(with: ";=>") {
                self = .expectedOutput(skip(3))
                return
            }
            if input.starts(with: ";/") {
                self = .expectedRegex(skip(2))
                return
            }
            if input.starts(with: ";>>> deferrable=") {
                let value = skip(";>>> deferrable=".count)
                    .lowercased()
                if let b = Bool(value) {
                    self = .setDeferrable(b)
                    return
                }
            }
            if input.starts(with: ";>>> optional=") {
                let value = skip(";>>> optional=".count)
                    .lowercased()
                if let b = Bool(value) {
                    self = .setOptional(b)
                    return
                }
            }

            self = .input(input)
        }
    }
    
    func makeScript(_ malInput: String) -> [TestInputLine] {
        return malInput
            .split(separator: "\n")
            .filter { $0.count > 0 }
            .compactMap { TestInputLine(String($0)) }
    }
    
    func runMALScript(_ tests: String) -> Void {
        var optional = false
        var deferrable = false
        var description = ""
        var output = ""
        
        initializationScript()
        
        makeScript(tests)
            .forEach { inputLine in
                switch inputLine {
                case .testDescription(let s): description = s
                case .input(let input):
                    output = rep(input)
                    if deferrable { print("DEFERRABLE:", terminator: "") }
                    else if optional { print("OPTIONAL:", terminator: "") }
                    print("\(input) -> \(output)")
                case .expectedOutput(let expected): XCTAssertEqual(output, expected, description)
                case .expectedRegex(let regex): XCTAssertNotNil(output.range(of: regex, options: .regularExpression), description)
                case .setDeferrable(let d): deferrable = d
                case .setOptional(let o): optional = o
                }
            }
    }

    func testStep0_REPL() {
        """
        ;; Testing basic string
        abcABC123
        ;=>abcABC123

        ;; Testing string containing spaces
        hello mal world
        ;=>hello mal world

        ;; Testing string containing symbols
        []{}"'* ;:()
        ;=>[]{}"'* ;:()


        ;; Test long string
        hello world abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 (;:() []{}"'* ;:() []{}"'* ;:() []{}"'*)
        ;=>hello world abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 (;:() []{}"'* ;:() []{}"'* ;:() []{}"'*)
        """
            |> runMALScript
    }
    
    func testStep1_Read_Print() {
        """
        ;; Testing read of numbers
        1
        ;=>1
        7
        ;=>7
        7
        ;=>7
        -123
        ;=>-123


        ;; Testing read of symbols
        +
        ;=>+
        abc
        ;=>abc
        abc
        ;=>abc
        abc5
        ;=>abc5
        abc-def
        ;=>abc-def

        ;; Testing non-numbers starting with a dash.
        -
        ;=>-
        -abc
        ;=>-abc
        ->>
        ;=>->>

        ;; Testing read of lists
        (+ 1 2)
        ;=>(+ 1 2)
        ()
        ;=>()
        ( )
        ;=>()
        (nil)
        ;=>(nil)
        ((3 4))
        ;=>((3 4))
        (+ 1 (+ 2 3))
        ;=>(+ 1 (+ 2 3))
        ( +   1   (+   2 3   )   )
        ;=>(+ 1 (+ 2 3))
        (* 1 2)
        ;=>(* 1 2)
        (** 1 2)
        ;=>(** 1 2)
        (* -3 6)
        ;=>(* -3 6)

        ;; Test commas as whitespace
        (1 2, 3,,,,),,
        ;=>(1 2 3)


        ;>>> deferrable=True

        ;;x
        ;; -------- Deferrable Functionality --------

        ;; Testing read of nil/true/false
        nil
        ;=>nil
        true
        ;=>true
        false
        ;=>false

        ;; Testing read of strings
        "abc"
        ;=>"abc"
        "abc"
        ;=>"abc"
        "abc (with parens)"
        ;=>"abc (with parens)"
        "abc\"def"
        ;=>"abc\"def"
        ;;;"abc\ndef"
        ;;;;=>"abc\ndef"
        ""
        ;=>""

        ;; Testing reader errors
        (1 2
        ;/.*(EOF|end of input|unbalanced).*
        [1 2
        ;/.*(EOF|end of input|unbalanced).*

        ;;; These should throw some error with no return value
        "abc
        ;/.*(EOF|end of input|unbalanced).*
        (1 "abc
        ;/.*(EOF|end of input|unbalanced).*
        (1 "abc"
        ;/.*(EOF|end of input|unbalanced).*

        ;; Testing read of quoting
        '1
        ;=>(quote 1)
        '(1 2 3)
        ;=>(quote (1 2 3))
        `1
        ;=>(quasiquote 1)
        `(1 2 3)
        ;=>(quasiquote (1 2 3))
        ~1
        ;=>(unquote 1)
        ~(1 2 3)
        ;=>(unquote (1 2 3))
        `(1 ~a 3)
        ;=>(quasiquote (1 (unquote a) 3))
        ~@(1 2 3)
        ;=>(splice-unquote (1 2 3))


        ;>>> optional=True
        ;;
        ;; -------- Optional Functionality --------

        ;; Testing keywords
        :kw
        ;=>:kw
        (:kw1 :kw2 :kw3)
        ;=>(:kw1 :kw2 :kw3)

        ;; Testing read of vectors
        [+ 1 2]
        ;=>[+ 1 2]
        []
        ;=>[]
        [ ]
        ;=>[]
        [[3 4]]
        ;=>[[3 4]]
        [+ 1 [+ 2 3]]
        ;=>[+ 1 [+ 2 3]]
        [ +   1   [+   2 3   ]   ]
        ;=>[+ 1 [+ 2 3]]

        ;; Testing read of hash maps
        {}
        ;=>{}
        { }
        ;=>{}
        {"abc" 1}
        ;=>{"abc" 1}
        {"a" {"b" 2}}
        ;=>{"a" {"b" 2}}
        {"a" {"b" {"c" 3}}}
        ;=>{"a" {"b" {"c" 3}}}
        {  "a"  {"b"   {  "cde"     3   }  }}
        ;=>{"a" {"b" {"cde" 3}}}
        {  :a  {:b   {  :cde     3   }  }}
        ;=>{:a {:b {:cde 3}}}

        ;; Testing read of comments
        ;; whole line comment (not an exception)
        1 ; comment after expression
        ;=>1
        1; comment after expression
        ;=>1

        ;; Testing read of ^/metadata
        ^{"a" 1} [1 2 3]
        ;=>(with-meta [1 2 3] {"a" 1})


        ;; Testing read of @/deref
        @a
        ;=>(deref a)
        """
            |> runMALScript
    }
    
    func testStep2_Eval() {
        """
        ;; Testing evaluation of arithmetic operations
        (+ 1 2)
        ;=>3

        (+ 5 (* 2 3))
        ;=>11

        (- (+ 5 (* 2 3)) 3)
        ;=>8

        (/ (- (+ 5 (* 2 3)) 3) 4)
        ;=>2

        (/ (- (+ 515 (* 87 311)) 302) 27)
        ;=>1010

        (* -3 6)
        ;=>-18

        (/ (- (+ 515 (* -87 311)) 296) 27)
        ;=>-994

        ;;; This should throw an error with no return value
        (abc 1 2 3)
        ;/.+

        ;; Testing empty list
        ()
        ;=>()

        ;>>> deferrable=True
        ;>>> optional=True
        ;;
        ;; -------- Deferrable/Optional Functionality --------

        ;; Testing evaluation within collection literals
        [1 2 (+ 1 2)]
        ;=>[1 2 3]

        {"a" (+ 7 8)}
        ;=>{"a" 15}

        {:a (+ 7 8)}
        ;=>{:a 15}
        """
            |> runMALScript
    }
    
    func testStep3_env() {
        """
        ;; Testing REPL_ENV
        (+ 1 2)
        ;=>3
        (/ (- (+ 5 (* 2 3)) 3) 4)
        ;=>2


        ;; Testing def!
        (def! x 3)
        ;=>3
        x
        ;=>3
        (def! x 4)
        ;=>4
        x
        ;=>4
        (def! y (+ 1 7))
        ;=>8
        y
        ;=>8

        ;; Verifying symbols are case-sensitive
        (def! mynum 111)
        ;=>111
        (def! MYNUM 222)
        ;=>222
        mynum
        ;=>111
        MYNUM
        ;=>222

        ;; Check env lookup non-fatal error
        (abc 1 2 3)
        ;/.*\'?abc\'? not found.*
        ;; Check that error aborts def!
        (def! w 123)
        (def! w (abc))
        w
        ;=>123

        ;; Testing let*
        (let* (z 9) z)
        ;=>9
        (let* (x 9) x)
        ;=>9
        x
        ;=>4
        (let* (z (+ 2 3)) (+ 1 z))
        ;=>6
        (let* (p (+ 2 3) q (+ 2 p)) (+ p q))
        ;=>12
        (def! y (let* (z 7) z))
        y
        ;=>7

        ;; Testing outer environment
        (def! a 4)
        ;=>4
        (let* (q 9) q)
        ;=>9
        (let* (q 9) a)
        ;=>4
        (let* (z 2) (let* (q 9) a))
        ;=>4

        ;>>> deferrable=True
        ;>>> optional=True
        ;;
        ;; -------- Deferrable/Optional Functionality --------

        ;; Testing let* with vector bindings
        (let* [z 9] z)
        ;=>9
        (let* [p (+ 2 3) q (+ 2 p)] (+ p q))
        ;=>12

        ;; Testing vector evaluation
        (let* (a 5 b 6) [3 4 a [b 7] 8])
        ;=>[3 4 5 [6 7] 8]
        """
            |> runMALScript
    }
    
    func testStep4_if_fn_do() {
        #"""
        ;; -----------------------------------------------------


        ;; Testing list functions
        (list)
        ;=>()
        (list? (list))
        ;=>true
        (empty? (list))
        ;=>true
        (empty? (list 1))
        ;=>false
        (list 1 2 3)
        ;=>(1 2 3)
        (count (list 1 2 3))
        ;=>3
        (count (list))
        ;=>0
        (count nil)
        ;=>0
        (if (> (count (list 1 2 3)) 3) 89 78)
        ;=>78
        (if (>= (count (list 1 2 3)) 3) 89 78)
        ;=>89


        ;; Testing if form
        (if true 7 8)
        ;=>7
        (if false 7 8)
        ;=>8
        (if false 7 false)
        ;=>false
        (if true (+ 1 7) (+ 1 8))
        ;=>8
        (if false (+ 1 7) (+ 1 8))
        ;=>9
        (if nil 7 8)
        ;=>8
        (if 0 7 8)
        ;=>7
        (if (list) 7 8)
        ;=>7
        (if (list 1 2 3) 7 8)
        ;=>7
        (= (list) nil)
        ;=>false


        ;; Testing 1-way if form
        (if false (+ 1 7))
        ;=>nil
        (if nil 8 7)
        ;=>7
        (if true (+ 1 7))
        ;=>8


        ;; Testing basic conditionals
        (= 2 1)
        ;=>false
        (= 1 1)
        ;=>true
        (= 1 2)
        ;=>false
        (= 1 (+ 1 1))
        ;=>false
        (= 2 (+ 1 1))
        ;=>true
        (= nil 1)
        ;=>false
        (= nil nil)
        ;=>true

        (> 2 1)
        ;=>true
        (> 1 1)
        ;=>false
        (> 1 2)
        ;=>false

        (>= 2 1)
        ;=>true
        (>= 1 1)
        ;=>true
        (>= 1 2)
        ;=>false

        (< 2 1)
        ;=>false
        (< 1 1)
        ;=>false
        (< 1 2)
        ;=>true

        (<= 2 1)
        ;=>false
        (<= 1 1)
        ;=>true
        (<= 1 2)
        ;=>true


        ;; Testing equality
        (= 1 1)
        ;=>true
        (= 0 0)
        ;=>true
        (= 1 0)
        ;=>false
        (= true true)
        ;=>true
        (= false false)
        ;=>true
        (= nil nil)
        ;=>true

        (= (list) (list))
        ;=>true
        (= (list 1 2) (list 1 2))
        ;=>true
        (= (list 1) (list))
        ;=>false
        (= (list) (list 1))
        ;=>false
        (= 0 (list))
        ;=>false
        (= (list) 0)
        ;=>false


        ;; Testing builtin and user defined functions
        (+ 1 2)
        ;=>3
        ( (fn* (a b) (+ b a)) 3 4)
        ;=>7
        ( (fn* () 4) )
        ;=>4

        ( (fn* (f x) (f x)) (fn* (a) (+ 1 a)) 7)
        ;=>8


        ;; Testing closures
        ( ( (fn* (a) (fn* (b) (+ a b))) 5) 7)
        ;=>12

        (def! gen-plus5 (fn* () (fn* (b) (+ 5 b))))
        (def! plus5 (gen-plus5))
        (plus5 7)
        ;=>12

        (def! gen-plusX (fn* (x) (fn* (b) (+ x b))))
        (def! plus7 (gen-plusX 7))
        (plus7 8)
        ;=>15

        ;; Testing do form
        (do (prn 101))
        ;/101
        ;=>nil
        (do (prn 102) 7)
        ;/102
        ;=>7
        (do (prn 101) (prn 102) (+ 1 2))
        ;/101
        ;/102
        ;=>3

        (do (def! a 6) 7 (+ a 8))
        ;=>14
        a
        ;=>6

        ;; Testing special form case-sensitivity
        (def! DO (fn* (a) 7))
        (DO 3)
        ;=>7

        ;; Testing recursive sumdown function
        (def! sumdown (fn* (N) (if (> N 0) (+ N (sumdown  (- N 1))) 0)))
        (sumdown 1)
        ;=>1
        (sumdown 2)
        ;=>3
        (sumdown 6)
        ;=>21


        ;; Testing recursive fibonacci function
        (def! fib (fn* (N) (if (= N 0) 1 (if (= N 1) 1 (+ (fib (- N 1)) (fib (- N 2)))))))
        (fib 1)
        ;=>1
        (fib 2)
        ;=>2
        (fib 4)
        ;=>5
        ;;; Too slow for bash, erlang, make and miniMAL
        ;;;(fib 10)
        ;;;;=>89


        ;; Testing recursive function in environment.
        (let* (cst (fn* (n) (if (= n 0) nil (cst (- n 1))))) (cst 1))
        ;=>nil
        (let* (f (fn* (n) (if (= n 0) 0 (g (- n 1)))) g (fn* (n) (f n))) (f 2))
        ;=>0


        ;>>> deferrable=True
        ;;
        ;; -------- Deferrable Functionality --------

        ;; Testing if on strings

        (if "" 7 8)
        ;=>7

        ;; Testing string equality

        (= "" "")
        ;=>true
        (= "abc" "abc")
        ;=>true
        (= "abc" "")
        ;=>false
        (= "" "abc")
        ;=>false
        (= "abc" "def")
        ;=>false
        (= "abc" "ABC")
        ;=>false
        (= (list) "")
        ;=>false
        (= "" (list))
        ;=>false

        ;; Testing variable length arguments

        ( (fn* (& more) (count more)) 1 2 3)
        ;=>3
        ( (fn* (& more) (list? more)) 1 2 3)
        ;=>true
        ( (fn* (& more) (count more)) 1)
        ;=>1
        ( (fn* (& more) (count more)) )
        ;=>0
        ( (fn* (& more) (list? more)) )
        ;=>true
        ( (fn* (a & more) (count more)) 1 2 3)
        ;=>2
        ( (fn* (a & more) (count more)) 1)
        ;=>0
        ( (fn* (a & more) (list? more)) 1)
        ;=>true


        ;; Testing language defined not function
        (not false)
        ;=>true
        (not nil)
        ;=>true
        (not true)
        ;=>false
        (not "a")
        ;=>false
        (not 0)
        ;=>false


        ;; -----------------------------------------------------

        ;; Testing string quoting

        ""
        ;=>""

        "abc"
        ;=>"abc"

        "abc  def"
        ;=>"abc  def"

        "\""
        ;=>"\""

        "abc\ndef\nghi"
        ;=>"abc\ndef\nghi"

        "abc\\def\\ghi"
        ;=>"abc\\def\\ghi"

        "\\n"
        ;=>"\\n"

        ;; Testing pr-str

        (pr-str)
        ;=>""

        (pr-str "")
        ;=>"\"\""

        (pr-str "abc")
        ;=>"\"abc\""

        (pr-str "abc  def" "ghi jkl")
        ;=>"\"abc  def\" \"ghi jkl\""

        (pr-str "\"")
        ;=>"\"\\\"\""

        (pr-str (list 1 2 "abc" "\"") "def")
        ;=>"(1 2 \"abc\" \"\\\"\") \"def\""

        (pr-str "abc\ndef\nghi")
        ;=>"\"abc\\ndef\\nghi\""

        (pr-str "abc\\def\\ghi")
        ;=>"\"abc\\\\def\\\\ghi\""

        (pr-str (list))
        ;=>"()"

        ;; Testing str

        (str)
        ;=>""

        (str "")
        ;=>""

        (str "abc")
        ;=>"abc"

        (str "\"")
        ;=>"\""

        (str 1 "abc" 3)
        ;=>"1abc3"

        (str "abc  def" "ghi jkl")
        ;=>"abc  defghi jkl"

        (str "abc\ndef\nghi")
        ;=>"abc\ndef\nghi"

        (str "abc\\def\\ghi")
        ;=>"abc\\def\\ghi"

        (str (list 1 2 "abc" "\"") "def")
        ;=>"(1 2 abc \")def"

        (str (list))
        ;=>"()"

        ;; Testing prn
        (prn)
        ;/
        ;=>nil

        (prn "")
        ;/""
        ;=>nil

        (prn "abc")
        ;/"abc"
        ;=>nil

        (prn "abc  def" "ghi jkl")
        ;/"abc  def" "ghi jkl"

        (prn "\"")
        ;/"\\""
        ;=>nil

        (prn "abc\ndef\nghi")
        ;/"abc\\ndef\\nghi"
        ;=>nil

        (prn "abc\\def\\ghi")
        ;/"abc\\\\def\\\\ghi"
        nil

        (prn (list 1 2 "abc" "\"") "def")
        ;/\(1 2 "abc" "\\""\) "def"
        ;=>nil


        ;; Testing println
        (println)
        ;/
        ;=>nil

        (println "")
        ;/
        ;=>nil

        (println "abc")
        ;/abc
        ;=>nil

        (println "abc  def" "ghi jkl")
        ;/abc  def ghi jkl

        (println "\"")
        ;/"
        ;=>nil

        (println "abc\ndef\nghi")
        ;/abc
        ;/def
        ;/ghi
        ;=>nil

        (println "abc\\def\\ghi")
        ;/abc\\def\\ghi
        ;=>nil

        (println (list 1 2 "abc" "\"") "def")
        ;/\(1 2 abc "\) def
        ;=>nil

        ;>>> optional=True
        ;;
        ;; -------- Optional Functionality --------

        ;; Testing keywords
        (= :abc :abc)
        ;=>true
        (= :abc :def)
        ;=>false
        (= :abc ":abc")
        ;=>false

        ;; Testing vector truthiness
        (if [] 7 8)
        ;=>7

        ;; Testing vector printing
        (pr-str [1 2 "abc" "\""] "def")
        ;=>"[1 2 \"abc\" \"\\\"\"] \"def\""

        (pr-str [])
        ;=>"[]"

        (str [1 2 "abc" "\""] "def")
        ;=>"[1 2 abc \"]def"

        (str [])
        ;=>"[]"


        ;; Testing vector functions
        (count [1 2 3])
        ;=>3
        (empty? [1 2 3])
        ;=>false
        (empty? [])
        ;=>true
        (list? [4 5 6])
        ;=>false

        ;; Testing vector equality
        (= [] (list))
        ;=>true
        (= [7 8] [7 8])
        ;=>true
        (= (list 1 2) [1 2])
        ;=>true
        (= (list 1) [])
        ;=>false
        (= [] [1])
        ;=>false
        (= 0 [])
        ;=>false
        (= [] 0)
        ;=>false
        (= [] "")
        ;=>false
        (= "" [])
        ;=>false

        ;; Testing vector parameter lists
        ( (fn* [] 4) )
        ;=>4
        ( (fn* [f x] (f x)) (fn* [a] (+ 1 a)) 7)
        ;=>8

        ;; Nested vector/list equality
        (= [(list)] (list []))
        ;=>true
        (= [1 2 (list 3 4 [5 6])] (list 1 2 [3 4 (list 5 6)]))
        ;=>true
        """#
            |> runMALScript
    }
    
    func testStep5_TCO() {
        """
        ;; Testing recursive tail-call function

        (def! sum2 (fn* (n acc) (if (= n 0) acc (sum2 (- n 1) (+ n acc)))))

        ;; TODO: test let*, and do for TCO

        (sum2 10 0)
        ;=>55

        (def! res2 nil)
        ;=>nil
        (def! res2 (sum2 10000 0))
        res2
        ;=>50005000


        ;; Test mutually recursive tail-call functions

        (def! foo (fn* (n) (if (= n 0) 0 (bar (- n 1)))))
        (def! bar (fn* (n) (if (= n 0) 0 (foo (- n 1)))))

        (foo 10000)
        ;=>0
        """
            |> runMALScript
    }
    
    func testStep6_file() {
        """
        ;;; TODO: really a step5 test
        ;;
        ;; Testing that (do (do)) not broken by TCO
        (do (do 1 2))
        ;=>2

        ;;
        ;; Testing read-string, eval and slurp
        (read-string "(1 2 (3 4) nil)")
        ;=>(1 2 (3 4) nil)

        (read-string "(+ 2 3)")
        ;=>(+ 2 3)

        (read-string "7 ;; comment")
        ;=>7

        ;;; Differing output, but make sure no fatal error
        (read-string ";; comment")


        (eval (read-string "(+ 2 3)"))
        ;=>5

        (slurp "/Users/ryan/projects/mal/tests/test.txt")
        ;=>"A line of text"

        ;; Testing load-file

        (load-file "/Users/ryan/projects/mal/tests/inc.mal")
        (inc1 7)
        ;=>8
        (inc2 7)
        ;=>9
        (inc3 9)
        ;=>12

        ;;
        ;; Testing atoms

        (def! inc3 (fn* (a) (+ 3 a)))

        (def! a (atom 2))
        ;=>(atom 2)

        (atom? a)
        ;=>true

        (atom? 1)
        ;=>false

        (deref a)
        ;=>2

        (reset! a 3)
        ;=>3

        (deref a)
        ;=>3

        (swap! a inc3)
        ;=>6

        (deref a)
        ;=>6

        (swap! a (fn* (a) a))
        ;=>6

        (swap! a (fn* (a) (* 2 a)))
        ;=>12

        (swap! a (fn* (a b) (* a b)) 10)
        ;=>120

        (swap! a + 3)
        ;=>123

        ;; Testing swap!/closure interaction
        (def! inc-it (fn* (a) (+ 1 a)))
        (def! atm (atom 7))
        (def! f (fn* () (swap! atm inc-it)))
        (f)
        ;=>8
        (f)
        ;=>9

        ;>>> deferrable=True
        ;;
        ;; -------- Deferrable Functionality --------

        ;; Testing reading of large files
        (load-file "/Users/ryan/projects/mal/tests/computations.mal")
        ;=>nil
        (sumdown 2)
        ;=>3
        (fib 2)
        ;=>1

        ;>>> optional=True
        ;;
        ;; -------- Optional Functionality --------

        ;; Testing comments in a file
        (load-file "/Users/ryan/projects/mal/tests/incB.mal")
        ;/"incB.mal finished"
        ;=>"incB.mal return string"
        (inc4 7)
        ;=>11
        (inc5 7)
        ;=>12

        ;; Testing map literal across multiple lines in a file
        (load-file "/Users/ryan/projects/mal/tests/incC.mal")
        mymap
        ;=>{"a" 1}

        ;; Testing `@` reader macro (short for `deref`)
        (def! atm (atom 9))
        @atm
        ;=>9

        ;;; TODO: really a step5 test
        ;; Testing that vector params not broken by TCO
        (def! g (fn* [] 78))
        (g)
        ;=>78
        (def! g (fn* [a] (+ a 78)))
        (g 3)
        ;=>81

        ;; Checking that eval does not use local environments.
        (def! a 1)
        ;=>1
        (let* (a 2) (eval (read-string "a")))
        ;=>1

        ;;
        ;; Testing that *ARGV* exists and is an empty list
        (list? *ARGV*)
        ;=>true
        *ARGV*
        ;=>()
        """
            |> runMALScript
    }
    
    func test_step7_quote() {
        """
        ;; Testing cons function
        (cons 1 (list))
        ;=>(1)
        (cons 1 (list 2))
        ;=>(1 2)
        (cons 1 (list 2 3))
        ;=>(1 2 3)
        (cons (list 1) (list 2 3))
        ;=>((1) 2 3)

        (def! a (list 2 3))
        (cons 1 a)
        ;=>(1 2 3)
        a
        ;=>(2 3)

        ;; Testing concat function
        (concat)
        ;=>()
        (concat (list 1 2))
        ;=>(1 2)
        (concat (list 1 2) (list 3 4))
        ;=>(1 2 3 4)
        (concat (list 1 2) (list 3 4) (list 5 6))
        ;=>(1 2 3 4 5 6)
        (concat (concat))
        ;=>()
        (concat (list) (list))
        ;=>()

        (def! a (list 1 2))
        (def! b (list 3 4))
        (concat a b (list 5 6))
        ;=>(1 2 3 4 5 6)
        a
        ;=>(1 2)
        b
        ;=>(3 4)

        ;; Testing regular quote
        (quote 7)
        ;=>7
        (quote (1 2 3))
        ;=>(1 2 3)
        (quote (1 2 (3 4)))
        ;=>(1 2 (3 4))

        ;; Testing simple quasiquote
        (quasiquote 7)
        ;=>7
        (quasiquote (1 2 3))
        ;=>(1 2 3)
        (quasiquote (1 2 (3 4)))
        ;=>(1 2 (3 4))
        (quasiquote (nil))
        ;=>(nil)

        ;; Testing unquote
        (quasiquote (unquote 7))
        ;=>7
        (def! a 8)
        ;=>8
        (quasiquote a)
        ;=>a
        (quasiquote (unquote a))
        ;=>8
        (quasiquote (1 a 3))
        ;=>(1 a 3)
        (quasiquote (1 (unquote a) 3))
        ;=>(1 8 3)
        (def! b (quote (1 "b" "d")))
        ;=>(1 "b" "d")
        (quasiquote (1 b 3))
        ;=>(1 b 3)
        (quasiquote (1 (unquote b) 3))
        ;=>(1 (1 "b" "d") 3)
        (quasiquote ((unquote 1) (unquote 2)))
        ;=>(1 2)

        ;; Testing splice-unquote
        (def! c (quote (1 "b" "d")))
        ;=>(1 "b" "d")
        (quasiquote (1 c 3))
        ;=>(1 c 3)
        (quasiquote (1 (splice-unquote c) 3))
        ;=>(1 1 "b" "d" 3)


        ;; Testing symbol equality
        (= (quote abc) (quote abc))
        ;=>true
        (= (quote abc) (quote abcd))
        ;=>false
        (= (quote abc) "abc")
        ;=>false
        (= "abc" (quote abc))
        ;=>false
        (= "abc" (str (quote abc)))
        ;=>true
        (= (quote abc) nil)
        ;=>false
        (= nil (quote abc))
        ;=>false

        ;;;;; Test quine
        ;;; TODO: needs expect line length fix
        ;;;((fn* [q] (quasiquote ((unquote q) (quote (unquote q))))) (quote (fn* [q] (quasiquote ((unquote q) (quote (unquote q)))))))
        ;;;=>((fn* [q] (quasiquote ((unquote q) (quote (unquote q))))) (quote (fn* [q] (quasiquote ((unquote q) (quote (unquote q)))))))

        ;>>> deferrable=True
        ;;
        ;; -------- Deferrable Functionality --------

        ;; Testing ' (quote) reader macro
        '7
        ;=>7
        '(1 2 3)
        ;=>(1 2 3)
        '(1 2 (3 4))
        ;=>(1 2 (3 4))

        ;; Testing ` (quasiquote) reader macro
        `7
        ;=>7
        `(1 2 3)
        ;=>(1 2 3)
        `(1 2 (3 4))
        ;=>(1 2 (3 4))
        `(nil)
        ;=>(nil)

        ;; Testing ~ (unquote) reader macro
        `~7
        ;=>7
        (def! a 8)
        ;=>8
        `(1 ~a 3)
        ;=>(1 8 3)
        (def! b '(1 "b" "d"))
        ;=>(1 "b" "d")
        `(1 b 3)
        ;=>(1 b 3)
        `(1 ~b 3)
        ;=>(1 (1 "b" "d") 3)

        ;; Testing ~@ (splice-unquote) reader macro
        (def! c '(1 "b" "d"))
        ;=>(1 "b" "d")
        `(1 c 3)
        ;=>(1 c 3)
        `(1 ~@c 3)
        ;=>(1 1 "b" "d" 3)


        ;>>> optional=True
        ;;
        ;; -------- Optional Functionality --------

        ;; Testing cons and concat with vectors

        (cons [1] [2 3])
        ;=>([1] 2 3)
        (cons 1 [2 3])
        ;=>(1 2 3)
        (concat [1 2] (list 3 4) [5 6])
        ;=>(1 2 3 4 5 6)
        (concat [1 2])
        ;=>(1 2)

        ;; Testing unquote with vectors
        (def! a 8)
        ;=>8
        `[1 a 3]
        ;=>(1 a 3)
        ;;; TODO: fix this
        ;;;;=>[1 a 3]

        ;; Testing splice-unquote with vectors
        (def! c '(1 "b" "d"))
        ;=>(1 "b" "d")
        `[1 ~@c 3]
        ;=>(1 1 "b" "d" 3)
        ;;; TODO: fix this
        ;;;;=>[1 1 "b" "d" 3]
        """
            |> runMALScript
    }
}
