import ArgumentParser
import Build
import Foundation
import PackageLoading
import PackageModel
import SPMBuildCore
import Workspace
import Xcodeproj

#if swift(>=5.6)
import Basics
import PackageGraph
import TSCBasic
#endif

struct PackageInfo {
    let rootDirectory: URL
    let buildDirectory: URL
    let platforms: [TargetPlatform]

    var projectBuildDirectory: URL {
        buildDirectory
            .appendingPathComponent("swift-create-xcframework")
            .absoluteURL
    }

    var hasDistributionBuildXcconfig: Bool {
        overridesXcconfig != nil || options.stackEvolution == false
    }

    var distributionBuildXcconfig: URL {
        projectBuildDirectory
            .appendingPathComponent("Distribution.xcconfig")
            .absoluteURL
    }

    var overridesXcconfig: URL? {
        guard let path = options.xcconfig else { return nil }

        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        } else if path.hasPrefix("./") {
            return rootDirectory.appendingPathComponent(String(path[path.index(path.startIndex, offsetBy: 2)...]))
        }

        return rootDirectory.appendingPathComponent(path)
    }

    #if swift(>=5.6)
    let observabilitySystem = ObservabilitySystem { _, diagnostics in
        logger.log("\(diagnostics.severity): \(diagnostics.message)")
    }
    #else
    let diagnostics = DiagnosticsEngine()
    #endif

    let options: Command.Options
    let graph: PackageGraph
    let manifest: Manifest
    let toolchain: UserToolchain
    let workspace: Workspace

    init(options: Command.Options) throws {
        self.options = options
        rootDirectory = URL(fileURLWithPath: options.packagePath, isDirectory: true).absoluteURL
        buildDirectory = rootDirectory.appendingPathComponent(options.buildPath, isDirectory: true).absoluteURL

        let root = AbsolutePath(rootDirectory.path)

        toolchain = try UserToolchain(destination: try .hostDestination())
        workspace = try Workspace(root: root, toolchain: toolchain)
        graph = try PackageGraph(root: root, workspace: workspace, observabilitySystem: observabilitySystem)
        manifest = try .createManifest(root: root, workspace: workspace, observabilitySystem: observabilitySystem)
        platforms = manifest.filterPlatforms(to: options.platform)

        try validate()
    }

    private func validate() throws {
        var errors: [PackageValidationError] = []

        let binaryTargets = graph.allTargets.filter { $0.type == .binary }
        if binaryTargets.isNotEmpty {
            errors.append(.containsBinaryTargets(binaryTargets.map(\.name)))
        }

        let systemTargets = graph.allTargets.filter { $0.type == .systemModule }
        if systemTargets.isNotEmpty {
            errors.append(.containsSystemModules(systemTargets.map(\.name)))
        }

        let conditionalDependencies = graph.allTargets.filter { $0.dependencies.contains { $0.conditions.isNotEmpty } }
        if conditionalDependencies.isNotEmpty {
            errors.append(.containsConditionalDependencies(conditionalDependencies.map(\.name)))
        }

        let productNames = manifest.libraryProductNames
        if productNames.isEmpty {
            errors.append(.missingProducts)
        }

        if errors.isNotEmpty {
            throw PackageError.validationFailed(errors)
        }
    }

    func validProductNames(project: Xcode.Project) throws -> [String] {
        let productNames: [String]
        if options.products.isNotEmpty {
            productNames = options.products
        } else {
            productNames = manifest.libraryProductNames
        }

        let xcodeTargetNames = project.frameworkTargets.map(\.name)
        let invalidProducts = productNames.filter { xcodeTargetNames.contains($0) == false }
        guard invalidProducts.isEmpty == true else {
            let allLibraryProductNames = manifest.libraryProductNames
            let nonRootPackageTargets = xcodeTargetNames.filter { allLibraryProductNames.contains($0) == false }

            throw ValidationError(
                """
                Invalid product/target name(s):
                    \(invalidProducts.joined(separator: "\n    "))

                Available \(manifest.displayName) products:
                    \(allLibraryProductNames.sorted().joined(separator: "\n    "))

                Additional available targets:
                    \(nonRootPackageTargets.sorted().joined(separator: "\n    "))
                """
            )
        }

        return productNames
    }

    func printAllProducts(project: Xcode.Project) {
        let allLibraryProductNames = manifest.libraryProductNames
        let xcodeTargetNames = project.frameworkTargets.map(\.name)
        let nonRootPackageTargets = xcodeTargetNames.filter { allLibraryProductNames.contains($0) == false }

        logger.log(
            """
            \nAvailable \(manifest.displayName) products:
                \(allLibraryProductNames.sorted().joined(separator: "\n    "))

            Additional available targets:
                \(nonRootPackageTargets.sorted().joined(separator: "\n    "))
            \n
            """
        )
    }

    // MARK: - Helpers

    private var absoluteRootDirectory: AbsolutePath {
        AbsolutePath(rootDirectory.path)
    }
}

enum SupportedPlatforms {
    case noPackagePlatforms(plan: [SupportedPlatform])
    case packagePlatformsUnsupported(plan: [SupportedPlatform])
    case packageValid(plan: [SupportedPlatform])
}

