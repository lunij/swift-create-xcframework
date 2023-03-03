import Basics
import Foundation
import TSCBasic

struct Zipper {
    let package: Package

    init(package: Package) {
        self.package = package
    }

    func zip(target: String, version: String?, file: URL) throws -> URL {
        let suffix = versionSuffix(target: target, default: version) ?? ""
        let zipPath = file.path.replacingOccurrences(of: "\\.xcframework$", with: "\(suffix).zip", options: .regularExpression)
        let zipURL = URL(fileURLWithPath: zipPath)

        let arguments = [
            "ditto",
            "-c",
            "-k",
            "--keepParent",
            file.path,
            zipURL.path
        ]
        let process = TSCBasic.Process(
            arguments: arguments,
            outputRedirection: .none
        )

        logger.info("\nPackaging \(file.path) into \(zipURL.path)\n\n")
        try process.launch()
        let result = try process.waitUntilExit()

        switch result.exitStatus {
        case let .terminated(code) where code != 0:
            throw CommandError.nonZeroExit(code, arguments, try result.utf8stderrOutput())
        case let .signalled(signal):
            throw CommandError.signalExit(signal, arguments)
        default:
            break
        }

        return zipURL
    }

    func checksum(file: URL) throws -> URL {
        let sum = try checksum(forBinaryArtifactAt: AbsolutePath(file.path))
        let checksumFile = file.deletingPathExtension().appendingPathExtension("sha256")
        try Data(sum.utf8).write(to: checksumFile)
        return checksumFile
    }

    private func versionSuffix(target: String, default fallback: String?) -> String? {
        // find the package that contains our target
        guard let packageRef = package.graph.packages.first(where: { $0.targets.contains(where: { $0.name == target }) }) else { return nil }

        guard
            let dependency = package.workspace.state.dependencies[packageRef.identity],
            case let .custom(version, _) = dependency.state
        else {
            return fallback.flatMap { "-" + $0 }
        }

        return "-" + version.description
    }

    func clean(file: URL) throws {
        try FileManager.default.removeItem(at: file)
    }

    private func checksum(forBinaryArtifactAt path: AbsolutePath) throws -> String {
        let fileSystem = localFileSystem
        let checksumAlgorithm = SHA256()
        let archiver = ZipArchiver(fileSystem: fileSystem)

        // Validate the path has a supported extension.
        guard let pathExtension = path.extension, archiver.supportedExtensions.contains(pathExtension) else {
            let supportedExtensionList = archiver.supportedExtensions.joined(separator: ", ")
            throw StringError("unexpected file type; supported extensions are: \(supportedExtensionList)")
        }

        // Ensure that the path with the accepted extension is a file.
        guard fileSystem.isFile(path) else {
            throw StringError("file not found at path: \(path.pathString)")
        }

        let contents = try fileSystem.readFileContents(path)
        return checksumAlgorithm.hash(contents).hexadecimalRepresentation
    }
}
