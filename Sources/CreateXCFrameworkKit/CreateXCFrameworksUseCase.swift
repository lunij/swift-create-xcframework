import TSCBasic

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

    private func createXcodeProject(from package: Package) throws -> XcodeProject {
        logger.info("Generating Xcode project")

        let generator = XcodeProjectGenerator(
            config: package.config,
            packageGraph: package.graph,
            projectName: package.name
        )
        let xcodeProject = try generator.generate()

        // we've applied the xcconfig to everything, but some dependencies (*cough* swift-nio)
        // have build errors, so we remove it from targets we're not building
        if package.config.options.stackEvolution == false {
            xcodeProject.enableDistribution(
                targets: package.filteredLibraryProducts.flatMap(\.targets),
                xcconfig: AbsolutePath(package.config.distributionBuildXcconfig.path).relative(to: AbsolutePath(package.config.packageDirectory.path))
            )
        }

        try xcodeProject.save()
        return xcodeProject
    }
}
