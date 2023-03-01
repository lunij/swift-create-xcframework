import Foundation
import os

final class FixtureManager {
    private static let fileManager = FileManager.default
    private static let testsDirectoryURL: URL = {
        let url = fileManager.temporaryDirectory.appendingPathComponent("swift-create-xcframework-tests", isDirectory: true)
        os_log("%{PUBLIC}@", "TESTS DIRECTORY \(url)")
        return url
    }()

    static func setUp() {
        try? fileManager.removeItem(at: testsDirectoryURL)
    }

    private var fileManager: FileManager { Self.fileManager }
    private var testDirectoryURL: URL { Self.testsDirectoryURL }

    func setUpFixture(named name: String, testName: String = #function) throws {
        guard let resourceURL = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw FixtureError.notFound(name)
        }
        let testDirectoryURL = try createTestDirectory(named: testName)
        try copyContent(from: resourceURL, into: testDirectoryURL)
        fileManager.changeCurrentDirectoryPath(testDirectoryURL.path)
    }

    private func createTestDirectory(named testName: String) throws -> URL {
        let directoryURL = testDirectoryURL.appendingPathComponent(testName, isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, removeExisting: true)
        return directoryURL
    }

    private func copyContent(from sourceDirectoryURL: URL, into targetDirectoryURL: URL) throws {
        let urls = try fileManager.contentsOfDirectory(at: sourceDirectoryURL)
        for url in urls {
            let path = url.relativePath == "FixturePackage.swift" ? "Package.swift" : url.relativePath
            let targetURL = URL(fileURLWithPath: path, relativeTo: targetDirectoryURL)
            try fileManager.copyItem(at: url, to: targetURL)
        }
    }
}

enum FixtureError: Error {
    case notFound(String)
}

private extension FileManager {
    func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool = true,
        removeExisting: Bool = false
    ) throws {
        if removeExisting, fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
        try createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: nil)
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            .map { $0.makeRelative(to: url) }
    }
}

private extension URL {
    func makeRelative(to url: URL) -> URL {
        let path = absoluteString.replacingOccurrences(of: url.absoluteString, with: "")
        return URL(fileURLWithPath: path, relativeTo: url)
    }
}
