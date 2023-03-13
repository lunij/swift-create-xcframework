import Basics
import PackageGraph
import TSCBasic
import XcodeKit

struct XcodeProjectGenerator {
    private enum Constants {
        static let `extension` = "xcodeproj"
    }

    private let config: Config
    private let packageGraph: PackageGraph
    private let projectPath: AbsolutePath

    init(projectName: String, config: Config, packageGraph: PackageGraph) {
        self.config = config
        self.packageGraph = packageGraph
        projectPath = XcodeKit.XcodeProject.makePath(
            outputDir: AbsolutePath(config.projectBuildDirectory.path),
            projectName: projectName
        )
    }

    /// Generate an Xcode project.
    ///
    /// This is basically a copy of Xcodeproj.generate()
    ///
    func generate() throws -> XcodeProject {
        try writeDistributionXcconfig()

        let path = projectPath
        try makeDirectories(path)

        // Generate the contents of project.xcodeproj (inside the .xcodeproj).
        let project = try pbxproj(
            xcodeprojPath: path,
            graph: packageGraph,
            extraDirs: [],
            extraFiles: [],
            options: XcodeprojOptions(
                xcconfigOverrides: (config.xcconfigOverride?.path).flatMap { AbsolutePath($0) },
                useLegacySchemeGenerator: true
            ),
            fileSystem: localFileSystem,
            observabilityScope: ObservabilitySystem.shared.topScope
        )
        return XcodeProject(path: path, project: project)
    }

    private func writeDistributionXcconfig() throws {
        guard config.hasDistributionBuildXcconfig else {
            return
        }

        try makeDirectories(projectPath)

        let path = AbsolutePath(config.distributionBuildXcconfig.path)
        try path.open { stream in
            if let absolutePath = self.config.xcconfigOverride?.path {
                stream(
                    """
                    #include "\(AbsolutePath(absolutePath).relative(to: AbsolutePath(path.dirname)).pathString)"

                    """
                )
            }

            stream(
                """
                BUILD_LIBRARY_FOR_DISTRIBUTION=YES
                """
            )
        }
    }
}
