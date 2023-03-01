import ArgumentParser
import Basics
import Build
import Foundation
import PackageGraph
import PackageLoading
import PackageModel
import SPMBuildCore
import TSCBasic
import Workspace
import Xcodeproj

struct PackageInfo {
    let config: Config
    let platforms: [Platform]
    let productNames: [String]
    let graph: PackageGraph
    let manifest: Manifest
    let workspace: Workspace

    init(config: Config) throws {
        self.config = config

        let root = AbsolutePath(config.packageDirectory.path)

        workspace = try Workspace(forRootPackage: root)
        graph = try workspace.loadPackageGraph(rootPath: root, observabilityScope: ObservabilitySystem.shared.topScope)

        guard let manifest = graph.rootPackages.first?.manifest else {
            throw PackageValidationError.missingManifest
        }
        self.manifest = manifest

        platforms = manifest.filterPlatforms(to: config.options.platforms)
        productNames = manifest.filterProductNames(to: config.options.products)

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

    func listProducts() {
        let productNames = manifest.libraryProductNames.sorted()
        logger.log("Available \(manifest.displayName) products:\n    \(productNames.joined(separator: "\n    "))")
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
    case missingManifest
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
        case .missingManifest:
            return "No manifest to create XCFrameworks for were found"
        case .missingProducts:
            return "No products to create XCFrameworks for were found"
        }
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

    func filterPlatforms(to userSpecifiedPlatforms: [Platform]) -> [Platform] {
        let supported = userSpecifiedPlatforms.nonEmpty ?? Platform.allCases.filter { $0 != .maccatalyst }

        guard let packagePlatforms = platforms.nonEmpty else {
            return supported
        }

        let target = packagePlatforms
            .compactMap { platform -> [Platform]? in
                supported.filter { $0.platformName == platform.platformName }
            }
            .flatMap { $0 }

        return target
    }

    func filterProductNames(to userSpecifiedProductNames: [String]) -> [String] {
        libraryProductNames.filter { productName in
            userSpecifiedProductNames.contains(productName)
        }
    }
}
