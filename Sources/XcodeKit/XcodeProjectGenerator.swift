import Basics
import PackageGraph
import TSCBasic

public struct XcodeProjectGenerator {
    let projectName: String
    let projectDirectory: AbsolutePath
    let packageGraph: PackageGraph
    let hasDistributionBuildXcconfig: Bool
    let xcconfigOverrides: AbsolutePath?
    let observabilityScope: ObservabilityScope
    let stackEvolution: Bool
    let targets: [String]?

    var distributionBuildXcconfig: AbsolutePath {
        projectDirectory.appending(component: "Distribution.xcconfig")
    }

    var resourceAccessorSwiftFile: AbsolutePath {
        projectDirectory.appending(component: "Bundle+Module.swift")
    }

    public init(
        projectName: String,
        projectDirectory: AbsolutePath,
        packageGraph: PackageGraph,
        hasDistributionBuildXcconfig: Bool,
        stackEvolution: Bool,
        xcconfigOverrides: AbsolutePath? = nil,
        targets: [String]?,
        observabilityScope: ObservabilityScope
    ) {
        self.projectName = projectName
        self.projectDirectory = projectDirectory
        self.packageGraph = packageGraph
        self.hasDistributionBuildXcconfig = hasDistributionBuildXcconfig
        self.xcconfigOverrides = xcconfigOverrides
        self.stackEvolution = stackEvolution
        self.targets = targets
        self.observabilityScope = observabilityScope
    }

    public func generate() throws -> XcodeProject2 {
        let projectPath = XcodeKit.XcodeProject.makePath(
            outputDir: projectDirectory,
            projectName: projectName
        )

        try makeDirectories(projectPath)
        try writeDistributionXcconfig()
        try writeBundleAccessor()

        let project = try pbxproj(
            xcodeprojPath: projectPath,
            graph: packageGraph,
            generatedSourceFiles: [resourceAccessorSwiftFile],
            options: XcodeprojOptions(
                xcconfigOverrides: xcconfigOverrides
            ),
            fileSystem: localFileSystem,
            observabilityScope: observabilityScope
        )

        let xcodeProject = XcodeProject2(path: projectPath, project: project)

        // we've applied the xcconfig to everything, but some dependencies (*cough* swift-nio)
        // have build errors, so we remove it from targets we're not building
        if !stackEvolution {
            xcodeProject.enableDistribution(
                targets: targets ?? packageGraph.reachableTargets.map(\.name),
                xcconfig: distributionBuildXcconfig
            )
        }

        return xcodeProject
    }

    private func writeDistributionXcconfig() throws {
        guard hasDistributionBuildXcconfig else {
            return
        }

        try distributionBuildXcconfig.open { stream in
            if let absolutePath = xcconfigOverrides {
                stream(
                    """
                    #include "\(absolutePath.relative(to: AbsolutePath(distributionBuildXcconfig.dirname)).pathString)"

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
        try resourceAccessorSwiftFile.open { stream in
            stream(
                """
                import Foundation

                extension Bundle {
                    static var module: Bundle = {
                        let bundleName = "\(projectName)"

                        let urls = [
                            Bundle.main.resourceURL,
                            Bundle(for: BundleFinder.self).resourceURL,
                            Bundle.main.bundleURL
                        ]

                        for url in urls {
                            let bundleURL = url?.appendingPathComponent(bundleName + ".bundle")
                            if let bundle = bundleURL.flatMap(Bundle.init(url:)) {
                                return bundle
                            }
                        }

                        fatalError("unable to find bundle named " + bundleName)
                    }()
                }

                private class BundleFinder {}
                """
            )
        }
    }
}
