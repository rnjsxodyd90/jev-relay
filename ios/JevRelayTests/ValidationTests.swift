import XCTest

final class ValidationTests: XCTestCase {
    func testTurnValidationAndToneContext() throws {
        let request = try InterpretRequest(text: "  Hello  ", context: "A guest speaks to a hotel clerk.", tone: .formal)
        XCTAssertEqual(request.text, "Hello")
        XCTAssertTrue(request.context.contains("formal singular"))
        XCTAssertThrowsError(try InterpretRequest(text: "   ", context: "", tone: .automatic))
        XCTAssertThrowsError(try InterpretRequest(text: String(repeating: "é", count: 2_001), context: "", tone: .automatic))
        XCTAssertThrowsError(try InterpretRequest(text: "Hello", context: String(repeating: "x", count: 2_001), tone: .automatic))
    }

    func testStrictResponseDecoding() throws {
        let valid = responseData(route: "translate", translated: "Hallo", source: "Hello")
        let response = try JSONDecoder().decode(InterpretResponse.self, from: valid)
        XCTAssertEqual(response.decisions.register?.choice, "unspecified")
        XCTAssertEqual(response.route, .translate)

        XCTAssertThrowsError(try JSONDecoder().decode(InterpretResponse.self, from: responseData(route: "clarify", translated: "Invented", source: "Hello")))
        let missingSense = String(data: valid, encoding: .utf8)!.replacingOccurrences(of: ",\"sense\":{\"choice\":\"NONE\",\"confidence\":0.9,\"probabilities\":{\"NONE\":1.0}}", with: "")
        XCTAssertThrowsError(try JSONDecoder().decode(InterpretResponse.self, from: Data(missingSense.utf8)))
        let reviewWithoutDecisions = String(data: valid, encoding: .utf8)!
            .replacingOccurrences(of: "\"decisions\":{\"action\":{\"choice\":\"translate\",\"confidence\":0.9,\"probabilities\":{\"translate\":1.0}},\"memory\":{\"choice\":\"NONE\",\"confidence\":0.9,\"probabilities\":{\"NONE\":1.0}},\"register\":{\"choice\":\"unspecified\",\"confidence\":0.9,\"probabilities\":{\"unspecified\":1.0}},\"sense\":{\"choice\":\"NONE\",\"confidence\":0.9,\"probabilities\":{\"NONE\":1.0}}}", with: "\"decisions\":{}")
            .replacingOccurrences(of: "\"translatedText\":\"Hallo\"", with: "\"translatedText\":\"\"")
            .replacingOccurrences(of: "\"route\":\"translate\"", with: "\"route\":\"review\"")
        XCTAssertEqual(try JSONDecoder().decode(InterpretResponse.self, from: Data(reviewWithoutDecisions.utf8)).route, .review)
        let badDistribution = String(data: valid, encoding: .utf8)!.replacingOccurrences(of: "\"translate\":1.0", with: "\"translate\":0.4")
        XCTAssertThrowsError(try JSONDecoder().decode(InterpretResponse.self, from: Data(badDistribution.utf8)))
    }
}

func responseData(route: String, translated: String, source: String) -> Data {
    Data("""
    {"mode":"live","sourceText":"\(source)","decisions":{"action":{"choice":"translate","confidence":0.9,"probabilities":{"translate":1.0}},"memory":{"choice":"NONE","confidence":0.9,"probabilities":{"NONE":1.0}},"register":{"choice":"unspecified","confidence":0.9,"probabilities":{"unspecified":1.0}},"sense":{"choice":"NONE","confidence":0.9,"probabilities":{"NONE":1.0}}},"model":"jev-1.13.0","timing":{"decisionMs":10,"translationMs":20,"totalMs":31},"usedTranslator":true,"translatedText":"\(translated)","clarification":"","route":"\(route)","reason":"Review before playback.","requestId":"test-id"}
    """.utf8)
}
