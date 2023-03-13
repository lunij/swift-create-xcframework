import Basics
import TSCBasic
import XcodeKit

final class CreateXCFrameworksUseCase {
    func createXCFrameworks(from package: Package) throws -> [XCFramework] {
        let xcodeProject = try createXcodeProject(from: package)
        let frameworkBuilder = FrameworkBuilder(config: package.config)
        let xcframeworkBuilder = XCFrameworkBuilder(config: package.config)

        return try package
            .filteredLibraryProducts
            .flatMap(\.targets)
            .map { target in
                try frameworkBuilder.buildFrameworks(from: target, sdks: package.platforms.flatMap(\.sdks), project: xcodeProject)
            }
            .map { frameworks in
                try xcframeworkBuilder.buildXCFramework(from: frameworks)
            }
    }

    private func createXcodeProject(from package: Package) throws -> XcodeProject2 {
        logger.info("Generating Xcode project")

        let generator = XcodeProjectGenerator(
            projectName: package.name,
            projectDirectory: AbsolutePath(package.config.projectBuildDirectory.path),
            packageGraph: package.graph,
            hasDistributionBuildXcconfig: package.config.hasDistributionBuildXcconfig,
            stackEvolution: package.config.options.stackEvolution,
            targets: package.filteredLibraryProducts.flatMap(\.targets),
            observabilityScope: ObservabilitySystem.shared.topScope
        )
        let xcodeProject = try generator.generate()
        try xcodeProject.save()
        return xcodeProject
    }
}
