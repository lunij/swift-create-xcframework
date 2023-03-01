import XCTest
@testable import CreateXCFrameworkKit

final class CommandTests: XCTestCase {
    private let fixtureManager = FixtureManager()
    private let mockLogger = LoggerMock()

    override class func setUp() {
        FixtureManager.setUp()
    }

    override func setUp() {
        super.setUp()
        CreateXCFrameworkKit.logger = mockLogger
    }

    func test_minimalManifest() throws {
        try fixtureManager.setUpFixture(named: "MinimalManifest")
        try Command.makeTestable().run()
        XCTAssertEqual(mockLogger.calls, [
            .log("debug: evaluating manifest for 'test_minimalmanifest()' v. unknown "),
            .log("debug: evaluating manifest for 'test_minimalmanifest()' v. unknown ")
        ])
    }

    func test_manifestWithErrors() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithErrors")

        let error: Error? = try catchError {
            try Command.makeTestable().run()
        }

        let catchedError = try XCTUnwrap(error)
        XCTAssertEqual("\(catchedError)", "fatalError")

        XCTAssertEqual(mockLogger.calls, [
            .log("debug: evaluating manifest for 'test_manifestwitherrors()' v. unknown "),
            .log("error: Source files for target FixtureTarget should be located under 'Sources/FixtureTarget', "
                + "or a custom sources path can be set with the 'path' property in Package.swift"),
            .log("debug: evaluating manifest for 'test_manifestwitherrors()' v. unknown ")
        ])
    }
}

private extension Command {
    static func makeTestable(_ arguments: [String] = [], file: StaticString = #filePath, line: UInt = #line) throws -> Command {
        try XCTUnwrap(Self.parseAsRoot(arguments) as? Command, file: file, line: line)
    }
}
