import Foundation
import PackageModel
import TSCBasic

struct FrameworkBuilder {
    let config: Config

    private let fileManager: FileManager

    var buildDirectory: URL {
        config
            .projectBuildDirectory
            .appendingPathComponent("build")
            .absoluteURL
    }

    init(
        config: Config,
        fileManager: FileManager = .default
    ) {
        self.config = config
        self.fileManager = fileManager
    }

    func buildFrameworks(from target: String, sdks: [Platform.SDK], project: XcodeProject) throws -> [Framework] {
        try sdks.map { sdk in
            try buildFramework(target: target, sdk: sdk, project: project)
        }
    }

    func buildFramework(target: String, sdk: Platform.SDK, project: XcodeProject) throws -> Framework {
        logger.info("Compiling \(target) for \(sdk.destination)")

        let arguments = try archiveCommand(target: target, sdk: sdk, project: project)
        let process = TSCBasic.Process(arguments: arguments)
        try process.launch()
        let result = try process.waitUntilExit()
        try result.utf8Output().log(level: .verbose)

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

    private func archiveCommand(target: String, sdk: Platform.SDK, project: XcodeProject) throws -> [String] {
        var arguments = [
            "xcrun",
            "xcodebuild",
            "archive",
            "-project", project.path.pathString,
            "-scheme", target,
            "-configuration", config.options.configuration.name,
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

        return arguments
    }

    private func frameworkURL(name: String, sdk: Platform.SDK) -> URL {
        buildDirectory.appendingPathComponent("\(name)/\(sdk.archiveName)/Products/Library/Frameworks/\(name).framework")
    }

    private func debugSymbolsURL(sdk: Platform.SDK) -> URL {
        buildDirectory.appendingPathComponent(sdk.releaseFolder)
    }
}

struct Framework {
    let name: String
    let url: URL
    let debugSymbolsURL: URL
}

private extension BuildConfiguration {
    var name: String {
        switch self {
        case .debug: return "Debug"
        case .release: return "Release"
        }
    }
}
