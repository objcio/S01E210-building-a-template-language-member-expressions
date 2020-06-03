import XCTest
import template_language

final class EvaluationTests: XCTestCase {
    var input: String! = nil
    var parsed: [AnnotatedExpression] {
        do {
            return try input.parseTemplate()
        } catch {
            let p = error as! ParseError
            let lineRange = input.lineRange(for: p.offset..<p.offset)
            print(input[lineRange])
            let dist = input.distance(from: lineRange.lowerBound, to: p.offset)
            print(String(repeating: " ", count: dist) + "^")
            print(p.reason)
            fatalError()
        }
    }
    
    var context: EvaluationContext = EvaluationContext()
    
    override func tearDown() {
        input = nil
        context = EvaluationContext()
    }
    
    var evaluated: TemplateValue {
        do {
            return try context.evaluate(parsed)
        } catch {
            dump(error) // todo
            fatalError()
        }
    }
    

    func testVariable() {
        input = "{ title }"
        context = EvaluationContext(values: ["title": .string("Title")])
        XCTAssertEqual(evaluated, .rawHTML("Title"))
    }
    
    func testForLoop() {
        input = "{ for foo in bar }<p>{ foo }</p>{ end }"
        context = EvaluationContext(values: ["bar": .array([.string("Hello"), .string("World")])])
        XCTAssertEqual(evaluated, .rawHTML("<p>Hello</p><p>World</p>"))
    }

    func testTag () {
        input = "<p><span>{bar}</span>{ title }</p>"
        context = EvaluationContext(values: ["title": .string("Title & Foo"), "bar": .string("&")])
        XCTAssertEqual(evaluated, .rawHTML("<p><span>&amp;</span>Title &amp; Foo</p>"))
    }
    
    func testTagWithAttributes() {
        input = "<div id={name}></div>"
        context = EvaluationContext(values: ["name": .string("foo \" bar")])
        XCTAssertEqual(evaluated, .rawHTML("<div id=\"foo &quot; bar\"></div>"))
    }
    
    func testIf() {
        input = "{ if published }{ title }{ end }"
        context = EvaluationContext(values: [
            "title": .string("Hello"),
            "published": .bool(true)
        ])
        XCTAssertEqual(evaluated, .rawHTML("Hello"))
        context = EvaluationContext(values: [
            "title": .string("World"),
            "published": .bool(false)
        ])
        XCTAssertEqual(evaluated, .rawHTML(""))
    }
    
    func testMember() {
        input = "{ post.title }"
        context = EvaluationContext(values: [
            "post": .dictionary(["title": .string("Hello")])
        ])
        XCTAssertEqual(evaluated, .rawHTML("Hello"))
    }


    func testNonExistentVariable() {
        input = "<p>{ title }</p>"
        XCTAssertThrowsError(try context.evaluate(parsed)) { err in
            let e = err as! EvaluationError
            XCTAssertEqual(e.reason, .variableMissing("title"))
            XCTAssertEqual(e.range, input.range(of: "title"))
        }
    }
    
    func testForLoopWithNonArrayType() {
        input = "{ for foo in bar }{ foo }{ end }"
        context = EvaluationContext(values: ["bar": .string("Hello")])
        XCTAssertThrowsError(try context.evaluate(parsed)) { err in
            let e = err as! EvaluationError
            XCTAssertEqual(e.reason, .expectedArray)
            XCTAssertEqual(e.range, input.range(of: "bar"))
        }
    }

    func testEvaluatingNonStringConvertibleToHTML() {
        input = "<p>{ foo }</p>"
        context = EvaluationContext(values: ["foo": .array([.string("Hello")])])
        XCTAssertThrowsError(try context.evaluate(parsed)) { err in
            let e = err as! EvaluationError
            XCTAssertEqual(e.reason, .expectedHTMLConvertible)
            XCTAssertEqual(e.range, input.range(of: "foo"))
        }
    }
    
    func testSyntax() {
        input = """
        <head><title>{ title }</title></head>
        <body>
        <ul>
        { for post in posts }
        { if post.published }
        <li><a href={post.url}>{ post.title }</a></li>
        { end }
        { end }
        </ul>
        </body>
        """
        context = EvaluationContext(values: [
            "posts": .array([
                .dictionary([
                    "published": .bool(true),
                    "title": .string("Hello"),
                    "url": .string("post1.html")
                ]),
                .dictionary([
                    "published": .bool(false),
                    "title": .string("World"),
                    "url": .string("post2.html")
                ])
            ]),
            "title": .string("Title")
        ])
        XCTAssertEqual(evaluated, .rawHTML("""
        <head><title>Title</title></head>
        <body>
        <ul>
        <li><a href="post1.html">Hello</a></li>
        </ul>
        </body>
        """.split(separator: "\n").joined()))
    }
}