extension SupportedPlatform: Comparable {
    public static func == (lhs: SupportedPlatform, rhs: SupportedPlatform) -> Bool {
        lhs.platform == rhs.platform && lhs.version == rhs.version
    }

    public static func < (lhs: SupportedPlatform, rhs: SupportedPlatform) -> Bool {
        if lhs.platform == rhs.platform {
            return lhs.version < rhs.version
        }

        return lhs.platform.name < rhs.platform.name
    }
}

enum PackageError: Error, CustomStringConvertible {
    case validationFailed([PackageValidationError])

    var description: String {
        switch self {
        case let .validationFailed(errors):
            return """
            Package validation failed:
            \(errors.map(\.description).joined(separator: "\n"))
            """
        }
    }
}

enum PackageValidationError: Error, CustomStringConvertible {
    case containsBinaryTargets([String])
    case containsSystemModules([String])
    case containsConditionalDependencies([String])
    case missingProducts

    var description: String {
        switch self {
        case let .containsBinaryTargets(targets):
            return "Xcode project generation is not supported by Swift Package Manager for packages that contain binary targets.\n"
                + "Detected binary targets: \(targets.joined(separator: ", "))"
        case let .containsSystemModules(targets):
            return "Xcode project generation is not supported by Swift Package Manager for packages that reference system modules.\n"
                + "Referenced system modules: \(targets.joined(separator: ", "))"
        case let .containsConditionalDependencies(targets):
            return "Xcode project generation does not support conditional target dependencies, so the generated project may not build successfully.\n"
                + "Targets with conditional dependencies: \(targets.joined(separator: ", "))"
        case .missingProducts:
            return "No products to create XCFrameworks for were found"
        }
    }
}

#if swift(<5.6)
extension Manifest {
    var displayName: String {
        name
    }
}
#endif

private extension Manifest {
    static func createManifest(root: AbsolutePath, workspace: Workspace, observabilitySystem: ObservabilitySystem) throws -> Manifest {
        #if swift(>=5.6)
        let scope = observabilitySystem.topScope
        return try tsc_await {
            workspace.loadRootManifest(
                at: root,
                observabilityScope: scope,
                completion: $0
            )
        }
        #elseif swift(>=5.5)
        let swiftCompiler = toolchain.swiftCompiler
        return try tsc_await {
            ManifestLoader.loadRootManifest(
                at: root,
                swiftCompiler: swiftCompiler,
                swiftCompilerFlags: [],
                identityResolver: DefaultIdentityResolver(),
                on: DispatchQueue.global(qos: .background),
                completion: $0
            )
        }
        #else
        return try ManifestLoader.loadManifest(
            packagePath: root,
            swiftCompiler: toolchain.swiftCompiler,
            packageKind: .root
        )
        #endif
    }
}

private extension PackageGraph {
    init(root: AbsolutePath, workspace: Workspace, observabilitySystem: ObservabilitySystem) throws {
        #if swift(>=5.6)
        self = try workspace.loadPackageGraph(rootPath: root, observabilityScope: observabilitySystem.topScope)
        #elseif swift(>=5.5)
        self = try workspace.loadPackageGraph(rootPath: root, diagnostics: diagnostics)
        #else
        self = workspace.loadPackageGraph(root: root, diagnostics: diagnostics)
        #endif
    }
}

private extension Workspace {
    convenience init(root: AbsolutePath, toolchain: UserToolchain) throws {
        #if swift(>=5.7)
        let loader = ManifestLoader(toolchain: toolchain)
        try self.init(forRootPackage: root, customManifestLoader: loader)
        #elseif swift(>=5.6)
        let resources = ToolchainConfiguration(swiftCompilerPath: toolchain.swiftCompilerPath)
        let loader = ManifestLoader(toolchain: resources)
        try self.init(forRootPackage: root, customManifestLoader: loader)
        #else
        #if swift(>=5.5)
        let resources = try UserManifestResources(swiftCompiler: toolchain.swiftCompiler, swiftCompilerFlags: [])
        #else
        let resources = try UserManifestResources(swiftCompiler: toolchain.swiftCompiler)
        #endif
        let loader = ManifestLoader(manifestResources: resources)
        self = Workspace.create(forRootPackage: root, manifestLoader: loader)
        #endif
    }
}

private extension ProductType {
    var isLibrary: Bool {
        if case .library = self {
            return true
        }
        return false
    }
}

private extension Manifest {
    var libraryProductNames: [String] {
        products
            .compactMap { product in
                guard product.type.isLibrary else { return nil }
                return product.name
            }
    }

    func filterPlatforms(to userSpecifiedPlatforms: [TargetPlatform]) -> [TargetPlatform] {
        let supported = userSpecifiedPlatforms.nonEmpty ?? TargetPlatform.allCases.filter { $0 != .maccatalyst }

        guard let packagePlatforms = platforms.nonEmpty else {
            return supported
        }

        let target = packagePlatforms
            .compactMap { platform -> [TargetPlatform]? in
                supported.filter { $0.platformName == platform.platformName }
            }
            .flatMap { $0 }

        return target
    }
}
