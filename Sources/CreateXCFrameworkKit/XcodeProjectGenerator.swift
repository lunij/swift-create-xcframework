import Basics
import PackageGraph
import TSCBasic
import XcodeKit

struct XcodeProjectGenerator {
    private let config: Config
    private let packageGraph: PackageGraph
    private let projectName: String

    init(config: Config, packageGraph: PackageGraph, projectName: String) {
        self.config = config
        self.packageGraph = packageGraph
        self.projectName = projectName
    }

    func generate() throws -> XcodeProject {
        let projectPath = XcodeKit.XcodeProject.makePath(
            outputDir: AbsolutePath(config.projectBuildDirectory.path),
            projectName: projectName
        )

        try makeDirectories(projectPath)
        try writeDistributionXcconfig()
        try writeBundleAccessor()

        let extraFile = AbsolutePath(config.resourceAccessorSwiftFile.path)

        let project = try pbxproj(
            xcodeprojPath: projectPath,
            graph: packageGraph,
            extraDirs: [],
            extraFiles: [extraFile],
            options: XcodeprojOptions(
                xcconfigOverrides: (config.xcconfigOverride?.path).flatMap { AbsolutePath($0) },
                addExtraFiles: true
            ),
            fileSystem: localFileSystem,
            observabilityScope: ObservabilitySystem.shared.topScope
        )
        return XcodeProject(path: projectPath, project: project)
    }

    private func writeDistributionXcconfig() throws {
        guard config.hasDistributionBuildXcconfig else {
            return
        }

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

    private func writeBundleAccessor() throws {
        let path = AbsolutePath(config.resourceAccessorSwiftFile.path)
        try path.open { stream in
            stream(
                """
                import Foundation

                extension Bundle {
                    let bundleName = "\(projectName)"

                    let urls = [
                        Bundle.main.resourceURL,
                        Bundle(for: BundleFinder.self).resourceURL,
                        Bundle.main.bundleURL
                    ]

                    for candidate in candidates {
                        let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
                        if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                            return bundle
                        }
                    }

                    fatalError("unable to find bundle named " + bundleName)
                }

                private class BundleFinder {}
                """
            )
        }
    }
}
