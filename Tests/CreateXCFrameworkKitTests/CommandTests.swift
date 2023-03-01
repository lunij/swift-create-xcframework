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
            .log("debug: evaluating manifest for 'test_minimalmanifest' v. unknown "),
            .log("Cleaning...")
        ])
    }

    func test_listProducts() throws {
        try fixtureManager.setUpFixture(named: "MinimalManifest")
        try Command.makeTestable("--list-products").run()
        XCTAssertEqual(mockLogger.calls, [
            .log("debug: evaluating manifest for 'test_listproducts' v. unknown "),
            .log("Available FixturePackage products:\n    FixtureLibrary")
        ])
    }

    func test_filterProducts() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithTwoProducts")
        try Command.makeTestable("--platforms", "macOS", "--products", "FixtureLibrary2").run()
        XCTAssertEqual(mockLogger.calls, [
            .log("debug: evaluating manifest for 'test_filterproducts' v. unknown ")
        ])
    }

    func test_manifestWithErrors() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithErrors")

        let error: Error? = try catchError {
            try Command.makeTestable().run()
        }

        let catchedError = try XCTUnwrap(error)
        XCTAssertEqual("\(catchedError)", "Source files for target FixtureTarget should be located under 'Sources/FixtureTarget',"
            + " or a custom sources path can be set with the 'path' property in Package.swift")

        XCTAssertEqual(mockLogger.calls, [
            .log("debug: evaluating manifest for 'test_manifestwitherrors' v. unknown ")
        ])
    }

    func test_manifestWithoutProducts() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithoutProducts")

        let error: Error? = try catchError {
            try Command.makeTestable().run()
        }

        let catchedError = try XCTUnwrap(error)
        XCTAssertEqual("\(catchedError)", "Package validation failed:\nNo products to create XCFrameworks for were found")
    }

    func test_manifestWithBinaryTargets() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithBinaryTargets")

        let error: Error? = try catchError {
            try Command.makeTestable().run()
        }

        let catchedError = try XCTUnwrap(error)
        XCTAssertEqual(
            "\(catchedError)",
            """
            Package validation failed:
            Xcode project generation is not supported by Swift Package Manager for packages that contain binary targets.
            Detected binary targets: BinaryTarget
            """
        )
    }
}

private extension Command {
    static func makeTestable(_ arguments: String..., file: StaticString = #filePath, line: UInt = #line) throws -> Command {
        try makeTestable(arguments, file: file, line: line)
    }

    static func makeTestable(_ arguments: [String] = [], file: StaticString = #filePath, line: UInt = #line) throws -> Command {
        try XCTUnwrap(Self.parseAsRoot(arguments) as? Command, file: file, line: line)
    }
}
