import Testing

@testable import AudioMarker

@Suite("TTML Parse Error")
struct TTMLParseErrorTests {

    // MARK: - Error Descriptions

    @Test("invalidXML has meaningful description")
    func invalidXMLDescription() {
        let error = TTMLParseError.invalidXML("bad encoding")
        #expect(error.errorDescription?.contains("bad encoding") == true)
    }

    @Test("notTTML has meaningful description")
    func notTTMLDescription() {
        let error = TTMLParseError.notTTML
        #expect(error.errorDescription?.contains("<tt>") == true)
    }

    @Test("invalidTimeExpression has meaningful description")
    func invalidTimeDescription() {
        let error = TTMLParseError.invalidTimeExpression("abc")
        #expect(error.errorDescription?.contains("abc") == true)
    }

    @Test("missingAttribute has meaningful description")
    func missingAttributeDescription() {
        let error = TTMLParseError.missingAttribute(element: "p", attribute: "begin")
        #expect(error.errorDescription?.contains("begin") == true)
        #expect(error.errorDescription?.contains("p") == true)
    }

    @Test("missingTiming has meaningful description")
    func missingTimingDescription() {
        let error = TTMLParseError.missingTiming(element: "p")
        #expect(error.errorDescription?.contains("p") == true)
    }

    // MARK: - Equatable

    @Test("Same errors are equal")
    func equatable() {
        #expect(TTMLParseError.notTTML == TTMLParseError.notTTML)
        #expect(TTMLParseError.invalidXML("a") == TTMLParseError.invalidXML("a"))
        #expect(
            TTMLParseError.invalidTimeExpression("1x")
                == TTMLParseError.invalidTimeExpression("1x"))
        #expect(
            TTMLParseError.missingAttribute(element: "p", attribute: "begin")
                == TTMLParseError.missingAttribute(element: "p", attribute: "begin"))
        #expect(
            TTMLParseError.missingTiming(element: "p")
                == TTMLParseError.missingTiming(element: "p"))
    }

    @Test("Different errors are not equal")
    func notEqual() {
        #expect(TTMLParseError.notTTML != TTMLParseError.invalidXML("x"))
        #expect(TTMLParseError.invalidXML("a") != TTMLParseError.invalidXML("b"))
        #expect(
            TTMLParseError.missingAttribute(element: "p", attribute: "begin")
                != TTMLParseError.missingAttribute(element: "div", attribute: "begin"))
    }

    // MARK: - Hashable

    @Test("Same errors produce same hash")
    func hashable() {
        let e1 = TTMLParseError.invalidXML("test")
        let e2 = TTMLParseError.invalidXML("test")
        #expect(e1.hashValue == e2.hashValue)

        let e3 = TTMLParseError.notTTML
        let e4 = TTMLParseError.notTTML
        #expect(e3.hashValue == e4.hashValue)

        let e5 = TTMLParseError.invalidTimeExpression("5x")
        let e6 = TTMLParseError.invalidTimeExpression("5x")
        #expect(e5.hashValue == e6.hashValue)

        let e7 = TTMLParseError.missingAttribute(element: "p", attribute: "begin")
        let e8 = TTMLParseError.missingAttribute(element: "p", attribute: "begin")
        #expect(e7.hashValue == e8.hashValue)

        let e9 = TTMLParseError.missingTiming(element: "span")
        let e10 = TTMLParseError.missingTiming(element: "span")
        #expect(e9.hashValue == e10.hashValue)
    }

    @Test("Errors can be stored in a Set")
    func setStorage() {
        let errors: Set<TTMLParseError> = [
            .invalidXML("a"),
            .notTTML,
            .invalidTimeExpression("1x"),
            .missingAttribute(element: "p", attribute: "begin"),
            .missingTiming(element: "p")
        ]
        #expect(errors.count == 5)
    }
}
