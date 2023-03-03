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

    func test_manifestWithOneProduct() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithOneProduct")
        try Command.makeTestable("--platforms", "macOS").run()
        XCTAssertEqual(mockLogger.infoCalls, [
            .info("Generating Xcode project"),
            .info("Compiling FixtureTarget for generic/platform=macOS,name=Any Mac"),
            .info("Creating FixtureTarget.xcframework")
        ])
    }

    func test_manifestWithTwoProducts() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithTwoProducts")
        try Command.makeTestable("--platforms", "macOS").run()
        XCTAssertEqual(mockLogger.infoCalls, [
            .info("Generating Xcode project"),
            .info("Compiling FixtureTarget1 for generic/platform=macOS,name=Any Mac"),
            .info("Compiling FixtureTarget2 for generic/platform=macOS,name=Any Mac"),
            .info("Creating FixtureTarget1.xcframework"),
            .info("Creating FixtureTarget2.xcframework")
        ])
    }

    func test_manifestWithResources() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithResources")
        try Command.makeTestable("--platforms", "macOS").run()
        XCTAssertEqual(mockLogger.infoCalls, [
            .info("Generating Xcode project"),
            .info("Compiling FixtureTarget for generic/platform=macOS,name=Any Mac"),
            .info("Creating FixtureTarget.xcframework")
        ])
    }

    func test_listProducts() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithTwoProducts")
        try Command.makeTestable("--list-products").run()
        XCTAssertEqual(mockLogger.infoCalls, [
            .info("Available FixturePackage products:\n    FixtureLibrary1\n    FixtureLibrary2")
        ])
    }

    func test_filterProducts() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithTwoProducts")
        try Command.makeTestable("--platforms", "macOS", "--products", "FixtureLibrary2").run()
        XCTAssertEqual(mockLogger.infoCalls, [
            .info("Generating Xcode project"),
            .info("Compiling FixtureTarget2 for generic/platform=macOS,name=Any Mac"),
            .info("Creating FixtureTarget2.xcframework")
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

        XCTAssertEqual(mockLogger.infoCalls, [])
    }

    func test_manifestWithoutProducts() throws {
        try fixtureManager.setUpFixture(named: "ManifestWithoutProducts")

        let error: Error? = try catchError {
            try Command.makeTestable().run()
        }

        let catchedError = try XCTUnwrap(error)
        XCTAssertEqual("\(catchedError)", "Package validation failed:\nNo library products to create XCFrameworks for were found")

        XCTAssertEqual(mockLogger.infoCalls, [])
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

        XCTAssertEqual(mockLogger.infoCalls, [])
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
