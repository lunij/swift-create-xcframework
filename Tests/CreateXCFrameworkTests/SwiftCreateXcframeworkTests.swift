import class Foundation.Bundle
import XCTest

final class SwiftCreateXcframeworkTests: XCTestCase {
    private let fixtureManager = FixtureManager()

    override class func setUp() {
        FixtureManager.setUp()
    }

    func test_minimalManifest() throws {
        let fixture = try fixtureManager.createFixture(named: "MinimalManifest")
        let (output, error) = try runExecutable(at: fixture.directoryURL)
        XCTAssertEqual(
            output,
            "debug: evaluating manifest for 'test_minimalmanifest()' v. unknown \n"
                + "debug: evaluating manifest for 'test_minimalmanifest()' v. unknown \n"
        )
        XCTAssertEqual(error, "")
    }

    func test_manifestWithErrors() throws {
        let fixture = try fixtureManager.createFixture(named: "ManifestWithErrors")
        let (output, error) = try runExecutable(at: fixture.directoryURL)
        XCTAssertEqual(
            output,
            "debug: evaluating manifest for 'test_manifestwitherrors()' v. unknown \n"
                + "error: Source files for target FixtureTarget should be located under 'Sources/FixtureTarget', "
                + "or a custom sources path can be set with the 'path' property in Package.swift\n"
                + "debug: evaluating manifest for 'test_manifestwitherrors()' v. unknown \n"
        )
        XCTAssertEqual(error, "Error: fatalError\n")
    }
}

private func runExecutable(at directoryURL: URL) throws -> (String, String) {
    let process = Process()
    process.currentDirectoryURL = directoryURL
    process.executableURL = URL.productsDirectory.appendingPathComponent("swift-create-xcframework")

    let standardOutput = Pipe()
    process.standardOutput = standardOutput

    let standardError = Pipe()
    process.standardError = standardError

    try process.run()
    process.waitUntilExit()

    let standardOutputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: standardOutputData, encoding: .utf8) ?? ""

    let standardErrorData = standardError.fileHandleForReading.readDataToEndOfFile()
    let error = String(data: standardErrorData, encoding: .utf8) ?? ""

    return (output, error)
}

private extension URL {
    static var productsDirectory: URL {
        #if os(macOS)
        let bundle = Bundle.allBundles.first { $0.bundleURL.pathExtension == "xctest" }
        guard let url = bundle?.bundleURL.deletingLastPathComponent() else {
            fatalError("couldn't find the products directory")
        }
        return url
        #else
        return Bundle.main.bundleURL
        #endif
    }
}
