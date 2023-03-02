import Foundation
import PackageModel
import TSCBasic

struct XcodeBuilder {
    let project: XcodeProject
    let config: Config

    private let fileManager: FileManager

    var buildDirectory: URL {
        config
            .projectBuildDirectory
            .appendingPathComponent("build")
            .absoluteURL
    }

    init(
        project: XcodeProject,
        config: Config,
        fileManager: FileManager = .default
    ) {
        self.project = project
        self.config = config
        self.fileManager = fileManager
    }

    func clean() throws {
        let arguments = [
            "xcrun",
            "xcodebuild",
            "-project", project.path.pathString,
            "BUILD_DIR=\(buildDirectory.path)",
            "clean"
        ]
        let process = TSCBasic.Process(arguments: arguments)
        try process.launch()
        let result = try process.waitUntilExit()

        logger.log("Cleaning...")

        switch result.exitStatus {
        case let .terminated(code) where code != 0:
            throw CommandError.nonZeroExit(code, arguments, try result.utf8stderrOutput())
        case let .signalled(signal):
            throw CommandError.signalExit(signal, arguments)
        default:
            break
        }
    }

    func build(target: String, sdk: Platform.SDK) throws -> Framework {
        let arguments = try createArchiveCommand(target: target, sdk: sdk)
        let process = TSCBasic.Process(arguments: arguments)
        try process.launch()
        let result = try process.waitUntilExit()
        try result.utf8Output().log()

        switch result.exitStatus {
        case let .terminated(code) where code != 0:
            throw CommandError.nonZeroExit(code, arguments, try result.utf8stderrOutput())
        case let .signalled(signal: signal):
            throw CommandError.signalExit(signal, arguments)
        default:
            break
        }

        return Framework(
            name: target,
            url: frameworkURL(name: target.normalized, sdk: sdk),
            debugSymbolsURL: debugSymbolsURL(sdk: sdk)
        )
    }

    private func createArchiveCommand(target: String, sdk: Platform.SDK) throws -> [String] {
        var arguments = [
            "xcrun",
            "xcodebuild",
            "-project", project.path.pathString,
            "-configuration", config.options.configuration.xcodeConfigurationName,
            "-archivePath", buildDirectory.appendingPathComponent(target.normalized).appendingPathComponent(sdk.archiveName).path,
            "-destination", sdk.destination,
            "BUILD_DIR=\(buildDirectory.path)",
            "SKIP_INSTALL=NO"
        ]

        if let settings = sdk.buildSettings {
            for setting in settings {
                arguments.append("\(setting.key)=\(setting.value)")
            }
        }

        if config.options.stackEvolution {
            arguments.append("BUILD_LIBRARY_FOR_DISTRIBUTION=YES")
        }

        config.options.xcSetting.forEach { setting in
            arguments.append("\(setting.name)=\(setting.value)")
        }

        arguments += ["-scheme", target]
        arguments += ["archive"]

        return arguments
    }

    private func frameworkURL(name: String, sdk: Platform.SDK) -> URL {
        buildDirectory
            .appendingPathComponent(name)
            .appendingPathComponent(sdk.archiveName)
            .appendingPathComponent("Products/Library/Frameworks")
            .appendingPathComponent("\(name).framework")
            .absoluteURL
    }

    private func debugSymbolsURL(sdk: Platform.SDK) -> URL {
        buildDirectory
            .appendingPathComponent(sdk.releaseFolder)
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
        try result.utf8Output().log()

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

    func createXCFramework(from frameworks: [Framework]) throws -> XCFramework {
        let frameworkNames = frameworks.map(\.name).removeDuplicates()
        assert(frameworkNames.count < 2, "All frameworks are expected to have the same name")

        guard let name = frameworkNames.first else {
            throw Error.missingFrameworks
        }

        let url = URL(fileURLWithPath: config.options.output)
            .appendingPathComponent("\(name.normalized).xcframework")

        try? fileManager.removeItem(at: url)

        let arguments = try createXCFrameworkCommand(outputURL: url, frameworks: frameworks)
        let process = TSCBasic.Process(arguments: arguments)
        try process.launch()
        let result = try process.waitUntilExit()
        try result.utf8Output().log()

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

    private func createXCFrameworkCommand(outputURL: URL, frameworks: [Framework]) throws -> [String] {
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

    enum Error: Swift.Error, Equatable {
        case missingFrameworks
    }
}

struct Framework {
    let name: String
    let url: URL
    let debugSymbolsURL: URL
}

struct XCFramework {
    let name: String
    let url: URL
}

private extension BuildConfiguration {
    var xcodeConfigurationName: String {
        switch self {
        case .debug: return "Debug"
        case .release: return "Release"
        }
    }
}

private extension String {
    var normalized: String {
        // Xcode replaces any non-alphanumeric characters in the target with an underscore
        // https://developer.apple.com/documentation/swift/imported_c_and_objective-c_apis/importing_swift_into_objective-c
        replacingOccurrences(of: "[^0-9a-zA-Z]", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "^[0-9]", with: "_", options: .regularExpression)
    }

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
