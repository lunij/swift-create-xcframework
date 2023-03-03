import Foundation
import PackageModel
import TSCBasic

struct XCFrameworkBuilder {
    let config: Config

    private let fileManager: FileManager

    init(
        config: Config,
        fileManager: FileManager = .default
    ) {
        self.config = config
        self.fileManager = fileManager
    }

    func buildXCFramework(from frameworks: [Framework]) throws -> XCFramework {
        let frameworkNames = frameworks.map(\.name).removeDuplicates()
        assert(frameworkNames.count < 2, "All frameworks are expected to have the same name")

        guard let name = frameworkNames.first else {
            throw Error.missingFrameworks
        }

        let url = URL(fileURLWithPath: config.options.output)
            .appendingPathComponent("\(name.normalized).xcframework")

        try? fileManager.removeItem(at: url)

        let arguments = try xcframeworkCommand(outputURL: url, frameworks: frameworks)
        let process = TSCBasic.Process(arguments: arguments)
        try process.launch()
        let result = try process.waitUntilExit()
        try result.utf8Output().log(level: .verbose)

        switch result.exitStatus {
        case let .terminated(code) where code != 0:
            throw CommandError.nonZeroExit(code, arguments, try result.utf8stderrOutput())
        case let .signalled(signal):
            throw CommandError.signalExit(signal, arguments)
        default:
            break
        }

        return XCFramework(name: name, url: url)
    }

    private func xcframeworkCommand(outputURL: URL, frameworks: [Framework]) throws -> [String] {
        logger.info("Creating \(outputURL.lastPathComponent)")

        var arguments = [
            "xcrun",
            "xcodebuild",
            "-create-xcframework"
        ]

        arguments += try frameworks.flatMap { framework -> [String] in
            var args = ["-framework", framework.url.absoluteURL.path]

            if self.config.options.debugSymbols {
                let symbolFiles = try self.debugSymbolFiles(target: framework.name, path: framework.debugSymbolsURL)
                for file in symbolFiles where fileManager.fileExists(atPath: file.absoluteURL.path) {
                    args += ["-debug-symbols", file.absoluteURL.path]
                }
            }

            return args
        }

        arguments += ["-output", outputURL.path]

        return arguments
    }

    private func dSYMPath(target: String, path: URL) -> URL {
        path
            .appendingPathComponent("\(target.normalized).framework.dSYM")
    }

    private func dwarfPath(target: String, path: URL) -> URL {
        path
            .appendingPathComponent("Contents/Resources/DWARF")
            .appendingPathComponent(target.normalized)
    }

    private func debugSymbolFiles(target: String, path: URL) throws -> [URL] {
        // if there is no dSYM directory there is no point continuing
        let dsym = dSYMPath(target: target, path: path)
        guard fileManager.fileExists(atPath: dsym.absoluteURL.path) else {
            return []
        }

        var files = [
            dsym
        ]

        // if we have a dwarf file we can inspect that to get the slice UUIDs
        let dwarf = dwarfPath(target: target, path: dsym)
        guard fileManager.fileExists(atPath: dwarf.absoluteURL.path) else {
            return files
        }

        // get the UUID of the slices in the DWARF
        let identifiers = try binarySliceIdentifiers(file: dwarf)

        // They should be bcsymbolmap files in the debug dir
        for identifier in identifiers {
            let file = "\(identifier.uuidString.uppercased()).bcsymbolmap"
            files.append(path.appendingPathComponent(file))
        }

        return files
    }

    private func binarySliceIdentifiers(file: URL) throws -> [UUID] {
        let arguments = [
            "xcrun",
            "dwarfdump",
            "--uuid",
            file.absoluteURL.path
        ]
        let process = TSCBasic.Process(arguments: arguments)
        try process.launch()
        let result = try process.waitUntilExit()
        try result.utf8Output().log(level: .verbose)

        switch result.exitStatus {
        case let .terminated(code) where code != 0:
            throw CommandError.nonZeroExit(code, arguments, try result.utf8stderrOutput())
        case let .signalled(signal):
            throw CommandError.signalExit(signal, arguments)
        default:
            break
        }

        switch result.output {
        case let .success(output):
            guard let string = String(bytes: output, encoding: .utf8) else {
                return []
            }
            return try string.sliceIdentifiers()

        case let .failure(error):
            throw CommandError.errorThrown(error, arguments)
        }
    }

    enum Error: Swift.Error, Equatable {
        case missingFrameworks
    }
}

struct XCFramework {
    let name: String
    let url: URL
}

private extension String {
    func sliceIdentifiers() throws -> [UUID] {
        let regex = try NSRegularExpression(pattern: #"^UUID: ([a-zA-Z0-9\-]+)"#, options: .anchorsMatchLines)
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: count))

        guard matches.isEmpty == false else {
            return []
        }

        return matches
            .compactMap { match in
                let nsrange = match.range(at: 1)
                guard let range = Range(nsrange, in: self) else {
                    return nil
                }
                return String(self[range])
            }
            .compactMap(UUID.init(uuidString:))
    }
}
