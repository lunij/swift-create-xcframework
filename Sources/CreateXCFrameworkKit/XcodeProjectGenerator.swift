import TSCBasic
import Xcodeproj

struct XcodeProjectGenerator {
    private enum Constants {
        static let `extension` = "xcodeproj"
    }

    let package: PackageInfo

    var projectPath: AbsolutePath {
        let dir = AbsolutePath(package.projectBuildDirectory.path)
        return Xcodeproj.XcodeProject.makePath(outputDir: dir, projectName: package.manifest.displayName)
    }

    init(package: PackageInfo) {
        self.package = package
    }

    /// Writes out the Xcconfig file
    func writeDistributionXcconfig() throws {
        guard package.hasDistributionBuildXcconfig else {
            return
        }

        try makeDirectories(projectPath)

        let path = AbsolutePath(package.distributionBuildXcconfig.path)
        try path.open { stream in
            if let absolutePath = self.package.overridesXcconfig?.path {
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

    /// Generate an Xcode project.
    ///
    /// This is basically a copy of Xcodeproj.generate()
    ///
    func generate() throws -> XcodeProject {
        let path = projectPath
        try makeDirectories(path)

        // Generate the contents of project.xcodeproj (inside the .xcodeproj).
        let project = try pbxproj(
            xcodeprojPath: path,
            graph: package.graph,
            extraDirs: [],
            extraFiles: [],
            options: XcodeprojOptions(
                xcconfigOverrides: (package.overridesXcconfig?.path).flatMap { AbsolutePath($0) },
                useLegacySchemeGenerator: true
            ),
            fileSystem: localFileSystem,
            observabilityScope: package.observabilitySystem.topScope
        )
        return XcodeProject(path: path, project: project)
    }
}
